"""Insights engine tests on synthetic data (pure Python, no database, no Gemini)."""

import random
from datetime import date, timedelta
from types import SimpleNamespace

from django.test import SimpleTestCase

from tracking.services import insights_engine as engine
from tracking.services.series import cycle_ranges
from tracking.services.streaks import compute_streaks

START = date(2026, 1, 1)


def make_log(day_index, **overrides):
    fields = dict(
        date=START + timedelta(days=day_index), acne_severity=0, affected_areas=[],
        sleep_hours=7.5, stress=3, food_tags=[], cycle_phase=None, routine_am=[], routine_pm=[],
    )
    fields.update(overrides)
    return SimpleNamespace(**fields)


def noise_dataset(seed, days=60):
    """No real relationship: everything is random."""
    rng = random.Random(seed)
    return [
        make_log(
            i,
            acne_severity=rng.choice([0, 1, 1, 2]),
            sleep_hours=rng.choice([5, 6.5, 7, 8]),
            stress=rng.randint(1, 10),
            food_tags=[t for t in ("dairy", "sugar", "fried", "alcohol") if rng.random() < 0.3],
            affected_areas=[a for a in ("chin", "forehead", "jawline") if rng.random() < 0.3],
        )
        for i in range(days)
    ]


def dairy_dataset(days=42, effect=2, base_noise=True):
    """Dairy every third day; acne is higher the DAY AFTER (lag 1)."""
    rng = random.Random(7)
    dairy_days = {i for i in range(days) if i % 3 == 0}
    logs = []
    for i in range(days):
        after_dairy = (i - 1) in dairy_days
        acne = (effect if after_dairy else 0) + (rng.choice([0, 1]) if base_noise else 0)
        logs.append(make_log(
            i,
            acne_severity=min(3, acne),
            food_tags=["dairy"] if i in dairy_days else [],
            affected_areas=["chin"] if after_dairy else [],
            sleep_hours=rng.choice([5, 7, 8]),
            stress=rng.randint(2, 6),
        ))
    return logs


