"""
Builds a one-page(ish) PDF summary of a single Analysis - condition, photo,
severity/confidence, description/symptoms/treatment, and recommendations -
so a patient can save or print their scan result instead of only viewing it
in the app. Called from analyses/views.py's analysis_pdf view.

Uses reportlab (pure Python, no system libraries needed - unlike
weasyprint/wkhtmltopdf, which need extra native dependencies that are
painful to install on Windows). Content is built with reportlab's
"platypus" layout API (SimpleDocTemplate + flowables) rather than drawing
at fixed x/y coordinates, so long descriptions/recommendation lists wrap
and flow onto a second page automatically instead of overlapping or
getting cut off.
"""

import io
import os
from xml.sax.saxutils import escape as xml_escape

from django.utils import timezone

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    Image as RLImage,
    ListFlowable,
    ListItem,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

from core.models import ConditionRecommendation, Recommendation

# Sage & Stone palette - same hex values as skin_mobile's AppColors.light /
# skin_web's theme-patient CSS variables, so the PDF looks like it belongs
# to the same app instead of a generic default-styled document.
#
# Kept as plain "#RRGGBB" strings (not just reportlab Color objects)
# because inline Paragraph markup like <font color='...'> needs a literal
# "#RRGGBB"/name string - reportlab Color's own .hexval() returns a
# "0xRRGGBB"-style string that the Paragraph XML parser doesn't accept,
# so mixing the two up would raise at PDF-build time, not import time.
_HEX_TEXT = "#2B1A10"
_HEX_TEXT_MUTED = "#8A7360"
_HEX_TEXT_LIGHT = "#B5A190"
_HEX_PRIMARY = "#7B4B2A"
_HEX_LOW = "#6E8B4F"
_HEX_MEDIUM = "#C08A3E"
_HEX_HIGH = "#B5482F"

_COLOR_TEXT = colors.HexColor(_HEX_TEXT)
_COLOR_TEXT_MUTED = colors.HexColor(_HEX_TEXT_MUTED)
_COLOR_TEXT_LIGHT = colors.HexColor(_HEX_TEXT_LIGHT)
_COLOR_PRIMARY = colors.HexColor(_HEX_PRIMARY)
_COLOR_HIGH = colors.HexColor(_HEX_HIGH)

_SEVERITY_HEX = {"LOW": _HEX_LOW, "MEDIUM": _HEX_MEDIUM, "HIGH": _HEX_HIGH}

# ---------------------------------------------------------------------------
# Font registration - reportlab's 14 built-in fonts (Helvetica etc.) only
# cover Latin-1, so Macedonian Cyrillic text renders as garbled tofu boxes
# with them. We register a real TTF that has Cyrillic glyphs instead -
# Arial on Windows (this project's dev/deploy target) covers it fully; a
# couple of Linux/macOS fallbacks are included in case this ever runs
# elsewhere. If none of these paths exist, we silently keep Helvetica -
# English reports still look fine, only Macedonian ones would show boxes,
# which beats crashing PDF generation entirely.
# ---------------------------------------------------------------------------

_FONT_REGULAR = "Helvetica"
_FONT_BOLD = "Helvetica-Bold"

_CANDIDATE_FONTS = [
    (r"C:\Windows\Fonts\arial.ttf", r"C:\Windows\Fonts\arialbd.ttf"),
    (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ),
    (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ),
    ("/Library/Fonts/Arial.ttf", "/Library/Fonts/Arial Bold.ttf"),
]


def _register_unicode_font():
    global _FONT_REGULAR, _FONT_BOLD

    for regular_path, bold_path in _CANDIDATE_FONTS:
        try:
            if not os.path.exists(regular_path):
                continue
            pdfmetrics.registerFont(TTFont("PDFBody", regular_path))
            _FONT_REGULAR = "PDFBody"
            if os.path.exists(bold_path):
                pdfmetrics.registerFont(TTFont("PDFBody-Bold", bold_path))
                _FONT_BOLD = "PDFBody-Bold"
            else:
                _FONT_BOLD = "PDFBody"
            return
        except Exception:
            continue


_register_unicode_font()


# ---------------------------------------------------------------------------
# Bilingual static labels - same spirit as gemini_service.py's prompts:
# everything user-facing exists in both EN and MK, chosen by the same
# ?lang= the rest of the API already uses (see AnalysisDetailSerializer).
# ---------------------------------------------------------------------------

