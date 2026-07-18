"""Proleptic Gregorian UTC to Julian Day conversion."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from math import floor


def julian_day_from_utc(value: datetime) -> float:
    """Convert an explicitly UTC datetime to Julian Day.

    UTC and UT1 are not interchangeable. This function returns a UTC-labelled Julian
    date for ingestion and reproducibility; callers must supply DUT1 before treating it
    as UT1. Leap seconds cannot be represented by ``datetime`` and are therefore not
    silently synthesized.
    """
    if value.tzinfo is None or value.utcoffset() is None:
        raise ValueError("UTC datetime must be timezone-aware")
    if value.utcoffset() != timedelta(0):
        raise ValueError("UTC datetime must have a zero UTC offset")

    utc_value = value.astimezone(UTC)
    year = utc_value.year
    month = utc_value.month
    fractional_day = (
        utc_value.day
        + utc_value.hour / 24.0
        + utc_value.minute / 1_440.0
        + utc_value.second / 86_400.0
        + utc_value.microsecond / 86_400_000_000.0
    )
    if month <= 2:
        year -= 1
        month += 12
    century = floor(year / 100)
    gregorian_correction = 2 - century + floor(century / 4)
    return (
        floor(365.25 * (year + 4_716))
        + floor(30.6001 * (month + 1))
        + fractional_day
        + gregorian_correction
        - 1_524.5
    )
