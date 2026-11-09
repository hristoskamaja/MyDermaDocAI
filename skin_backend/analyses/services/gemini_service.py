"""
gemini_service.py

"""

import json
import logging
import os
import re
import time
from typing import List, Dict

from google import genai
from google.genai import types
from google.genai.errors import APIError

logger = logging.getLogger(__name__)

# "gemini-2.5-flash" was cut off by Google for new projects (full shutdown
# planned for October 2026) - we use the "latest" alias instead of a fixed
# version so the model doesn't need to be changed by hand every time Google
# ships a new generation (Google gives 2 weeks notice before "latest" points
# to a version with breaking changes).
GEMINI_MODEL = "gemini-flash-latest"

# HTTP statuses that mean "try again" (temporarily overloaded model /
# rate limit), not a real error in our code or prompt.
_RETRYABLE_STATUS_CODES = {429, 503}
_MAX_ATTEMPTS = 3
_RETRY_BACKOFF_SECONDS = 1.5

# Without an explicit timeout, the underlying HTTP client has NO default
# ceiling - if Google's API is slow/unreachable from the server's network,
# a single call can hang for minutes, which hangs the whole scan-skin /
# chat request (and eventually the mobile/web client's own timeout fires
# first, showing "TimeoutException..." with no useful fallback content).
# Scan/recommendation calls are additionally capped by a time budget (see
# _RECOMMENDATION_BUDGET_S).
#
# Built defensively at import time: if the installed google-genai version
# doesn't recognize this field, we fall back to no explicit timeout
# instead of crashing the import (which would break every view in this
# app, since views.py imports from this module at startup).
#
# The recommendation answer is now much longer (5-7 rich items in two
# languages), so it gets a larger timeout than the short chat answers.
_GEMINI_TIMEOUT_MS = 15_000
_GEMINI_LONG_TIMEOUT_MS = 40_000
# Chat uses the light model first (it answers in a few seconds); a slow
# attempt is cut off after 20s so a retry on the other model still fits.
_GEMINI_CHAT_TIMEOUT_MS = 20_000

# Recommendations run inside the scan request: a retry is only started if
# it can still finish within this budget, so the worst case stays below the
# mobile app's 60s scan timeout (first attempt up to 40s, a retry only if
# elapsed + backoff + 40s <= 55s).
_RECOMMENDATION_BUDGET_S = 55

# Chat: up to 3 attempts, retrying 504 too. The first attempt uses the light
# model, retries use the regular one. A retry only starts if it can still
# finish inside the budget, so the worst case stays under ~50s
# (20s + backoff + 20s for two timeouts).
_CHAT_MAX_ATTEMPTS = 3
_CHAT_RETRYABLE_STATUS_CODES = {429, 503, 504}
_CHAT_BUDGET_S = 50
GEMINI_CHAT_MODEL = "gemini-flash-lite-latest"
GEMINI_CHAT_RETRY_MODEL = GEMINI_MODEL
_CHAT_MODELS = (GEMINI_CHAT_MODEL, GEMINI_CHAT_RETRY_MODEL)


def _build_http_options(timeout_ms):
    try:
        return types.HttpOptions(timeout=timeout_ms)
    except Exception:
        return None


_HTTP_OPTIONS = _build_http_options(_GEMINI_TIMEOUT_MS)
_LONG_HTTP_OPTIONS = _build_http_options(_GEMINI_LONG_TIMEOUT_MS)
_CHAT_HTTP_OPTIONS = _build_http_options(_GEMINI_CHAT_TIMEOUT_MS)


def _make_client(api_key: str, long_timeout: bool = False, chat_timeout: bool = False):
    if chat_timeout:
        http_options = _CHAT_HTTP_OPTIONS
    else:
        http_options = _LONG_HTTP_OPTIONS if long_timeout else _HTTP_OPTIONS
    if http_options is not None:
        return genai.Client(api_key=api_key, http_options=http_options)
    return genai.Client(api_key=api_key)


