"""Allowed values shared by models, serializers and the insights engine."""

AREAS = ["forehead", "nose", "left_cheek", "right_cheek", "chin", "jawline"]
FOOD_TAGS = ["dairy", "sugar", "fried", "alcohol", "caffeine", "water"]

# Custom food / drink tags typed by the user (stored lowercase, trimmed).
MAX_FOOD_TAGS_PER_LOG = 12
MAX_CUSTOM_FOOD_LENGTH = 30
MAX_FOOD_SUGGESTIONS = 20
# Letters and digits (any language) joined by single spaces, hyphens or
# apostrophes. No HTML, quotes, brackets or other symbols can match.
CUSTOM_FOOD_PATTERN = r"[^\W_]+(?:[ '\-][^\W_]+)*"
CYCLE_PHASES = ["menstrual", "follicular", "ovulation", "luteal"]
SLEEP_QUALITIES = ["poor", "okay", "great"]
STEP_TYPES = ["cleanse", "treat", "hydrate", "protect"]
TIME_OF_DAY = ["AM", "PM", "BOTH"]

# Body areas a saved scan can be attached to (face areas + a few others).
SCAN_AREAS = AREAS + ["neck", "chest", "back", "arms", "other"]

# acne_severity is stored as 0-3.
SEVERITY_LEVELS = ["clear", "mild", "moderate", "severe"]

ALLOWED_PHOTO_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
MAX_PHOTO_BYTES = 8 * 1024 * 1024
