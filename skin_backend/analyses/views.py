import uuid

from django.http import HttpResponse
from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from core.models import SkinCondition, Recommendation, ConditionRecommendation
from .models import Analysis, AnalysisChatMessage, ChatRole
from .serializers import (
    AnalysisListSerializer,
    AnalysisDetailSerializer,
    AnalysisChatMessageSerializer,
)
from .services.skin_model_service import predict_skin_condition, SkinModelPredictionError
from .services.gemini_service import (
    generate_recommendations_with_gemini,
    generate_chat_answer,
)
from .services.pdf_service import build_analysis_pdf

MAX_CHAT_HISTORY_MESSAGES = 10
MAX_CHAT_QUESTION_LENGTH = 500


# ---------------------------------------------------------------------------
# HELPERS (same as in leafscan: is_admin_user, can_access_analysis,
# generate_analysis_key)
# ---------------------------------------------------------------------------

def is_admin_user(request):
    return (
        request.user.is_staff
        or request.user.is_superuser
        or getattr(request.user, "role", None) == "ADMIN"
    )


def can_access_analysis(request, analysis):
    return is_admin_user(request) or analysis.user_id == request.user.id


def generate_analysis_key():
    return f"SK-{uuid.uuid4().hex[:8].upper()}"


def condition_has_recommendations(condition):
    if not condition:
        return False
    return ConditionRecommendation.objects.filter(condition=condition).exists()


def save_gemini_recommendations_for_condition(condition, recommendations_data):
    if not condition or not recommendations_data:
        return []

    saved = []

    for item in recommendations_data:
        name = item.get("name")
        description = item.get("description")
        rec_type = item.get("type")
        name_mk = item.get("name_mk")
        description_mk = item.get("description_mk")

        if not name or not description or not rec_type:
            continue

        recommendation, created = Recommendation.objects.get_or_create(
            name=name,
            type=rec_type,
            defaults={
                "description": description,
                "name_mk": name_mk,
                "description_mk": description_mk,
            },
        )

        if not created:
            update_fields = []
            if not recommendation.description:
                recommendation.description = description
                update_fields.append("description")
            if not recommendation.name_mk and name_mk:
                recommendation.name_mk = name_mk
                update_fields.append("name_mk")
            if not recommendation.description_mk and description_mk:
                recommendation.description_mk = description_mk
                update_fields.append("description_mk")
            if update_fields:
                recommendation.save(update_fields=update_fields)

        ConditionRecommendation.objects.get_or_create(
            condition=condition,
            recommendation=recommendation,
        )

        saved.append(recommendation)

    return saved


def generate_recommendations_only_if_missing(condition):
    """
    Gemini is only called if the condition doesn't already have saved
    recommendations - same as the treatments in leafscan (we don't want
    different advice on every scan of the same condition).
    """

    if not condition:
        return {"generated": False, "reason": "Missing condition.", "count": 0}

    if condition_has_recommendations(condition):
        existing_count = ConditionRecommendation.objects.filter(condition=condition).count()
        return {
            "generated": False,
            "reason": "Recommendations already exist for this condition.",
            "count": existing_count,
        }

    recommendations_data = generate_recommendations_with_gemini(
        condition_name=condition.name,
        severity=condition.severity or "MEDIUM",
    )

    saved = save_gemini_recommendations_for_condition(condition, recommendations_data)

    return {
        "generated": True,
        "reason": "Recommendations generated successfully.",
        "count": len(saved),
    }


# ---------------------------------------------------------------------------
# ANALYSES
# ---------------------------------------------------------------------------

