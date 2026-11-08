"""
Tracking endpoints: ownership, upsert, photos, insights, Ask AI, scans.
Gemini is ALWAYS mocked - the real API is never called.
"""

import io
import json
import os
import random
import shutil
import tempfile
from datetime import timedelta
from unittest import mock

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.utils import timezone
from PIL import Image
from rest_framework.test import APIClient

from analyses.models import Analysis
from tracking.models import DailyLog, InsightCache, SkincareProduct, TrackedScan, private_photo_storage

User = get_user_model()
GEMINI = "tracking.services.insights_text._call_gemini"


def png_upload(name="selfie.png"):
    buffer = io.BytesIO()
    Image.new("RGB", (8, 8), (200, 150, 140)).save(buffer, format="PNG")
    return SimpleUploadedFile(name, buffer.getvalue(), content_type="image/png")


def make_user(email):
    return User.objects.create_user(username=email, email=email, password="pw-123456", full_name="Test User")


def checkin(day_offset=0, **overrides):
    day = timezone.localdate() - timedelta(days=day_offset)
    body = {"date": day.isoformat(), "skin_rating": 3, "acne_severity": 1}
    body.update(overrides)
    return body


class TrackingTestCase(TestCase):
    def setUp(self):
        # Keep test photos out of the real private folder.
        self.photo_dir = tempfile.mkdtemp()
        self._old_location = private_photo_storage._location
        private_photo_storage._location = self.photo_dir
        for cached in ("base_location", "location"):
            private_photo_storage.__dict__.pop(cached, None)

        self.user = make_user("a@example.com")
        self.other = make_user("b@example.com")
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def tearDown(self):
        private_photo_storage._location = self._old_location
        for cached in ("base_location", "location"):
            private_photo_storage.__dict__.pop(cached, None)
        shutil.rmtree(self.photo_dir, ignore_errors=True)

    def photo_files(self):
        folder = os.path.join(self.photo_dir, "tracking")
        return os.listdir(folder) if os.path.isdir(folder) else []

    def seed_dairy_history(self, user=None, days=42):
        """Dairy every 3rd day, acne higher the day after."""
        user = user or self.user
        rng = random.Random(7)
        today = timezone.localdate()
        dairy_days = {i for i in range(days) if i % 3 == 0}
        for i in range(days):
            DailyLog.objects.create(
                user=user, date=today - timedelta(days=days - 1 - i), skin_rating=3,
                acne_severity=min(3, (2 if (i - 1) in dairy_days else 0) + rng.choice([0, 1])),
                food_tags=["dairy"] if i in dairy_days else [],
                sleep_hours=rng.choice([5, 7, 8]), stress=rng.randint(2, 6),
            )


class AuthAndOwnershipTests(TrackingTestCase):
    def test_all_endpoints_require_auth(self):
        anon = APIClient()
        for url in ("/api/tracking/logs/", "/api/tracking/today/", "/api/tracking/insights/",
                    "/api/tracking/reminders/", "/api/tracking/products/"):
            self.assertEqual(anon.get(url).status_code, 401, url)

    def test_other_users_data_is_invisible(self):
        day = timezone.localdate()
        DailyLog.objects.create(user=self.other, date=day, skin_rating=2, acne_severity=2, notes="private")
        product = SkincareProduct.objects.create(user=self.other, name="Secret", step_type="treat")

        self.assertEqual(self.client.get("/api/tracking/logs/").json(), [])
        self.assertEqual(self.client.get(f"/api/tracking/logs/{day}/").status_code, 404)
        self.assertEqual(self.client.delete(f"/api/tracking/logs/{day}/").status_code, 404)
        self.assertEqual(self.client.get(f"/api/tracking/products/{product.id}/").status_code, 404)
        self.assertEqual(self.client.delete(f"/api/tracking/products/{product.id}/").status_code, 404)
        self.assertTrue(DailyLog.objects.filter(user=self.other).exists())


