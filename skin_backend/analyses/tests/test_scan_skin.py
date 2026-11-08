"""
POST /api/analyses/scan-skin/ - the AI model and Gemini are ALWAYS mocked;
neither the real model file nor the real API is touched.
"""

import io
import shutil
import tempfile
from unittest import mock

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from PIL import Image
from rest_framework.test import APIClient

from analyses.models import Analysis
from analyses.services.skin_model_service import SkinModelPredictionError
from core.models import SkinCondition

User = get_user_model()
URL = "/api/analyses/scan-skin/"
PREDICT = "analyses.views.predict_skin_condition"
RECS = "analyses.views.generate_recommendations_only_if_missing"


def png_upload():
    buffer = io.BytesIO()
    Image.new("RGB", (8, 8), (200, 150, 140)).save(buffer, format="PNG")
    return SimpleUploadedFile("spot.png", buffer.getvalue(), content_type="image/png")


def prediction(key="acne", confidence=0.91, low=False):
    return {
        "condition_key": key,
        "confidence": confidence,
        "is_low_confidence": low,
    }


class ScanSkinTests(TestCase):
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
        self.user = User.objects.create_user(
            username="scan@example.com", email="scan@example.com",
            password="pw-123456", full_name="Scan User",
        )
        self.condition = SkinCondition.objects.create(key="acne", name="Acne", severity="LOW")
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def post(self, **kwargs):
        return self.client.post(URL, {"image": png_upload()}, format="multipart", **kwargs)

    def test_requires_login(self):
        response = APIClient().post(URL, {"image": png_upload()}, format="multipart")
        self.assertEqual(response.status_code, 401)

    def test_image_is_required(self):
        with mock.patch(PREDICT) as predict:
            response = self.client.post(URL, {}, format="multipart")
        self.assertEqual(response.status_code, 400)
        predict.assert_not_called()
        self.assertEqual(Analysis.objects.count(), 0)

    def test_success_creates_analysis_for_the_user(self):
        with mock.patch(PREDICT, return_value=prediction()), \
                mock.patch(RECS, return_value={"generated": False}) as recs:
            response = self.post()

        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual(body["analysis"]["condition"]["key"], "acne")
        self.assertEqual(body["prediction"]["condition_key"], "acne")
        recs.assert_called_once_with(self.condition)

        analysis = Analysis.objects.get()
        self.assertEqual(analysis.user, self.user)
        self.assertEqual(analysis.condition, self.condition)
        self.assertAlmostEqual(analysis.confidence, 0.91)
        self.assertFalse(analysis.is_low_confidence)

    def test_low_confidence_flag_is_stored(self):
        with mock.patch(PREDICT, return_value=prediction(confidence=0.31, low=True)), \
                mock.patch(RECS, return_value={}):
            response = self.post()
        self.assertEqual(response.status_code, 201)
        self.assertTrue(Analysis.objects.get().is_low_confidence)

    def test_model_failure_is_a_502_and_saves_nothing(self):
        with mock.patch(PREDICT, side_effect=SkinModelPredictionError("model missing")), \
                mock.patch(RECS) as recs:
            response = self.post()
        self.assertEqual(response.status_code, 502)
        self.assertEqual(response.json()["detail"], "AI prediction failed.")
        recs.assert_not_called()
        self.assertEqual(Analysis.objects.count(), 0)

    def test_unknown_condition_key_is_a_404(self):
        with mock.patch(PREDICT, return_value=prediction(key="not_seeded")), \
                mock.patch(RECS) as recs:
            response = self.post()
        self.assertEqual(response.status_code, 404)
        recs.assert_not_called()
        self.assertEqual(Analysis.objects.count(), 0)
