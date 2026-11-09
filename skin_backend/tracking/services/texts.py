"""
Bilingual wording used by the insights engine, weekly report and Ask AI
fallbacks. Everything describes PATTERNS in the user's own logs - never
causes, diagnoses or treatment advice.
"""

AREA_NAMES = {
    "en": {
        "forehead": "forehead", "nose": "nose", "left_cheek": "left cheek",
        "right_cheek": "right cheek", "chin": "chin", "jawline": "jawline",
    },
    "mk": {
        "forehead": "челото", "nose": "носот", "left_cheek": "левиот образ",
        "right_cheek": "десниот образ", "chin": "брадичката", "jawline": "вилицата",
    },
}

# Factor labels as noun phrases. Product / adherence labels are built in code.
FACTOR_NAMES = {
    "en": {
        "low_sleep": "less than 6 hours of sleep",
        "high_stress": "high stress (7 or more)",
        "dairy": "dairy", "sugar": "sugar", "fried": "fried food", "alcohol": "alcohol",
        "menstrual": "the menstrual phase", "follicular": "the follicular phase",
        "ovulation": "the ovulation phase", "luteal": "the luteal phase",
        "adherence": "a mostly completed skincare routine",
    },
    "mk": {
        "low_sleep": "помалку од 6 часа спиење",
        "high_stress": "висок стрес (7 или повеќе)",
        "dairy": "млечни производи", "sugar": "шеќер", "fried": "пржена храна", "alcohol": "алкохол",
        "menstrual": "менструалната фаза", "follicular": "фоликуларната фаза",
        "ovulation": "фазата на овулација", "luteal": "лутеалната фаза",
        "adherence": "речиси целосно следена рутина за нега",
    },
}

CATEGORY_LABELS = {
    "en": {"sleep": "Sleep", "stress": "Stress", "food": "Food", "cycle": "Cycle", "skincare": "Skincare"},
    "mk": {"sleep": "Спиење", "stress": "Стрес", "food": "Исхрана", "cycle": "Циклус", "skincare": "Нега"},
}

LAG_PREFIX = {
    "en": {0: "On days with {f}", 1: "The day after {f}", 2: "Two days after {f}"},
    "mk": {0: "Во деновите со {f}", 1: "Денот по {f}", 2: "Два дена по {f}"},
}

STRENGTH_LABELS = {
    "en": {"pattern": "Pattern", "early_signal": "Early signal"},
    "mk": {"pattern": "Шема", "early_signal": "Ран сигнал"},
}

TREND_LABELS = {
    "en": {"calmer": "Calmer", "similar": "Similar", "more_active": "More active"},
    "mk": {"calmer": "Помирно", "similar": "Слично", "more_active": "Поактивно"},
}

DISCLAIMER = {
    "en": "These are patterns found in your own check-ins, not causes and not medical advice. "
          "For skin concerns, talk to a dermatologist.",
    "mk": "Ова се шеми пронајдени во вашите дневни записи, а не причини и не медицински совет. "
          "За проблеми со кожата, обратете се кај дерматолог.",
}

ENDING = {
    "en": "This describes a pattern in your logs, not a cause.",
    "mk": "Ова опишува шема во вашите записи, а не причина.",
}


def acne_template(lang, prefix, direction, mean_with, mean_without, n_with, n_without, early):
    if lang == "mk":
        word = "беа посилно изразени" if direction == "higher" else "беа послабо изразени"
        text = (f"{prefix}, акните {word} (просек {mean_with:.1f} наспроти {mean_without:.1f} "
                f"на скала 0-3; {n_with} наспроти {n_without} дена). {ENDING['mk']}")
        return ("Ран сигнал: " if early else "") + text
    word = "tended to be higher" if direction == "higher" else "tended to be lower"
    text = (f"{prefix}, acne {word} (average {mean_with:.1f} vs {mean_without:.1f} "
            f"on the 0-3 scale; {n_with} vs {n_without} days). {ENDING['en']}")
    return ("Early signal: " if early else "") + text


def area_template(lang, prefix, area, direction, share_with, share_without, n_with, n_without, early):
    pct_with, pct_without = round(share_with * 100), round(share_without * 100)
    if lang == "mk":
        word = "почесто" if direction == "higher" else "поретко"
        text = (f"{prefix}, {AREA_NAMES['mk'][area]} беше {word} означено како засегнато "
                f"({pct_with}% наспроти {pct_without}% од деновите; {n_with} наспроти {n_without} дена). {ENDING['mk']}")
        return ("Ран сигнал: " if early else "") + text
    word = "more often" if direction == "higher" else "less often"
    text = (f"{prefix}, your {AREA_NAMES['en'][area]} was marked as affected {word} "
            f"({pct_with}% vs {pct_without}% of days; {n_with} vs {n_without} days). {ENDING['en']}")
    return ("Early signal: " if early else "") + text