class EngineTests(SimpleTestCase):
    def test_not_enough_data(self):
        result = engine.compute_insights(noise_dataset(1, days=6))
        self.assertFalse(result["enough_data"])
        self.assertEqual(result["findings"], [])

    def test_finds_planted_dairy_pattern_at_lag_one(self):
        result = engine.compute_insights(dairy_dataset())
        self.assertTrue(result["enough_data"])
        top = result["findings"][0]
        self.assertEqual(top["factor"], "dairy")
        self.assertEqual(top["lag"], 1)
        self.assertEqual(top["direction"], "higher")
        self.assertEqual(top["strength"], "pattern")
        self.assertGreaterEqual(top["effect"], engine.MIN_EFFECT_ACNE)
        self.assertIn("The day after dairy", top["template_en"])
        self.assertIn("Денот по млечни производи", top["template_mk"])

    def test_wording_never_claims_a_cause(self):
        for finding in engine.compute_insights(dairy_dataset())["findings"]:
            for text in (finding["template_en"], finding["template_mk"]):
                self.assertNotRegex(text.lower(), r"\bcauses?d?\b.*\bacne\b|because|diagnos")
            self.assertIn("not a cause", finding["template_en"])

    def test_area_finding_competes_with_overall_one_per_factor(self):
        factors = [f["factor"] for f in engine.compute_insights(dairy_dataset())["findings"]]
        self.assertEqual(len(factors), len(set(factors)))

    def test_pure_noise_produces_no_strong_patterns(self):
        for seed in range(12):
            result = engine.compute_insights(noise_dataset(seed))
            strong = [f for f in result["findings"] if f["strength"] == "pattern"]
            self.assertEqual(strong, [], f"false positive pattern with seed {seed}: {strong}")

    def test_findings_are_capped(self):
        self.assertLessEqual(len(engine.compute_insights(dairy_dataset())["findings"]), engine.MAX_FINDINGS)

    def test_tiny_groups_are_skipped(self):
        logs = [make_log(i, acne_severity=3 if i in (3, 6) else 0, food_tags=["dairy"] if i in (2, 5) else [])
                for i in range(20)]
        factors = {f["factor"] for f in engine.compute_insights(logs)["findings"]}
        self.assertNotIn("dairy", factors)  # only 2 dairy days < MIN_GROUP

    def test_small_effect_is_ignored(self):
        # Dairy-day acne is only ~0.1 higher than normal: below the minimum effect size.
        logs = []
        for i in range(60):
            dairy = i % 2 == 0
            logs.append(make_log(i, acne_severity=1, food_tags=["dairy"] if dairy else []))
        logs[0].acne_severity = 2  # one lone difference
        self.assertEqual([f for f in engine.compute_insights(logs)["findings"] if f["factor"] == "dairy"], [])

    def test_inconsistent_direction_is_rejected(self):
        # Strong effect in the first half, reversed in the second half.
        logs = []
        for i in range(40):
            dairy = i % 2 == 0
            first_half = i < 20
            acne = (3 if dairy else 0) if first_half else (0 if dairy else 1)
            logs.append(make_log(i, acne_severity=acne, food_tags=["dairy"] if dairy else []))
        self.assertEqual([f for f in engine.compute_insights(logs)["findings"] if f["factor"] == "dairy"], [])

    def test_short_history_is_only_an_early_signal(self):
        result = engine.compute_insights(dairy_dataset(days=12))
        dairy = [f for f in result["findings"] if f["factor"] == "dairy"]
        for finding in dairy:
            self.assertEqual(finding["strength"], "early_signal")
            self.assertLessEqual(finding["confidence"], engine.EARLY_SIGNAL_CONFIDENCE_CAP)
            self.assertTrue(finding["template_en"].startswith("Early signal"))

    def test_confidence_is_bounded_heuristic(self):
        for finding in engine.compute_insights(dairy_dataset())["findings"]:
            self.assertTrue(0 <= finding["confidence"] <= 100)

    def test_low_sleep_and_product_factors(self):
        product = SimpleNamespace(id=5, name="Gel", started_on=None, stopped_on=None)
        logs = []
        rng = random.Random(3)
        for i in range(40):
            used = i % 2 == 0
            logs.append(make_log(
                i, acne_severity=0 if used else 2 + rng.choice([0, 1]) - 1,
                routine_pm=[5] if used else [], sleep_hours=7,
            ))
        result = engine.compute_insights(logs, [product])
        factors = {f["factor"]: f for f in result["findings"]}
        self.assertIn("product_5", factors)
        self.assertEqual(factors["product_5"]["direction"], "lower")
        self.assertIn("Gel in your routine", factors["product_5"]["template_en"])

    def test_cycle_phase_needs_logged_phases(self):
        logs = [make_log(i, cycle_phase=None) for i in range(20)]
        factors = engine.build_factors(logs, [])
        self.assertEqual(factors["luteal"]["values"], {})


class HelperTests(SimpleTestCase):
    def test_benjamini_hochberg(self):
        q = engine.benjamini_hochberg([0.01, 0.04, 0.03, 0.5])
        self.assertAlmostEqual(q[0], 0.04)
        self.assertAlmostEqual(q[1], 0.0533, places=3)
        self.assertEqual(len(q), 4)
        self.assertEqual(engine.benjamini_hochberg([]), [])

    def test_pearson(self):
        self.assertAlmostEqual(engine.pearson([1, 2, 3, 4, 5], [2, 4, 6, 8, 10]), 1.0)
        self.assertIsNone(engine.pearson([1, 2, 3], [1, 2, 3]))      # too few points
        self.assertIsNone(engine.pearson([1] * 6, [1, 2, 3, 4, 5, 6]))  # no variance

    def test_streaks(self):
        today = date(2026, 3, 10)
        days = {today - timedelta(days=n) for n in (0, 1, 2, 5, 6, 7, 8)}
        self.assertEqual(compute_streaks(days, today), (3, 4))
        # Not logged yet today: yesterday's run still counts.
        self.assertEqual(compute_streaks({today - timedelta(days=1), today - timedelta(days=2)}, today), (2, 2))
        self.assertEqual(compute_streaks(set(), today), (0, 0))

    def test_cycle_ranges_group_consecutive_days(self):
        logs = [make_log(i, cycle_phase="luteal") for i in range(3)] + [make_log(3, cycle_phase="menstrual")]
        ranges = cycle_ranges(logs)
        self.assertEqual([r["phase"] for r in ranges], ["luteal", "menstrual"])
        self.assertEqual(ranges[0]["start"], "2026-01-01")
        self.assertEqual(ranges[0]["end"], "2026-01-03")
