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
from .orb_overrides import (
    EffectiveOrb,
    OrbOverrideResolutionError,
    OrbOverrideRule,
    OrbOverrideScope,
    OrbOverrideSet,
    canonical_point_pair,
    parse_orb_overrides,
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
    "EffectiveOrb",
    "OrbOverrideResolutionError",
    "OrbOverrideRule",
    "OrbOverrideScope",
    "OrbOverrideSet",
    "canonical_point_pair",
    "parse_orb_overrides",
    "find_closest_major_aspect",
    "find_major_aspects",
]