@api_view(["POST"])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def scan_skin(request):
    """
    THE MAIN endpoint - equivalent to scan_plant() from leafscan.

    Flow: image -> local model (skin_model_service) -> looks up SkinCondition
    by `key` -> saves Analysis -> generates Gemini recommendations (only the
    first time for that condition) -> returns everything together.

    While analyses/services/ai_model/skin_model.pt doesn't exist yet (before
    you train it), this will return a 502 with a clear message - that's
    expected, not a bug.
    """

    image = request.FILES.get("image")

    if not image:
        return Response(
            {"image": "This field is required."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        prediction = predict_skin_condition(image)

        if hasattr(image, "seek"):
            image.seek(0)

    except SkinModelPredictionError as error:
        return Response(
            {
                "detail": "AI prediction failed.",
                "error": str(error),
            },
            status=status.HTTP_502_BAD_GATEWAY,
        )

    condition_key = prediction.get("condition_key")

    condition = SkinCondition.objects.filter(key=condition_key).first()

    if not condition:
        return Response(
            {
                "condition": (
                    f"Condition '{condition_key}' does not exist in database. "
                    "Изврши `python manage.py seed_skin_conditions` прво."
                ),
                "prediction": prediction,
            },
            status=status.HTTP_404_NOT_FOUND,
        )

    analysis = Analysis.objects.create(
        analysis_key=generate_analysis_key(),
        user=request.user,
        condition=condition,
        image=image,
        confidence=prediction.get("confidence"),
        is_low_confidence=prediction.get("is_low_confidence", False),
    )

    recommendation_generation = generate_recommendations_only_if_missing(condition)

    serializer = AnalysisDetailSerializer(analysis, context={"request": request})

    return Response(
        {
            "message": "Analysis created successfully.",
            "prediction": prediction,
            "recommendation_generation": recommendation_generation,
            "analysis": serializer.data,
        },
        status=status.HTTP_201_CREATED,
    )


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def my_analyses(request):
    analyses = Analysis.objects.filter(
        user=request.user
    ).select_related("condition").order_by("-created_at")

    serializer = AnalysisListSerializer(analyses, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def analysis_detail(request, id):
    analysis = get_object_or_404(
        Analysis.objects.select_related("user", "condition"),
        id=id,
    )

    if not can_access_analysis(request, analysis):
        return Response(
            {"detail": "You do not have permission to access this analysis."},
            status=status.HTTP_403_FORBIDDEN,
        )

    serializer = AnalysisDetailSerializer(analysis, context={"request": request})
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def analysis_pdf(request, id):
    """
    Downloadable PDF summary of one analysis - condition, photo, severity/
    confidence, description/symptoms/treatment, recommendations. Same
    access rule as analysis_detail (owner or admin only - this is
    personal health-adjacent data). Language follows the usual ?lang=
    convention (defaults to mk, matching every other endpoint).

    Returns a plain Django HttpResponse (not a DRF Response) because the
    body is raw PDF bytes, not JSON - DRF's renderers aren't involved.
    """
    analysis = get_object_or_404(
        Analysis.objects.select_related("user", "condition"),
        id=id,
    )

    if not can_access_analysis(request, analysis):
        return Response(
            {"detail": "You do not have permission to access this analysis."},
            status=status.HTTP_403_FORBIDDEN,
        )

    lang = request.query_params.get("lang", "mk")
    pdf_bytes = build_analysis_pdf(analysis, lang=lang)

    response = HttpResponse(pdf_bytes, content_type="application/pdf")
    response["Content-Disposition"] = f'attachment; filename="{analysis.analysis_key}.pdf"'
    return response


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_analyses(request):
    if not is_admin_user(request):
        return Response(
            {"detail": "Admin permission required."},
            status=status.HTTP_403_FORBIDDEN,
        )

    analyses = Analysis.objects.all().select_related("user", "condition").order_by("-created_at")
    serializer = AnalysisListSerializer(analyses, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)


# ---------------------------------------------------------------------------
# CHAT (Q&A for a specific analysis)
# ---------------------------------------------------------------------------

@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def analysis_chat(request, id):
    analysis = get_object_or_404(
        Analysis.objects.select_related("user", "condition"),
        id=id,
    )

    if not can_access_analysis(request, analysis):
        return Response(
            {"detail": "You do not have permission to access this analysis."},
            status=status.HTTP_403_FORBIDDEN,
        )

    if request.method == "GET":
        messages = analysis.chat_messages.all()
        serializer = AnalysisChatMessageSerializer(messages, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    # POST - ask a new question
    if not analysis.condition:
        return Response(
            {"detail": "This analysis has no associated condition to ask about."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    question = str(request.data.get("question", "")).strip()

    if not question:
        return Response(
            {"question": "This field is required."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if len(question) > MAX_CHAT_QUESTION_LENGTH:
        return Response(
            {"question": f"Question is too long (max {MAX_CHAT_QUESTION_LENGTH} characters)."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    recent_messages = list(
        analysis.chat_messages.order_by("-created_at")[:MAX_CHAT_HISTORY_MESSAGES]
    )
    recent_messages.reverse()
    history = [{"role": m.role, "content": m.content} for m in recent_messages]

    user_message = AnalysisChatMessage.objects.create(
        analysis=analysis,
        role=ChatRole.USER,
        content=question,
    )

    answer_text = generate_chat_answer(
        condition_name=analysis.condition.name,
        severity=analysis.condition.severity or "MEDIUM",
        description=analysis.condition.description,
        history=history,
        question=question,
    )

    assistant_message = AnalysisChatMessage.objects.create(
        analysis=analysis,
        role=ChatRole.ASSISTANT,
        content=answer_text,
    )

    return Response(
        {
            "user_message": AnalysisChatMessageSerializer(user_message).data,
            "assistant_message": AnalysisChatMessageSerializer(assistant_message).data,
        },
        status=status.HTTP_201_CREATED,
    )
