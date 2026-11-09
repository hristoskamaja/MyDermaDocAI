"""
Phrasing of the computed insights and the "Ask AI about my patterns" panel.

Gemini is used ONLY to put already-computed findings into plain EN/MK
sentences. It never sees raw notes, photos or dates - only the numeric
summary the engine produced. Results are cached, and a template sentence
is used whenever Gemini is unavailable (no key, quota, bad output).
"""

import hashlib
import json
import logging
import os
import re
from datetime import timedelta

from google.genai import types

from analyses.services.gemini_service import _generate_content_with_retry, _make_client
from tracking.models import InsightCache, SkincareProduct, DailyLog

from . import texts
from .insights_engine import CUSTOM_PLACEHOLDER, compute_insights
from .weekly import compute_weekly_report

logger = logging.getLogger(__name__)

HISTORY_DAYS = 120
MAX_CACHED_PER_LANG = 5

# Safety net on Gemini output: no diagnoses, medication or causal claims.
_FORBIDDEN = re.compile(
    r"\b(because|causes|caused by|leads to|cure|diagnos\w*|prescri\w*|medicat\w*)\b"
    r"|\b(предизвикува|поради|дијагноз\w*|лекови|лекот|лек)\b",
    re.IGNORECASE,
)


def _call_gemini(prompt, json_output=False):
    """The single place that talks to Gemini (mocked in tests)."""
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY is missing.")

    config = types.GenerateContentConfig(
        temperature=0.3,
        response_mime_type="application/json" if json_output else None,
    )
    response = _generate_content_with_retry(_make_client(api_key), prompt, config)
    return (response.text or "").strip()


def _is_safe(text):
    return isinstance(text, str) and 10 <= len(text.strip()) <= 700 and not _FORBIDDEN.search(text)


def load_data(user, today):
    since = today - timedelta(days=HISTORY_DAYS)
    logs = list(DailyLog.objects.filter(user=user, date__gte=since, date__lte=today))
    products = list(SkincareProduct.objects.filter(user=user))
    return logs, products


# ---------------------------------------------------------------------------
# Insight cards
# ---------------------------------------------------------------------------

def _findings_hash(findings, lang):
    core = [
        [f["id"], f["strength"], f["confidence"], f["n_with"], f["n_without"], f["mean_with"], f["mean_without"]]
        for f in findings
    ]
    return hashlib.sha256(json.dumps([lang, core]).encode()).hexdigest()


def _phrasing_prompt(findings, lang):
    language = "Macedonian" if lang == "mk" else "English"
    # Custom food names are user-typed text: they never reach the prompt. A
    # placeholder stands in for them and is swapped back after phrasing.
    items = [
        {"id": f["id"], "sentence": f.get(f"template_masked_{lang}") or f[f"template_{lang}"]}
        for f in findings
    ]
    return (
        f"Rewrite each sentence below in simple, friendly {language}. Keep every number and fact "
        "exactly as given. These describe patterns in a person's own skin diary.\n"
        "Rules: describe patterns only - never say something causes acne; no diagnosis; no medication, "
        "products or doses; no advice except, if natural, 'a dermatologist can help with skin concerns'. "
        "Each result is at most 2 sentences.\n"
        'Return ONLY a JSON object mapping each id to its rewritten sentence, e.g. {"id": "text"}.\n\n'
        + json.dumps(items, ensure_ascii=False)
    )


def _phrase_with_gemini(findings, lang):
    raw = _call_gemini(_phrasing_prompt(findings, lang), json_output=True)
    data = json.loads(raw)
    result = {}
    for f in findings:
        text = data.get(f["id"]) if isinstance(data, dict) else None
        if f.get("custom_food"):
            # The placeholder must survive; then the user's own tag goes back in.
            if not isinstance(text, str) or CUSTOM_PLACEHOLDER not in text:
                raise ValueError(f"Placeholder lost in Gemini phrasing for {f['id']}")
            text = text.replace(CUSTOM_PLACEHOLDER, f["custom_food"])
        if not _is_safe(text):
            raise ValueError(f"Unusable Gemini phrasing for {f['id']}")
        result[f["id"]] = text.strip()
    return result


def attach_texts(user, findings, lang):
    """Adds `text` and `text_source` ('ai' | 'template') to every finding."""
    if not findings:
        return findings

    digest = _findings_hash(findings, lang)
    cached = InsightCache.objects.filter(user=user, lang=lang, findings_hash=digest).first()
    phrased = cached.texts if cached else None

    if phrased is None:
        try:
            phrased = _phrase_with_gemini(findings, lang)
            InsightCache.objects.get_or_create(user=user, lang=lang, findings_hash=digest, defaults={"texts": phrased})
            stale = InsightCache.objects.filter(user=user, lang=lang).order_by("-created_at").values_list("id", flat=True)[MAX_CACHED_PER_LANG:]
            InsightCache.objects.filter(id__in=list(stale)).delete()
        except Exception:
            logger.warning("Insight phrasing fell back to templates", exc_info=True)
            phrased = None

    for f in findings:
        text = (phrased or {}).get(f["id"])
        f["text"] = text or f[f"template_{lang}"]
        f["text_source"] = "ai" if text else "template"
        f["category_label"] = texts.CATEGORY_LABELS[lang][f["category"]]
        f["strength_label"] = texts.STRENGTH_LABELS[lang][f["strength"]]
    return findings


