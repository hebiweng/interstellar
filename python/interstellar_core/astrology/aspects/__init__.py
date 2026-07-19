"""Versioned major-aspect engine public API."""

from .engine import find_closest_major_aspect, find_major_aspects
from .models import (
    ApplyingReason,
    ApplyingState,
    AspectContext,
    AspectDirection,
    AspectOrbAllowance,
    AspectPoint,
    CanonicalAspect,
    MajorAspectDefinition,
    MajorAspectProfile,
    OrbProfile,
)
from .profiles import (
    OFFICIAL_MAJOR_ASPECTS_V1,
    OFFICIAL_PROFESSIONAL_NATAL_ASPECTS_V1,
    OFFICIAL_PROFESSIONAL_NATAL_ORBS_V1,
    OFFICIAL_STANDARD_ORBS_V1,
)

__all__ = [
    "OFFICIAL_MAJOR_ASPECTS_V1",
    "OFFICIAL_PROFESSIONAL_NATAL_ASPECTS_V1",
    "OFFICIAL_PROFESSIONAL_NATAL_ORBS_V1",
    "OFFICIAL_STANDARD_ORBS_V1",
    "ApplyingReason",
    "ApplyingState",
    "AspectContext",
    "AspectDirection",
    "AspectOrbAllowance",
    "AspectPoint",
    "CanonicalAspect",
    "MajorAspectDefinition",
    "MajorAspectProfile",
    "OrbProfile",
    "find_closest_major_aspect",
    "find_major_aspects",
]
