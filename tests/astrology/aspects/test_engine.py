from __future__ import annotations

import pytest

from interstellar_core.astrology.aspects import (
    OFFICIAL_MAJOR_ASPECTS_V1,
    OFFICIAL_STANDARD_ORBS_V1,
    ApplyingReason,
    ApplyingState,
    AspectContext,
    AspectDirection,
    AspectOrbAllowance,
    AspectPoint,
    MajorAspectDefinition,
    MajorAspectProfile,
    OrbProfile,
    find_closest_major_aspect,
    find_major_aspects,
)


def point(
    point_id: str,
    longitude: float,
    speed: float | None = 1.0,
) -> AspectPoint:
    return AspectPoint(point_id, longitude, speed)


def test_official_profile_contains_only_five_major_aspects_and_explicit_orbs() -> None:
    assert [item.exact_angle_deg for item in OFFICIAL_MAJOR_ASPECTS_V1.aspects] == [
        0.0,
        60.0,
        90.0,
        120.0,
        180.0,
    ]
    assert OFFICIAL_MAJOR_ASPECTS_V1.id == "official.aspects.major.v1"
    assert OFFICIAL_MAJOR_ASPECTS_V1.version == "1.0.0"
    assert OFFICIAL_MAJOR_ASPECTS_V1.source
    assert OFFICIAL_STANDARD_ORBS_V1.id == "official.orbs.standard.v1"
    assert OFFICIAL_STANDARD_ORBS_V1.version == "1.0.0"
    assert OFFICIAL_STANDARD_ORBS_V1.source
    assert {
        item.aspect_id: item.orb_deg for item in OFFICIAL_STANDARD_ORBS_V1.allowances
    } == {
        "conjunction": 8.0,
        "sextile": 4.0,
        "square": 6.0,
        "trine": 6.0,
        "opposition": 8.0,
    }


def test_exact_square_outputs_canonical_aspect_fields() -> None:
    result = find_closest_major_aspect(point("sun", 0.0), point("moon", 90.0))
    assert result is not None
    assert result.type == "square"
    assert result.actual_angle_deg == 90.0
    assert result.exact_angle_deg == 90.0
    assert result.orb_deg == 0.0
    assert result.orb_ratio == 1.0
    assert result.strength == 1.0
    assert result.applying_state is ApplyingState.EXACT
    assert result.applying_reason is ApplyingReason.EXACT_WITHIN_TOLERANCE
    assert result.direction is AspectDirection.NOT_APPLICABLE
    assert result.exact_hits == ()

    payload = result.to_dict()
    assert set(payload) == {
        "aspect_id",
        "point_a",
        "point_b",
        "context",
        "type",
        "exact_angle_deg",
        "actual_angle_deg",
        "orb_deg",
        "orb_ratio",
        "applying_state",
        "direction",
        "strength",
        "entered_at",
        "exact_hits",
        "left_at",
        "rule_refs",
    }
    assert "applying_reason" not in payload
    assert payload["exact_hits"] == []
    assert payload["rule_refs"][0] == "ALG-ASTRONOMY-004"


@pytest.mark.parametrize(
    ("first", "second", "expected_type", "actual"),
    [
        (359.0, 1.0, "conjunction", 2.0),
        (359.0, 59.0, "sextile", 60.0),
        (29.0, 89.0, "sextile", 60.0),
        (1.0, 181.0, "opposition", 180.0),
    ],
)
def test_zero_boundary_and_cross_sign_hits_use_minimum_separation(
    first: float,
    second: float,
    expected_type: str,
    actual: float,
) -> None:
    result = find_closest_major_aspect(point("a", first), point("b", second))
    assert result is not None
    assert result.type == expected_type
    assert result.actual_angle_deg == actual


def test_orb_boundary_is_inclusive_and_just_outside_is_not_a_hit() -> None:
    boundary = find_major_aspects(point("a", 0.0), point("b", 64.0))
    assert len(boundary) == 1
    assert boundary[0].type == "sextile"
    assert boundary[0].orb_deg == 4.0
    assert boundary[0].orb_ratio == 0.0
    assert boundary[0].strength == 0.0

    outside = find_major_aspects(point("a", 0.0), point("b", 64.000001))
    assert outside == ()