def _generate_content_with_retry(
    client,
    prompt,
    config,
    *,
    max_attempts=_MAX_ATTEMPTS,
    retryable_codes=_RETRYABLE_STATUS_CODES,
    models=None,
    attempt_timeout_s=None,
    budget_s=None,
):
    """
    Same call as client.models.generate_content, but with automatic retries
    on temporary errors (model overloaded / rate limit; chat also retries
    504 timeouts). After the last attempt, re-raises the real error so the
    existing except blocks handle it exactly as before (fallback content).

    - models: model per attempt (the last entry is reused for later attempts);
      defaults to GEMINI_MODEL for every attempt.
    - budget_s + attempt_timeout_s: a retry is only started if it could still
      finish inside the budget, which keeps the worst case under a caller's
      own deadline (e.g. the mobile app's 60s scan timeout).
    """
    started = time.monotonic()
    last_error = None

    for attempt in range(max_attempts):
        is_last_attempt = attempt == max_attempts - 1
        model = models[min(attempt, len(models) - 1)] if models else GEMINI_MODEL
        try:
            return client.models.generate_content(
                model=model,
                contents=prompt,
                config=config,
            )
        except APIError as error:
            last_error = error
            status_code = getattr(error, "code", None)

            if status_code in retryable_codes and not is_last_attempt:
                backoff = _RETRY_BACKOFF_SECONDS * (attempt + 1)
                if budget_s is not None and attempt_timeout_s is not None:
                    elapsed = time.monotonic() - started
                    if elapsed + backoff + attempt_timeout_s > budget_s:
                        raise
                logger.warning(
                    "Gemini %s on attempt %d/%d (model=%s); retrying.",
                    status_code, attempt + 1, max_attempts, model,
                )
                time.sleep(backoff)
                continue

            raise

    raise last_error


ALLOWED_RECOMMENDATION_TYPES = ["SELF_CARE", "MEDICAL_CONSULT", "LIFESTYLE"]

# Each condition gets 5-7 recommendations. Per-type caps keep the list
# balanced (and make sure MEDICAL_CONSULT can't crowd out the care advice).
MIN_RECOMMENDATIONS = 5
MAX_RECOMMENDATIONS = 7
MAX_PER_TYPE = {"SELF_CARE": 3, "LIFESTYLE": 3, "MEDICAL_CONSULT": 2}

# A "what to do" shorter than this is just a slogan, not useful advice.
MIN_DESCRIPTION_LENGTH = 40

# Safety net on top of the prompt rule "no medications or doses": drop any
# item that still contains a dose-like quantity (e.g. "500 mg", "2 ml").
_DOSE_PATTERN = re.compile(r"\b\d+(?:[.,]\d+)?\s?(?:mg|mcg|µg|ml|iu)\b", re.IGNORECASE)

# Text fields of a recommendation (English key, Macedonian key).
_TEXT_FIELDS = [
    ("name", "name_mk"),
    ("description", "description_mk"),
    ("what_to_avoid", "what_to_avoid_mk"),
    ("when_to_see_doctor", "when_to_see_doctor_mk"),
]


