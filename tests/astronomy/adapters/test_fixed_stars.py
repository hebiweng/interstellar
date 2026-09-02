from __future__ import annotations

from pathlib import Path

import pytest

from interstellar_core.astronomy.fixed_stars import (
    COMMON_FIXED_STAR_IDS,
    SwissFixedStarCalculator,
    calculate_fixed_star_contacts,
)


EPHEMERIS_PATH = Path(__file__).resolve().parents[3] / "vendor" / "swisseph" / "ephe"


def test_common_fixed_star_registry_is_unique_and_calculable() -> None:
    assert len(COMMON_FIXED_STAR_IDS) == 24
    assert len(set(COMMON_FIXED_STAR_IDS)) == 24

    result = SwissFixedStarCalculator(ephemeris_path=EPHEMERIS_PATH).calculate(
        julian_day_ut=2451604.8541666665,
        star_ids=("aldebaran", "spica", "regulus"),
    )

    assert [star["star_id"] for star in result.stars] == [
        "aldebaran",
        "spica",
        "regulus",
    ]
    assert result.stars[0]["position"]["ecliptic"]["longitude_deg"] == pytest.approx(
        69.78759234909427,
        abs=1e-9,
    )
    assert result.stars[0]["magnitude_v"] == pytest.approx(0.86)
    assert result.stars[1]["label_zh"] == "角宿一"
    assert result.provenance["catalog"] == "sefstars.txt"


def test_sidereal_fixed_star_longitude_uses_declared_ayanamsa() -> None:
    calculator = SwissFixedStarCalculator(ephemeris_path=EPHEMERIS_PATH)
    tropical = calculator.calculate(
        julian_day_ut=2451545.0,
        star_ids=("aldebaran",),
    )
    sidereal = calculator.calculate(
        julian_day_ut=2451545.0,
        star_ids=("aldebaran",),
        zodiac="sidereal",
        ayanamsa="lahiri",
    )

    assert sidereal.stars[0]["position"]["ecliptic"]["longitude_deg"] != pytest.approx(
        tropical.stars[0]["position"]["ecliptic"]["longitude_deg"]
    )
    assert sidereal.stars[0]["position"]["equatorial"] == pytest.approx(
        tropical.stars[0]["position"]["equatorial"]
    )


def test_fixed_star_contacts_are_explicit_conjunctions_with_locked_orb() -> None:
    star = {
        "star_id": "spica",
        "position": {"ecliptic": {"longitude_deg": 203.5}},
    }
    points = [
        {"point_id": "moon", "position": {"ecliptic": {"longitude_deg": 204.0}}},
        {"point_id": "sun", "position": {"ecliptic": {"longitude_deg": 210.0}}},
    ]

    contacts = calculate_fixed_star_contacts([star], points, conjunction_orb_deg=1.0)

    assert contacts == [
        {
            "contact_id": "fixed_star_contact:spica:moon:conjunction",
            "star_id": "spica",
            "point_id": "moon",
            "type": "conjunction",
            "exact_angle_deg": 0.0,
            "orb_deg": 0.5,
            "orb_allowance_deg": 1.0,
            "strength": 0.5,
            "applying_state": "not_applicable",
            "formula_ref": "aspect.fixed_star_conjunction.v1",
        }
    ]
