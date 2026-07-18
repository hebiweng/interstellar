from __future__ import annotations

from importlib.metadata import version

import pytest
import swisseph as swe

from interstellar_core.astrology.houses import (
    HouseCalculationError,
    HouseCalculator,
    HouseInputError,
    HouseSystem,
    whole_sign_cusps,
)

J2000 = 2451545.0
SHANGHAI_LAT = 31.2304
SHANGHAI_LON = 121.4737


class BrokenBackend:
    version = "test"

    def houses_ex2(self, *_args):  # type: ignore[no-untyped-def]
        raise RuntimeError("unrelated engine failure")

    def get_library_path(self) -> str:
        return "/test/swisseph.so"


def test_real_placidus_returns_canonical_house_set_and_angles() -> None:
    result = HouseCalculator().calculate(
        julian_day_ut=J2000,
        latitude_deg=SHANGHAI_LAT,
        longitude_deg=SHANGHAI_LON,
        system=HouseSystem.PLACIDUS,
    )

    assert result.status == "available"
    assert result.requested_system == "placidus"
    assert result.actual_system == "placidus"
    assert result.warnings == ()
    assert result.house_set is not None
    house_set = result.house_set
    assert set(house_set) == {
        "system",
        "houses",
        "angles",
        "sensitive_points",
        "polar_status",
        "warnings",
    }
    assert len(house_set["houses"]) == 12
    assert tuple(house["number"] for house in house_set["houses"]) == tuple(
        range(1, 13)
    )
    assert house_set["houses"][0]["cusp_longitude_deg"] == pytest.approx(
        138.9487029561661,
        abs=1e-10,
    )
    assert house_set["angles"]["asc"] == pytest.approx(138.9487029561661, abs=1e-10)
    assert house_set["angles"]["dsc"] == pytest.approx(318.9487029561661, abs=1e-10)
    assert house_set["angles"]["mc"] == pytest.approx(44.39180048110061, abs=1e-10)
    assert house_set["angles"]["ic"] == pytest.approx(224.39180048110061, abs=1e-10)
    assert house_set["polar_status"] == "normal"
    assert len(result.cusp_speeds_deg_per_day) == 12
    assert len(result.sensitive_point_speeds_deg_per_day) == 8


def test_whole_sign_cusps_are_implemented_from_ascendant_sign() -> None:
    result = HouseCalculator().calculate(
        julian_day_ut=J2000,
        latitude_deg=SHANGHAI_LAT,
        longitude_deg=SHANGHAI_LON,
        system=HouseSystem.WHOLE_SIGN,
    )

    assert result.status == "available"
    assert result.requested_system == result.actual_system == "whole_sign"
    assert result.house_set is not None
    cusps = tuple(house["cusp_longitude_deg"] for house in result.house_set["houses"])
    assert cusps == (
        120.0,
        150.0,
        180.0,
        210.0,
        240.0,
        270.0,
        300.0,
        330.0,
        0.0,
        30.0,
        60.0,
        90.0,
    )
    assert result.house_set["houses"][0]["sign"] == "leo"
    assert result.house_set["angles"]["asc"] == pytest.approx(138.9487029561661)
    assert result.provenance.implementation == "interstellar_whole_sign"
    assert result.provenance.actual_house_code == "self:whole_sign"
    assert result.cusp_speeds_deg_per_day == (0.0,) * 12


@pytest.mark.parametrize(
    ("ascendant", "expected_first"),
    [(0, 0), (29.999999, 0), (30, 30), (359.999999, 330), (-1, 330), (360, 0)],
)
def test_whole_sign_pure_function_handles_zodiac_boundaries(
    ascendant: float,
    expected_first: float,
) -> None:
    cusps = whole_sign_cusps(ascendant)
    assert cusps[0] == expected_first
    assert len(cusps) == len(set(cusps)) == 12