def build_recommendation_prompt(condition_name: str, severity: str) -> str:
    return f"""
You are a dermatology information assistant. You are NOT a doctor and must
never claim to provide a medical diagnosis or prescribe treatment.

Generate general, educational care information for the following predicted
skin condition:

Condition name: {condition_name}
Severity category: {severity}

Rules:
- Return ONLY valid JSON. No markdown, no text outside the JSON.
- Return between {MIN_RECOMMENDATIONS} and {MAX_RECOMMENDATIONS} recommendations (aim for 6).
- Allowed recommendation types and the maximum number of each:
  - SELF_CARE (max {MAX_PER_TYPE["SELF_CARE"]})
  - LIFESTYLE (max {MAX_PER_TYPE["LIFESTYLE"]})
  - MEDICAL_CONSULT (max {MAX_PER_TYPE["MEDICAL_CONSULT"]})
- You MUST include at least ONE recommendation of type "MEDICAL_CONSULT"
  that clearly advises seeing a dermatologist for a proper diagnosis. If the
  severity is "HIGH", make the urgency explicit.
- NEVER diagnose, never say what the user's lesion definitely is, and never
  name specific medications, active drug ingredients, brands, or dosages.
  Keep advice general (for example sun protection, gentle skin care,
  monitoring changes, not picking or scratching, photographing the area).
- Every recommendation must be specific to this condition, practical and
  written in plain, calm language. Do not repeat the same advice twice.
- The app is bilingual (English/Macedonian), so provide EVERY text field in
  BOTH languages: the English fields, and the "_mk" fields as a natural (not
  word-for-word) Macedonian translation with the same meaning and tone.

Each recommendation must have these fields:
- "type": one of the allowed types
- "name" / "name_mk": a short title (max 8 words)
- "description" / "description_mk": WHAT TO DO - 2 to 3 complete sentences
  with concrete, practical steps
- "what_to_avoid" / "what_to_avoid_mk": WHAT TO AVOID - 1 to 2 sentences
- "when_to_see_doctor" / "when_to_see_doctor_mk": WHEN TO SEE A DOCTOR - 1 to
  2 sentences naming concrete warning signs (for example rapid growth,
  bleeding, pain, color change, a sore that does not heal)

The response must be a JSON array in this format:

[
  {{
    "type": "MEDICAL_CONSULT",
    "name": "See a dermatologist",
    "name_mk": "Посети дерматолог",
    "description": "Book an appointment with a dermatologist for a proper examination. Bring dated photos of the area so changes over time are easy to see.",
    "description_mk": "Закажи преглед кај дерматолог за соодветна проценка. Понеси датирани фотографии од подрачјето за полесно да се видат промените со времето.",
    "what_to_avoid": "Do not wait for the area to go away on its own or try to remove it yourself.",
    "what_to_avoid_mk": "Не чекај подрачјето да исчезне само и не обидувај се сам да го отстраниш.",
    "when_to_see_doctor": "As soon as you can, and sooner if the area bleeds, hurts, grows quickly or changes color.",
    "when_to_see_doctor_mk": "Што е можно побрзо, а уште поскоро ако крвави, боли, расте брзо или менува боја."
  }}
]
"""


def _clean(value) -> str:
    return str(value).strip() if value else ""


def validate_recommendations(recommendations: List[Dict]) -> List[Dict]:
    valid_recommendations = []

    type_counter = {rec_type: 0 for rec_type in ALLOWED_RECOMMENDATION_TYPES}

    for item in recommendations:
        if not isinstance(item, dict):
            continue

        name = _clean(item.get("name"))
        description = _clean(item.get("description"))
        rec_type = _clean(item.get("type")).upper()

        if not name or not description or not rec_type:
            continue

        if rec_type not in ALLOWED_RECOMMENDATION_TYPES:
            continue

        if len(description) < MIN_DESCRIPTION_LENGTH:
            continue

        if type_counter[rec_type] >= MAX_PER_TYPE[rec_type]:
            continue

        cleaned = {"type": rec_type}
        for en_key, mk_key in _TEXT_FIELDS:
            en_value = _clean(item.get(en_key))
            # The _mk text is best-effort - if Gemini omitted it, fall back
            # to the English text rather than dropping the whole item (an
            # English-only card beats no card at all).
            cleaned[en_key] = en_value
            cleaned[mk_key] = _clean(item.get(mk_key)) or en_value

        # Safety net: no dose-like quantities in any text field.
        if any(_DOSE_PATTERN.search(cleaned[key]) for pair in _TEXT_FIELDS for key in pair):
            continue

        valid_recommendations.append(cleaned)
        type_counter[rec_type] += 1

        if len(valid_recommendations) >= MAX_RECOMMENDATIONS:
            break

    # GUARANTEE: there must always be at least one MEDICAL_CONSULT, even if
    # Gemini doesn't return one (or returns invalid JSON).
    if type_counter["MEDICAL_CONSULT"] == 0:
        if len(valid_recommendations) >= MAX_RECOMMENDATIONS:
            valid_recommendations.pop()
        valid_recommendations.append(get_mandatory_medical_consult())

    return valid_recommendations


