from __future__ import annotations

import pytest

from interstellar_core.astrology.distributions import (
    CLASSICAL_SEVEN_PROFILE_V1,
    MODERN_TEN_PROFILE_V1,
    DistributionAvailability,
    DistributionPoint,
    calculate_distributions,
)
from interstellar_core.domain import DomainError


MODERN_POINTS = (
    DistributionPoint("sun", 0.0),
    DistributionPoint("moon", 30.0),
    DistributionPoint("mercury", 60.0),
    DistributionPoint("venus", 90.0),
    DistributionPoint("mars", 120.0),
    DistributionPoint("jupiter", 150.0),
    DistributionPoint("saturn", 180.0),
    DistributionPoint("uranus", 210.0),
    DistributionPoint("neptune", 240.0),
    DistributionPoint("pluto", 270.0),
)


def _dimension(result: object, name: str) -> object:
    return next(item for item in result.dimensions if item.dimension == name)


def _category(dimension: object, name: str) -> object:
    return next(item for item in dimension.categories if item.category_id == name)


def test_modern_profile_returns_raw_weighted_and_percentage_statistics() -> None:
    result = calculate_distributions(MODERN_POINTS)
    elements = _dimension(result, "elements")
    modalities = _dimension(result, "modalities")
    polarities = _dimension(result, "polarities")

    assert result.availability is DistributionAvailability.AVAILABLE
    assert elements.denominator == 12.0
    assert (
        _category(elements, "fire").raw_count,
        _category(elements, "fire").weighted_score,
    ) == (
        3,
        4.0,
    )
    assert _category(elements, "fire").percentage == pytest.approx(100 / 3)
    assert _category(elements, "earth").weighted_score == 4.0
    assert _category(elements, "air").weighted_score == 2.0
    assert _category(elements, "water").weighted_score == 2.0
    assert _category(modalities, "cardinal").weighted_score == 5.0
    assert _category(modalities, "fixed").weighted_score == 4.0
    assert _category(modalities, "mutable").weighted_score == 3.0
    assert _category(polarities, "positive").percentage == pytest.approx(50.0)
    assert _category(polarities, "negative").percentage == pytest.approx(50.0)
    assert sum(item.percentage for item in elements.categories) == pytest.approx(100.0)


def test_threshold_flags_are_returned_as_profile_rules_not_personality_scores() -> None:
    points = tuple(
        DistributionPoint(item.point_id, 0.0)
        for item in MODERN_TEN_PROFILE_V1.point_weights
    )
    result = calculate_distributions(points)
    elements = _dimension(result, "elements")
    fire = _category(elements, "fire")
    water = _category(elements, "water")

    assert fire.is_overrepresented is True
    assert fire.is_missing is False
    assert water.is_missing is True
    assert water.is_overrepresented is False
    assert elements.threshold.overrepresented_percentage_min == 40.0
    assert "not a personality" in result.provenance.interpretation_boundary


def test_classical_profile_switches_participants_and_denominator() -> None:
    result = calculate_distributions(
        MODERN_POINTS[:7],
        profile=CLASSICAL_SEVEN_PROFILE_V1,
    )
    assert result.availability is DistributionAvailability.AVAILABLE
    assert result.dimensions[0].denominator == 9.0
    assert result.provenance.profile_id == CLASSICAL_SEVEN_PROFILE_V1.profile_id
    assert (
        result.provenance.profile_content_hash
        == CLASSICAL_SEVEN_PROFILE_V1.content_hash
    )


def test_missing_participant_returns_counts_but_no_percentages_or_flags() -> None:
    result = calculate_distributions(MODERN_POINTS[:-1])
    elements = _dimension(result, "elements")

    assert result.availability is DistributionAvailability.UNAVAILABLE
    assert result.unavailable_reasons == ("MISSING_REQUIRED_PARTICIPANTS",)
    assert result.provenance.missing_participant_ids == ("pluto",)
    assert all(item.percentage is None for item in elements.categories)
    assert all(item.is_missing is None for item in elements.categories)


def test_empty_input_has_explicit_zero_denominator_unavailable_state() -> None:
    result = calculate_distributions(())
    assert result.availability is DistributionAvailability.UNAVAILABLE
    assert result.unavailable_reasons == (
        "MISSING_REQUIRED_PARTICIPANTS",
        "ZERO_WEIGHT_DENOMINATOR",
    )
    assert all(dimension.denominator == 0 for dimension in result.dimensions)
    assert all(
        statistic.percentage is None
        for dimension in result.dimensions
        for statistic in dimension.categories
    )


def test_unknown_or_duplicate_points_are_rejected() -> None:
    with pytest.raises(DomainError) as unknown:
        calculate_distributions((*MODERN_POINTS, DistributionPoint("asc", 10.0)))
    assert unknown.value.code == "DISTRIBUTION_POINT_UNKNOWN"

    with pytest.raises(DomainError) as duplicate:
        calculate_distributions((*MODERN_POINTS, DistributionPoint("sun", 10.0)))
    assert duplicate.value.code == "DISTRIBUTION_POINT_DUPLICATE"


def test_output_explicitly_excludes_m3_deferred_patterns() -> None:
    result = calculate_distributions(MODERN_POINTS)
    assert not hasattr(result, "patterns")
    assert result.provenance.excluded_capabilities == (
        "distribution.hemisphere.v1",
        "pattern.jones.v1",
        "pattern.geometry.v1",
    )