def get_insights(user, lang, today):
    logs, products = load_data(user, today)
    result = compute_insights(logs, products)
    result["findings"] = attach_texts(user, result["findings"], lang)
    result["featured"] = result["findings"][0] if result["findings"] else None
    result["disclaimer"] = texts.DISCLAIMER[lang]
    return result


# ---------------------------------------------------------------------------
# Ask AI about my patterns
# ---------------------------------------------------------------------------

SUGGESTED_CHIPS = {
    "why_breakout_week": {"en": "Why did I break out this week?", "mk": "Зошто ми излегоа бубулички оваа недела?"},
    "food_most": {"en": "Which food affects me most?", "mk": "Која храна најмногу влијае врз мене?"},
    "retinol_timing": {"en": "Best time to start retinol?", "mk": "Кога е најдобро да почнам со ретинол?"},
}

RETINOL_ANSWER = {
    "en": "Whether and when to start retinol depends on your skin, your current routine and other factors "
          "that a diary can't judge. In general, active ingredients are introduced slowly and not during "
          "a period of irritated skin - but please ask a dermatologist what suits you.",
    "mk": "Дали и кога да започнете со ретинол зависи од вашата кожа, моменталната рутина и други фактори "
          "што еден дневник не може да ги процени. Општо, активните состојки се воведуваат полека и не "
          "додека кожата е надразнета - но прашајте дерматолог што е соодветно за вас.",
}

NO_DATA_ANSWER = {
    "en": "There isn't enough data in your check-ins yet to see a pattern. Keep logging for a few more days.",
    "mk": "Сè уште нема доволно податоци во вашите записи за да се види шема. Продолжете да бележите уште неколку дена.",
}

_RETINOL_WORDS = re.compile(r"retinol|ретинол", re.IGNORECASE)


def _question_kind(question, chip):
    if chip in SUGGESTED_CHIPS:
        return chip
    for key, labels in SUGGESTED_CHIPS.items():
        if question.strip().lower() in (labels["en"].lower(), labels["mk"].lower()):
            return key
    return "retinol_timing" if _RETINOL_WORDS.search(question) else "general"


def _fallback_answer(kind, summary, lang):
    findings = summary["findings"]
    report = summary["weekly_report"]

    if kind == "food_most":
        food = next((f for f in findings if f["category"] == "food"), None)
        if food:
            return food[f"template_{lang}"]
        return NO_DATA_ANSWER[lang]

    if kind == "why_breakout_week":
        if report["avg_severity"] is None:
            return NO_DATA_ANSWER[lang]
        if lang == "mk":
            head = (f"Во последните 7 дена просечната изразеност беше {report['avg_severity']:.1f} "
                    f"(на скала 0-3), {report['trend_label'].lower() if report['trend_label'] else 'без споредба со претходната недела'}.")
        else:
            head = (f"Over the last 7 days your average was {report['avg_severity']:.1f} (0-3 scale), "
                    f"{report['trend_label'].lower() if report['trend_label'] else 'with no previous week to compare'}.")
        return head + (" " + findings[0][f"template_{lang}"] if findings else "")

    return findings[0][f"template_{lang}"] if findings else NO_DATA_ANSWER[lang]


def _answer_prompt(summary, question, lang):
    language = "Macedonian" if lang == "mk" else "English"
    compact = {
        "weekly_report": {k: v for k, v in summary["weekly_report"].items() if k != "top_pattern"},
        "findings": [
            {
                **{k: f[k] for k in ("category", "area", "lag", "direction", "effect", "n_with", "n_without", "strength", "confidence")},
                # Custom food names are user text and are never sent to Gemini.
                "factor": "custom_food" if f.get("custom_food") else f["factor"],
            }
            for f in summary["findings"]
        ],
    }
    return (
        f"You answer in {language}, in at most 4 short sentences, using ONLY this computed summary of a "
        "person's skin diary. Describe patterns, never causes. Do not diagnose, do not mention medication, "
        "doses or specific products, and do not give medical advice. If the summary doesn't support an "
        "answer, say there isn't enough data yet. End by suggesting a dermatologist for any skin concern.\n\n"
        f"Summary (JSON): {json.dumps(compact, ensure_ascii=False)}\n\nQuestion: {question}"
    )


def answer_question(user, question, chip, lang, today):
    """Answers only from the computed summary - raw notes are never used."""
    kind = _question_kind(question, chip)
    if kind == "retinol_timing":
        return {"answer": RETINOL_ANSWER[lang], "source": "template"}

    logs, products = load_data(user, today)
    insights = compute_insights(logs, products)
    summary = {
        "findings": insights["findings"],
        "weekly_report": compute_weekly_report(logs, today, None, lang),
    }

    if insights["enough_data"]:
        try:
            answer = _call_gemini(_answer_prompt(summary, question, lang))
            if _is_safe(answer):
                return {"answer": answer, "source": "ai"}
            logger.warning("Ask-AI answer rejected by the safety filter")
        except Exception:
            logger.warning("Ask-AI fell back to a template answer", exc_info=True)

    return {"answer": _fallback_answer(kind, summary, lang), "source": "template"}