def get_mandatory_medical_consult() -> Dict:
    return {
        "type": "MEDICAL_CONSULT",
        "name": "Consult a dermatologist",
        "name_mk": "Посети дерматолог",
        "description": (
            "This result is an AI-generated estimate, not a medical diagnosis. "
            "Please consult a licensed dermatologist for accurate evaluation."
        ),
        "description_mk": (
            "Овој резултат е AI-генерирана процена, а не медицинска дијагноза. "
            "Посети лиценциран дерматолог за точна проценка."
        ),
        "what_to_avoid": (
            "Do not rely on this app alone, and do not try to treat or remove "
            "the area yourself."
        ),
        "what_to_avoid_mk": (
            "Не се потпирај само на оваа апликација и не обидувај се сам да го "
            "третираш или отстраниш подрачјето."
        ),
        "when_to_see_doctor": (
            "As soon as you reasonably can, and sooner if the area bleeds, "
            "hurts, grows quickly or changes color or shape."
        ),
        "when_to_see_doctor_mk": (
            "Што е можно побрзо, а уште поскоро ако подрачјето крвави, боли, "
            "расте брзо или менува боја или облик."
        ),
    }


def get_fallback_recommendations(condition_name: str, severity: str) -> List[Dict]:
    fallback = [get_mandatory_medical_consult()]

    fallback.append({
        "type": "SELF_CARE",
        "name": "Monitor for changes",
        "name_mk": "Следи ги промените",
        "description": (
            f"Keep track of any changes in size, shape, or color of the area "
            f"associated with {condition_name}, and take a dated photo for comparison."
        ),
        "description_mk": (
            f"Следи ги промените во големина, облик или боја на подрачјето "
            f"поврзано со {condition_name}, и направи датирана фотографија за споредба."
        ),
        "what_to_avoid": "Do not scratch, pick at or irritate the area.",
        "what_to_avoid_mk": "Не чешај, не чепкај и не го иритирај подрачјето.",
        "when_to_see_doctor": (
            "If you notice any change, bleeding, pain or a sore that does not heal."
        ),
        "when_to_see_doctor_mk": (
            "Ако забележиш каква било промена, крвавење, болка или рана што не заздравува."
        ),
    })

    return fallback


def generate_recommendations_detailed(condition_name: str, severity: str) -> Dict:
    """
    Calls Gemini and returns {"items": [...], "is_fallback": bool}.

    `is_fallback` is True when the items are NOT a complete, successful
    Gemini answer (API error, bad JSON, or fewer than MIN_RECOMMENDATIONS
    valid items). The caller must not treat such a list as the final,
    cached advice for the condition - it is shown, but replaced the next
    time generation succeeds.
    """
    api_key = os.getenv("GEMINI_API_KEY")

    if not api_key:
        raise ValueError("GEMINI_API_KEY is missing. Check your .env file.")

    prompt = build_recommendation_prompt(
        condition_name=condition_name,
        severity=severity,
    )

    def fallback(reason):
        logger.warning(
            "Using fallback recommendations for %r (%s).", condition_name, reason
        )
        return {
            "items": get_fallback_recommendations(condition_name, severity),
            "is_fallback": True,
        }

    try:
        client = _make_client(api_key, long_timeout=True)
        response = _generate_content_with_retry(
            client,
            prompt,
            types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.4,
                max_output_tokens=8192,
            ),
            attempt_timeout_s=_GEMINI_LONG_TIMEOUT_MS / 1000,
            budget_s=_RECOMMENDATION_BUDGET_S,
        )

        if not response.text:
            return fallback("empty response")

        try:
            recommendations = json.loads(response.text)
        except json.JSONDecodeError:
            return fallback("invalid JSON")

        if not isinstance(recommendations, list):
            return fallback("response was not a JSON array")

        valid_recommendations = validate_recommendations(recommendations)

        if not valid_recommendations:
            return fallback("no valid items")

        if len(valid_recommendations) < MIN_RECOMMENDATIONS:
            logger.warning(
                "Gemini returned only %d valid recommendations for %r (need %d); "
                "keeping them but marking as incomplete.",
                len(valid_recommendations), condition_name, MIN_RECOMMENDATIONS,
            )
            return {"items": valid_recommendations, "is_fallback": True}

        return {"items": valid_recommendations, "is_fallback": False}

    except APIError as error:
        # Includes 429 (free-tier quota: 5/min, 20/day).
        logger.error(
            "Gemini API error while generating recommendations (code=%s): %s",
            getattr(error, "code", None), error,
        )
        return fallback("API error")

    except Exception:
        logger.exception("Unexpected Gemini service error")
        return fallback("unexpected error")


