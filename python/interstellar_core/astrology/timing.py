"""Versioned natal time-lord tables used by the calculation snapshot."""

from __future__ import annotations

import calendar
from dataclasses import asdict, dataclass
from datetime import UTC, date, datetime, timedelta
from typing import Any

from interstellar_core.astrology.classical import Sect, traditional_rulers
from interstellar_core.astrology.classical.tables import SIGN_IDS

ALGORITHM_ANNUAL_PROFECTIONS = "ALG-TIMING-PROFECTIONS-001"
ALGORITHM_FIRDARIA = "ALG-TIMING-FIRDARIA-001"
ALGORITHM_ZODIACAL_RELEASING = "ALG-TIMING-ZR-001"

RULE_ANNUAL_PROFECTION = "timing.profection.annual.whole_sign.v1"
RULE_FIRDARIA = "timing.firdaria.sect_sequence.v1"
RULE_ZODIACAL_RELEASING = "timing.zodiacal_releasing.minor_years.360_day.v1"

SRC_VALENS_ANTHOLOGY = "source.valens.anthology"
SRC_ABU_MASHAR_SOLAR_REVOLUTIONS = "source.abu_mashar.on_solar_revolutions"


FIRDARIA_DURATIONS = {
    "sun": 10,
    "venus": 8,
    "mercury": 13,
    "moon": 9,
    "saturn": 11,
    "jupiter": 12,
    "mars": 7,
    "true_north_node": 3,
    "true_south_node": 2,
}
FIRDARIA_DAY_SEQUENCE = (
    "sun", "venus", "mercury", "moon", "saturn", "jupiter", "mars",
    "true_north_node", "true_south_node",
)
FIRDARIA_NIGHT_SEQUENCE = (
    "moon", "saturn", "jupiter", "mars", "sun", "venus", "mercury",
    "true_north_node", "true_south_node",
)
FIRDARIA_SUB_SEQUENCE = ("sun", "venus", "mercury", "moon", "saturn", "jupiter", "mars")

ZODIACAL_RELEASING_MINOR_YEARS = {
    "aries": 15,
    "taurus": 8,
    "gemini": 20,
    "cancer": 25,
    "leo": 19,
    "virgo": 20,
    "libra": 8,
    "scorpio": 15,
    "sagittarius": 12,
    "capricorn": 27,
    "aquarius": 30,
    "pisces": 12,
}


def _iso(value: datetime) -> str:
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _add_years(value: date, years: int) -> date:
    target_year = value.year + years
    day = min(value.day, calendar.monthrange(target_year, value.month)[1])
    return value.replace(year=target_year, day=day)


def _age_on(birth_date: date, target_date: date) -> int:
    return target_date.year - birth_date.year - (
        (target_date.month, target_date.day) < (birth_date.month, birth_date.day)
    )


@dataclass(frozen=True, slots=True)
class AnnualProfectionPeriod:
    age: int
    start_date: str
    end_date: str
    activated_house: int
    activated_sign: str
    time_lord_ids: tuple[str, ...]
    current: bool


def calculate_annual_profections(
    *,
    birth_date: date,
    ascendant_sign: str,
    as_of: date,
    count: int = 100,
) -> dict[str, Any]:
    if ascendant_sign not in SIGN_IDS:
        raise ValueError("annual profections require a released ascendant sign")
    if not 1 <= count <= 150:
        raise ValueError("annual profection count must be in [1, 150]")
    asc_index = SIGN_IDS.index(ascendant_sign)
    current_age = max(0, _age_on(birth_date, as_of))
    periods = []
    for age in range(count):
        activated_sign = SIGN_IDS[(asc_index + age) % 12]
        periods.append(
            AnnualProfectionPeriod(
                age=age,
                start_date=_add_years(birth_date, age).isoformat(),
                end_date=_add_years(birth_date, age + 1).isoformat(),
                activated_house=age % 12 + 1,
                activated_sign=activated_sign,
                time_lord_ids=tuple(traditional_rulers(activated_sign)),
                current=age == current_age,
            )
        )
    return {
        "periods": [asdict(item) for item in periods],
        "current_age": current_age,
        "provenance": {
            "algorithm_card_id": ALGORITHM_ANNUAL_PROFECTIONS,
            "capability_id": "timing.annual_profections",
            "rule_ids": [RULE_ANNUAL_PROFECTION],
            "source_ids": [SRC_VALENS_ANTHOLOGY],
            "starting_house": 1,
            "level": "annual",
            "interpretation_boundary": "Time-lord periods only; no event prediction is generated",
        },
    }


