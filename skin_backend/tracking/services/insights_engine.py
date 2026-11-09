"""
Insights engine - plain Python + `statistics`, no black box.

It compares acne severity (0-3) on the days AFTER a factor (lag 0, 1 or 2
days) with days without that factor, and optionally per breakout area.

Guards against false positives (many factors x lags x areas are tested):
  * a fixed, small list of factors and of (factor, area) pairs - nothing
    is tested "just in case";
  * at least MIN_LOGGED_DAYS logged days and MIN_GROUP samples per group;
  * a minimum effect size (0.4 points on the 0-3 scale, 25 percentage
    points for an area);
  * a consistent direction: when the data is split in two chronological
    halves, both halves must point the same way as the overall difference;
  * only the best lag per test is kept, and its p-value is multiplied by
    the number of lags tried; then Benjamini-Hochberg across ALL tests;
  * at most MAX_FINDINGS findings, one per factor;
  * weaker results are labelled "early_signal", not "pattern".

CONFIDENCE (0-100) IS A HEURISTIC, NOT A PROBABILITY. It is
  50 * min(1, smaller_group_size / 10) + 50 * min(1, |effect| / scale)
where scale is 1.0 (acne points) or 0.5 (area share). It only says "more
days and a bigger difference -> more trustworthy". Early signals are capped
at EARLY_SIGNAL_CONFIDENCE_CAP.

Wording always describes a pattern in the user's logs, never a cause.
"""

import hashlib
import math
from collections import Counter
from datetime import timedelta
from statistics import mean, variance

from ..food_tags import is_custom_food_tag
from . import texts

MIN_LOGGED_DAYS = 7
MIN_GROUP = 3
LAGS = (0, 1, 2)
MIN_EFFECT_ACNE = 0.4
MIN_EFFECT_AREA = 0.25
MAX_FINDINGS = 5
KEEP_Q = 0.10          # Benjamini-Hochberg q-value needed to be shown at all
PATTERN_Q = 0.02       # ... and to be called a "pattern"
PATTERN_MIN_GROUP = 5
PATTERN_MIN_LOGGED_DAYS = 14
EARLY_SIGNAL_CONFIDENCE_CAP = 59
ADHERENCE_THRESHOLD = 0.8
_SE_FLOOR = 0.05       # avoids absurd t-values when a group has zero variance

LOW_SLEEP_HOURS = 6
HIGH_STRESS = 7
FOOD_FACTORS = ["dairy", "sugar", "fried", "alcohol"]
# User-typed food tags are tested like the fixed ones, but only the most
# frequent ones (each extra test raises the false-positive risk, and a tag
# needs at least MIN_GROUP days to be testable at all).
MAX_CUSTOM_FACTORS = 10
CUSTOM_PLACEHOLDER = "[FOOD]"
PHASES = ["menstrual", "follicular", "ovulation", "luteal"]

# The only (factor, area) combinations that are tested.
AREA_PAIRS = [
    ("dairy", "chin"), ("dairy", "jawline"),
    ("sugar", "chin"),
    ("high_stress", "forehead"), ("high_stress", "jawline"),
    ("luteal", "chin"), ("luteal", "jawline"),
]


# ---------------------------------------------------------------------------
# Statistics helpers
# ---------------------------------------------------------------------------

def welch_p_value(a, b):
    """Two-sided t-test with a conservative standard error; the t-distribution
    is approximated by a normal one with Wallace's correction (no scipy)."""
    na, nb = len(a), len(b)
    va, vb = variance(a), variance(b)
    se2 = va / na + vb / nb
    # Welch alone is over-confident when one group has (almost) no variance,
    # which happens a lot with rare 0/1 outcomes. Use whichever standard
    # error is larger: Welch or the pooled-variance one.
    pooled_var = ((na - 1) * va + (nb - 1) * vb) / (na + nb - 2)
    se = max(math.sqrt(se2), math.sqrt(pooled_var * (1 / na + 1 / nb)), _SE_FLOOR)
    t = (mean(a) - mean(b)) / se
    den = (va / na) ** 2 / (na - 1) + (vb / nb) ** 2 / (nb - 1)
    df = se2 ** 2 / den if den > 0 else na + nb - 2
    z = t * (1 - 1 / (4 * df)) / math.sqrt(1 + t * t / (2 * df))
    return math.erfc(abs(z) / math.sqrt(2))


def benjamini_hochberg(p_values):
    """Returns q-values in the same order as the input."""
    m = len(p_values)
    order = sorted(range(m), key=lambda i: p_values[i])
    q = [1.0] * m
    running_min = 1.0
    for rank in range(m, 0, -1):
        i = order[rank - 1]
        running_min = min(running_min, p_values[i] * m / rank)
        q[i] = running_min
    return q


