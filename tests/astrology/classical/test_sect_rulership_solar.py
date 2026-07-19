from __future__ import annotations

import pytest

from interstellar_core.astrology.classical import (
    LILLY_SOLAR_THRESHOLDS_V1,
    Sect,
    SolarRelation,
    SolarThresholdProfile,
    assign_house_rulers,
    classify_solar_condition,
    modern_rulers,
    sect_facts,
    traditional_rulers,
)
from interstellar_core.domain import DomainError


def test_sect_uses_explicit_input_and_does_not_claim_hayz_or_mercury_sect() -> None:
    day = sect_facts(Sect.DAY)
    night = sect_facts(Sect.NIGHT)
    assert day.sect_light_id == "sun"
    assert night.sect_light_id == "moon"
    assert day.diurnal_planet_ids == ("sun", "jupiter", "saturn")
    assert night.nocturnal_planet_ids == ("moon", "venus", "mars")
    assert day.conditional_planet_ids == ("mercury",)
    assert "hayz" in day.excluded_capabilities


def test_traditional_and_modern_rulers_are_separate_versioned_profiles() -> None:
    assert traditional_rulers("scorpio") == ("mars",)
    assert modern_rulers("scorpio") == ("mars", "pluto")
    assert traditional_rulers("aquarius") == ("saturn",)
    assert modern_rulers("aquarius") == ("saturn", "uranus")


def test_house_rulers_preserve_house_order_and_both_profiles() -> None:
    result = assign_house_rulers(tuple(float(index * 30) for index in range(12)))
    assert len(result) == 12
    assert result[0].house_number == 1
    assert result[0].sign_id == "aries"
    assert result[0].traditional_ruler_ids == ("mars",)
    assert result[10].sign_id == "aquarius"
    assert result[10].modern_ruler_ids == ("saturn", "uranus")
    assert result[0].traditional_table_ref.content_hash
    assert result[0].modern_table_ref.content_hash


def test_house_rulers_require_exactly_twelve_valid_cusps() -> None:
    with pytest.raises(DomainError) as count:
        assign_house_rulers((0.0, 30.0))
    assert count.value.code == "CLASSICAL_HOUSE_COUNT_INVALID"
    with pytest.raises(DomainError) as longitude:
        assign_house_rulers((*tuple(float(index * 30) for index in range(11)), 360.0))
    assert longitude.value.code == "CLASSICAL_LONGITUDE_INVALID"


@pytest.mark.parametrize(
    ("distance", "relation"),
    [
        (17 / 60, SolarRelation.CAZIMI),
        (17 / 60 + 1e-6, SolarRelation.COMBUST),
        (8.5, SolarRelation.COMBUST),
        (8.5 + 1e-6, SolarRelation.UNDER_BEAMS),
        (17.0, SolarRelation.UNDER_BEAMS),
        (17.0 + 1e-6, SolarRelation.FREE),
    ],
)
def test_solar_relation_thresholds_are_inclusive_and_versioned(
    distance: float,
    relation: SolarRelation,
) -> None:
    result = classify_solar_condition("mercury", distance, sun_longitude_deg=0.0)
    assert result.relation is relation
    assert result.threshold_profile is LILLY_SOLAR_THRESHOLDS_V1
    assert len(result.threshold_profile.content_hash) == 64
    assert "physical_visibility" in result.excluded_capabilities


def test_solar_relation_uses_shortest_circular_separation() -> None:
    result = classify_solar_condition("venus", 359.9, sun_longitude_deg=0.0)
    assert result.separation_deg == pytest.approx(0.1)
    assert result.relation is SolarRelation.CAZIMI


def test_sun_itself_has_not_applicable_solar_relation() -> None:
    result = classify_solar_condition("sun", 10.0, sun_longitude_deg=10.0)
    assert result.relation is SolarRelation.NOT_APPLICABLE


def test_solar_profile_rejects_unordered_thresholds() -> None:
    with pytest.raises(ValueError, match="ordered"):
        SolarThresholdProfile(
            profile_id="invalid",
            version="1",
            cazimi_deg=1.0,
            combust_deg=0.5,
            under_beams_deg=17.0,
            source_ids=("source.test",),
            content_hash="0" * 64,
        )
