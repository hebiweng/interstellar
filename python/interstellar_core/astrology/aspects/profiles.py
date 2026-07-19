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


OFFICIAL_PROFESSIONAL_NATAL_ASPECTS_V1 = MajorAspectProfile(
    id="official.aspects.professional_natal.v1",
    version="1.0.0",
    source=(
        "Interstellar professional natal aspect set; named harmonic angles and "
        "default allowances are versioned product rules, not astronomical constants"
    ),
    aspects=(
        MajorAspectDefinition("conjunction", 0.0, "Conjunction"),
        MajorAspectDefinition("semiduodecile", 15.0, "Semiduodecile"),
        MajorAspectDefinition("semioctile", 22.5, "Semioctile"),
        MajorAspectDefinition("semisextile", 30.0, "Semisextile"),
        MajorAspectDefinition("undecile", 360.0 / 11.0, "Undecile"),
        MajorAspectDefinition("decile", 36.0, "Decile"),
        MajorAspectDefinition("novile", 40.0, "Novile"),
        MajorAspectDefinition("semisquare", 45.0, "Semisquare"),
        MajorAspectDefinition("septile", 360.0 / 7.0, "Septile"),
        MajorAspectDefinition("sextile", 60.0, "Sextile"),
        MajorAspectDefinition("quintile", 72.0, "Quintile"),
        MajorAspectDefinition("square", 90.0, "Square"),
        MajorAspectDefinition("biseptile", 720.0 / 7.0, "Biseptile"),
        MajorAspectDefinition("trine", 120.0, "Trine"),
        MajorAspectDefinition("sesquisquare", 135.0, "Sesquisquare"),
        MajorAspectDefinition("biquintile", 144.0, "Biquintile"),
        MajorAspectDefinition("quincunx", 150.0, "Quincunx"),
        MajorAspectDefinition("triseptile", 1080.0 / 7.0, "Triseptile"),
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


OFFICIAL_PROFESSIONAL_NATAL_ORBS_V1 = OrbProfile(
    id="official.orbs.professional_natal.v1",
    version="1.0.0",
    source=(
        "Interstellar professional natal defaults; user-overridable and intentionally "
        "separate from aspect geometry"
    ),
    allowances=(
        AspectOrbAllowance("conjunction", 8.0),
        AspectOrbAllowance("semiduodecile", 1.0),
        AspectOrbAllowance("semioctile", 1.5),
        AspectOrbAllowance("semisextile", 2.0),
        AspectOrbAllowance("undecile", 1.0),
        AspectOrbAllowance("decile", 1.5),
        AspectOrbAllowance("novile", 1.5),
        AspectOrbAllowance("semisquare", 2.0),
        AspectOrbAllowance("septile", 1.5),
        AspectOrbAllowance("sextile", 4.0),
        AspectOrbAllowance("quintile", 2.0),
        AspectOrbAllowance("square", 6.0),
        AspectOrbAllowance("biseptile", 1.5),
        AspectOrbAllowance("trine", 6.0),
        AspectOrbAllowance("sesquisquare", 2.0),
        AspectOrbAllowance("biquintile", 2.0),
        AspectOrbAllowance("quincunx", 3.0),
        AspectOrbAllowance("triseptile", 1.5),
        AspectOrbAllowance("opposition", 8.0),
    ),
    probe_step_days=1.0 / 1_440.0,
    exact_tolerance_deg=1e-9,
    relative_stationary_threshold_deg_per_day=1e-9,
    probe_change_tolerance_deg=1e-12,
)