def pearson(xs, ys):
    """Pearson r, or None when it can't be computed."""
    n = len(xs)
    if n < 5:
        return None
    mx, my = mean(xs), mean(ys)
    sx = math.sqrt(sum((x - mx) ** 2 for x in xs))
    sy = math.sqrt(sum((y - my) ** 2 for y in ys))
    if sx == 0 or sy == 0:
        return None
    return sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / (sx * sy)


# ---------------------------------------------------------------------------
# Factor series
# ---------------------------------------------------------------------------

def _active_products(products, day):
    return [
        p for p in products
        if (p.started_on is None or p.started_on <= day)
        and (p.stopped_on is None or day <= p.stopped_on)
    ]


def custom_food_tags(logs):
    """Valid custom tags that appear on enough days, most frequent first."""
    counts = Counter(
        tag for log in logs for tag in set(log.food_tags or []) if is_custom_food_tag(tag)
    )
    usable = [(tag, n) for tag, n in counts.items() if n >= MIN_GROUP]
    usable.sort(key=lambda item: (-item[1], item[0]))
    return [tag for tag, _ in usable[:MAX_CUSTOM_FACTORS]]


def custom_factor_id(tag):
    return "food_custom_" + hashlib.sha1(tag.encode("utf-8")).hexdigest()[:8]


def build_factors(logs, products):
    """
    Returns {factor_id: {"category", "name_en", "name_mk", "values": {date: bool}}}.
    A date is only present when the factor could be determined that day.
    """
    factors = {}

    def add(factor_id, category, name_en, name_mk, custom_label=None):
        factors[factor_id] = {
            "category": category, "name_en": name_en, "name_mk": name_mk,
            "custom_label": custom_label, "values": {},
        }
        return factors[factor_id]["values"]

    names_en, names_mk = texts.FACTOR_NAMES["en"], texts.FACTOR_NAMES["mk"]

    low_sleep = add("low_sleep", "sleep", names_en["low_sleep"], names_mk["low_sleep"])
    high_stress = add("high_stress", "stress", names_en["high_stress"], names_mk["high_stress"])
    foods = {f: add(f, "food", names_en[f], names_mk[f]) for f in FOOD_FACTORS}
    custom_foods = {
        tag: add(custom_factor_id(tag), "food", tag, tag, custom_label=tag)
        for tag in custom_food_tags(logs)
    }
    phases = {p: add(p, "cycle", names_en[p], names_mk[p]) for p in PHASES}
    adherence = add("adherence", "skincare", names_en["adherence"], names_mk["adherence"])
    product_values = {
        p.id: add(f"product_{p.id}", "skincare", f"{p.name} in your routine", f"{p.name} во рутината")
        for p in products
    }

    for log in logs:
        day = log.date
        if log.sleep_hours is not None:
            low_sleep[day] = log.sleep_hours < LOW_SLEEP_HOURS
        if log.stress is not None:
            high_stress[day] = log.stress >= HIGH_STRESS
        for food, values in foods.items():
            values[day] = food in (log.food_tags or [])
        for tag, values in custom_foods.items():
            values[day] = tag in (log.food_tags or [])
        if log.cycle_phase:
            for phase, values in phases.items():
                values[day] = log.cycle_phase == phase

        used = set(log.routine_am or []) | set(log.routine_pm or [])
        active = _active_products(products, day)
        for product in active:
            product_values[product.id][day] = product.id in used
        if active:
            adherence[day] = sum(1 for p in active if p.id in used) / len(active) >= ADHERENCE_THRESHOLD

    return factors


# ---------------------------------------------------------------------------
# One comparison (factor -> outcome, at the best lag)
# ---------------------------------------------------------------------------

def _pairs(values, outcome, lag):
    """(factor_date, factor_value, outcome_value) for every usable day."""
    result = []
    for day, flag in values.items():
        y = outcome.get(day + timedelta(days=lag))
        if y is not None:
            result.append((day, flag, y))
    result.sort(key=lambda item: item[0])
    return result


def _split(pairs):
    with_f = [y for _, flag, y in pairs if flag]
    without_f = [y for _, flag, y in pairs if not flag]
    return with_f, without_f


def _diff(pairs):
    with_f, without_f = _split(pairs)
    if not with_f or not without_f:
        return None
    return mean(with_f) - mean(without_f)


def _consistent(pairs, overall_diff):
    """Both chronological halves must have both groups and agree in sign."""
    mid = len(pairs) // 2
    for half in (pairs[:mid], pairs[mid:]):
        d = _diff(half)
        if d is None or d == 0 or (d > 0) != (overall_diff > 0):
            return False
    return True


