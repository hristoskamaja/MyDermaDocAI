"""
Tests for the richer recommendations: prompt/validation, fallback handling,
caching/replacing, the regenerate command and the localized serializer.

Gemini is ALWAYS mocked here - the real API is never called.
"""

import json
from io import StringIO
from unittest import mock

from django.core.management import call_command
from django.test import RequestFactory, TestCase
from google.genai.errors import APIError
from rest_framework.request import Request

from analyses.services import gemini_service
from analyses.services.recommendation_store import (
    condition_needs_generation,
    generate_recommendations_only_if_missing,
    replace_condition_recommendations,
)
from core.models import ConditionRecommendation, Recommendation, SkinCondition
from core.serializers import LocalizedRecommendationSerializer


def make_item(index, rec_type="SELF_CARE", **overrides):
    item = {
        "type": rec_type,
        "name": f"Title {index}",
        "name_mk": f"Наслов {index}",
        "description": f"Do this gentle thing number {index} every day, calmly and carefully.",
        "description_mk": f"Направи го ова нежно нешто број {index} секој ден, мирно и внимателно.",
        "what_to_avoid": f"Avoid thing {index}.",
        "what_to_avoid_mk": f"Избегнувај нешто {index}.",
        "when_to_see_doctor": f"See a doctor if thing {index} changes.",
        "when_to_see_doctor_mk": f"Посети лекар ако нешто {index} се промени.",
    }
    item.update(overrides)
    return item


def good_gemini_items():
    return [
        make_item(1, "SELF_CARE"),
        make_item(2, "SELF_CARE"),
        make_item(3, "LIFESTYLE"),
        make_item(4, "LIFESTYLE"),
        make_item(5, "MEDICAL_CONSULT"),
        make_item(6, "SELF_CARE"),
    ]


class FakeResponse:
    def __init__(self, text):
        self.text = text


class FakeClient:
    """Stands in for genai.Client; returns `payload` or raises `error`."""

    def __init__(self, payload=None, error=None):
        self.payload = payload
        self.error = error
        self.calls = 0
        self.models = self

    def generate_content(self, model, contents, config):
        self.calls += 1
        if self.error:
            raise self.error
        return FakeResponse(json.dumps(self.payload))


def patch_gemini(client):
    return mock.patch.object(gemini_service, "_make_client", return_value=client)


ENV = mock.patch.dict("os.environ", {"GEMINI_API_KEY": "test-key"})


class ValidateRecommendationsTests(TestCase):
    def test_keeps_all_four_parts_and_caps_at_seven(self):
        items = [make_item(i, ["SELF_CARE", "LIFESTYLE"][i % 2]) for i in range(10)]
        items.append(make_item(99, "MEDICAL_CONSULT"))
        result = gemini_service.validate_recommendations(items)

        self.assertLessEqual(len(result), gemini_service.MAX_RECOMMENDATIONS)
        self.assertTrue(any(r["type"] == "MEDICAL_CONSULT" for r in result))
        for rec in result:
            self.assertTrue(rec["what_to_avoid"])
            self.assertTrue(rec["when_to_see_doctor_mk"])

    def test_per_type_cap(self):
        items = [make_item(i, "SELF_CARE") for i in range(6)]
        result = gemini_service.validate_recommendations(items)
        self_care = [r for r in result if r["type"] == "SELF_CARE"]
        self.assertEqual(len(self_care), gemini_service.MAX_PER_TYPE["SELF_CARE"])

    def test_drops_too_short_description(self):
        result = gemini_service.validate_recommendations(
            [make_item(1, description="Too short.")]
        )
        # Only the mandatory consult remains.
        self.assertEqual([r["type"] for r in result], ["MEDICAL_CONSULT"])

    def test_drops_items_with_a_dose(self):
        result = gemini_service.validate_recommendations(
            [make_item(1, description="Take 500 mg of something every single day for a week.")]
        )
        self.assertEqual([r["type"] for r in result], ["MEDICAL_CONSULT"])

    def test_missing_macedonian_falls_back_to_english(self):
        result = gemini_service.validate_recommendations(
            [make_item(1, name_mk="", what_to_avoid_mk=None)]
        )
        first = result[0]
        self.assertEqual(first["name_mk"], first["name"])
        self.assertEqual(first["what_to_avoid_mk"], first["what_to_avoid"])

    def test_always_adds_medical_consult(self):
        result = gemini_service.validate_recommendations([make_item(1, "SELF_CARE")])
        self.assertTrue(any(r["type"] == "MEDICAL_CONSULT" for r in result))

    def test_prompt_mentions_all_parts_and_safety_rules(self):
        prompt = gemini_service.build_recommendation_prompt("Nevus", "LOW")
        for needle in ("what_to_avoid_mk", "when_to_see_doctor_mk", "MEDICAL_CONSULT", "dosages"):
            self.assertIn(needle, prompt)