def test_forward_probe_classifies_applying_and_separating() -> None:
    applying = find_closest_major_aspect(
        point("a", 0.0, 0.0),
        point("b", 95.0, -1.0),
    )
    separating = find_closest_major_aspect(
        point("a", 0.0, 0.0),
        point("b", 95.0, 1.0),
    )
    assert applying is not None and separating is not None
    assert applying.applying_state is ApplyingState.APPLYING
    assert applying.applying_reason is ApplyingReason.PROBED_FORWARD
    assert separating.applying_state is ApplyingState.SEPARATING
    assert separating.applying_reason is ApplyingReason.PROBED_FORWARD


def test_retrograde_motion_can_apply_across_zero() -> None:
    result = find_closest_major_aspect(
        point("a", 359.0, 1.0),
        point("b", 1.0, -1.0),
    )
    assert result is not None
    assert result.type == "conjunction"
    assert result.applying_state is ApplyingState.APPLYING


def test_missing_speed_and_relative_stationary_are_explicitly_indeterminate() -> None:
    missing = find_closest_major_aspect(
        point("a", 0.0, None),
        point("b", 94.0, 1.0),
    )
    stationary = find_closest_major_aspect(
        point("a", 0.0, -0.2),
        point("b", 94.0, -0.2),
    )
    assert missing is not None and stationary is not None
    assert missing.applying_state is ApplyingState.INDETERMINATE
    assert missing.applying_reason is ApplyingReason.SPEED_UNAVAILABLE
    assert stationary.applying_state is ApplyingState.INDETERMINATE
    assert stationary.applying_reason is ApplyingReason.RELATIVE_STATIONARY


def test_exchange_symmetry_preserves_id_geometry_and_applying_state() -> None:
    samples = (
        (359.0, 1.0, 0.9, -0.2),
        (20.0, 84.0, 1.1, 0.3),
        (150.0, 244.0, -0.5, 0.8),
        (10.0, 190.0, 0.0, -0.1),
    )
    for longitude_a, longitude_b, speed_a, speed_b in samples:
        forward = find_major_aspects(
            point("alpha", longitude_a, speed_a),
            point("beta", longitude_b, speed_b),
            context=AspectContext.CROSS_CHART,
        )
        reverse = find_major_aspects(
            point("beta", longitude_b, speed_b),
            point("alpha", longitude_a, speed_a),
            context=AspectContext.CROSS_CHART,
        )
        assert forward == reverse


def test_custom_zero_orb_profile_only_accepts_exact_hit() -> None:
    profile = MajorAspectProfile(
        id="test.conjunction.only",
        version="1",
        source="test",
        aspects=(MajorAspectDefinition("conjunction", 0.0, "Conjunction"),),
    )
    orbs = OrbProfile(
        id="test.zero.orb",
        version="1",
        source="test",
        allowances=(AspectOrbAllowance("conjunction", 0.0),),
        probe_step_days=1 / 1_440,
        exact_tolerance_deg=1e-9,
        relative_stationary_threshold_deg_per_day=1e-9,
        probe_change_tolerance_deg=1e-12,
    )
    exact = find_major_aspects(
        point("a", 0.0),
        point("b", 360.0),
        major_profile=profile,
        orb_profile=orbs,
    )
    outside = find_major_aspects(
        point("a", 0.0),
        point("b", 0.000001),
        major_profile=profile,
        orb_profile=orbs,
    )
    assert len(exact) == 1
    assert exact[0].orb_ratio == 1.0
    assert outside == ()


def test_no_dynamic_exact_times_are_invented_in_m3() -> None:
    result = find_closest_major_aspect(point("a", 0.0), point("b", 94.0))
    assert result is not None
    assert result.entered_at is None
    assert result.exact_hits == ()
    assert result.left_at is None


def test_aspect_id_remains_canonical_when_point_ids_are_long() -> None:
    result = find_closest_major_aspect(
        point("a" * 150, 0.0),
        point("b" * 150, 60.0),
    )
    assert result is not None
    assert len(result.aspect_id) <= 160
    assert "sha256:" in result.aspect_id
