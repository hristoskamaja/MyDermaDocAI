"""GET /api/analyses/<id>/pdf/ - owner-only PDF summary, in either language."""

import shutil
import tempfile

from django.contrib.auth import get_user_model
from django.core.files.base import ContentFile
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from analyses.models import Analysis
from core.models import ConditionRecommendation, Recommendation, SkinCondition

User = get_user_model()


class AnalysisPdfTests(TestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.media = tempfile.mkdtemp()
        cls.override = override_settings(MEDIA_ROOT=cls.media)
        cls.override.enable()

    @classmethod
    def tearDownClass(cls):
        cls.override.disable()
        shutil.rmtree(cls.media, ignore_errors=True)
        super().tearDownClass()

    def setUp(self):
        self.owner = User.objects.create_user(
            username="o@example.com", email="o@example.com", password="pw-123456", full_name="Owner")
        self.other = User.objects.create_user(
            username="x@example.com", email="x@example.com", password="pw-123456", full_name="Other")

        condition = SkinCondition.objects.create(
            key="acne", name="Акни", severity="LOW",
            description="Опис на акни.", description_en="About acne.",
            symptoms="Симптоми.", symptoms_en="Symptoms.",
        )
        rec = Recommendation.objects.create(
            type="SELF_CARE", name="Gentle care", name_mk="Нежна нега",
            description="Wash gently.", description_mk="Мијте нежно.",
        )
        ConditionRecommendation.objects.create(condition=condition, recommendation=rec)

        self.analysis = Analysis.objects.create(
            analysis_key="SK-PDFTEST1", user=self.owner, condition=condition, confidence=0.88)
        # An unreadable image must not break the PDF, so use plain bytes.
        self.analysis.image.save("spot.png", ContentFile(b"not-really-an-image"), save=True)

        self.client = APIClient()

    def url(self, analysis_id=None, lang=None):
        base = f"/api/analyses/{analysis_id or self.analysis.id}/pdf/"
        return f"{base}?lang={lang}" if lang else base

    def test_owner_downloads_a_pdf_in_both_languages(self):
        self.client.force_authenticate(self.owner)
        for lang in ("en", "mk"):
            response = self.client.get(self.url(lang=lang))
            self.assertEqual(response.status_code, 200, lang)
            self.assertEqual(response["Content-Type"], "application/pdf")
            self.assertIn("SK-PDFTEST1.pdf", response["Content-Disposition"])
            self.assertTrue(response.content.startswith(b"%PDF"), lang)

    def test_defaults_to_macedonian_without_lang(self):
        self.client.force_authenticate(self.owner)
        response = self.client.get(self.url())
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.content.startswith(b"%PDF"))

    def test_another_users_analysis_is_forbidden(self):
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.get(self.url()).status_code, 403)

    def test_unknown_analysis_is_404(self):
        self.client.force_authenticate(self.owner)
        self.assertEqual(self.client.get(self.url(analysis_id=999999)).status_code, 404)

    def test_requires_login(self):
        self.assertEqual(self.client.get(self.url()).status_code, 401)