class LogTests(TrackingTestCase):
    def test_upsert_by_date(self):
        first = self.client.post("/api/tracking/logs/", checkin(sleep_hours=7, food_tags=["dairy"]), format="json")
        self.assertEqual(first.status_code, 201)
        second = self.client.post("/api/tracking/logs/", checkin(acne_severity=3), format="json")
        self.assertEqual(second.status_code, 200)
        self.assertEqual(DailyLog.objects.filter(user=self.user).count(), 1)
        log = DailyLog.objects.get(user=self.user)
        self.assertEqual(log.acne_severity, 3)
        self.assertEqual(log.food_tags, ["dairy"])  # untouched by the partial update

    def test_put_by_date_in_url(self):
        day = timezone.localdate()
        response = self.client.put(f"/api/tracking/logs/{day}/", {"skin_rating": 4, "acne_severity": 0}, format="json")
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["date"], day.isoformat())

    def test_validation(self):
        bad_payloads = [
            checkin(acne_severity=4), checkin(skin_rating=0), checkin(stress=11),
            checkin(affected_areas=["elbow"]), checkin(food_tags=["pizza"]),
            checkin(sleep_quality="amazing"), checkin(sleep_hours=30),
            {"date": (timezone.localdate() + timedelta(days=10)).isoformat(), "skin_rating": 3, "acne_severity": 1},
            {"skin_rating": 3, "acne_severity": 1},  # no date
        ]
        for payload in bad_payloads:
            self.assertEqual(self.client.post("/api/tracking/logs/", payload, format="json").status_code, 400, payload)
        self.assertFalse(DailyLog.objects.exists())

    def test_list_by_range(self):
        for offset in (0, 2, 10, 40):
            self.client.post("/api/tracking/logs/", checkin(offset), format="json")
        today = timezone.localdate()
        response = self.client.get("/api/tracking/logs/", {"from": (today - timedelta(days=5)).isoformat()})
        self.assertEqual(len(response.json()), 2)
        everything = self.client.get("/api/tracking/logs/", {"from": (today - timedelta(days=60)).isoformat()})
        self.assertEqual(len(everything.json()), 4)
        self.assertEqual(self.client.get("/api/tracking/logs/", {"from": "nope"}).status_code, 400)

    def test_delete(self):
        day = timezone.localdate()
        self.client.post("/api/tracking/logs/", checkin(), format="json")
        self.assertEqual(self.client.delete(f"/api/tracking/logs/{day}/").status_code, 204)
        self.assertEqual(self.client.get(f"/api/tracking/logs/{day}/").status_code, 404)

    def test_cycle_is_opt_in(self):
        self.client.post("/api/tracking/logs/", checkin(cycle_phase="luteal"), format="json")
        self.assertIsNone(DailyLog.objects.get().cycle_phase)

        self.client.put("/api/tracking/reminders/", {"cycle_tracking_enabled": True}, format="json")
        self.client.post("/api/tracking/logs/", checkin(cycle_phase="luteal"), format="json")
        self.assertEqual(DailyLog.objects.get().cycle_phase, "luteal")

    def test_routine_only_accepts_own_products(self):
        mine = SkincareProduct.objects.create(user=self.user, name="Mine", step_type="cleanse")
        theirs = SkincareProduct.objects.create(user=self.other, name="Theirs", step_type="cleanse")
        ok = self.client.post("/api/tracking/logs/", checkin(routine_am=[mine.id]), format="json")
        self.assertEqual(ok.status_code, 201)
        bad = self.client.post("/api/tracking/logs/", checkin(1, routine_pm=[theirs.id]), format="json")
        self.assertEqual(bad.status_code, 400)


class PhotoTests(TrackingTestCase):
    def upload(self, **extra):
        data = {k: str(v) for k, v in checkin().items()}
        data.update(extra)
        data["photo"] = png_upload()
        return self.client.post("/api/tracking/logs/", data, format="multipart")

    def test_photo_is_private_uuid_named_and_owner_only(self):
        response = self.upload()
        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertTrue(body["has_photo"])
        self.assertTrue(body["photo_url"].endswith(f"/api/tracking/logs/{body['date']}/photo/"))

        name = DailyLog.objects.get().photo.name
        self.assertNotIn("selfie", name)
        self.assertRegex(name, r"^tracking/[0-9a-f]{32}\.png$")
        self.assertEqual(len(self.photo_files()), 1)

        url = f"/api/tracking/logs/{body['date']}/photo/"
        mine = self.client.get(url)
        self.assertEqual(mine.status_code, 200)
        self.assertEqual(mine["Content-Type"], "image/png")
        self.assertIn("private", mine["Cache-Control"])

        stranger = APIClient()
        stranger.force_authenticate(self.other)
        self.assertEqual(stranger.get(url).status_code, 404)
        self.assertEqual(APIClient().get(url).status_code, 401)

    def test_photo_is_not_under_public_media(self):
        self.upload()
        from django.conf import settings
        self.assertFalse(str(private_photo_storage.location).startswith(str(settings.MEDIA_ROOT)))

    def test_replacing_and_removing_deletes_old_file(self):
        self.upload()
        first = self.photo_files()
        self.upload()
        self.assertEqual(len(self.photo_files()), 1)
        self.assertNotEqual(self.photo_files(), first)

        day = timezone.localdate()
        self.client.put(f"/api/tracking/logs/{day}/", {"remove_photo": True}, format="json")
        self.assertEqual(self.photo_files(), [])
        self.assertFalse(DailyLog.objects.get().photo)

    def test_deleting_log_and_delete_all_remove_files(self):
        self.upload()
        day = timezone.localdate()
        self.client.delete(f"/api/tracking/logs/{day}/")
        self.assertEqual(self.photo_files(), [])

        self.upload()
        self.assertEqual(len(self.photo_files()), 1)
        self.assertEqual(self.client.delete("/api/tracking/data/").status_code, 400)  # needs confirm
        self.assertEqual(len(self.photo_files()), 1)
        self.assertEqual(self.client.delete("/api/tracking/data/?confirm=true").status_code, 200)
        self.assertEqual(self.photo_files(), [])


