from django.db import models


# ---------------------------------------------------------------------------
# Same choices as in leafscan (Severity), plus a new ConditionCategory
# instead of PlantType/DiseaseCategory - skin has no "plant type", so
# instead of Plant + Disease there's just one model here: SkinCondition.
# ---------------------------------------------------------------------------

class Severity(models.TextChoices):
    LOW = "LOW", "Low"
    MEDIUM = "MEDIUM", "Medium"
    HIGH = "HIGH", "High"


class ConditionCategory(models.TextChoices):
    BENIGN = "BENIGN", "Benign"
    PRECANCEROUS = "PRECANCEROUS", "Precancerous"
    MALIGNANT = "MALIGNANT", "Malignant"
    INFLAMMATORY = "INFLAMMATORY", "Inflammatory"
    OTHER = "OTHER", "Other"


class RecommendationType(models.TextChoices):
    SELF_CARE = "SELF_CARE", "Self-care"
    MEDICAL_CONSULT = "MEDICAL_CONSULT", "Medical consultation"
    LIFESTYLE = "LIFESTYLE", "Lifestyle"


class SkinCondition(models.Model):
    """
    IMPORTANT: the `key` field must exactly match the names in
    `class_names` from skin_model.pt (e.g. "melanoma", "basal_cell_carcinoma"...).
    That's what the AI model returns - views.py then looks up records by
    `key` to pull out the description/severity/recommendations.

    Fill this table once with `python manage.py seed_skin_conditions`
    (core/management/commands/seed_skin_conditions.py), then adjust the
    descriptions/symptoms by hand through the Django admin or React admin
    panel (same as the Diseases page in leafscan_web).
    """

    key = models.SlugField(max_length=50, unique=True)
    name = models.CharField(max_length=100, unique=True)

    # The admin normally only types the Macedonian text (below), and the
    # matching _en field is filled in automatically by
    # core/services/translation.py (a Gemini call) whenever description/
    # symptoms/treatment_overview is created or changed - see
    # core/views.py. The admin can also hand-edit/correct the _en text
    # directly in the admin panel; views.py protects a manually-typed _en
    # value from being auto-overwritten in the same request.
    description = models.TextField(blank=True, null=True)
    description_en = models.TextField(blank=True, null=True)
    symptoms = models.TextField(blank=True, null=True)
    symptoms_en = models.TextField(blank=True, null=True)

    # DELIBERATELY "treatment_overview", not "treatment" / "prescription":
    # this is a general, educational description of what dermatologists
    # TYPICALLY use for this condition (same spirit as gemini_service.py -
    # never a specific medication/dose/personal advice). Always shown
    # together with a reminder that a doctor, not the app, makes the final
    # treatment decision.
    treatment_overview = models.TextField(blank=True, null=True)
    treatment_overview_en = models.TextField(blank=True, null=True)

    image = models.ImageField(upload_to="conditions/", blank=True, null=True)
    image_description = models.TextField(blank=True, null=True)
    severity = models.CharField(
        max_length=10,
        choices=Severity.choices,
        blank=True,
        null=True,
    )
    category = models.CharField(
        max_length=20,
        choices=ConditionCategory.choices,
        blank=True,
        null=True,
    )

    class Meta:
        db_table = "skin_conditions"

    def __str__(self):
        return self.name


class Dermatologist(models.Model):
    """
    Directory of dermatologists shown to patients. Rows can come from two
    places: the admin typing one in by hand through the React admin panel,
    or core/management/commands/scrape_dermatologists.py (a one-off, admin-
    run command that pulls public listings from zk.mk, the Macedonian
    business directory - this is a student project, so we deliberately
    didn't build anything more elaborate than that around legal/ToS
    concerns). Either way, the admin can edit or deactivate any row
    afterwards. The table can legitimately be empty until populated -
    that's not a bug, the UI must clearly show that instead of displaying
    fabricated/fake contact info.
    """

    name = models.CharField(max_length=150)
    clinic_name = models.CharField(max_length=150, blank=True, null=True)
    city = models.CharField(max_length=100, blank=True, null=True)
    address = models.CharField(max_length=255, blank=True, null=True)
    phone = models.CharField(max_length=50, blank=True, null=True)
    website = models.URLField(blank=True, null=True)
    notes = models.TextField(blank=True, null=True)

    # Used to sort "find a dermatologist" results by proximity - real GPS
    # coords on mobile, or the chosen city's center coords on web (see
    # core/views.py -> _resolve_origin / _haversine_km). Filled in
    # automatically by the scraper (from the Google Maps link on zk.mk),
    # or left blank for hand-entered rows (they just won't be distance-
    # sorted - they still show up, sorted alphabetically at the end).
    latitude = models.FloatField(blank=True, null=True)
    longitude = models.FloatField(blank=True, null=True)

    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "dermatologists"
        ordering = ["name"]

    def __str__(self):
        return self.name


class Recommendation(models.Model):
    """
    Replaces Treatment from leafscan. Deliberately NOT called "Treatment" /
    "medication" - the app must not give medical treatment/dosing, only
    general care advice and a recommendation to see a doctor.
    """

    # Unlike SkinCondition (where the admin-entered text is Macedonian and
    # English gets auto-translated), Gemini's recommendation prompt has
    # always been written in English - so `name`/`description` ARE English
    # (unchanged, so existing rows stay valid), and name_mk/description_mk
    # are the Macedonian counterpart, now generated in the same Gemini call
    # (see analyses/services/gemini_service.py -> generate_recommendations_with_gemini).
    #
    # Richer format: `name` is the short title, `description` is "what to
    # do", and what_to_avoid / when_to_see_doctor are the other two parts
    # (each with a Macedonian counterpart). Older rows simply leave the two
    # new parts empty, and the UIs hide a part that has no text.
    name = models.CharField(max_length=150)
    name_mk = models.CharField(max_length=150, blank=True, null=True)
    description = models.TextField(blank=True, null=True)
    description_mk = models.TextField(blank=True, null=True)
    what_to_avoid = models.TextField(blank=True, null=True)
    what_to_avoid_mk = models.TextField(blank=True, null=True)
    when_to_see_doctor = models.TextField(blank=True, null=True)
    when_to_see_doctor_mk = models.TextField(blank=True, null=True)
    type = models.CharField(
        max_length=20,
        choices=RecommendationType.choices,
    )

    # True for the short built-in fallback text (or an incomplete Gemini
    # answer) that is shown when generation fails. A condition whose
    # recommendations are flagged like this is generated again on the next
    # scan instead of being stuck with the short list forever.
    is_fallback = models.BooleanField(default=False)

    class Meta:
        db_table = "recommendations"

    def __str__(self):
        return self.name


class ConditionRecommendation(models.Model):
    condition = models.ForeignKey(
        SkinCondition,
        on_delete=models.CASCADE,
        related_name="condition_recommendations",
    )
    recommendation = models.ForeignKey(
        Recommendation,
        on_delete=models.CASCADE,
        related_name="condition_recommendations",
    )

    class Meta:
        db_table = "condition_recommendations"
        constraints = [
            models.UniqueConstraint(
                fields=["condition", "recommendation"],
                name="unique_condition_recommendation",
            )
        ]

    def __str__(self):
        return f"{self.condition.name} - {self.recommendation.name}"