def calculate_firdaria(
    *,
    birth_utc: datetime,
    sect: Sect,
    as_of: datetime,
) -> dict[str, Any]:
    sequence = FIRDARIA_DAY_SEQUENCE if sect is Sect.DAY else FIRDARIA_NIGHT_SEQUENCE
    cursor = birth_utc.astimezone(UTC)
    major_periods: list[dict[str, Any]] = []
    sub_periods: list[dict[str, Any]] = []
    for major_index, major_lord in enumerate(sequence):
        duration_years = FIRDARIA_DURATIONS[major_lord]
        end = cursor + timedelta(days=duration_years * 365.2425)
        major_id = f"firdaria:{major_index + 1}:{major_lord}"
        major_periods.append(
            {
                "period_id": major_id,
                "major_lord_id": major_lord,
                "duration_years": duration_years,
                "start_utc": _iso(cursor),
                "end_utc": _iso(end),
                "current": cursor <= as_of.astimezone(UTC) < end,
            }
        )
        if major_lord not in {"true_north_node", "true_south_node"}:
            start_index = FIRDARIA_SUB_SEQUENCE.index(major_lord)
            ordered_sub_lords = (
                FIRDARIA_SUB_SEQUENCE[start_index:] + FIRDARIA_SUB_SEQUENCE[:start_index]
            )
            sub_duration = (end - cursor) / 7
            sub_cursor = cursor
            for sub_index, sub_lord in enumerate(ordered_sub_lords):
                sub_end = end if sub_index == 6 else sub_cursor + sub_duration
                sub_periods.append(
                    {
                        "period_id": f"{major_id}:sub:{sub_index + 1}:{sub_lord}",
                        "major_lord_id": major_lord,
                        "minor_lord_id": sub_lord,
                        "start_utc": _iso(sub_cursor),
                        "end_utc": _iso(sub_end),
                        "current": sub_cursor <= as_of.astimezone(UTC) < sub_end,
                    }
                )
                sub_cursor = sub_end
        cursor = end
    return {
        "sect": sect.value,
        "major_periods": major_periods,
        "sub_periods": sub_periods,
        "provenance": {
            "algorithm_card_id": ALGORITHM_FIRDARIA,
            "capability_id": "timing.firdaria",
            "rule_ids": [RULE_FIRDARIA],
            "source_ids": [SRC_ABU_MASHAR_SOLAR_REVOLUTIONS],
            "year_length_days": 365.2425,
            "node_subperiods": False,
            "interpretation_boundary": (
                "Major and minor lords with dates only; no event claim is generated"
            ),
        },
    }


def calculate_zodiacal_releasing(
    *,
    lot_id: str,
    lot_sign: str,
    birth_utc: datetime,
    as_of: datetime,
    horizon_years: float = 100,
) -> dict[str, Any]:
    if lot_sign not in SIGN_IDS:
        raise ValueError("zodiacal releasing requires a released lot sign")
    if not 1 <= horizon_years <= 150:
        raise ValueError("zodiacal releasing horizon must be in [1, 150]")
    start_index = SIGN_IDS.index(lot_sign)
    horizon = birth_utc.astimezone(UTC) + timedelta(days=horizon_years * 365.2425)
    cursor = birth_utc.astimezone(UTC)
    level_1: list[dict[str, Any]] = []
    level_2: list[dict[str, Any]] = []
    l1_index = 0
    while cursor < horizon:
        sign = SIGN_IDS[(start_index + l1_index) % 12]
        end = min(
            horizon,
            cursor + timedelta(days=ZODIACAL_RELEASING_MINOR_YEARS[sign] * 360),
        )
        period_id = f"zr:{lot_id}:L1:{l1_index + 1}:{sign}"
        level_1.append(
            {
                "period_id": period_id,
                "level": 1,
                "sign_id": sign,
                "time_lord_ids": list(traditional_rulers(sign)),
                "start_utc": _iso(cursor),
                "end_utc": _iso(end),
                "current": cursor <= as_of.astimezone(UTC) < end,
            }
        )
        sub_cursor = cursor
        sub_index = 0
        while sub_cursor < end:
            sub_sign = SIGN_IDS[(SIGN_IDS.index(sign) + sub_index) % 12]
            sub_end = min(
                end,
                sub_cursor
                + timedelta(days=ZODIACAL_RELEASING_MINOR_YEARS[sub_sign] * 30),
            )
            level_2.append(
                {
                    "period_id": f"{period_id}:L2:{sub_index + 1}:{sub_sign}",
                    "parent_period_id": period_id,
                    "level": 2,
                    "sign_id": sub_sign,
                    "time_lord_ids": list(traditional_rulers(sub_sign)),
                    "start_utc": _iso(sub_cursor),
                    "end_utc": _iso(sub_end),
                    "current": sub_cursor <= as_of.astimezone(UTC) < sub_end,
                }
            )
            sub_cursor = sub_end
            sub_index += 1
        cursor = end
        l1_index += 1
    return {
        "lot_id": lot_id,
        "starting_sign": lot_sign,
        "levels": {"L1": level_1, "L2": level_2},
        "provenance": {
            "algorithm_card_id": ALGORITHM_ZODIACAL_RELEASING,
            "capability_id": "timing.zodiacal_releasing",
            "rule_ids": [RULE_ZODIACAL_RELEASING],
            "source_ids": [SRC_VALENS_ANTHOLOGY],
            "year_length_days": 360,
            "level_2_unit_days": 30,
            "implemented_levels": [1, 2],
            "excluded_capabilities": ["loosing_of_bond", "peak_period_scoring", "levels_3_4"],
            "interpretation_boundary": (
                "Period boundaries and lords only; no event claim is generated"
            ),
        },
    }


__all__ = [
    "ALGORITHM_ANNUAL_PROFECTIONS",
    "ALGORITHM_FIRDARIA",
    "ALGORITHM_ZODIACAL_RELEASING",
    "RULE_ANNUAL_PROFECTION",
    "RULE_FIRDARIA",
    "RULE_ZODIACAL_RELEASING",
    "calculate_annual_profections",
    "calculate_firdaria",
    "calculate_zodiacal_releasing",
]
