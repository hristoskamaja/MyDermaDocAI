"""
Tracking API. Every view is IsAuthenticated and only ever touches
request.user's own rows - another user's data answers 404.
"""

import json
import mimetypes
from datetime import timedelta

from django.http import FileResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import serializers, status
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from analyses.models import Analysis

from .models import DailyLog, InsightCache, ReminderSettings, SkincareProduct, TrackedScan
from .serializers import (
    DailyLogSerializer,
    ReminderSettingsSerializer,
    SkincareProductSerializer,
    TrackedScanSerializer,
)
from . import constants as c
from .food_tags import is_custom_food_tag
from .services import insights_text, series
from .services.streaks import compute_streaks, week_strip
from .services.weekly import compute_weekly_report

LIST_FIELDS = ("affected_areas", "food_tags", "routine_am", "routine_pm")
NULLABLE_FIELDS = ("sleep_hours", "sleep_quality", "stress", "cycle_phase")
DEFAULT_RANGE_DAYS = 30
MAX_RANGE_DAYS = 366
MAX_QUESTION_LENGTH = 300


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def get_lang(request):
    # Same convention as the rest of the API: anything but "en" is Macedonian.
    return "en" if request.query_params.get("lang") == "en" else "mk"


def parse_date(value, field="date"):
    try:
        return serializers.DateField().run_validation(value)
    except serializers.ValidationError as error:
        raise serializers.ValidationError({field: error.detail})


def date_range(request, default_days=DEFAULT_RANGE_DAYS):
    today = timezone.localdate()
    end = parse_date(request.query_params["to"], "to") if request.query_params.get("to") else today
    start = parse_date(request.query_params["from"], "from") if request.query_params.get("from") else end - timedelta(days=default_days - 1)
    if start > end:
        raise serializers.ValidationError({"from": "Must not be after 'to'."})
    if (end - start).days >= MAX_RANGE_DAYS:
        raise serializers.ValidationError({"from": f"Range is limited to {MAX_RANGE_DAYS} days."})
    return start, end


def get_reminder_settings(user):
    return ReminderSettings.objects.get_or_create(user=user)[0]


def normalize_log_data(request):
    """Accepts JSON or multipart (photo upload); returns a plain dict."""
    raw = request.data
    if not hasattr(raw, "getlist"):
        data = dict(raw)
    else:
        data = {}
        for key in raw.keys():
            if key in LIST_FIELDS:
                values = raw.getlist(key)
                if len(values) == 1 and values[0].strip().startswith("["):
                    try:
                        values = json.loads(values[0])
                    except ValueError:
                        raise serializers.ValidationError({key: "Invalid list."})
                if key in ("routine_am", "routine_pm"):
                    values = [int(v) if isinstance(v, str) and v.isdigit() else v for v in values]
                data[key] = values
            else:
                data[key] = raw.get(key)

    for key in NULLABLE_FIELDS:
        if data.get(key) == "":
            data[key] = None
    if str(data.pop("remove_photo", "")).lower() in ("1", "true"):
        data["photo"] = None
    return data


def save_log(request, day):
    """Upsert by date. Returns (log, created)."""
    user = request.user
    today = timezone.localdate()
    if day > today + timedelta(days=1):
        raise serializers.ValidationError({"date": "Cannot log a future date."})

    data = normalize_log_data(request)
    data["date"] = day.isoformat()

    instance = DailyLog.objects.filter(user=user, date=day).first()
    old_photo = instance.photo.name if instance and instance.photo else None

    serializer = DailyLogSerializer(instance, data=data, partial=instance is not None, context={"request": request})
    serializer.is_valid(raise_exception=True)

    extra = {}
    # Cycle tracking is opt-in: ignore the phase unless the user enabled it.
    if not get_reminder_settings(user).cycle_tracking_enabled:
        extra["cycle_phase"] = None

    log = serializer.save(user=user, date=day, **extra)

    if old_photo and log.photo.name != old_photo:
        log.photo.storage.delete(old_photo)

    return log, instance is None


def own_log_or_404(request, day):
    return get_object_or_404(DailyLog, user=request.user, date=day)


# ---------------------------------------------------------------------------
# Daily logs
# ---------------------------------------------------------------------------

