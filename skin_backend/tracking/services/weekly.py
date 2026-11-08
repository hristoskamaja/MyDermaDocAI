"""Weekly report: the last 7 days (today included) vs the 7 days before."""

from datetime import timedelta
from statistics import mean

from . import texts

TREND_THRESHOLD = 0.25  # change in average severity needed to leave "similar"


def _avg(values):
    values = [v for v in values if v is not None]
    return round(mean(values), 2) if values else None


def compute_weekly_report(logs, today, top_finding=None, lang="en"):
    this_start = today - timedelta(days=6)
    last_start = today - timedelta(days=13)

    this_week = [l for l in logs if this_start <= l.date <= today]
    last_week = [l for l in logs if last_start <= l.date < this_start]

    this_avg = _avg(l.acne_severity for l in this_week)
    last_avg = _avg(l.acne_severity for l in last_week)

    trend = None
    if this_avg is not None and last_avg is not None:
        delta = this_avg - last_avg
        trend = "calmer" if delta <= -TREND_THRESHOLD else "more_active" if delta >= TREND_THRESHOLD else "similar"

    return {
        "period": {"start": this_start.isoformat(), "end": today.isoformat()},
        "avg_severity": this_avg,
        "avg_severity_last_week": last_avg,
        "trend": trend,
        "trend_label": texts.TREND_LABELS[lang][trend] if trend else None,
        "avg_sleep": _avg(l.sleep_hours for l in this_week),
        "avg_stress": _avg(l.stress for l in this_week),
        "check_ins": len(this_week),
        "check_ins_of": 7,
        "top_pattern": top_finding,
    }
