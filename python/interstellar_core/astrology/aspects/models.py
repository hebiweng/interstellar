"""Versioned aspect profiles and canonical Aspect result models."""

from __future__ import annotations

import re
from dataclasses import dataclass
from enum import StrEnum
from math import isfinite
from typing import Any

_IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]*$")


def _is_identifier(value: str) -> bool:
    return len(value) <= 160 and _IDENTIFIER.fullmatch(value) is not None


class AspectContext(StrEnum):
    WITHIN_CHART = "within_chart"
    CROSS_CHART = "cross_chart"
    TRANSIT = "transit"
    PROGRESSION = "progression"
    DIRECTION = "direction"
    DECLINATION = "declination"
    LATITUDE = "latitude"
    MIDPOINT = "midpoint"


class ApplyingState(StrEnum):
    APPLYING = "applying"
    SEPARATING = "separating"
    EXACT = "exact"
    INDETERMINATE = "indeterminate"
    NOT_APPLICABLE = "not_applicable"


class ApplyingReason(StrEnum):
    PROBED_FORWARD = "probed_forward"
    EXACT_WITHIN_TOLERANCE = "exact_within_tolerance"
    RELATIVE_STATIONARY = "relative_stationary"
    SPEED_UNAVAILABLE = "speed_unavailable"
    PROBE_CHANGE_BELOW_TOLERANCE = "probe_change_below_tolerance"


class AspectDirection(StrEnum):
    DEXTER = "dexter"
    SINISTER = "sinister"
    BIDIRECTIONAL = "bidirectional"
    NOT_APPLICABLE = "not_applicable"


@dataclass(frozen=True, slots=True)
class MajorAspectDefinition:
    id: str
    exact_angle_deg: float
    label: str

    def __post_init__(self) -> None:
        if not _is_identifier(self.id):
            raise ValueError(f"invalid aspect definition id: {self.id!r}")
        if not self.label.strip():
            raise ValueError("aspect label is required")
        if not isfinite(self.exact_angle_deg) or not 0 <= self.exact_angle_deg <= 180:
            raise ValueError("exact aspect angle must be finite and within [0, 180]")


@dataclass(frozen=True, slots=True)
class MajorAspectProfile:
    id: str
    version: str
    source: str
    aspects: tuple[MajorAspectDefinition, ...]

    def __post_init__(self) -> None:
        if not _is_identifier(self.id):
            raise ValueError(f"invalid major aspect profile id: {self.id!r}")
        if not self.version.strip() or not self.source.strip():
            raise ValueError("major aspect profile version and source are required")
        if not self.aspects:
            raise ValueError("major aspect profile must define at least one aspect")
        ids = [aspect.id for aspect in self.aspects]
        angles = [aspect.exact_angle_deg for aspect in self.aspects]
        if len(ids) != len(set(ids)):
            raise ValueError("major aspect profile contains duplicate ids")
        if len(angles) != len(set(angles)):
            raise ValueError("major aspect profile contains duplicate exact angles")


@dataclass(frozen=True, slots=True)
class AspectOrbAllowance:
    aspect_id: str
    orb_deg: float

    def __post_init__(self) -> None:
        if not _is_identifier(self.aspect_id):
            raise ValueError(f"invalid aspect id in orb allowance: {self.aspect_id!r}")
        if not isfinite(self.orb_deg) or self.orb_deg < 0:
            raise ValueError("orb allowance must be finite and non-negative")


@dataclass(frozen=True, slots=True)
class OrbProfile:
    id: str
    version: str
    source: str
    allowances: tuple[AspectOrbAllowance, ...]
    probe_step_days: float
    exact_tolerance_deg: float
    relative_stationary_threshold_deg_per_day: float
    probe_change_tolerance_deg: float

    def __post_init__(self) -> None:
        if not _is_identifier(self.id):
            raise ValueError(f"invalid orb profile id: {self.id!r}")
        if not self.version.strip() or not self.source.strip():
            raise ValueError("orb profile version and source are required")
        if not self.allowances:
            raise ValueError("orb profile must define at least one allowance")
        ids = [allowance.aspect_id for allowance in self.allowances]
        if len(ids) != len(set(ids)):
            raise ValueError("orb profile contains duplicate aspect ids")
        for name in (
            "probe_step_days",
            "exact_tolerance_deg",
            "relative_stationary_threshold_deg_per_day",
            "probe_change_tolerance_deg",
        ):
            value = getattr(self, name)
            if not isfinite(value) or value < 0:
                raise ValueError(f"{name} must be finite and non-negative")
        if self.probe_step_days == 0:
            raise ValueError("probe_step_days must be greater than zero")

    def effective_orb(self, aspect_id: str) -> float:
        for allowance in self.allowances:
            if allowance.aspect_id == aspect_id:
                return allowance.orb_deg
        raise KeyError(f"orb profile {self.id}@{self.version} has no allowance for {aspect_id}")


@dataclass(frozen=True, slots=True)
class AspectPoint:
    id: str
    longitude_deg: float
    longitude_speed_deg_per_day: float | None = None

    def __post_init__(self) -> None:
        if not _is_identifier(self.id):
            raise ValueError(f"invalid point id: {self.id!r}")
        if not isfinite(self.longitude_deg):
            raise ValueError("point longitude must be finite")
        if self.longitude_speed_deg_per_day is not None and not isfinite(
            self.longitude_speed_deg_per_day
        ):
            raise ValueError("point longitude speed must be finite when supplied")


@dataclass(frozen=True, slots=True)
class CanonicalAspect:
    aspect_id: str
    point_a: str
    point_b: str
    context: AspectContext
    type: str
    exact_angle_deg: float
    actual_angle_deg: float
    orb_deg: float
    orb_ratio: float
    applying_state: ApplyingState
    direction: AspectDirection
    strength: float
    exact_hits: tuple[str, ...]
    rule_refs: tuple[str, ...]
    applying_reason: ApplyingReason
    entered_at: str | None = None
    left_at: str | None = None

    def to_dict(self) -> dict[str, Any]:
        """Serialize exactly the fields allowed by Canonical Aspect."""
        return {
            "aspect_id": self.aspect_id,
            "point_a": self.point_a,
            "point_b": self.point_b,
            "context": self.context.value,
            "type": self.type,
            "exact_angle_deg": self.exact_angle_deg,
            "actual_angle_deg": self.actual_angle_deg,
            "orb_deg": self.orb_deg,
            "orb_ratio": self.orb_ratio,
            "applying_state": self.applying_state.value,
            "direction": self.direction.value,
            "strength": self.strength,
            "entered_at": self.entered_at,
            "exact_hits": list(self.exact_hits),
            "left_at": self.left_at,
            "rule_refs": list(self.rule_refs),
        }