def generate_recommendations_with_gemini(
    condition_name: str,
    severity: str,
    use_fallback: bool = True,
) -> List[Dict]:
    """Backwards-compatible wrapper: just the list of recommendation dicts."""
    result = generate_recommendations_detailed(condition_name, severity)

    if result["is_fallback"] and not use_fallback:
        # Keep a partially valid Gemini answer, but drop pure fallback text.
        fallback_names = {
            item["name"]
            for item in get_fallback_recommendations(condition_name, severity)
        }
        return [item for item in result["items"] if item["name"] not in fallback_names]

    return result["items"]


# ---------------------------------------------------------------------------
# CHAT (Q&A for a specific analysis)
#
# Unlike generate_recommendations_with_gemini (called ONCE per condition and
# cached in the database via ConditionRecommendation), the answers here are
# NOT cached - each question is personal and different, so Gemini is called
# on every question. The same safety rules apply: no diagnosis, no specific
# medications/doses, always refer anything personal to a dermatologist.
# ---------------------------------------------------------------------------

CHAT_ANSWER_FALLBACK = (
    "Sorry, I couldn't generate an answer right now. For any questions "
    "about this result, please consult a licensed dermatologist."
)


def build_chat_prompt(
    condition_name: str,
    severity: str,
    description: str,
    history: List[Dict],
    question: str,
) -> str:
    history_lines = []
    for message in history:
        speaker = "User" if message.get("role") == "USER" else "Assistant"
        history_lines.append(f"{speaker}: {message.get('content', '')}")
    history_text = "\n".join(history_lines) if history_lines else "(no previous messages)"

    return f"""
You are a dermatology information assistant answering a user's follow-up
question about an AI-predicted skin condition detected from a photo in the
DermaScanAI app.

Condition: {condition_name}
Severity category: {severity}
General description: {description or "N/A"}

Rules:
- You are NOT a doctor. Never claim to provide a medical diagnosis, never
  state with certainty what the user's lesion is, never recommend specific
  medications, dosages, or personalized treatment plans.
- Only answer questions related to this skin condition, general dermatology,
  or skin health. If the question is unrelated to these topics, politely
  decline and redirect the user back to the topic.
- ALWAYS answer in the same language the user's question below is written
  in (e.g. if it's in Macedonian, answer in Macedonian; if English, answer
  in English), regardless of what language the condition name/description
  above are in.
- Keep answers concise and in plain, accessible language (roughly 2-5
  sentences).
- If the question implies urgency (bleeding, rapid change, pain) or the
  severity category is HIGH, clearly recommend seeing a dermatologist soon.
- Always keep in mind this is general educational information, not
  personalized medical advice, and the AI prediction itself is only an
  estimate, not a confirmed diagnosis.
- Respond with plain text only - no JSON, no markdown formatting.

Conversation so far:
{history_text}

New user question: {question}
"""


def generate_chat_answer(
    condition_name: str,
    severity: str,
    description: str,
    history: List[Dict],
    question: str,
) -> str:
    api_key = os.getenv("GEMINI_API_KEY")

    if not api_key:
        raise ValueError("GEMINI_API_KEY is missing. Check your .env file.")

    prompt = build_chat_prompt(
        condition_name=condition_name,
        severity=severity,
        description=description,
        history=history,
        question=question,
    )

    try:
        client = _make_client(api_key, chat_timeout=True)
        response = _generate_content_with_retry(
            client,
            prompt,
            types.GenerateContentConfig(temperature=0.4),
            max_attempts=_CHAT_MAX_ATTEMPTS,
            retryable_codes=_CHAT_RETRYABLE_STATUS_CODES,
            models=_CHAT_MODELS,
            attempt_timeout_s=_GEMINI_CHAT_TIMEOUT_MS / 1000,
            budget_s=_CHAT_BUDGET_S,
        )

        text = (response.text or "").strip()
        return text if text else CHAT_ANSWER_FALLBACK

    except APIError as error:
        logger.error(
            "Gemini API error (chat) (code=%s): %s", getattr(error, "code", None), error
        )
        return CHAT_ANSWER_FALLBACK

    except Exception:
        logger.exception("Unexpected Gemini chat error")
        return CHAT_ANSWER_FALLBACK