class StatusTests(TrackingTestCase):
    def test_today_status_and_streak(self):
        self.assertEqual(self.client.get("/api/tracking/today/").json()["streak"], {"current": 0, "best": 0})
        for offset in (0, 1, 2, 5, 6, 7, 8):
            self.client.post("/api/tracking/logs/", checkin(offset), format="json")
        body = self.client.get("/api/tracking/today/").json()
        self.assertTrue(body["logged_today"])
        self.assertEqual(body["streak"], {"current": 3, "best": 4})
        self.assertEqual(body["total_check_ins"], 7)

    def test_week_strip(self):
        self.client.post("/api/tracking/logs/", checkin(acne_severity=3), format="json")
        days = self.client.get("/api/tracking/week/").json()["days"]
        self.assertEqual(len(days), 7)
        today = next(d for d in days if d["is_today"])
        self.assertEqual(today["level"], "severe")
        self.assertTrue(all(d["level"] == "none" for d in days if not d["is_today"]))

    def test_timeline(self):
        self.client.put("/api/tracking/reminders/", {"cycle_tracking_enabled": True}, format="json")
        for offset in (0, 1, 2):
            self.client.post("/api/tracking/logs/", checkin(offset, cycle_phase="luteal", sleep_hours=6, stress=5), format="json")
        body = self.client.get("/api/tracking/timeline/").json()
        self.assertEqual(len(body["points"]), 3)
        self.assertEqual(len(body["cycle_phases"]), 1)
        self.assertEqual(body["cycle_phases"][0]["phase"], "luteal")

    def test_correlation(self):
        for offset in range(8):
            self.client.post("/api/tracking/logs/", checkin(offset, sleep_hours=5 + offset * 0.5, acne_severity=offset % 4), format="json")
        body = self.client.get("/api/tracking/correlation/?x=sleep&y=acne").json()
        self.assertEqual(body["n"], 8)
        self.assertIsNotNone(body["r"])
        self.assertEqual(self.client.get("/api/tracking/correlation/?x=sleep&y=sleep").status_code, 400)
        self.assertEqual(self.client.get("/api/tracking/correlation/?x=sleep&y=mood").status_code, 400)

    def test_weekly_report(self):
        for offset, severity in ((0, 0), (1, 0), (8, 2), (9, 2)):
            self.client.post("/api/tracking/logs/", checkin(offset, acne_severity=severity, sleep_hours=7, stress=4), format="json")
        body = self.client.get("/api/tracking/weekly-report/?lang=en").json()
        self.assertEqual(body["avg_severity"], 0)
        self.assertEqual(body["avg_severity_last_week"], 2)
        self.assertEqual(body["trend"], "calmer")
        self.assertEqual(body["trend_label"], "Calmer")
        self.assertEqual((body["check_ins"], body["check_ins_of"]), (2, 7))
        self.assertEqual(body["avg_sleep"], 7)
        mk = self.client.get("/api/tracking/weekly-report/?lang=mk").json()
        self.assertEqual(mk["trend_label"], "Помирно")