class GenerateDetailedTests(TestCase):
    def test_success_is_not_fallback(self):
        with ENV, patch_gemini(FakeClient(good_gemini_items())):
            result = gemini_service.generate_recommendations_detailed("Nevus", "LOW")
        self.assertFalse(result["is_fallback"])
        self.assertGreaterEqual(len(result["items"]), gemini_service.MIN_RECOMMENDATIONS)

    def test_api_error_gives_fallback(self):
        error = APIError(500, {"error": {"message": "boom"}})
        with ENV, patch_gemini(FakeClient(error=error)):
            result = gemini_service.generate_recommendations_detailed("Nevus", "LOW")
        self.assertTrue(result["is_fallback"])
        self.assertTrue(any(i["type"] == "MEDICAL_CONSULT" for i in result["items"]))

    def test_quota_error_retries_then_falls_back(self):
        error = APIError(429, {"error": {"message": "quota"}})
        client = FakeClient(error=error)
        with ENV, patch_gemini(client), mock.patch.object(gemini_service.time, "sleep"):
            result = gemini_service.generate_recommendations_detailed("Nevus", "LOW")
        self.assertTrue(result["is_fallback"])
        self.assertEqual(client.calls, gemini_service._MAX_ATTEMPTS)

    def test_too_few_items_is_marked_incomplete(self):
        with ENV, patch_gemini(FakeClient([make_item(1), make_item(2, "MEDICAL_CONSULT")])):
            result = gemini_service.generate_recommendations_detailed("Nevus", "LOW")
        self.assertTrue(result["is_fallback"])

    def test_invalid_json_gives_fallback(self):
        class BadClient(FakeClient):
            def generate_content(self, model, contents, config):
                return FakeResponse("not json")

        with ENV, patch_gemini(BadClient()):
            result = gemini_service.generate_recommendations_detailed("Nevus", "LOW")
        self.assertTrue(result["is_fallback"])


class RecommendationStoreTests(TestCase):
    def setUp(self):
        self.condition = SkinCondition.objects.create(key="nevus", name="Nevus", severity="LOW")

    def test_first_scan_saves_rich_recommendations(self):
        with ENV, patch_gemini(FakeClient(good_gemini_items())):
            info = generate_recommendations_only_if_missing(self.condition)
        self.assertTrue(info["generated"])
        self.assertEqual(info["count"], 6)
        self.assertFalse(condition_needs_generation(self.condition))
        rec = Recommendation.objects.first()
        self.assertTrue(rec.what_to_avoid)
        self.assertTrue(rec.when_to_see_doctor_mk)

    def test_second_scan_does_not_call_gemini(self):
        client = FakeClient(good_gemini_items())
        with ENV, patch_gemini(client):
            generate_recommendations_only_if_missing(self.condition)
            generate_recommendations_only_if_missing(self.condition)
        self.assertEqual(client.calls, 1)

    def test_fallback_is_not_locked_in(self):
        failing = FakeClient(error=APIError(500, {"error": {"message": "boom"}}))
        with ENV, patch_gemini(failing):
            first = generate_recommendations_only_if_missing(self.condition)
        self.assertFalse(first["generated"])
        self.assertEqual(first["count"], 2)
        self.assertTrue(condition_needs_generation(self.condition))

        # Gemini still failing: nothing is duplicated.
        with ENV, patch_gemini(failing):
            generate_recommendations_only_if_missing(self.condition)
        self.assertEqual(ConditionRecommendation.objects.count(), 2)

        # Gemini works again on a later scan: the short list is replaced.
        with ENV, patch_gemini(FakeClient(good_gemini_items())):
            third = generate_recommendations_only_if_missing(self.condition)
        self.assertTrue(third["generated"])
        self.assertEqual(ConditionRecommendation.objects.filter(condition=self.condition).count(), 6)
        self.assertFalse(Recommendation.objects.filter(is_fallback=True).exists())
        # Old fallback rows are cleaned up, not orphaned.
        self.assertEqual(Recommendation.objects.count(), 6)

    def test_replace_keeps_rows_used_by_other_conditions(self):
        other = SkinCondition.objects.create(key="melanoma", name="Melanoma", severity="HIGH")
        shared = Recommendation.objects.create(name="Shared", description="x" * 50, type="SELF_CARE")
        ConditionRecommendation.objects.create(condition=self.condition, recommendation=shared)
        ConditionRecommendation.objects.create(condition=other, recommendation=shared)

        replace_condition_recommendations(self.condition, good_gemini_items())

        self.assertTrue(Recommendation.objects.filter(pk=shared.pk).exists())
        self.assertTrue(ConditionRecommendation.objects.filter(condition=other, recommendation=shared).exists())

    def test_replace_with_nothing_changes_nothing(self):
        replace_condition_recommendations(self.condition, good_gemini_items())
        replace_condition_recommendations(self.condition, [])
        self.assertEqual(ConditionRecommendation.objects.filter(condition=self.condition).count(), 6)


