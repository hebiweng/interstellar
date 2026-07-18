"""Angle normalization primitives with explicit half-open ranges."""

from __future__ import annotations

from math import isfinite

FULL_CIRCLE_DEG = 360.0
HALF_CIRCLE_DEG = 180.0


def normalize_degrees(angle_deg: float) -> float:
    """Normalize an angle into the half-open interval [0, 360)."""
    if not isfinite(angle_deg):
        raise ValueError("angle must be finite")
    normalized = angle_deg % FULL_CIRCLE_DEG
    return 0.0 if normalized == 0.0 else normalized


def signed_angular_difference(target_deg: float, origin_deg: float) -> float:
    """Return target−origin in the half-open interval [-180, 180)."""
    difference = normalize_degrees(target_deg - origin_deg + HALF_CIRCLE_DEG)
    return difference - HALF_CIRCLE_DEG


def smallest_angular_separation(first_deg: float, second_deg: float) -> float:
    """Return the unsigned separation in [0, 180]."""
    return abs(signed_angular_difference(first_deg, second_deg))
