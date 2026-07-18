"""Sun–Moon elongation-derived lunar phase quantities."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from math import cos, isfinite, radians

from .angles import normalize_degrees


class LunarPhase(StrEnum):
    NEW_MOON = "new_moon"
    WAXING_CRESCENT = "waxing_crescent"
    FIRST_QUARTER = "first_quarter"
    WAXING_GIBBOUS = "waxing_gibbous"
    FULL_MOON = "full_moon"
    WANING_GIBBOUS = "waning_gibbous"
    LAST_QUARTER = "last_quarter"
    WANING_CRESCENT = "waning_crescent"


_PHASES = (
    LunarPhase.NEW_MOON,
    LunarPhase.WAXING_CRESCENT,
    LunarPhase.FIRST_QUARTER,
    LunarPhase.WAXING_GIBBOUS,
    LunarPhase.FULL_MOON,
    LunarPhase.WANING_GIBBOUS,
    LunarPhase.LAST_QUARTER,
    LunarPhase.WANING_CRESCENT,
)


@dataclass(frozen=True, slots=True)
class SynodicMonthModel:
    days: float
    source: str
    version: str

    def __post_init__(self) -> None:
        if not isfinite(self.days) or self.days <= 0:
            raise ValueError("synodic month length must be finite and positive")
        if not self.source.strip() or not self.version.strip():
            raise ValueError("synodic month source and version are required")


MEAN_SYNODIC_MONTH = SynodicMonthModel(
    days=29.530588861,
    source="mean_synodic_month_constant",
    version="v1",
)


@dataclass(frozen=True, slots=True)
class LunarPhaseResult:
    elongation_deg: float
    lunar_age_days: float
    illumination_fraction: float
    phase: LunarPhase
    month_model: SynodicMonthModel
    illumination_method: str = "elongation_cosine_approximation"


def classify_lunar_phase(elongation_deg: float) -> LunarPhase:
    """Classify eight 45° sectors; lower boundaries are inclusive."""
    elongation = normalize_degrees(elongation_deg)
    sector = int(((elongation + 22.5) % 360.0) // 45.0)
    return _PHASES[sector]


def derive_lunar_phase(
    sun_longitude_deg: float,
    moon_longitude_deg: float,
    *,
    month_model: SynodicMonthModel = MEAN_SYNODIC_MONTH,
) -> LunarPhaseResult:
    elongation = normalize_degrees(moon_longitude_deg - sun_longitude_deg)
    lunar_age = elongation / 360.0 * month_model.days
    illumination = (1.0 - cos(radians(elongation))) / 2.0
    return LunarPhaseResult(
        elongation_deg=elongation,
        lunar_age_days=lunar_age,
        illumination_fraction=illumination,
        phase=classify_lunar_phase(elongation),
        month_model=month_model,
    )
