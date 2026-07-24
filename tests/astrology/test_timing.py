from __future__ import annotations

from datetime import UTC, date, datetime

from interstellar_core.astrology.classical import Sect
from interstellar_core.astrology.timing import (
    calculate_annual_profections,
    calculate_firdaria,
    calculate_zodiacal_releasing,
)


def test_annual_profection_repeats_first_house_at_age_twelve() -> None:
    result = calculate_annual_profections(
        birth_date=date(2000, 3, 1),
        ascendant_sign="leo",
        as_of=date(2012, 3, 2),
        count=13,
    )
    assert result["periods"][0]["activated_house"] == 1
    assert result["periods"][12]["activated_house"] == 1
    assert result["periods"][12]["activated_sign"] == "leo"
    assert result["periods"][12]["current"] is True


def test_firdaria_uses_sect_sequence_and_seven_subperiods() -> None:
    birth = datetime(2000, 1, 1, tzinfo=UTC)
    day = calculate_firdaria(birth_utc=birth, sect=Sect.DAY, as_of=birth)
    night = calculate_firdaria(birth_utc=birth, sect=Sect.NIGHT, as_of=birth)
    assert day["major_periods"][0]["major_lord_id"] == "sun"
    assert night["major_periods"][0]["major_lord_id"] == "moon"
    assert [item["minor_lord_id"] for item in day["sub_periods"][:7]] == [
        "sun", "venus", "mercury", "moon", "saturn", "jupiter", "mars"
    ]


def test_zodiacal_releasing_generates_l1_and_l2_from_lot_sign() -> None:
    birth = datetime(2000, 1, 1, tzinfo=UTC)
    result = calculate_zodiacal_releasing(
        lot_id="fortune",
        lot_sign="aries",
        birth_utc=birth,
        as_of=birth,
        horizon_years=20,
    )
    assert result["levels"]["L1"][0]["sign_id"] == "aries"
    assert result["levels"]["L1"][0]["current"] is True
    assert result["levels"]["L2"][0]["sign_id"] == "aries"
    assert result["levels"]["L2"][1]["sign_id"] == "taurus"