def _best_lag_test(values, outcome):
    """Best lag for one factor/outcome, or None if no lag has enough samples."""
    best = None
    for lag in LAGS:
        pairs = _pairs(values, outcome, lag)
        with_f, without_f = _split(pairs)
        if len(with_f) < MIN_GROUP or len(without_f) < MIN_GROUP:
            continue
        p = welch_p_value(with_f, without_f)
        if best is None or p < best["p"]:
            best = {"lag": lag, "p": p, "pairs": pairs, "with": with_f, "without": without_f}
    if best is not None:
        # We tried len(LAGS) lags, so the raw p-value is inflated by that much.
        best["p_adj"] = min(1.0, best["p"] * len(LAGS))
    return best


def _confidence(min_n, effect, scale, early):
    score = 50 * min(1.0, min_n / 10) + 50 * min(1.0, abs(effect) / scale)
    value = round(score)
    return min(value, EARLY_SIGNAL_CONFIDENCE_CAP) if early else value


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

def compute_insights(logs, products=()):
    """
    `logs`: objects with date, acne_severity, affected_areas, sleep_hours,
    stress, food_tags, cycle_phase, routine_am, routine_pm.
    `products`: objects with id, name, started_on, stopped_on.
    """
    logs = list(logs)
    products = list(products)
    base = {"logged_days": len(logs), "min_days": MIN_LOGGED_DAYS}

    if len(logs) < MIN_LOGGED_DAYS:
        return {**base, "enough_data": False, "findings": []}

    factors = build_factors(logs, products)
    acne = {log.date: log.acne_severity for log in logs}
    area_outcomes = {
        area: {log.date: 1 if area in (log.affected_areas or []) else 0 for log in logs}
        for area in {a for _, a in AREA_PAIRS}
    }

    # Every test that was actually run (needed for the BH correction).
    tests = []
    for factor_id, meta in factors.items():
        result = _best_lag_test(meta["values"], acne)
        if result:
            tests.append({"factor": factor_id, "area": None, "scale": 1.0, "min_effect": MIN_EFFECT_ACNE, **result})
    for factor_id, area in AREA_PAIRS:
        if factor_id not in factors:
            continue
        result = _best_lag_test(factors[factor_id]["values"], area_outcomes[area])
        if result:
            tests.append({"factor": factor_id, "area": area, "scale": 0.5, "min_effect": MIN_EFFECT_AREA, **result})

    q_values = benjamini_hochberg([t["p_adj"] for t in tests])

    candidates = []
    for test, q in zip(tests, q_values):
        effect = mean(test["with"]) - mean(test["without"])
        if abs(effect) < test["min_effect"] or q > KEEP_Q:
            continue
        if not _consistent(test["pairs"], effect):
            continue

        n_with, n_without = len(test["with"]), len(test["without"])
        min_n = min(n_with, n_without)
        early = not (q <= PATTERN_Q and min_n >= PATTERN_MIN_GROUP and len(logs) >= PATTERN_MIN_LOGGED_DAYS)
        meta = factors[test["factor"]]
        direction = "higher" if effect > 0 else "lower"
        mean_with, mean_without = mean(test["with"]), mean(test["without"])

        finding = {
            "id": f"{test['factor']}:{test['area'] + ':' if test['area'] else ''}{test['lag']}",
            "factor": test["factor"],
            "category": meta["category"],
            "area": test["area"],
            "lag": test["lag"],
            "direction": direction,
            "effect": round(effect, 2),
            "mean_with": round(mean_with, 2),
            "mean_without": round(mean_without, 2),
            "n_with": n_with,
            "n_without": n_without,
            "strength": "early_signal" if early else "pattern",
            "confidence": _confidence(min_n, effect, test["scale"], early),
        }
        custom_label = meta.get("custom_label")
        if custom_label:
            finding["custom_food"] = custom_label
        for lang in ("en", "mk"):
            prefix = texts.LAG_PREFIX[lang][test["lag"]].format(f=meta[f"name_{lang}"])
            if test["area"]:
                finding[f"template_{lang}"] = texts.area_template(
                    lang, prefix, test["area"], direction, mean_with, mean_without, n_with, n_without, early)
            else:
                finding[f"template_{lang}"] = texts.acne_template(
                    lang, prefix, direction, mean_with, mean_without, n_with, n_without, early)
            if custom_label:
                # Same sentence with the user's text replaced by a placeholder:
                # this is the only version that is ever sent to Gemini.
                masked_prefix = texts.LAG_PREFIX[lang][test["lag"]].format(f=CUSTOM_PLACEHOLDER)
                finding[f"template_masked_{lang}"] = texts.acne_template(
                    lang, masked_prefix, direction, mean_with, mean_without, n_with, n_without, early)
        candidates.append(finding)

    # One finding per factor (the most confident), best first, capped.
    candidates.sort(key=lambda f: (f["confidence"], abs(f["effect"])), reverse=True)
    findings, seen = [], set()
    for finding in candidates:
        if finding["factor"] in seen:
            continue
        seen.add(finding["factor"])
        findings.append(finding)
        if len(findings) == MAX_FINDINGS:
            break

    return {**base, "enough_data": True, "findings": findings}
