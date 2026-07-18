"""Derived astronomical quantities independent of any ephemeris adapter."""

from .angles import (
    FULL_CIRCLE_DEG,
    HALF_CIRCLE_DEG,
    normalize_degrees,
    signed_angular_difference,
    smallest_angular_separation,
)
from .lunar import (
    MEAN_SYNODIC_MONTH,
    LunarPhase,
    LunarPhaseResult,
    SynodicMonthModel,
    classify_lunar_phase,
    derive_lunar_phase,
)
from .motion import (
    MotionClassification,
    MotionState,
    MotionThreshold,
    classify_motion,
)

__all__ = [
    "FULL_CIRCLE_DEG",
    "HALF_CIRCLE_DEG",
    "MEAN_SYNODIC_MONTH",
    "LunarPhase",
    "LunarPhaseResult",
    "MotionClassification",
    "MotionState",
    "MotionThreshold",
    "SynodicMonthModel",
    "classify_lunar_phase",
    "classify_motion",
    "derive_lunar_phase",
    "normalize_degrees",
    "signed_angular_difference",
    "smallest_angular_separation",
]