_LABELS = {
    "en": {
        "title": "DermaScanAI",
        "subtitle": "Skin Analysis Report",
        "analysis_id": "Analysis ID",
        "date": "Date",
        "severity": "Severity",
        "confidence": "Confidence",
        "low_confidence_note": (
            "Low-confidence result - treat this prediction with extra caution."
        ),
        "description": "Description",
        "symptoms": "Symptoms",
        "treatment": "General treatment overview",
        "recommendations": "Recommendations",
        "no_condition": "No condition could be matched for this scan.",
        "no_recommendations": "No recommendations available yet.",
        "disclaimer": (
            "This report is generated by an AI model and is not a medical "
            "diagnosis. Always consult a licensed dermatologist for an "
            "accurate evaluation and treatment."
        ),
        "generated_on": "Generated on",
        "severity_labels": {"LOW": "Low", "MEDIUM": "Medium", "HIGH": "High"},
        "type_labels": {
            "SELF_CARE": "Self-care",
            "MEDICAL_CONSULT": "Medical consultation",
            "LIFESTYLE": "Lifestyle",
        },
    },
    "mk": {
        "title": "DermaScanAI",
        "subtitle": "Извештај од анализа на кожа",
        "analysis_id": "ID на анализа",
        "date": "Датум",
        "severity": "Тежина",
        "confidence": "Доверливост",
        "low_confidence_note": (
            "Резултат со ниска доверливост - земи го со дополнителна претпазливост."
        ),
        "description": "Опис",
        "symptoms": "Симптоми",
        "treatment": "Општ преглед на третман",
        "recommendations": "Препораки",
        "no_condition": "Не можеше да се препознае состојба за ова скенирање.",
        "no_recommendations": "Сè уште нема достапни препораки.",
        "disclaimer": (
            "Овој извештај е генериран од AI модел и не претставува "
            "медицинска дијагноза. Секогаш консултирај се со лиценциран "
            "дерматолог за точна проценка и третман."
        ),
        "generated_on": "Генерирано на",
        "severity_labels": {"LOW": "Ниска", "MEDIUM": "Средна", "HIGH": "Висока"},
        "type_labels": {
            "SELF_CARE": "Само-нега",
            "MEDICAL_CONSULT": "Медицинска консултација",
            "LIFESTYLE": "Начин на живот",
        },
    },
}


def _escape(text):
    return xml_escape(str(text or ""))


def _format_date(dt):
    if dt is None:
        return "-"
    local_dt = timezone.localtime(dt) if timezone.is_aware(dt) else dt
    return local_dt.strftime("%d.%m.%Y %H:%M")


def _build_styles():
    base = getSampleStyleSheet()
    return {
        "Brand": ParagraphStyle(
            "Brand", parent=base["Title"], fontName=_FONT_BOLD, fontSize=20,
            textColor=_COLOR_PRIMARY, spaceAfter=2, alignment=0,
        ),
        "Subtitle": ParagraphStyle(
            "Subtitle", parent=base["Normal"], fontName=_FONT_REGULAR,
            fontSize=11, textColor=_COLOR_TEXT_MUTED,
        ),
        "ConditionName": ParagraphStyle(
            "ConditionName", parent=base["Heading1"], fontName=_FONT_BOLD,
            fontSize=16, textColor=_COLOR_TEXT, spaceAfter=4,
        ),
        "SectionHeading": ParagraphStyle(
            "SectionHeading", parent=base["Heading2"], fontName=_FONT_BOLD,
            fontSize=12, textColor=_COLOR_PRIMARY, spaceBefore=8, spaceAfter=4,
        ),
        "Body": ParagraphStyle(
            "Body", parent=base["Normal"], fontName=_FONT_REGULAR,
            fontSize=10.5, textColor=_COLOR_TEXT, leading=15,
        ),
        "Warning": ParagraphStyle(
            "Warning", parent=base["Normal"], fontName=_FONT_BOLD,
            fontSize=9.5, textColor=_COLOR_HIGH,
        ),
        "Disclaimer": ParagraphStyle(
            "Disclaimer", parent=base["Normal"], fontName=_FONT_REGULAR,
            fontSize=8.5, textColor=_COLOR_TEXT_MUTED, leading=12,
        ),
        "Footer": ParagraphStyle(
            "Footer", parent=base["Normal"], fontName=_FONT_REGULAR,
            fontSize=8, textColor=_COLOR_TEXT_LIGHT,
        ),
    }


def _build_image_flowable(analysis):
    try:
        image_field = analysis.image
        if not image_field or not image_field.name:
            return None
        path = image_field.path
        if not os.path.exists(path):
            return None

        img = RLImage(path)
        max_width = 90 * mm
        max_height = 90 * mm
        ratio = min(max_width / img.imageWidth, max_height / img.imageHeight, 1)
        img.drawWidth = img.imageWidth * ratio
        img.drawHeight = img.imageHeight * ratio
        img.hAlign = "CENTER"
        return img
    except Exception:
        # A missing/corrupt image file shouldn't block the rest of the
        # report from generating - just skip the picture.
        return None


def _get_localized_recommendations(condition, wants_english):
    recommendation_ids = ConditionRecommendation.objects.filter(
        condition=condition
    ).values_list("recommendation_id", flat=True)
    recommendations = Recommendation.objects.filter(id__in=recommendation_ids)

    result = []
    for rec in recommendations:
        name = rec.name if wants_english else (rec.name_mk or rec.name)
        description = rec.description if wants_english else (rec.description_mk or rec.description)
        result.append({"name": name, "description": description or "", "type": rec.type})
    return result