class RegenerateCommandTests(TestCase):
    def setUp(self):
        self.condition = SkinCondition.objects.create(key="nevus", name="Nevus", severity="LOW")
        old = Recommendation.objects.create(name="Old", description="short", type="SELF_CARE")
        ConditionRecommendation.objects.create(condition=self.condition, recommendation=old)

    def run_command(self, *args):
        out = StringIO()
        call_command("regenerate_recommendations", *args, stdout=out)
        return out.getvalue()

    def test_replaces_cached_recommendations(self):
        with ENV, patch_gemini(FakeClient(good_gemini_items())):
            output = self.run_command("--condition", "nevus")
        self.assertIn("replaced with 6", output)
        names = set(
            Recommendation.objects.filter(condition_recommendations__condition=self.condition)
            .values_list("name", flat=True)
        )
        self.assertNotIn("Old", names)
        self.assertEqual(len(names), 6)

    def test_keeps_old_ones_when_gemini_fails(self):
        failing = FakeClient(error=APIError(500, {"error": {"message": "boom"}}))
        with ENV, patch_gemini(failing):
            output = self.run_command("--condition", "nevus")
        self.assertIn("kept the existing", output)
        self.assertTrue(Recommendation.objects.filter(name="Old").exists())

    def test_unknown_key_errors(self):
        from django.core.management.base import CommandError

        with self.assertRaises(CommandError):
            self.run_command("--condition", "does_not_exist")


class LocalizedSerializerTests(TestCase):
    def serialize(self, lang, rec):
        request = Request(RequestFactory().get("/", {"lang": lang}))
        return LocalizedRecommendationSerializer(rec, context={"request": request}).data

    def test_both_languages_and_all_parts(self):
        rec = Recommendation.objects.create(
            name="Sun care", name_mk="Заштита од сонце",
            description="Do it.", description_mk="Направи го.",
            what_to_avoid="Sunbeds.", what_to_avoid_mk="Солариуми.",
            when_to_see_doctor="If it grows.", when_to_see_doctor_mk="Ако расте.",
            type="SELF_CARE",
        )
        en = self.serialize("en", rec)
        mk = self.serialize("mk", rec)
        self.assertEqual(en["what_to_avoid"], "Sunbeds.")
        self.assertEqual(mk["when_to_see_doctor"], "Ако расте.")
        self.assertEqual(mk["name"], "Заштита од сонце")

    def test_old_rows_return_null_for_new_parts(self):
        rec = Recommendation.objects.create(name="Old", description="x", type="SELF_CARE")
        data = self.serialize("en", rec)
        self.assertIsNone(data["what_to_avoid"])
        self.assertIsNone(data["when_to_see_doctor"])
