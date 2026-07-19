from __future__ import annotations

import pytest

from interstellar_core.astrology.classical import (
    DignityKind,
    LotId,
    Sect,
    calculate_fortune_and_spirit,
    calculate_supported_lots,
    calculate_receptions,
    calculate_traditional_dispositors,
)
from interstellar_core.domain import DomainError


def test_dispositor_graph_reports_final_dispositor_cycle_and_unresolved_ruler() -> None:
    result = calculate_traditional_dispositors(
        {
            "mars": 10.0,
            "venus": 40.0,
            "sun": 350.0,
        }
    )
    assert ("mars",) in result.cycles
    assert ("venus",) in result.cycles
    assert result.final_dispositor_ids == ("mars", "venus")
    assert result.unresolved_ruler_ids == ("jupiter",)


def test_dispositor_graph_canonicalizes_mutual_cycle_once() -> None:
    result = calculate_traditional_dispositors({"mars": 40.0, "venus": 10.0})
    assert result.cycles == (("mars", "venus"),)
    assert result.final_dispositor_ids == ()
    assert result.unresolved_ruler_ids == ()


def test_reception_direction_is_host_receives_guest_and_mutual_is_explicit() -> None:
    result = calculate_receptions(
        {"mars": 40.0, "venus": 10.0},
        sect=Sect.DAY,
    )
    assert any(
        item.host_point_id == "venus"
        and item.guest_point_id == "mars"
        and item.dignity_kind is DignityKind.DOMICILE
        for item in result.receptions
    )
    assert any(
        item.host_point_id == "mars"
        and item.guest_point_id == "venus"
        and item.dignity_kind is DignityKind.DOMICILE
        for item in result.receptions
    )
    assert len(result.mutual_receptions) == 1
    assert result.mutual_receptions[0].point_a == "mars"
    assert result.mutual_receptions[0].point_b == "venus"
    assert result.aspect_required is False
    assert "aspect_perfection" in result.excluded_capabilities


def test_out_of_sect_triplicity_does_not_create_reception() -> None:
    result = calculate_receptions(
        {"sun": 1.0, "jupiter": 31.0},
        sect=Sect.NIGHT,
    )
    assert not any(
        item.host_point_id == "sun"
        and item.guest_point_id == "jupiter"
        and item.dignity_kind is DignityKind.TRIPLICITY
        for item in result.receptions
    )


def test_fortune_and_spirit_use_opposite_day_and_night_formulas_with_wrap() -> None:
    day_fortune, day_spirit = calculate_fortune_and_spirit(
        asc_longitude_deg=350.0,
        sun_longitude_deg=10.0,
        moon_longitude_deg=40.0,
        sect=Sect.DAY,
    )
    night_fortune, night_spirit = calculate_fortune_and_spirit(
        asc_longitude_deg=350.0,
        sun_longitude_deg=10.0,
        moon_longitude_deg=40.0,
        sect=Sect.NIGHT,
    )
    assert day_fortune.lot_id is LotId.FORTUNE
    assert day_fortune.longitude_deg == pytest.approx(20.0)
    assert day_spirit.longitude_deg == pytest.approx(320.0)
    assert night_fortune.longitude_deg == pytest.approx(day_spirit.longitude_deg)
    assert night_spirit.longitude_deg == pytest.approx(day_fortune.longitude_deg)
    assert day_fortune.formula_expression == "ASC + Moon - Sun"
    assert night_fortune.formula_expression == "ASC + Sun - Moon"


def test_lots_publish_operands_sources_and_explicit_exclusions() -> None:
    fortune, spirit = calculate_fortune_and_spirit(
        asc_longitude_deg=0.0,
        sun_longitude_deg=0.0,
        moon_longitude_deg=0.0,
        sect=Sect.DAY,
    )
    payload = fortune.to_dict()
    assert payload["formula_id"] == "lot.fortune.paulus.v1"
    assert payload["operands"] == [
        {"point_id": "asc", "longitude_deg": 0.0, "coefficient": 1},
        {"point_id": "moon", "longitude_deg": 0.0, "coefficient": 1},
        {"point_id": "sun", "longitude_deg": 0.0, "coefficient": -1},
    ]
    assert fortune.source_ids
    assert spirit.source_ids
    assert "additional_lots" in fortune.excluded_capabilities


