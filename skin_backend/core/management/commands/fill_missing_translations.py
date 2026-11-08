"""
python manage.py fill_missing_translations [--dry-run]

Fills any empty description_en / symptoms_en / treatment_overview_en on
SkinCondition rows by translating the Macedonian text with Gemini.

The seed command already ships real English text for the 8 built-in
conditions, so this is only needed for conditions an admin added by hand
(or if a background translation failed, e.g. free-tier quota 5/min, 20/day).
One Gemini call is made per condition, with a pause between calls to stay
under the per-minute quota. Run it again later for anything that failed.
"""

import time

from django.core.management.base import BaseCommand

from core.models import SkinCondition
from core.services.translation import fill_missing_translations

# Free tier allows 5 requests/minute -> one call every 13s stays under it.
PAUSE_SECONDS = 13


class Command(BaseCommand):
    help = "Fill missing English (_en) fields on skin conditions using Gemini."

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Only list conditions with missing English text; call nothing.",
        )

    def handle(self, *args, **options):
        pairs = [
            ("description", "description_en"),
            ("symptoms", "symptoms_en"),
            ("treatment_overview", "treatment_overview_en"),
        ]

        pending = [
            condition
            for condition in SkinCondition.objects.order_by("key")
            if any(
                getattr(condition, source) and not getattr(condition, target)
                for source, target in pairs
            )
        ]

        if not pending:
            self.stdout.write(self.style.SUCCESS("Nothing to fill: all English fields are set."))
            return

        if options["dry_run"]:
            for condition in pending:
                self.stdout.write(f"Missing English text: {condition.key}")
            return

        filled = 0
        failed = 0

        for index, condition in enumerate(pending):
            if index > 0:
                time.sleep(PAUSE_SECONDS)

            if fill_missing_translations(condition):
                condition.save()
                filled += 1
                self.stdout.write(f"Filled: {condition.key}")
            else:
                failed += 1
                self.stdout.write(
                    self.style.WARNING(
                        f"Could not translate: {condition.key} (see the log for the reason)"
                    )
                )

        self.stdout.write(
            self.style.SUCCESS(f"Done. Filled: {filled}, failed: {failed}.")
            if not failed
            else self.style.WARNING(f"Done. Filled: {filled}, failed: {failed}. Run again later.")
        )