class ProductAndReminderTests(TrackingTestCase):
    def test_product_crud(self):
        created = self.client.post("/api/tracking/products/", {
            "name": "BHA serum", "step_type": "treat", "time_of_day": "PM",
            "frequency": "3x/week", "tags": ["BHA"], "started_on": "2026-01-01",
        }, format="json")
        self.assertEqual(created.status_code, 201)
        pid = created.json()["id"]
        self.assertEqual(self.client.patch(f"/api/tracking/products/{pid}/", {"stopped_on": "2026-02-01"}, format="json").status_code, 200)
        bad = self.client.patch(f"/api/tracking/products/{pid}/", {"stopped_on": "2025-01-01"}, format="json")
        self.assertEqual(bad.status_code, 400)
        self.assertEqual(self.client.post("/api/tracking/products/", {"name": "x", "step_type": "magic"}, format="json").status_code, 400)
        self.assertEqual(len(self.client.get("/api/tracking/products/").json()), 1)
        self.assertEqual(self.client.delete(f"/api/tracking/products/{pid}/").status_code, 204)

    def test_reminders(self):
        defaults = self.client.get("/api/tracking/reminders/").json()
        self.assertFalse(defaults["checkin_enabled"])
        self.assertFalse(defaults["cycle_tracking_enabled"])
        updated = self.client.put("/api/tracking/reminders/", {"checkin_enabled": True, "checkin_time": "21:30", "rescan_weeks": 6}, format="json")
        self.assertEqual(updated.status_code, 200)
        self.assertEqual(self.client.get("/api/tracking/reminders/").json()["checkin_time"], "21:30:00")
        self.assertEqual(self.client.put("/api/tracking/reminders/", {"rescan_weeks": 99}, format="json").status_code, 400)


class InsightsEndpointTests(TrackingTestCase):
    def test_not_enough_data(self):
        with mock.patch(GEMINI) as gemini:
            body = self.client.get("/api/tracking/insights/?lang=en").json()
        self.assertFalse(body["enough_data"])
        self.assertEqual(body["findings"], [])
        gemini.assert_not_called()

    def test_gemini_phrasing_is_used_and_cached(self):
        self.seed_dairy_history()
        reply = lambda prompt, json_output=False: json.dumps({"dairy:1": "Acne tended to be higher the day after dairy in your diary."})
        with mock.patch(GEMINI, side_effect=reply) as gemini:
            first = self.client.get("/api/tracking/insights/?lang=en").json()
            second = self.client.get("/api/tracking/insights/?lang=en").json()
        self.assertEqual(gemini.call_count, 1)  # second call came from the cache
        finding = first["findings"][0]
        self.assertEqual(finding["text_source"], "ai")
        self.assertEqual(second["findings"][0]["text"], finding["text"])
        self.assertEqual(first["featured"]["id"], "dairy:1")
        self.assertIn("not medical advice", first["disclaimer"])
        self.assertEqual(InsightCache.objects.filter(user=self.user).count(), 1)

    def test_prompt_contains_no_raw_notes(self):
        self.seed_dairy_history()
        DailyLog.objects.update(notes="SECRET-NOTE-TEXT")
        with mock.patch(GEMINI, side_effect=RuntimeError("quota")) as gemini:
            self.client.get("/api/tracking/insights/?lang=en")
            self.client.post("/api/tracking/ask/?lang=en", {"question": "Which food affects me most?"}, format="json")
        for call in gemini.call_args_list:
            self.assertNotIn("SECRET-NOTE-TEXT", call.args[0])

    def test_falls_back_to_templates_when_gemini_fails(self):
        self.seed_dairy_history()
        with mock.patch(GEMINI, side_effect=RuntimeError("429 quota")):
            body = self.client.get("/api/tracking/insights/?lang=mk").json()
        finding = body["findings"][0]
        self.assertEqual(finding["text_source"], "template")
        self.assertEqual(finding["text"], finding["template_mk"])
        self.assertFalse(InsightCache.objects.exists())

    def test_unsafe_gemini_text_is_rejected(self):
        self.seed_dairy_history()
        reply = json.dumps({"dairy:1": "Dairy causes acne, so take this medication to fix it."})
        with mock.patch(GEMINI, return_value=reply):
            body = self.client.get("/api/tracking/insights/?lang=en").json()
        self.assertEqual(body["findings"][0]["text_source"], "template")

    def test_insights_are_per_user(self):
        self.seed_dairy_history(self.other)
        with mock.patch(GEMINI, side_effect=RuntimeError):
            body = self.client.get("/api/tracking/insights/").json()
        self.assertFalse(body["enough_data"])


