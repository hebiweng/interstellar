from __future__ import annotations

import math

import pytest

from interstellar_core.astronomy.derived import (
    LunarPhase,
    MotionState,
    MotionThreshold,
    classify_lunar_phase,
    classify_motion,
    derive_lunar_phase,
    normalize_degrees,
    signed_angular_difference,
    smallest_angular_separation,
)


THRESHOLD = MotionThreshold(
    id="test.stationary.v1",
    absolute_speed_deg_per_day=0.01,
    source="gold-test-policy",
    version="1.0.0",
    rationale="Inclusive stationary band for deterministic boundary tests.",
)


@pytest.mark.parametrize(
    ("angle", "expected"),
    [
        (0.0, 0.0),
        (360.0, 0.0),
        (720.0, 0.0),
        (-360.0, 0.0),
        (-1.0, 359.0),
        (361.0, 1.0),
    ],
)
def test_angle_normalization_gold_boundaries(angle: float, expected: float) -> None:
    assert normalize_degrees(angle) == expected


def test_angle_normalization_property_is_periodic_and_half_open() -> None:
    for angle in range(-10_000, 10_001, 37):
        normalized = normalize_degrees(float(angle))
        assert 0.0 <= normalized < 360.0
        assert normalize_degrees(float(angle) + 360.0 * 19) == normalized


def test_signed_and_smallest_angle_cross_zero_without_360_degree_jump() -> None:
    assert signed_angular_difference(1.0, 359.0) == 2.0
    assert signed_angular_difference(359.0, 1.0) == -2.0
    assert signed_angular_difference(180.0, 0.0) == -180.0
    assert smallest_angular_separation(1.0, 359.0) == 2.0
    assert smallest_angular_separation(180.0, 0.0) == 180.0


@pytest.mark.parametrize(
    ("speed", "expected"),
    [
        (-0.0100001, MotionState.RETROGRADE),
        (-0.01, MotionState.STATIONARY),
        (0.0, MotionState.STATIONARY),
        (0.01, MotionState.STATIONARY),
        (0.0100001, MotionState.DIRECT),
    ],
)
def test_motion_state_uses_inclusive_traceable_threshold(
    speed: float,
    expected: MotionState,
) -> None:
    result = classify_motion(speed, THRESHOLD)
    assert result.state is expected
    assert result.threshold is THRESHOLD
    assert result.threshold.source == "gold-test-policy"


def test_motion_threshold_and_speed_must_be_finite_and_nonnegative() -> None:
    with pytest.raises(ValueError, match="negative"):
        MotionThreshold("bad", -0.1, "fixture", "v1")
    with pytest.raises(ValueError, match="finite"):
        classify_motion(math.nan, THRESHOLD)


@pytest.mark.parametrize(
    ("elongation", "phase"),
    [
        (0.0, LunarPhase.NEW_MOON),
        (22.499999, LunarPhase.NEW_MOON),
        (22.5, LunarPhase.WAXING_CRESCENT),
        (67.5, LunarPhase.FIRST_QUARTER),
        (112.5, LunarPhase.WAXING_GIBBOUS),
        (157.5, LunarPhase.FULL_MOON),
        (202.5, LunarPhase.WANING_GIBBOUS),
        (247.5, LunarPhase.LAST_QUARTER),
        (292.5, LunarPhase.WANING_CRESCENT),
        (337.499999, LunarPhase.WANING_CRESCENT),
        (337.5, LunarPhase.NEW_MOON),
        (360.0, LunarPhase.NEW_MOON),
    ],
)
def test_eight_phase_classification_has_explicit_inclusive_boundaries(
    elongation: float,
    phase: LunarPhase,
) -> None:
    assert classify_lunar_phase(elongation) is phase


@pytest.mark.parametrize(
    ("elongation", "phase", "illumination"),
    [
        (0.0, LunarPhase.NEW_MOON, 0.0),
        (90.0, LunarPhase.FIRST_QUARTER, 0.5),
        (180.0, LunarPhase.FULL_MOON, 1.0),
        (270.0, LunarPhase.LAST_QUARTER, 0.5),
    ],
)
def test_lunar_phase_gold_values(
    elongation: float,
    phase: LunarPhase,
    illumination: float,
) -> None:
    result = derive_lunar_phase(10.0, 10.0 + elongation)
    assert result.elongation_deg == elongation
    assert result.phase is phase
    assert result.illumination_fraction == pytest.approx(illumination, abs=1e-15)
    assert result.lunar_age_days == pytest.approx(
        elongation / 360.0 * result.month_model.days
    )
    assert result.illumination_method == "elongation_cosine_approximation"


def test_sun_moon_elongation_wraps_across_zero() -> None:
    result = derive_lunar_phase(359.0, 1.0)
    assert result.elongation_deg == 2.0
    assert result.phase is LunarPhase.NEW_MOON
    assert 0.0 <= result.illumination_fraction <= 1.0