def test_other_registered_swiss_system_uses_houses_ex2() -> None:
    result = HouseCalculator().calculate(
        julian_day_ut=J2000,
        latitude_deg=SHANGHAI_LAT,
        longitude_deg=SHANGHAI_LON,
        system=HouseSystem.KOCH,
    )

    assert result.status == "available"
    assert result.provenance.requested_house_code == "K"
    assert result.provenance.actual_house_code == "K"
    assert result.provenance.implementation == "swiss_houses_ex2"


def test_provenance_preserves_binding_engine_system_and_flags() -> None:
    result = HouseCalculator().calculate(
        julian_day_ut=J2000,
        latitude_deg=SHANGHAI_LAT,
        longitude_deg=SHANGHAI_LON,
        system="placidus",
        flags=swe.FLG_NONUT,
    )

    provenance = result.provenance
    assert provenance.algorithm_card == "ALG-ASTRONOMY-003"
    assert provenance.maturity == "experimental"
    assert provenance.swiss_c_library_version == swe.version
    assert provenance.binding_version == version("pysweph")
    assert provenance.binding_library_path == swe.get_library_path()
    assert provenance.flags == swe.FLG_NONUT


def test_polar_placidus_is_unavailable_without_silent_substitution() -> None:
    result = HouseCalculator().calculate(
        julian_day_ut=J2000,
        latitude_deg=70,
        longitude_deg=0,
        system=HouseSystem.PLACIDUS,
    )

    assert result.status == "unavailable"
    assert result.requested_system == "placidus"
    assert result.actual_system is None
    assert result.house_set is None
    assert result.provenance.implementation == "unavailable"
    assert result.warnings[0].code == "HOUSE_SYSTEM_UNAVAILABLE_AT_LATITUDE"
    assert "no house system was substituted automatically" in result.warnings[0].message


def test_polar_fallback_requires_explicit_opt_in_and_records_degradation() -> None:
    result = HouseCalculator().calculate(
        julian_day_ut=J2000,
        latitude_deg=70,
        longitude_deg=0,
        system=HouseSystem.PLACIDUS,
        allow_fallback_whole_sign=True,
    )

    assert result.status == "degraded"
    assert result.requested_system == "placidus"
    assert result.actual_system == "whole_sign"
    assert result.house_set is not None
    assert result.house_set["system"] == "whole_sign"
    assert result.house_set["polar_status"] == "degraded"
    assert (
        result.house_set["warnings"][0]["code"]
        == "HOUSE_SYSTEM_UNAVAILABLE_AT_LATITUDE"
    )
    assert result.provenance.requested_house_code == "P"
    assert result.provenance.actual_house_code == "self:whole_sign"


def test_nonpolar_engine_errors_are_not_misreported_as_latitude_unavailable() -> None:
    with pytest.raises(HouseCalculationError, match="unrelated engine failure"):
        HouseCalculator(_backend=BrokenBackend()).calculate(  # type: ignore[arg-type]
            julian_day_ut=J2000,
            latitude_deg=0,
            longitude_deg=0,
            system=HouseSystem.PLACIDUS,
        )


@pytest.mark.parametrize(
    "kwargs",
    [
        {"julian_day_ut": float("nan"), "latitude_deg": 0, "longitude_deg": 0},
        {"julian_day_ut": J2000, "latitude_deg": 91, "longitude_deg": 0},
        {"julian_day_ut": J2000, "latitude_deg": 0, "longitude_deg": 180},
        {
            "julian_day_ut": J2000,
            "latitude_deg": 0,
            "longitude_deg": 0,
            "system": "unknown",
        },
        {"julian_day_ut": J2000, "latitude_deg": 0, "longitude_deg": 0, "flags": -1},
    ],
)
def test_invalid_inputs_are_rejected(kwargs: dict[str, object]) -> None:
    with pytest.raises(HouseInputError):
        HouseCalculator().calculate(**kwargs)  # type: ignore[arg-type]