@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
@parser_classes([JSONParser, MultiPartParser, FormParser])
def logs_collection(request):
    if request.method == "POST":
        day = parse_date(request.data.get("date"))
        log, created = save_log(request, day)
        body = DailyLogSerializer(log, context={"request": request}).data
        return Response(body, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)

    start, end = date_range(request)
    logs = DailyLog.objects.filter(user=request.user, date__gte=start, date__lte=end).order_by("date")
    return Response(DailyLogSerializer(logs, many=True, context={"request": request}).data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def food_suggestions(request):
    """The user's own recently used custom food tags (newest first)."""
    seen = []
    recent = DailyLog.objects.filter(user=request.user).order_by("-date").values_list("food_tags", flat=True)[:90]
    for tags in recent:
        for tag in tags or []:
            if is_custom_food_tag(tag) and tag not in seen:
                seen.append(tag)
    return Response({"tags": seen[:c.MAX_FOOD_SUGGESTIONS]})


@api_view(["GET", "PUT", "DELETE"])
@permission_classes([IsAuthenticated])
@parser_classes([JSONParser, MultiPartParser, FormParser])
def log_detail(request, day):
    if request.method == "PUT":
        log, created = save_log(request, day)
        body = DailyLogSerializer(log, context={"request": request}).data
        return Response(body, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)

    log = own_log_or_404(request, day)
    if request.method == "DELETE":
        log.delete()  # post_delete signal removes the photo file
        return Response(status=status.HTTP_204_NO_CONTENT)
    return Response(DailyLogSerializer(log, context={"request": request}).data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def log_photo(request, day):
    """The ONLY way to read a check-in photo: authenticated and owner-checked."""
    log = own_log_or_404(request, day)
    if not log.photo:
        return Response(status=status.HTTP_404_NOT_FOUND)

    content_type = mimetypes.guess_type(log.photo.name)[0] or "application/octet-stream"
    response = FileResponse(log.photo.open("rb"), content_type=content_type)
    response["Cache-Control"] = "private, no-store"
    return response


# ---------------------------------------------------------------------------
# Products
# ---------------------------------------------------------------------------

@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def products_collection(request):
    if request.method == "POST":
        serializer = SkincareProductSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(user=request.user)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    products = SkincareProduct.objects.filter(user=request.user)
    return Response(SkincareProductSerializer(products, many=True).data)


@api_view(["GET", "PUT", "PATCH", "DELETE"])
@permission_classes([IsAuthenticated])
def product_detail(request, id):
    product = get_object_or_404(SkincareProduct, id=id, user=request.user)

    if request.method == "DELETE":
        product.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    if request.method in ("PUT", "PATCH"):
        serializer = SkincareProductSerializer(product, data=request.data, partial=request.method == "PATCH")
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)
    return Response(SkincareProductSerializer(product).data)


# ---------------------------------------------------------------------------
# Status, week strip, timeline
# ---------------------------------------------------------------------------

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def today_status(request):
    today = timezone.localdate()
    logs = DailyLog.objects.filter(user=request.user)
    current, best = compute_streaks(set(logs.values_list("date", flat=True)), today)
    today_log = logs.filter(date=today).first()
    return Response({
        "date": today.isoformat(),
        "logged_today": today_log is not None,
        "today_log": DailyLogSerializer(today_log, context={"request": request}).data if today_log else None,
        "streak": {"current": current, "best": best},
        "total_check_ins": logs.count(),
    })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def week_view(request):
    today = timezone.localdate()
    monday = today - timedelta(days=today.weekday())
    logs = DailyLog.objects.filter(user=request.user, date__gte=monday, date__lte=monday + timedelta(days=6))
    return Response({"days": week_strip({log.date: log for log in logs}, today)})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def timeline_view(request):
    start, end = date_range(request)
    logs = list(DailyLog.objects.filter(user=request.user, date__gte=start, date__lte=end))
    scans = TrackedScan.objects.filter(user=request.user, date__gte=start, date__lte=end).select_related("analysis__condition")

    points = series.timeline_points(logs)
    for point in points:
        point["photo_url"] = (
            request.build_absolute_uri(f"/api/tracking/logs/{point['date']}/photo/") if point["has_photo"] else None
        )

    return Response({
        "from": start.isoformat(),
        "to": end.isoformat(),
        "points": points,
        "cycle_phases": series.cycle_ranges(logs),
        "scans": TrackedScanSerializer(scans, many=True, context={"request": request}).data,
    })


# ---------------------------------------------------------------------------
# Insights, correlation, weekly report, Ask AI
# ---------------------------------------------------------------------------

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def insights_view(request):
    result = insights_text.get_insights(request.user, get_lang(request), timezone.localdate())
    return Response(result)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def correlation_view(request):
    x, y = request.query_params.get("x"), request.query_params.get("y")
    if x not in series.METRICS or y not in series.METRICS or x == y:
        return Response(
            {"detail": f"'x' and 'y' must be two different values of: {', '.join(series.METRICS)}."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    start, end = date_range(request, default_days=90)
    logs = DailyLog.objects.filter(user=request.user, date__gte=start, date__lte=end)
    return Response(series.correlation(list(logs), x, y))


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def weekly_report_view(request):
    lang = get_lang(request)
    today = timezone.localdate()
    logs, products = insights_text.load_data(request.user, today)
    insights = insights_text.compute_insights(logs, products)
    top = None
    if insights["findings"]:
        findings = insights_text.attach_texts(request.user, insights["findings"][:1], lang)
        top = {k: findings[0][k] for k in ("id", "category", "category_label", "strength", "strength_label", "confidence", "text")}
    return Response(compute_weekly_report(logs, today, top, lang))


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def ask_view(request):
    question = str(request.data.get("question", "")).strip()
    if not question or len(question) > MAX_QUESTION_LENGTH:
        return Response(
            {"question": f"Required, up to {MAX_QUESTION_LENGTH} characters."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    lang = get_lang(request)
    result = insights_text.answer_question(request.user, question, request.data.get("chip"), lang, timezone.localdate())
    result["disclaimer"] = insights_text.texts.DISCLAIMER[lang]
    return Response(result)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def suggested_questions(request):
    lang = get_lang(request)
    return Response([
        {"chip": key, "text": labels[lang]} for key, labels in insights_text.SUGGESTED_CHIPS.items()
    ])


# ---------------------------------------------------------------------------
# Reminders
# ---------------------------------------------------------------------------

@api_view(["GET", "PUT", "PATCH"])
@permission_classes([IsAuthenticated])
def reminders_view(request):
    settings_obj = get_reminder_settings(request.user)
    if request.method == "GET":
        return Response(ReminderSettingsSerializer(settings_obj).data)

    serializer = ReminderSettingsSerializer(settings_obj, data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)
    serializer.save()
    return Response(serializer.data)


# ---------------------------------------------------------------------------
# Saved scans ("Save to tracking")
# ---------------------------------------------------------------------------

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def scan_save(request, analysis_id):
    analysis = get_object_or_404(Analysis, id=analysis_id, user=request.user)

    existing = TrackedScan.objects.filter(user=request.user, analysis=analysis).first()
    data = {key: request.data[key] for key in ("body_area", "note") if key in request.data}
    serializer = TrackedScanSerializer(existing, data=data, partial=True, context={"request": request})
    serializer.is_valid(raise_exception=True)

    extra = {}
    if request.data.get("date"):
        extra["date"] = parse_date(request.data["date"])
    elif existing is None:
        extra["date"] = timezone.localdate(analysis.created_at)
    scan = serializer.save(user=request.user, analysis=analysis, **extra)

    # The scan is linked to that day's check-in by date; no empty log is created.
    body = TrackedScanSerializer(scan, context={"request": request}).data
    body["log_exists"] = DailyLog.objects.filter(user=request.user, date=scan.date).exists()
    return Response(body, status=status.HTTP_201_CREATED if existing is None else status.HTTP_200_OK)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def scans_collection(request):
    scans = TrackedScan.objects.filter(user=request.user).select_related("analysis__condition")
    area = request.query_params.get("body_area")
    if area:
        scans = scans.filter(body_area=area)
    return Response(TrackedScanSerializer(scans, many=True, context={"request": request}).data)


@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def scan_delete(request, id):
    get_object_or_404(TrackedScan, id=id, user=request.user).delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


# ---------------------------------------------------------------------------
# Delete everything
# ---------------------------------------------------------------------------

@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def delete_all_tracking_data(request):
    """Wipes the user's logs (and photo files), products, saved scans, reminders and cached insights."""
    if request.query_params.get("confirm") != "true":
        return Response({"detail": "Add ?confirm=true to delete all tracking data."}, status=status.HTTP_400_BAD_REQUEST)

    user = request.user
    deleted = {
        "logs": DailyLog.objects.filter(user=user).delete()[1].get("tracking.DailyLog", 0),  # signal removes photo files
        "products": SkincareProduct.objects.filter(user=user).delete()[1].get("tracking.SkincareProduct", 0),
        "scans": TrackedScan.objects.filter(user=user).delete()[1].get("tracking.TrackedScan", 0),
    }
    ReminderSettings.objects.filter(user=user).delete()
    InsightCache.objects.filter(user=user).delete()
    return Response(deleted)
