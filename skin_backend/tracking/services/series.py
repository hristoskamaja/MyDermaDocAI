"""Chart data: timeline series, cycle-phase ranges and the correlation explorer."""

from datetime import timedelta

from .insights_engine import pearson

METRICS = {
    "sleep": "sleep_hours",
    "stress": "stress",
    "acne": "acne_severity",
}


def cycle_ranges(logs):
    """Groups consecutive logged days with the same cycle phase (for shading)."""
    ranges = []
    for log in sorted(logs, key=lambda item: item.date):
        if not log.cycle_phase:
            continue
        last = ranges[-1] if ranges else None
        if last and last["phase"] == log.cycle_phase and log.date - last["_end"] <= timedelta(days=1):
            last["_end"] = log.date
        else:
            ranges.append({"phase": log.cycle_phase, "_start": log.date, "_end": log.date})
    return [
        {"phase": r["phase"], "start": r["_start"].isoformat(), "end": r["_end"].isoformat()}
        for r in ranges
    ]


def timeline_points(logs):
    return [
        {
            "date": log.date.isoformat(),
            "acne_severity": log.acne_severity,
            "skin_rating": log.skin_rating,
            "sleep_hours": log.sleep_hours,
            "stress": log.stress,
            "cycle_phase": log.cycle_phase,
            "has_photo": bool(log.photo),
        }
        for log in sorted(logs, key=lambda item: item.date)
    ]


def correlation(logs, x_name, y_name):
    """Paired points (same day) for two metrics, plus Pearson r when computable."""
    x_attr, y_attr = METRICS[x_name], METRICS[y_name]
    points = []
    for log in sorted(logs, key=lambda item: item.date):
        x, y = getattr(log, x_attr), getattr(log, y_attr)
        if x is not None and y is not None:
            points.append({"date": log.date.isoformat(), "x": x, "y": y})

    r = pearson([p["x"] for p in points], [p["y"] for p in points])
    return {
        "x": x_name,
        "y": y_name,
        "points": points,
        "n": len(points),
        "r": round(r, 2) if r is not None else None,
    }
