import datetime
import os
import uuid

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.files.storage import FileSystemStorage
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from analyses.models import Analysis

from . import constants as c


def _choices(values):
    return [(v, v) for v in values]


# Check-in photos are sensitive. They live OUTSIDE MEDIA_ROOT so the public
# MEDIA_URL can never serve them; the only way to read one is the
# authenticated, owner-checked endpoint in views.py.
private_photo_storage = FileSystemStorage(location=str(settings.TRACKING_PRIVATE_ROOT))


def tracking_photo_path(instance, filename):
    """Random UUID file name - the original name (which may leak info) is dropped."""
    ext = os.path.splitext(filename)[1].lower()
    if ext not in c.ALLOWED_PHOTO_EXTENSIONS:
        ext = ".jpg"
    return f"tracking/{uuid.uuid4().hex}{ext}"


def validate_string_list(allowed):
    def validator(value):
        if not isinstance(value, list) or any(v not in allowed for v in value):
            raise ValidationError(f"Allowed values: {', '.join(allowed)}.")
        if len(set(value)) != len(value):
            raise ValidationError("Duplicate values are not allowed.")

    return validator


def validate_areas(value):
    validate_string_list(c.AREAS)(value)


def validate_food_tags(value):
    validate_string_list(c.FOOD_TAGS)(value)


class DailyLog(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="daily_logs")
    date = models.DateField()

    skin_rating = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    # 0 = clear, 1 = mild, 2 = moderate, 3 = severe
    acne_severity = models.PositiveSmallIntegerField(validators=[MinValueValidator(0), MaxValueValidator(3)])
    affected_areas = models.JSONField(default=list, blank=True, validators=[validate_areas])

    photo = models.ImageField(upload_to=tracking_photo_path, storage=private_photo_storage, blank=True, null=True)
    notes = models.TextField(blank=True, default="")

    sleep_hours = models.FloatField(blank=True, null=True, validators=[MinValueValidator(0), MaxValueValidator(24)])
    sleep_quality = models.CharField(max_length=10, choices=_choices(c.SLEEP_QUALITIES), blank=True, null=True)
    stress = models.PositiveSmallIntegerField(blank=True, null=True, validators=[MinValueValidator(1), MaxValueValidator(10)])
    food_tags = models.JSONField(default=list, blank=True, validators=[validate_food_tags])

    # null = skipped / not tracked
    cycle_phase = models.CharField(max_length=12, choices=_choices(c.CYCLE_PHASES), blank=True, null=True)

    # Ids of SkincareProduct used that day.
    routine_am = models.JSONField(default=list, blank=True)
    routine_pm = models.JSONField(default=list, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "tracking_daily_logs"
        ordering = ["-date"]
        constraints = [models.UniqueConstraint(fields=["user", "date"], name="unique_log_per_user_per_day")]

    def __str__(self):
        return f"{self.user_id} {self.date}"


class SkincareProduct(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="skincare_products")
    name = models.CharField(max_length=100)
    step_type = models.CharField(max_length=10, choices=_choices(c.STEP_TYPES))
    time_of_day = models.CharField(max_length=4, choices=_choices(c.TIME_OF_DAY), default="BOTH")
    frequency = models.CharField(max_length=40, blank=True, default="")  # e.g. "3x/week"
    tags = models.JSONField(default=list, blank=True)  # e.g. ["BHA", "ceramides"]
    started_on = models.DateField(blank=True, null=True)
    stopped_on = models.DateField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "tracking_products"
        ordering = ["step_type", "name"]

    def __str__(self):
        return self.name


class TrackedScan(models.Model):
    """A scan the user saved to the timeline, optionally tied to a body area
    so the same spot can be compared over time. The analyses app is untouched."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="tracked_scans")
    analysis = models.ForeignKey(Analysis, on_delete=models.CASCADE, related_name="tracked_scans")
    body_area = models.CharField(max_length=20, choices=_choices(c.SCAN_AREAS), blank=True, default="")
    date = models.DateField()
    note = models.CharField(max_length=300, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "tracking_scans"
        ordering = ["-date", "-id"]
        constraints = [models.UniqueConstraint(fields=["user", "analysis"], name="unique_tracked_scan")]


class ReminderSettings(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="reminder_settings")
    checkin_enabled = models.BooleanField(default=False)
    checkin_time = models.TimeField(default=datetime.time(20, 0))
    rescan_enabled = models.BooleanField(default=False)
    rescan_weeks = models.PositiveSmallIntegerField(default=4, validators=[MinValueValidator(1), MaxValueValidator(12)])
    # Cycle tracking is opt-in; while False the API ignores cycle_phase.
    cycle_tracking_enabled = models.BooleanField(default=False)

    class Meta:
        db_table = "tracking_reminder_settings"


class InsightCache(models.Model):
    """Gemini phrasing of already-computed findings, keyed by a hash of them."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="insight_cache")
    lang = models.CharField(max_length=2)
    findings_hash = models.CharField(max_length=64)
    texts = models.JSONField(default=dict)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "tracking_insight_cache"
        constraints = [models.UniqueConstraint(fields=["user", "lang", "findings_hash"], name="unique_insight_cache")]
