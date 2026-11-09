"""
recommendation_store.py

Saving, checking and replacing the cached recommendations of a condition.
Used by analyses/views.py (first scan of a condition) and by the
`regenerate_recommendations` management command.

Each condition gets its OWN Recommendation rows. They are no longer shared
by title between conditions: with the richer format (what to do / avoid /
when to see a doctor) the same title means different advice for different
conditions, so sharing rows would let one condition overwrite another's text.
"""

from django.db import transaction

from core.models import ConditionRecommendation, Recommendation

from .gemini_service import generate_recommendations_detailed


def condition_needs_generation(condition) -> bool:
    """
    True if the condition has no recommendations yet, or only fallback /
    incomplete ones (flagged is_fallback) that should be replaced as soon
    as Gemini works again.
    """
    links = ConditionRecommendation.objects.filter(condition=condition)
    if not links.exists():
        return True
    return links.filter(recommendation__is_fallback=True).exists()


def save_recommendations_for_condition(condition, items, is_fallback=False):
    """Creates one Recommendation row per item and links it to the condition."""
    if not condition or not items:
        return []

    saved = []

    for item in items:
        name = item.get("name")
        description = item.get("description")
        rec_type = item.get("type")

        if not name or not description or not rec_type:
            continue

        recommendation = Recommendation.objects.create(
            name=name,
            name_mk=item.get("name_mk"),
            description=description,
            description_mk=item.get("description_mk"),
            what_to_avoid=item.get("what_to_avoid"),
            what_to_avoid_mk=item.get("what_to_avoid_mk"),
            when_to_see_doctor=item.get("when_to_see_doctor"),
            when_to_see_doctor_mk=item.get("when_to_see_doctor_mk"),
            type=rec_type,
            is_fallback=is_fallback,
        )

        ConditionRecommendation.objects.create(
            condition=condition,
            recommendation=recommendation,
        )

        saved.append(recommendation)

    return saved


def replace_condition_recommendations(condition, items, is_fallback=False):
    """
    Atomically swaps the condition's recommendations for `items`. Old links
    are removed, and old Recommendation rows that no other condition uses are
    deleted so they don't pile up. If `items` is empty nothing is touched.
    """
    if not items:
        return []

    with transaction.atomic():
        old_ids = list(
            ConditionRecommendation.objects.filter(condition=condition)
            .values_list("recommendation_id", flat=True)
        )
        ConditionRecommendation.objects.filter(condition=condition).delete()

        saved = save_recommendations_for_condition(condition, items, is_fallback)

        Recommendation.objects.filter(
            id__in=old_ids, condition_recommendations__isnull=True
        ).delete()

    return saved


def generate_recommendations_only_if_missing(condition):
    """
    Gemini is only called if the condition has no (real) saved
    recommendations - we don't want different advice on every scan of the
    same condition. A condition that only has fallback/incomplete text is
    treated as missing, so one failed Gemini call can no longer lock in the
    short list forever.
    """
    if not condition:
        return {"generated": False, "reason": "Missing condition.", "count": 0}

    if not condition_needs_generation(condition):
        existing_count = ConditionRecommendation.objects.filter(condition=condition).count()
        return {
            "generated": False,
            "reason": "Recommendations already exist for this condition.",
            "count": existing_count,
        }

    result = generate_recommendations_detailed(
        condition_name=condition.name,
        severity=condition.severity or "MEDIUM",
    )

    has_existing = ConditionRecommendation.objects.filter(condition=condition).exists()

    if result["is_fallback"] and has_existing:
        # Already showing a fallback list and Gemini still failed: keep what
        # is there (no pointless delete + re-create of the same short text).
        return {
            "generated": False,
            "reason": "Gemini unavailable; keeping fallback recommendations.",
            "count": ConditionRecommendation.objects.filter(condition=condition).count(),
        }

    saved = replace_condition_recommendations(
        condition, result["items"], is_fallback=result["is_fallback"]
    )

    return {
        "generated": not result["is_fallback"],
        "reason": (
            "Recommendations generated successfully."
            if not result["is_fallback"]
            else "Gemini unavailable; saved fallback recommendations (will retry on a later scan)."
        ),
        "count": len(saved),
    }
