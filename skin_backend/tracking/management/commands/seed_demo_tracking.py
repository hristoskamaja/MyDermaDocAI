"""
Dev-only: fills ONE user's tracker with realistic synthetic data so the
Track screens and the insights engine can be tried without logging for weeks.

    python manage.py seed_demo_tracking --email you@example.com --days 30 [--reset] [--seed 42]

Planted patterns (so the insights engine has something real to find):
  * acne is worse the day AFTER a night of poor sleep (< 6 h);
  * acne flares in the luteal phase (28-day cycle, chin/jawline);
  * high stress (7+) adds a small bump.
Everything else is random noise. Refuses to run unless DEBUG is True, only
touches the given user, and never creates users or touches other apps.
"""

import random
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from tracking import constants as c
from tracking.models import DailyLog, InsightCache, ReminderSettings, SkincareProduct, TrackedScan

MAX_DAYS = 365
CYCLE_LENGTH = 28
SKIP_CHANCE = 0.08
ADHERENCE = 0.85
POOR_SLEEP_HOURS = 6

# (name, step_type, time_of_day, frequency, tags)
DEMO_PRODUCTS = [
    ("Gentle cleanser",      "cleanse", "BOTH", "daily",    ["fragrance-free"]),
    ("Salicylic acid serum", "treat",   "PM",   "3x/week",  ["BHA"]),
    ("Ceramide moisturizer", "hydrate", "BOTH", "daily",    ["ceramides"]),
    ("Mineral SPF 50",       "protect", "AM",   "daily",    ["zinc oxide"]),
]


def cycle_phase(cycle_day):
    """cycle_day is 1..28."""
    if cycle_day <= 5:
        return "menstrual"
    if cycle_day <= 13:
        return "follicular"
    if cycle_day <= 16:
        return "ovulation"
    return "luteal"


def clamp(value, low, high):
    return max(low, min(high, value))


class Command(BaseCommand):
    help = "DEV ONLY: seed realistic synthetic tracking data for one user (refuses when DEBUG is False)."

    def add_arguments(self, parser):
        parser.add_argument("--email", required=True, help="Email of an EXISTING user.")
        parser.add_argument("--days", type=int, default=30, help=f"How many days back to generate (1-{MAX_DAYS}).")
        parser.add_argument("--reset", action="store_true", help="Delete this user's tracking data first.")
        parser.add_argument("--seed", type=int, default=42, help="Random seed (same seed = same data).")

    def handle(self, *args, **options):
        if not settings.DEBUG:
            raise CommandError("seed_demo_tracking is dev-only and refuses to run when DEBUG is False.")

        days = options["days"]
        if not 1 <= days <= MAX_DAYS:
            raise CommandError(f"--days must be between 1 and {MAX_DAYS}.")

        User = get_user_model()
        user = User.objects.filter(email__iexact=options["email"]).first()
        if user is None:
            raise CommandError(f"No user with email {options['email']!r}. Create the account first.")

        rng = random.Random(options["seed"])

        with transaction.atomic():
            if options["reset"]:
                self._reset(user)

            products = self._seed_products(user, days)
            ReminderSettings.objects.update_or_create(
                user=user, defaults={"cycle_tracking_enabled": True, "checkin_enabled": True},
            )
            created, updated, skipped = self._seed_logs(user, days, products, rng)

        self.stdout.write(self.style.SUCCESS(
            f"Seeded {user.email}: {created} new + {updated} updated check-ins "
            f"({skipped} days left empty), {len(products)} products, cycle tracking on."
        ))
        self.stdout.write(
            "Planted: poor sleep -> worse acne next day; luteal-phase flare-ups; small bump on high-stress days."
        )

    # ------------------------------------------------------------------

    def _reset(self, user):
        counts = {
            "check-ins": DailyLog.objects.filter(user=user).delete()[0],
            "products": SkincareProduct.objects.filter(user=user).delete()[0],
            "saved scans": TrackedScan.objects.filter(user=user).delete()[0],
        }
        ReminderSettings.objects.filter(user=user).delete()
        InsightCache.objects.filter(user=user).delete()
        self.stdout.write("Reset: removed " + ", ".join(f"{n} {label}" for label, n in counts.items()) + ".")

    def _seed_products(self, user, days):
        started = timezone.localdate() - timedelta(days=days)
        products = []
        for name, step, when, frequency, tags in DEMO_PRODUCTS:
            product, _ = SkincareProduct.objects.get_or_create(
                user=user, name=name,
                defaults={"step_type": step, "time_of_day": when, "frequency": frequency,
                          "tags": tags, "started_on": started},
            )
            products.append(product)
        return products

    def _seed_logs(self, user, days, products, rng):
        today = timezone.localdate()
        offset = rng.randrange(CYCLE_LENGTH)
        am = [p.id for p in products if p.time_of_day in ("AM", "BOTH")]
        pm = [p.id for p in products if p.time_of_day in ("PM", "BOTH")]

        # Sleep for one extra day before the window, so day 1 has a "previous night".
        sleep = {}
        for back in range(days, -1, -1):
            sleep[today - timedelta(days=back)] = clamp(round(rng.gauss(7, 1.2) * 2) / 2, 4, 9.5)

        created = updated = skipped = 0
        for back in range(days - 1, -1, -1):
            day = today - timedelta(days=back)
            # Today is always logged so the hub shows a done state.
            if back and rng.random() < SKIP_CHANCE:
                skipped += 1
                continue

            phase = cycle_phase((days - 1 - back + offset) % CYCLE_LENGTH + 1)
            hours = sleep[day]
            prev_poor = sleep[day - timedelta(days=1)] < POOR_SLEEP_HOURS
            stress = int(clamp(round(rng.gauss(4.5, 2.2)), 1, 10))

            latent = (0.5 + 1.2 * prev_poor + 0.9 * (phase == "luteal")
                      + 0.3 * (stress >= 7) + rng.gauss(0, 0.3))
            severity = int(clamp(round(latent), 0, 3))

            if severity == 0:
                areas = []
            elif phase == "luteal":
                areas = ["chin", "jawline"][: 1 + (severity > 1)]
            else:
                areas = rng.sample(c.AREAS, min(severity, 2))

            food = [tag for tag, chance in
                    (("dairy", .3), ("sugar", .3), ("fried", .15), ("alcohol", .1), ("caffeine", .5), ("water", .6))
                    if rng.random() < chance]

            _, was_created = DailyLog.objects.update_or_create(
                user=user, date=day,
                defaults={
                    "skin_rating": int(clamp(round(4.4 - 0.9 * severity + rng.gauss(0, 0.5)), 1, 5)),
                    "acne_severity": severity,
                    "affected_areas": areas,
                    "sleep_hours": hours,
                    "sleep_quality": "poor" if hours < POOR_SLEEP_HOURS else "great" if hours >= 8 else "okay",
                    "stress": stress,
                    "food_tags": food,
                    "cycle_phase": phase,
                    "routine_am": [pid for pid in am if rng.random() < ADHERENCE],
                    "routine_pm": [pid for pid in pm if rng.random() < ADHERENCE],
                    "notes": "",
                },
            )
            created += was_created
            updated += not was_created
        return created, updated, skipped
