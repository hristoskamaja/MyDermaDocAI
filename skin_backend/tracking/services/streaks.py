"""Streaks and the 'This week' strip."""

from datetime import timedelta

from tracking.constants import SEVERITY_LEVELS


def compute_streaks(logged_dates, today):
    """
    Returns (current, best). The current streak is the run of consecutive
    logged days ending today, or ending yesterday if today isn't logged yet
    (so the streak doesn't show 0 before the user has had a chance to check in).
    """
    days = set(logged_dates)
    if not days:
        return 0, 0

    cursor = today if today in days else today - timedelta(days=1)
    current = 0
    while cursor in days:
        current += 1
        cursor -= timedelta(days=1)

    best = 0
    for day in days:
        if day - timedelta(days=1) in days:
            continue  # not the start of a run
        length = 1
        while day + timedelta(days=length) in days:
            length += 1
        best = max(best, length)

    return current, best


def severity_level(acne_severity):
    if acne_severity is None:
        return "none"
    return SEVERITY_LEVELS[max(0, min(3, acne_severity))]


def week_strip(logs_by_date, today):
    """Monday..Sunday of the current week; `level` drives the per-day colour."""
    monday = today - timedelta(days=today.weekday())
    strip = []
    for offset in range(7):
        day = monday + timedelta(days=offset)
        log = logs_by_date.get(day)
        strip.append({
            "date": day.isoformat(),
            "weekday": offset,  # 0 = Monday
            "is_today": day == today,
            "is_future": day > today,
            "logged": log is not None,
            "acne_severity": log.acne_severity if log else None,
            "level": severity_level(log.acne_severity) if log else "none",
        })
    return strip
