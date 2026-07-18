"""Immutable contracts for element, modality, and polarity distributions."""

from __future__ import annotations

import hashlib
import json
import math
from dataclasses import asdict, dataclass
from enum import StrEnum


class DistributionAvailability(StrEnum):
    AVAILABLE = "available"
    UNAVAILABLE = "unavailable"


@dataclass(frozen=True, slots=True)
class DistributionPoint:
    point_id: str
    longitude_deg: float


@dataclass(frozen=True, slots=True)
class PointWeight:
    point_id: str
    weight: float

    def __post_init__(self) -> None:
        if not self.point_id:
            raise ValueError("point_id cannot be empty")
        if not math.isfinite(self.weight) or self.weight <= 0:
            raise ValueError("distribution weights must be finite and greater than zero")


@dataclass(frozen=True, slots=True)
class DimensionThreshold:
    dimension: str
    missing_weight_max: float
    overrepresented_percentage_min: float

    def __post_init__(self) -> None:
        if self.missing_weight_max < 0:
            raise ValueError("missing threshold cannot be negative")
        if not 0 < self.overrepresented_percentage_min <= 100:
            raise ValueError("overrepresented threshold must be in (0, 100]")


@dataclass(frozen=True, slots=True)
class DistributionProfile:
    profile_id: str
    version: str
    tradition: str
    point_weights: tuple[PointWeight, ...]
    thresholds: tuple[DimensionThreshold, ...]
    description: str

    def __post_init__(self) -> None:
        point_ids = [item.point_id for item in self.point_weights]
        if not self.profile_id or not self.version or not self.tradition:
            raise ValueError("profile id, version, and tradition are required")
        if not point_ids or len(set(point_ids)) != len(point_ids):
            raise ValueError("profile point ids must be non-empty and unique")
        threshold_dimensions = [item.dimension for item in self.thresholds]
        if set(threshold_dimensions) != {"elements", "modalities", "polarities"}:
            raise ValueError("profile must define element, modality, and polarity thresholds")
        if len(set(threshold_dimensions)) != len(threshold_dimensions):
            raise ValueError("profile threshold dimensions must be unique")

    @property
    def content_hash(self) -> str:
        payload = json.dumps(asdict(self), sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(payload.encode()).hexdigest()


@dataclass(frozen=True, slots=True)
class DistributionParticipant:
    point_id: str
    longitude_deg: float
    sign_id: str
    element: str
    modality: str
    polarity: str
    weight: float


@dataclass(frozen=True, slots=True)
class CategoryStatistic:
    category_id: str
    raw_count: int
    weighted_score: float
    percentage: float | None
    is_missing: bool | None
    is_overrepresented: bool | None


@dataclass(frozen=True, slots=True)
class DimensionResult:
    dimension: str
    availability: DistributionAvailability
    denominator: float
    threshold: DimensionThreshold
    categories: tuple[CategoryStatistic, ...]


@dataclass(frozen=True, slots=True)
class DistributionProvenance:
    algorithm_card_id: str
    capability_id: str
    calculation_ids: tuple[str, ...]
    implementation_version: str
    zodiac_mapping: str
    profile_id: str
    profile_version: str
    profile_content_hash: str
    expected_participant_ids: tuple[str, ...]
    supplied_participant_ids: tuple[str, ...]
    missing_participant_ids: tuple[str, ...]
    excluded_capabilities: tuple[str, ...]
    interpretation_boundary: str


@dataclass(frozen=True, slots=True)
class DistributionResult:
    availability: DistributionAvailability
    unavailable_reasons: tuple[str, ...]
    participants: tuple[DistributionParticipant, ...]
    dimensions: tuple[DimensionResult, ...]
    provenance: DistributionProvenance
