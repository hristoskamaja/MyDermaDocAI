"""
translation.py

Auto-translates the Macedonian text an admin types for a SkinCondition
(description/symptoms/treatment_overview) into English via Gemini, so the
web/mobile apps can show either language without the admin ever typing the
same content twice. Called from core/views.py right after a condition is
created or one of those three fields changes.

Deliberately a separate, self-contained call (not shared with
analyses/services/gemini_service.py) - core and analyses are independent
Django apps and this is a much simpler, single-purpose prompt (plain
translation, no JSON schema, no recommendation/chat safety rules).

IMPORTANT (free-tier quota): the Gemini free tier is limited to just 5
requests/minute and 20/day for this model. fill_missing_translations()
therefore batches ALL fields that need translating into ONE Gemini call
(JSON in, JSON out) instead of one call per field - a condition has up to
3 translatable fields, so this is up to 3x fewer requests per admin save.
"""

import json
import logging
import os

from google import genai
from google.genai import types
from google.genai.errors import APIError

logger = logging.getLogger(__name__)

GEMINI_MODEL = "gemini-flash-latest"

# Without this, a slow/unreachable Gemini API call can hang the admin's
# condition save request indefinitely (same issue fixed in
# analyses/services/gemini_service.py - see the comment there).
#
# Built defensively: if the installed google-genai version doesn't
# recognize this field, importing this module must not fail - that would
# break every condition/recommendation/dermatologist admin endpoint, since
# core/views.py imports fill_missing_translations at startup.
try:
    _HTTP_OPTIONS = types.HttpOptions(timeout=20_000)
except Exception:
    _HTTP_OPTIONS = None


def _make_client(api_key: str):
    if _HTTP_OPTIONS is not None:
        return genai.Client(api_key=api_key, http_options=_HTTP_OPTIONS)
    return genai.Client(api_key=api_key)


def translate_fields_to_english(fields: dict) -> dict:
    """
    Translates several Macedonian text fields to English in a SINGLE
    Gemini call (one request instead of one-per-field - see the quota
    note above). `fields` is {field_name: macedonian_text}; only non-empty
    values are sent. Returns {field_name: english_text} - a field is
    simply absent from the result (not "") if translation failed or the
    input was empty, so callers can tell "not translated yet" apart from
    "translated to an empty string".
    """
    items = {k: (v or "").strip() for k, v in fields.items() if (v or "").strip()}
    if not items:
        return {}

    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        logger.warning(
            "GEMINI_API_KEY is not set; skipping translation of: %s",
            ", ".join(items),
        )
        return {}

    payload = json.dumps(items, ensure_ascii=False)

    prompt = f"""
Translate each value in the following JSON object from Macedonian to
clear, natural English. This is patient-facing educational text in a
skin-scanning app (dermatology descriptions/symptoms/treatment overviews),
not a medical prescription - keep the same meaning, tone, and level of
detail for each one.

Rules:
- Return ONLY a JSON object with the exact same keys as the input.
- Each value must be the English translation of the corresponding input
  value.
- If a value is already in English, return it unchanged.
- No markdown, no explanations, no text outside the JSON object.

Input JSON:
{payload}
"""

    try:
        client = _make_client(api_key)
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(response_mime_type="application/json"),
        )

        if not response.text:
            logger.warning("Gemini returned an empty translation response.")
            return {}

        translated = json.loads(response.text)
        if not isinstance(translated, dict):
            logger.warning("Gemini translation response was not a JSON object.")
            return {}

        return {
            key: str(value).strip()
            for key, value in translated.items()
            if key in items and str(value).strip()
        }

    except APIError as error:
        # Includes 429 (free-tier quota: 5/min, 20/day).
        logger.error(
            "Gemini translation API error (code=%s): %s",
            getattr(error, "code", None),
            error,
        )
        return {}
    except Exception:
        logger.exception("Unexpected translation error")
        return {}


def fill_missing_translations(condition, skip_fields=None) -> bool:
    """
    Mutates `condition` in place, filling in description_en/symptoms_en/
    treatment_overview_en for whichever of description/symptoms/
    treatment_overview currently has no (or a stale) English counterpart.
    Returns True if anything changed (caller is responsible for saving).

    "Stale" here just means empty - if the admin edits the Macedonian text
    later, core/views.py clears the matching _en field first so this
    function re-translates it.

    `skip_fields` (a set of target field names, e.g. {"description_en"})
    lets the caller protect fields the admin just typed by hand in this
    same request - those are left alone even if empty, instead of being
    immediately overwritten by a Gemini translation.
    """
    skip_fields = skip_fields or set()

    pairs = [
        ("description", "description_en"),
        ("symptoms", "symptoms_en"),
        ("treatment_overview", "treatment_overview_en"),
    ]

    to_translate = {}
    for source_field, target_field in pairs:
        if target_field in skip_fields:
            continue
        source_value = getattr(condition, source_field, None)
        target_value = getattr(condition, target_field, None)
        if source_value and not target_value:
            to_translate[source_field] = source_value

    if not to_translate:
        return False

    translated = translate_fields_to_english(to_translate)
    if not translated:
        return False

    changed = False
    for source_field, target_field in pairs:
        if source_field in translated:
            setattr(condition, target_field, translated[source_field])
            changed = True

    return changed
