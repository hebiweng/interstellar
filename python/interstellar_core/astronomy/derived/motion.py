"""Traceable motion-state classification."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from math import isfinite


class MotionState(StrEnum):
    DIRECT = "direct"
    RETROGRADE = "retrograde"
    STATIONARY = "stationary"


@dataclass(frozen=True, slots=True)
class MotionThreshold:
    id: str
    absolute_speed_deg_per_day: float
    source: str
    version: str
    rationale: str | None = None

    def __post_init__(self) -> None:
        if not self.id.strip() or not self.source.strip() or not self.version.strip():
            raise ValueError("threshold id, source, and version are required")
        if not isfinite(self.absolute_speed_deg_per_day):
            raise ValueError("stationary threshold must be finite")
        if self.absolute_speed_deg_per_day < 0:
            raise ValueError("stationary threshold cannot be negative")


@dataclass(frozen=True, slots=True)
class MotionClassification:
    speed_deg_per_day: float
    state: MotionState
    threshold: MotionThreshold


def classify_motion(
    speed_deg_per_day: float,
    threshold: MotionThreshold,
) -> MotionClassification:
    """Classify speed with an inclusive stationary band around zero."""
    if not isfinite(speed_deg_per_day):
        raise ValueError("speed must be finite")
    limit = threshold.absolute_speed_deg_per_day
    if abs(speed_deg_per_day) <= limit:
        state = MotionState.STATIONARY
    elif speed_deg_per_day > 0:
        state = MotionState.DIRECT
    else:
        state = MotionState.RETROGRADE
    return MotionClassification(
        speed_deg_per_day=speed_deg_per_day,
        state=state,
        threshold=threshold,
    )