class AskAITests(TrackingTestCase):
    def ask(self, question, **extra):
        return self.client.post("/api/tracking/ask/?lang=en", {"question": question, **extra}, format="json")

    def test_retinol_is_general_and_never_calls_gemini(self):
        self.seed_dairy_history()
        with mock.patch(GEMINI) as gemini:
            body = self.ask("Best time to start retinol?").json()
            by_chip = self.ask("anything", chip="retinol_timing").json()
        gemini.assert_not_called()
        for answer in (body, by_chip):
            self.assertIn("dermatologist", answer["answer"])
            self.assertEqual(answer["source"], "template")

    def test_answer_from_gemini(self):
        self.seed_dairy_history()
        with mock.patch(GEMINI, return_value="Your diary shows higher acne the day after dairy. A dermatologist can help with concerns.") as gemini:
            body = self.ask("Which food affects me most?").json()
        self.assertEqual(body["source"], "ai")
        self.assertIn("summary", gemini.call_args.args[0].lower())
        self.assertIn("disclaimer", body)

    def test_fallback_answers(self):
        self.seed_dairy_history()
        with mock.patch(GEMINI, side_effect=RuntimeError("quota")):
            food = self.ask("Which food affects me most?").json()
            week = self.ask("Why did I break out this week?").json()
        self.assertEqual(food["source"], "template")
        self.assertIn("dairy", food["answer"])
        self.assertIn("last 7 days", week["answer"])

    def test_unsafe_answer_is_replaced(self):
        self.seed_dairy_history()
        with mock.patch(GEMINI, return_value="Dairy causes your acne. Take this medication twice a day."):
            body = self.ask("Which food affects me most?").json()
        self.assertEqual(body["source"], "template")

    def test_not_enough_data_skips_gemini(self):
        with mock.patch(GEMINI) as gemini:
            body = self.ask("Why did I break out this week?").json()
        gemini.assert_not_called()
        self.assertIn("enough data", body["answer"])

    def test_validation_and_suggestions(self):
        self.assertEqual(self.ask("").status_code, 400)
        self.assertEqual(self.ask("x" * 301).status_code, 400)
        chips = self.client.get("/api/tracking/ask/suggestions/?lang=en").json()
        self.assertEqual([c["text"] for c in chips], [
            "Why did I break out this week?", "Which food affects me most?", "Best time to start retinol?"])


class ScanTests(TrackingTestCase):
    def make_analysis(self, user):
        return Analysis.objects.create(analysis_key=f"SK-{user.id}TEST", user=user, image="analyses/x.jpg", confidence=0.8)

    def test_save_scan_to_tracking(self):
        analysis = self.make_analysis(self.user)
        url = f"/api/tracking/scans/{analysis.id}/save/"
        created = self.client.post(url, {"body_area": "chin", "note": "left side"}, format="json")
        self.assertEqual(created.status_code, 201)
        self.assertEqual(created.json()["body_area"], "chin")
        self.assertFalse(created.json()["log_exists"])
        self.assertFalse(DailyLog.objects.exists())  # no empty check-in is invented

        again = self.client.post(url, {"body_area": "nose"}, format="json")
        self.assertEqual(again.status_code, 200)
        self.assertEqual(TrackedScan.objects.count(), 1)
        self.assertEqual(TrackedScan.objects.get().body_area, "nose")

        self.assertEqual(len(self.client.get("/api/tracking/scans/?body_area=nose").json()), 1)
        self.assertEqual(self.client.get("/api/tracking/scans/?body_area=chin").json(), [])
        self.assertEqual(self.client.post(url, {"body_area": "elbow-ish"}, format="json").status_code, 400)

    def test_cannot_save_someone_elses_scan(self):
        analysis = self.make_analysis(self.other)
        self.assertEqual(self.client.post(f"/api/tracking/scans/{analysis.id}/save/", {}, format="json").status_code, 404)

    def test_log_exists_flag_and_delete_all(self):
        self.client.post("/api/tracking/logs/", checkin(), format="json")
        analysis = self.make_analysis(self.user)
        saved = self.client.post(f"/api/tracking/scans/{analysis.id}/save/", {"date": timezone.localdate().isoformat()}, format="json")
        self.assertTrue(saved.json()["log_exists"])

        SkincareProduct.objects.create(user=self.user, name="P", step_type="treat")
        InsightCache.objects.create(user=self.user, lang="en", findings_hash="x", texts={})
        self.client.put("/api/tracking/reminders/", {"checkin_enabled": True}, format="json")
        other_log = DailyLog.objects.create(user=self.other, date=timezone.localdate(), skin_rating=3, acne_severity=1)

        deleted = self.client.delete("/api/tracking/data/?confirm=true").json()
        self.assertEqual(deleted, {"logs": 1, "products": 1, "scans": 1})
        self.assertFalse(DailyLog.objects.filter(user=self.user).exists())
        self.assertFalse(TrackedScan.objects.exists())
        self.assertFalse(InsightCache.objects.exists())
        self.assertTrue(Analysis.objects.filter(id=analysis.id).exists())  # the scan itself is untouched
        self.assertTrue(DailyLog.objects.filter(id=other_log.id).exists())  # other users unaffected
