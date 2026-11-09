"""
English text never depends on Gemini: ?lang=en returns the stored *_en text,
and falls back to the Macedonian original when an _en field is still empty.
(The recommendation serializer's fallback is covered in analyses/tests.)
"""

from django.test import RequestFactory, TestCase
from rest_framework.request import Request

from analyses.serializers import SkinConditionSerializer
from core.models import SkinCondition


def serialize(condition, lang=None):
    path = f"/x/?lang={lang}" if lang else "/x/"
    request = Request(RequestFactory().get(path))
    return SkinConditionSerializer(condition, context={"request": request}).data


class ConditionLanguageFallbackTests(TestCase):
    def setUp(self):
        self.full = SkinCondition.objects.create(
            key="acne", name="Acne",
            description="Опис", description_en="Description",
            symptoms="Симптоми", symptoms_en="Symptoms",
            treatment_overview="Преглед", treatment_overview_en="Overview",
        )
        self.partial = SkinCondition.objects.create(
            key="eczema", name="Eczema",
            description="Опис 2", description_en="Description 2",
            symptoms="Симптоми 2", symptoms_en="",          # translation missing
            treatment_overview="Преглед 2", treatment_overview_en=None,
        )

    def test_english_returns_the_english_text(self):
        data = serialize(self.full, "en")
        self.assertEqual(
            (data["description"], data["symptoms"], data["treatment_overview"]),
            ("Description", "Symptoms", "Overview"),
        )

    def test_macedonian_returns_the_original(self):
        data = serialize(self.full, "mk")
        self.assertEqual(data["description"], "Опис")
        self.assertEqual(data["symptoms"], "Симптоми")

    def test_macedonian_is_the_default_without_lang(self):
        self.assertEqual(serialize(self.full)["description"], "Опис")

    def test_missing_english_falls_back_per_field(self):
        data = serialize(self.partial, "en")
        self.assertEqual(data["description"], "Description 2")   # has _en
        self.assertEqual(data["symptoms"], "Симптоми 2")          # empty string -> fallback
        self.assertEqual(data["treatment_overview"], "Преглед 2")  # None -> fallback

    def test_unknown_lang_value_behaves_like_macedonian(self):
        self.assertEqual(serialize(self.full, "de")["description"], "Опис")
