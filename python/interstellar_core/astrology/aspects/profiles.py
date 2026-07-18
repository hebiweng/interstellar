"""Official V1 major-aspect and orb profiles."""

from __future__ import annotations

from .models import (
    AspectOrbAllowance,
    MajorAspectDefinition,
    MajorAspectProfile,
    OrbProfile,
)

OFFICIAL_MAJOR_ASPECTS_V1 = MajorAspectProfile(
    id="official.aspects.major.v1",
    version="1.0.0",
    source="ALG-ASTRONOMY-004 major aspect set",
    aspects=(
        MajorAspectDefinition("conjunction", 0.0, "Conjunction"),
        MajorAspectDefinition("sextile", 60.0, "Sextile"),
        MajorAspectDefinition("square", 90.0, "Square"),
        MajorAspectDefinition("trine", 120.0, "Trine"),
        MajorAspectDefinition("opposition", 180.0, "Opposition"),
    ),
)


OFFICIAL_STANDARD_ORBS_V1 = OrbProfile(
    id="official.orbs.standard.v1",
    version="1.0.0",
    source="Interstellar V1 professional baseline; versioned rule-pack default",
    allowances=(
        AspectOrbAllowance("conjunction", 8.0),
        AspectOrbAllowance("sextile", 4.0),
        AspectOrbAllowance("square", 6.0),
        AspectOrbAllowance("trine", 6.0),
        AspectOrbAllowance("opposition", 8.0),
    ),
    probe_step_days=1.0 / 1_440.0,
    exact_tolerance_deg=1e-9,
    relative_stationary_threshold_deg_per_day=1e-9,
    probe_change_tolerance_deg=1e-12,
)