def test_lots_reject_invalid_longitude_and_non_enum_sect() -> None:
    with pytest.raises(DomainError) as longitude:
        calculate_fortune_and_spirit(
            asc_longitude_deg=-1.0,
            sun_longitude_deg=0.0,
            moon_longitude_deg=0.0,
            sect=Sect.DAY,
        )
    assert longitude.value.code == "CLASSICAL_LONGITUDE_INVALID"

    with pytest.raises(DomainError) as sect:
        calculate_fortune_and_spirit(
            asc_longitude_deg=0.0,
            sun_longitude_deg=0.0,
            moon_longitude_deg=0.0,
            sect="day",  # type: ignore[arg-type]
        )
    assert sect.value.code == "CLASSICAL_SECT_INVALID"


def test_supported_hermetic_lots_match_locked_competitor_reference_case() -> None:
    # 2000-03-01 16:30 Asia/Shanghai, tropical geocentric chart. These
    # longitudes are the independently calculated chart operands used by the
    # competitor reference fixture; assertions are rounded only for display.
    lots = calculate_supported_lots(
        asc_longitude_deg=142.956245,
        sun_longitude_deg=341.073479,
        moon_longitude_deg=285.665275,
        mercury_longitude_deg=341.631438,
        venus_longitude_deg=315.027083,
        mars_longitude_deg=13.862552,
        jupiter_longitude_deg=32.742255,
        saturn_longitude_deg=42.441019,
        sect=Sect.DAY,
    )
    by_id = {lot.lot_id.value: lot for lot in lots}
    assert tuple(by_id) == (
        "fortune",
        "spirit",
        "lot_basis",
        "lot_exaltation",
        "lot_eros",
        "lot_necessity",
        "lot_courage",
        "lot_victory",
        "lot_nemesis",
    )
    expected = {
        "fortune": 87.548041,
        "spirit": 198.364449,
        "lot_basis": 253.772653,
        "lot_eros": 259.618879,
        "lot_necessity": 248.872848,
        "lot_courage": 216.641734,
        "lot_victory": 337.334051,
        "lot_nemesis": 188.063267,
        "lot_exaltation": 180.882766,
    }
    for lot_id, longitude in expected.items():
        assert by_id[lot_id].longitude_deg == pytest.approx(longitude, abs=2e-5)
        assert by_id[lot_id].formula_id
        assert by_id[lot_id].source_ids


def test_supported_planetary_lots_reverse_operands_at_night() -> None:
    day = calculate_supported_lots(
        asc_longitude_deg=100,
        sun_longitude_deg=10,
        moon_longitude_deg=20,
        mercury_longitude_deg=30,
        venus_longitude_deg=40,
        mars_longitude_deg=50,
        jupiter_longitude_deg=60,
        saturn_longitude_deg=70,
        sect=Sect.DAY,
    )
    night = calculate_supported_lots(
        asc_longitude_deg=100,
        sun_longitude_deg=10,
        moon_longitude_deg=20,
        mercury_longitude_deg=30,
        venus_longitude_deg=40,
        mars_longitude_deg=50,
        jupiter_longitude_deg=60,
        saturn_longitude_deg=70,
        sect=Sect.NIGHT,
    )
    day_by_id = {item.lot_id: item for item in day}
    night_by_id = {item.lot_id: item for item in night}
    assert (
        day_by_id[LotId.FORTUNE].longitude_deg
        == night_by_id[LotId.SPIRIT].longitude_deg
    )
    assert (
        day_by_id[LotId.SPIRIT].longitude_deg
        == night_by_id[LotId.FORTUNE].longitude_deg
    )
    assert day_by_id[LotId.EROS].formula_expression == "ASC + Venus - Spirit"
    assert night_by_id[LotId.EROS].formula_expression == "ASC + Spirit - Venus"
    assert day_by_id[LotId.EXALTATION].formula_expression == "ASC + 19 Aries - Sun"
    assert night_by_id[LotId.EXALTATION].formula_expression == "ASC + 3 Taurus - Moon"
    assert day_by_id[LotId.BASIS].formula_expression == (
        "ASC + signed shorter arc Fortune to Spirit"
    )
