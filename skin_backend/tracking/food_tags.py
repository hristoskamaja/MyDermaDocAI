"""Normalization and validation of food tags (fixed + user-typed custom ones).

Custom tags are untrusted user text. They are only ever used as data: stored
as plain strings, compared for equality in the insights engine, and never
placed into a Gemini prompt (see insights_text).
"""

import re
import unicodedata

from . import constants as c

_CUSTOM_RE = re.compile(rf"^{c.CUSTOM_FOOD_PATTERN}$")


def normalize_food_tag(value):
    """Lowercase, trimmed, single-spaced. Returns None for non-strings."""
    if not isinstance(value, str):
        return None
    return " ".join(unicodedata.normalize("NFC", value).split()).lower()


def is_valid_food_tag(tag):
    """True for a fixed tag or an already-normalized, safe custom tag."""
    if not isinstance(tag, str):
        return False
    if tag in c.FOOD_TAGS:
        return True
    return (
        tag == normalize_food_tag(tag)
        and 0 < len(tag) <= c.MAX_CUSTOM_FOOD_LENGTH
        and _CUSTOM_RE.match(tag) is not None
    )


def is_custom_food_tag(tag):
    return tag not in c.FOOD_TAGS and is_valid_food_tag(tag)


def clean_food_tags(value):
    """Normalizes a list of tags and de-duplicates it (order kept).
    Raises ValueError with a readable message when anything is invalid."""
    if not isinstance(value, list):
        raise ValueError("Expected a list of food tags.")
    result = []
    for raw in value:
        tag = normalize_food_tag(raw)
        if tag is None or not is_valid_food_tag(tag):
            raise ValueError(
                f"Invalid food tag. Custom tags may use letters, digits, spaces, '-' and apostrophes "
                f"(max {c.MAX_CUSTOM_FOOD_LENGTH} characters)."
            )
        if tag not in result:
            result.append(tag)
    if len(result) > c.MAX_FOOD_TAGS_PER_LOG:
        raise ValueError(f"At most {c.MAX_FOOD_TAGS_PER_LOG} food tags per check-in.")
    return result