def build_analysis_pdf(analysis, lang="mk"):
    """
    Returns the PDF file content as raw bytes. `lang` picks both the
    static labels above and which language column (description vs
    description_en, name vs name_mk, ...) gets used for the condition/
    recommendation text - same ?lang=en|mk convention as the rest of the
    API (see AnalysisDetailSerializer / LocalizedRecommendationSerializer).
    """
    lang = lang if lang in _LABELS else "mk"
    labels = _LABELS[lang]
    wants_english = lang == "en"

    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        topMargin=20 * mm,
        bottomMargin=16 * mm,
        leftMargin=20 * mm,
        rightMargin=20 * mm,
        title=f"{labels['title']} - {analysis.analysis_key}",
    )

    styles = _build_styles()
    story = []

    story.append(Paragraph(labels["title"], styles["Brand"]))
    story.append(Paragraph(labels["subtitle"], styles["Subtitle"]))
    story.append(Spacer(1, 10))

    meta_table = Table(
        [
            [labels["analysis_id"], analysis.analysis_key],
            [labels["date"], _format_date(analysis.created_at)],
        ],
        colWidths=[40 * mm, None],
    )
    meta_table.setStyle(TableStyle([
        ("FONTNAME", (0, 0), (-1, -1), _FONT_REGULAR),
        ("FONTSIZE", (0, 0), (-1, -1), 10),
        ("TEXTCOLOR", (0, 0), (0, -1), _COLOR_TEXT_MUTED),
        ("TEXTCOLOR", (1, 0), (1, -1), _COLOR_TEXT),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
    ]))
    story.append(meta_table)
    story.append(Spacer(1, 14))

    image_flowable = _build_image_flowable(analysis)
    if image_flowable:
        story.append(image_flowable)
        story.append(Spacer(1, 14))

    condition = analysis.condition

    if not condition:
        story.append(Paragraph(labels["no_condition"], styles["Body"]))
    else:
        story.append(Paragraph(_escape(condition.name), styles["ConditionName"]))

        severity_label = labels["severity_labels"].get(condition.severity, condition.severity or "-")
        severity_hex = _SEVERITY_HEX.get(condition.severity, _HEX_TEXT_MUTED)
        confidence_pct = (
            f"{round((analysis.confidence or 0) * 100)}%"
            if analysis.confidence is not None
            else "-"
        )

        story.append(Paragraph(
            f"<font color='{severity_hex}'>{labels['severity']}: {severity_label}</font>"
            f"&nbsp;&nbsp;&nbsp;&nbsp;{labels['confidence']}: {confidence_pct}",
            ParagraphStyle(
                "Badges", parent=styles["Body"], fontName=_FONT_BOLD, fontSize=11,
            ),
        ))

        if analysis.is_low_confidence:
            story.append(Spacer(1, 4))
            story.append(Paragraph(labels["low_confidence_note"], styles["Warning"]))

        story.append(Spacer(1, 10))

        description = (condition.description_en or condition.description) if wants_english else condition.description
        symptoms = (condition.symptoms_en or condition.symptoms) if wants_english else condition.symptoms
        treatment = (
            (condition.treatment_overview_en or condition.treatment_overview)
            if wants_english
            else condition.treatment_overview
        )

        for heading_key, text in (
            ("description", description),
            ("symptoms", symptoms),
            ("treatment", treatment),
        ):
            if text:
                story.append(Paragraph(labels[heading_key], styles["SectionHeading"]))
                story.append(Paragraph(_escape(text), styles["Body"]))

        story.append(Paragraph(labels["recommendations"], styles["SectionHeading"]))
        recommendations = _get_localized_recommendations(condition, wants_english)

        if recommendations:
            items = []
            for rec in recommendations:
                type_label = labels["type_labels"].get(rec["type"], rec["type"])
                items.append(
                    ListItem(
                        Paragraph(
                            f"<font name='{_FONT_BOLD}'>{_escape(rec['name'])}</font> "
                            f"<font color='{_HEX_TEXT_MUTED}'>({_escape(type_label)})</font>"
                            f" &mdash; {_escape(rec['description'])}",
                            styles["Body"],
                        ),
                        bulletColor=_COLOR_PRIMARY,
                    )
                )
            story.append(ListFlowable(items, bulletType="bullet", start="circle", leftIndent=14))
        else:
            story.append(Paragraph(labels["no_recommendations"], styles["Body"]))

    story.append(Spacer(1, 18))
    story.append(Paragraph(labels["disclaimer"], styles["Disclaimer"]))
    story.append(Spacer(1, 4))
    story.append(Paragraph(
        f"{labels['generated_on']}: {_format_date(timezone.now())}",
        styles["Footer"],
    ))

    doc.build(story)
    return buffer.getvalue()
