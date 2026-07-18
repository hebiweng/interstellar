"""Explicit astronomical time-scale inputs; no hidden Delta-T estimates."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from math import isfinite

SECONDS_PER_DAY = 86_400.0


class DeltaTQuality(StrEnum):
    OBSERVED = "observed"
    PREDICTED = "predicted"
    ESTIMATED = "estimated"
    UNKNOWN = "unknown"


class TimeScaleStatus(StrEnum):
    RESOLVED = "resolved"
    UNRESOLVED_DELTA_T = "unresolved_delta_t"


@dataclass(frozen=True, slots=True)
class DeltaTInput:
    """TT−UT1 in seconds with mandatory provenance when a value is supplied."""

    seconds: float | None
    source: str
    quality: DeltaTQuality
    model: str | None = None
    version: str | None = None
    uncertainty_seconds: float | None = None

    def __post_init__(self) -> None:
        if not self.source.strip():
            raise ValueError("Delta-T source must be visible and non-empty")
        if self.seconds is not None and not isfinite(self.seconds):
            raise ValueError("Delta-T must be finite")
        if self.seconds is None and self.quality is not DeltaTQuality.UNKNOWN:
            raise ValueError("missing Delta-T must use quality=unknown")
        if self.seconds is not None and self.quality is DeltaTQuality.UNKNOWN:
            raise ValueError("a numeric Delta-T cannot use quality=unknown")
        if self.uncertainty_seconds is not None:
            if not isfinite(self.uncertainty_seconds):
                raise ValueError("Delta-T uncertainty must be finite")
            if self.uncertainty_seconds < 0:
                raise ValueError("Delta-T uncertainty cannot be negative")


@dataclass(frozen=True, slots=True)
class AstronomicalTimeScales:
    """UT1 and TT Julian Days with the exact Delta-T input retained."""

    jd_ut1: float
    jd_tt: float | None
    delta_t: DeltaTInput
    status: TimeScaleStatus


def derive_time_scales(jd_ut1: float, delta_t: DeltaTInput) -> AstronomicalTimeScales:
    if not isfinite(jd_ut1):
        raise ValueError("UT1 Julian Day must be finite")
    if delta_t.seconds is None:
        return AstronomicalTimeScales(
            jd_ut1=jd_ut1,
            jd_tt=None,
            delta_t=delta_t,
            status=TimeScaleStatus.UNRESOLVED_DELTA_T,
        )
    return AstronomicalTimeScales(
        jd_ut1=jd_ut1,
        jd_tt=jd_ut1 + delta_t.seconds / SECONDS_PER_DAY,
        delta_t=delta_t,
        status=TimeScaleStatus.RESOLVED,
    )
