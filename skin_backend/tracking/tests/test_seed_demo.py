"""seed_demo_tracking: dev-only guard, scope (one user only), planted patterns, --reset."""

from datetime import timedelta
from io import StringIO
from statistics import mean

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import TestCase, override_settings
from django.utils import timezone

from tracking.models import DailyLog, ReminderSettings, SkincareProduct

User = get_user_model()


def make_user(email):
    return User.objects.create_user(username=email, email=email, password="pw-123456", full_name="Demo")


def seed(email, **kwargs):
    out = StringIO()
    call_command("seed_demo_tracking", email=email, stdout=out, **kwargs)
    return out.getvalue()


@override_settings(DEBUG=True)
class SeedDemoTrackingTests(TestCase):
    def setUp(self):
        self.user = make_user("demo@example.com")
        self.other = make_user("other@example.com")

    def test_refuses_when_debug_is_false(self):
        with override_settings(DEBUG=False):
            with self.assertRaises(CommandError):
                seed(self.user.email, days=30)
        self.assertEqual(DailyLog.objects.count(), 0)

    def test_unknown_email_and_bad_days(self):
        with self.assertRaises(CommandError):
            seed("nobody@example.com", days=30)
        with self.assertRaises(CommandError):
            seed(self.user.email, days=0)
        self.assertEqual(User.objects.count(), 2)  # no user was created

    def test_seeds_only_the_given_user(self):
        seed(self.user.email, days=30)

        logs = DailyLog.objects.filter(user=self.user)
        self.assertGreater(logs.count(), 20)
        self.assertTrue(logs.filter(date=timezone.localdate()).exists())
        self.assertEqual(SkincareProduct.objects.filter(user=self.user).count(), 4)
        self.assertTrue(ReminderSettings.objects.get(user=self.user).cycle_tracking_enabled)

        self.assertEqual(DailyLog.objects.filter(user=self.other).count(), 0)
        self.assertEqual(SkincareProduct.objects.filter(user=self.other).count(), 0)
        self.assertFalse(ReminderSettings.objects.filter(user=self.other).exists())

        for log in logs:
            log.full_clean(exclude=["user", "photo"])  # values obey the model validators
            self.assertTrue(set(log.routine_am + log.routine_pm) <= set(
                SkincareProduct.objects.filter(user=self.user).values_list("id", flat=True)))

    def test_planted_patterns_are_present(self):
        seed(self.user.email, days=120)
        logs = {log.date: log for log in DailyLog.objects.filter(user=self.user)}

        after_poor, after_ok = [], []
        for day, log in logs.items():
            prev = logs.get(day - timedelta(days=1))
            if prev and prev.sleep_hours is not None:
                (after_poor if prev.sleep_hours < 6 else after_ok).append(log.acne_severity)
        self.assertGreater(mean(after_poor), mean(after_ok) + 0.4)

        luteal = [l.acne_severity for l in logs.values() if l.cycle_phase == "luteal"]
        other = [l.acne_severity for l in logs.values() if l.cycle_phase != "luteal"]
        self.assertGreater(mean(luteal), mean(other) + 0.4)

    def test_same_seed_same_data_and_rerun_has_no_duplicates(self):
        seed(self.user.email, days=30)
        first = list(DailyLog.objects.filter(user=self.user).values_list("date", "acne_severity", "sleep_hours"))
        seed(self.user.email, days=30)
        second = list(DailyLog.objects.filter(user=self.user).values_list("date", "acne_severity", "sleep_hours"))
        self.assertEqual(sorted(first), sorted(second))
        self.assertEqual(SkincareProduct.objects.filter(user=self.user).count(), 4)

    def test_reset_only_deletes_that_users_data(self):
        old = timezone.localdate() - timedelta(days=200)
        DailyLog.objects.create(user=self.user, date=old, skin_rating=3, acne_severity=1)
        keep = DailyLog.objects.create(user=self.other, date=old, skin_rating=3, acne_severity=2)
        SkincareProduct.objects.create(user=self.other, name="Mine", step_type="cleanse")

        seed(self.user.email, days=14, reset=True)

        self.assertFalse(DailyLog.objects.filter(user=self.user, date=old).exists())
        self.assertTrue(DailyLog.objects.filter(pk=keep.pk).exists())
        self.assertEqual(SkincareProduct.objects.filter(user=self.other).count(), 1)
