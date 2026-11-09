"""
Tests for the English text of conditions: the seed command ships real
English, and fill_missing_translations only touches empty fields.
Gemini is mocked - the real API is never called.
"""

from io import StringIO
from unittest import mock

from django.core.management import call_command
from django.test import TestCase

from core.models import SkinCondition


class SeedEnglishTests(TestCase):
    def test_seed_fills_english_for_all_eight_conditions(self):
        call_command("seed_skin_conditions", stdout=StringIO())

        conditions = SkinCondition.objects.all()
        self.assertEqual(conditions.count(), 8)
        for condition in conditions:
            self.assertTrue(condition.description_en, condition.key)
            self.assertTrue(condition.symptoms_en, condition.key)
            self.assertTrue(condition.treatment_overview_en, condition.key)
            # English must really be English, not a copy of the Macedonian.
            self.assertNotEqual(condition.description_en, condition.description)

    def test_seed_is_idempotent(self):
        call_command("seed_skin_conditions", stdout=StringIO())
        call_command("seed_skin_conditions", stdout=StringIO())
        self.assertEqual(SkinCondition.objects.count(), 8)


class FillMissingTranslationsCommandTests(TestCase):
    def run_command(self, *args):
        out = StringIO()
        call_command("fill_missing_translations", *args, stdout=out)
        return out.getvalue()

    def test_nothing_to_do_when_seeded(self):
        call_command("seed_skin_conditions", stdout=StringIO())
        with mock.patch("core.services.translation.translate_fields_to_english") as translate:
            output = self.run_command()
        translate.assert_not_called()
        self.assertIn("Nothing to fill", output)

    def test_fills_only_empty_fields(self):
        SkinCondition.objects.create(
            key="a", name="A", description="Опис", symptoms="Симптоми",
            symptoms_en="Already English",
        )
        fake = {"description": "Description"}
        with mock.patch(
            "core.services.translation.translate_fields_to_english", return_value=fake
        ) as translate:
            self.run_command()

        # Only the empty field was sent for translation.
        translate.assert_called_once_with({"description": "Опис"})
        condition = SkinCondition.objects.get(key="a")
        self.assertEqual(condition.description_en, "Description")
        self.assertEqual(condition.symptoms_en, "Already English")

    def test_dry_run_calls_nothing(self):
        SkinCondition.objects.create(key="a", name="A", description="Опис")
        with mock.patch("core.services.translation.translate_fields_to_english") as translate:
            output = self.run_command("--dry-run")
        translate.assert_not_called()
        self.assertIn("Missing English text: a", output)

    def test_failed_translation_is_reported_not_raised(self):
        SkinCondition.objects.create(key="a", name="A", description="Опис")
        with mock.patch("core.services.translation.translate_fields_to_english", return_value={}):
            output = self.run_command()
        self.assertIn("Could not translate: a", output)
        self.assertFalse(SkinCondition.objects.get(key="a").description_en)

    def test_missing_api_key_is_logged(self):
        from core.services.translation import translate_fields_to_english

        with mock.patch.dict("os.environ", {"GEMINI_API_KEY": ""}):
            with self.assertLogs("core.services.translation", level="WARNING") as logs:
                result = translate_fields_to_english({"description": "Опис"})
        self.assertEqual(result, {})
        self.assertIn("GEMINI_API_KEY", logs.output[0])
