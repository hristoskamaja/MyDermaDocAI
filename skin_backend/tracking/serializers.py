from rest_framework import serializers

from . import constants as c
from .models import DailyLog, ReminderSettings, SkincareProduct, TrackedScan


class DailyLogSerializer(serializers.ModelSerializer):
    photo = serializers.ImageField(write_only=True, required=False, allow_null=True)
    photo_url = serializers.SerializerMethodField()
    has_photo = serializers.SerializerMethodField()

    class Meta:
        model = DailyLog
        fields = [
            "id", "date", "skin_rating", "acne_severity", "affected_areas",
            "photo", "photo_url", "has_photo", "notes",
            "sleep_hours", "sleep_quality", "stress", "food_tags",
            "cycle_phase", "routine_am", "routine_pm", "updated_at",
        ]
        read_only_fields = ["id", "updated_at"]

    def get_has_photo(self, obj):
        return bool(obj.photo)

    def get_photo_url(self, obj):
        """Authenticated, owner-checked endpoint - never a public media URL."""
        if not obj.photo:
            return None
        request = self.context.get("request")
        path = f"/api/tracking/logs/{obj.date.isoformat()}/photo/"
        return request.build_absolute_uri(path) if request else path

    def validate_photo(self, value):
        if value is None:
            return value
        if value.size > c.MAX_PHOTO_BYTES:
            raise serializers.ValidationError("Photo is too large (max 8 MB).")
        return value

    def _validate_product_ids(self, value):
        if not isinstance(value, list) or any(not isinstance(v, int) for v in value):
            raise serializers.ValidationError("Expected a list of product ids.")
        user = self.context["request"].user
        owned = set(SkincareProduct.objects.filter(user=user, id__in=value).values_list("id", flat=True))
        if set(value) - owned:
            raise serializers.ValidationError("Unknown product id.")
        return value

    def validate_routine_am(self, value):
        return self._validate_product_ids(value)

    def validate_routine_pm(self, value):
        return self._validate_product_ids(value)

    def validate_notes(self, value):
        if len(value) > 2000:
            raise serializers.ValidationError("Notes are too long (max 2000 characters).")
        return value


class SkincareProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = SkincareProduct
        fields = ["id", "name", "step_type", "time_of_day", "frequency", "tags", "started_on", "stopped_on"]
        read_only_fields = ["id"]

    def validate_tags(self, value):
        if not isinstance(value, list) or len(value) > 10 or any(not isinstance(t, str) or len(t) > 30 for t in value):
            raise serializers.ValidationError("Up to 10 short text tags.")
        return value

    def validate(self, attrs):
        started = attrs.get("started_on", getattr(self.instance, "started_on", None))
        stopped = attrs.get("stopped_on", getattr(self.instance, "stopped_on", None))
        if started and stopped and stopped < started:
            raise serializers.ValidationError({"stopped_on": "Must not be before started_on."})
        return attrs


class ReminderSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReminderSettings
        fields = ["checkin_enabled", "checkin_time", "rescan_enabled", "rescan_weeks", "cycle_tracking_enabled"]


class TrackedScanSerializer(serializers.ModelSerializer):
    analysis_id = serializers.IntegerField(read_only=True)
    analysis_key = serializers.CharField(source="analysis.analysis_key", read_only=True)
    condition_key = serializers.CharField(source="analysis.condition.key", read_only=True, default=None)
    condition_name = serializers.SerializerMethodField()
    confidence = serializers.FloatField(source="analysis.confidence", read_only=True)
    image = serializers.SerializerMethodField()

    class Meta:
        model = TrackedScan
        fields = [
            "id", "analysis_id", "analysis_key", "condition_key", "condition_name",
            "confidence", "image", "body_area", "date", "note",
        ]
        read_only_fields = ["id", "date"]

    def get_condition_name(self, obj):
        condition = obj.analysis.condition
        return condition.name if condition else None

    def get_image(self, obj):
        # Scan images are already served by the analyses app (same as in History).
        request = self.context.get("request")
        image = obj.analysis.image
        if not image:
            return None
        return request.build_absolute_uri(image.url) if request else image.url
