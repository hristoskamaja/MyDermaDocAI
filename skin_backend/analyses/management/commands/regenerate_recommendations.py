"""
python manage.py regenerate_recommendations --condition <key> [--condition <key> ...]
python manage.py regenerate_recommendations --all
python manage.py regenerate_recommendations --all --only-fallback

Asks Gemini for fresh, richer recommendations (what to do / what to avoid /
when to see a doctor, EN + MK) and REPLACES the cached ones of the chosen
condition(s). Nothing is replaced if Gemini fails: the old recommendations
stay as they are.

Free-tier quota is 5 requests/minute and 20/day, so --all pauses between
conditions. Condition keys: see `SkinCondition.key` (for example melanoma,
nevus, actinic_keratosis).
"""

import time

from django.core.management.base import BaseCommand, CommandError

from analyses.services.recommendation_store import (
    condition_needs_generation,
    replace_condition_recommendations,
)
from analyses.services.gemini_service import generate_recommendations_detailed
from core.models import SkinCondition

# 5 requests/minute on the free tier -> one call every 13s stays under it.
PAUSE_SECONDS = 13


class Command(BaseCommand):
    help = "Regenerate and replace the cached recommendations of skin conditions."

    def add_arguments(self, parser):
        parser.add_argument(
            "--condition",
            action="append",
            default=[],
            help="Condition key (repeatable), e.g. --condition melanoma",
        )
        parser.add_argument(
            "--all",
            action="store_true",
            help="Regenerate every condition.",
        )
        parser.add_argument(
            "--only-fallback",
            action="store_true",
            help="With --all: only conditions with no or fallback recommendations.",
        )

    def handle(self, *args, **options):
        keys = options["condition"]

        if not keys and not options["all"]:
            raise CommandError("Pass --condition <key> (repeatable) or --all.")

        if options["all"]:
            conditions = list(SkinCondition.objects.order_by("key"))
        else:
            conditions = list(SkinCondition.objects.filter(key__in=keys).order_by("key"))
            missing = set(keys) - {c.key for c in conditions}
            if missing:
                raise CommandError(f"Unknown condition key(s): {', '.join(sorted(missing))}")

        if options["all"] and options["only_fallback"]:
            conditions = [c for c in conditions if condition_needs_generation(c)]

        if not conditions:
            self.stdout.write("Nothing to regenerate.")
            return

        replaced = 0
        failed = 0

        for index, condition in enumerate(conditions):
            if index > 0:
                time.sleep(PAUSE_SECONDS)

            result = generate_recommendations_detailed(
                condition_name=condition.name,
                severity=condition.severity or "MEDIUM",
            )

            if result["is_fallback"]:
                failed += 1
                self.stdout.write(
                    self.style.WARNING(
                        f"{condition.key}: Gemini did not return a complete answer; "
                        "kept the existing recommendations."
                    )
                )
                continue

            saved = replace_condition_recommendations(condition, result["items"])
            replaced += 1
            self.stdout.write(f"{condition.key}: replaced with {len(saved)} recommendations.")

        summary = f"Done. Replaced: {replaced}, failed: {failed}."
        self.stdout.write(
            self.style.SUCCESS(summary) if not failed else self.style.WARNING(summary + " Run again later.")
        )
