"""Typed, interpretation-free contracts for classical natal facts."""

from __future__ import annotations

import math
from dataclasses import asdict, dataclass
from enum import StrEnum
from typing import Any


def _json_value(value: Any) -> Any:
    if isinstance(value, StrEnum):
        return value.value
    if isinstance(value, dict):
        return {key: _json_value(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_value(item) for item in value]
    return value


class SerializableFact:
    """Provide a JSON-compatible representation without changing immutable values."""

    def to_dict(self) -> dict[str, Any]:
        return _json_value(asdict(self))


class Sect(StrEnum):
    DAY = "day"
    NIGHT = "night"


class DignityKind(StrEnum):
    DOMICILE = "domicile"
    EXALTATION = "exaltation"
    TRIPLICITY = "triplicity"
    TERM = "term"
    FACE = "face"
    DETRIMENT = "detriment"
    FALL = "fall"
    PEREGRINE = "peregrine"


class EssentialStatusPolarity(StrEnum):
    DIGNITY = "dignity"
    DEBILITY = "debility"
    NEUTRAL = "neutral"


class EssentialStatusLevel(StrEnum):
    MAJOR = "major"
    MINOR = "minor"
    DERIVED = "derived"


class TriplicityRole(StrEnum):
    DAY = "day_ruler"
    NIGHT = "night_ruler"
    PARTICIPATING = "participating_ruler"


class SolarRelation(StrEnum):
    CAZIMI = "cazimi"
    COMBUST = "combust"
    UNDER_BEAMS = "under_beams"
    FREE = "free"
    NOT_APPLICABLE = "not_applicable"


class LotId(StrEnum):
    FORTUNE = "fortune"
    SPIRIT = "spirit"
    BASIS = "lot_basis"
    EROS = "lot_eros"
    NECESSITY = "lot_necessity"
    COURAGE = "lot_courage"
    VICTORY = "lot_victory"
    NEMESIS = "lot_nemesis"
    EXALTATION = "lot_exaltation"


@dataclass(frozen=True, slots=True)
class TableReference(SerializableFact):
    table_id: str
    version: str
    source_ids: tuple[str, ...]
    content_hash: str

    def __post_init__(self) -> None:
        if not self.table_id or not self.version or not self.source_ids:
            raise ValueError("table id, version, and at least one source id are required")
        if len(set(self.source_ids)) != len(self.source_ids):
            raise ValueError("table source ids must be unique")
        if len(self.content_hash) != 64:
            raise ValueError("table content hash must be a SHA-256 hex digest")


@dataclass(frozen=True, slots=True)
class SectResult(SerializableFact):
    sect: Sect
    sect_light_id: str
    diurnal_planet_ids: tuple[str, ...]
    nocturnal_planet_ids: tuple[str, ...]
    conditional_planet_ids: tuple[str, ...]
    algorithm_card_id: str
    rule_ids: tuple[str, ...]
    source_ids: tuple[str, ...]
    excluded_capabilities: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class DignityCondition(SerializableFact):
    kind: DignityKind
    ruler_id: str
    sign_id: str
    degree_in_sign: float
    role: TriplicityRole | None
    is_active_for_sect: bool | None
    table_ref: TableReference
    rule_id: str


@dataclass(frozen=True, slots=True)
class EssentialStatusFact(SerializableFact):
    """Language-independent projection for compact tables and detail drawers."""

    status_id: DignityKind
    polarity: EssentialStatusPolarity
    level: EssentialStatusLevel
    active: bool
    label_key: str
    role: TriplicityRole | None
    table_ref: TableReference | None
    rule_id: str


@dataclass(frozen=True, slots=True)
class EssentialDignityResult(SerializableFact):
    point_id: str
    longitude_deg: float
    sign_id: str
    degree_in_sign: float
    sect: Sect
    applicable: bool
    unavailable_reason: str | None
    profile_id: str
    dignities: tuple[DignityCondition, ...]
    debilities: tuple[DignityCondition, ...]
    peregrine: bool | None
    status_facts: tuple[EssentialStatusFact, ...]
    algorithm_card_id: str
    rule_ids: tuple[str, ...]
    source_ids: tuple[str, ...]
    excluded_capabilities: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class HouseRulerAssignment(SerializableFact):
    house_number: int
    cusp_longitude_deg: float
    sign_id: str
    traditional_ruler_ids: tuple[str, ...]
    modern_ruler_ids: tuple[str, ...]
    traditional_table_ref: TableReference
    modern_table_ref: TableReference
    rule_ids: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class DispositorEdge(SerializableFact):
    subject_point_id: str
    subject_sign_id: str
    ruler_point_id: str
    table_ref: TableReference
    rule_id: str


@dataclass(frozen=True, slots=True)
class DispositorGraphResult(SerializableFact):
    edges: tuple[DispositorEdge, ...]
    cycles: tuple[tuple[str, ...], ...]
    final_dispositor_ids: tuple[str, ...]
    unresolved_ruler_ids: tuple[str, ...]
    algorithm_card_id: str
    rule_ids: tuple[str, ...]
    source_ids: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class Reception(SerializableFact):
    host_point_id: str
    guest_point_id: str
    dignity_kind: DignityKind
    triplicity_role: TriplicityRole | None
    active_for_sect: bool | None
    table_ref: TableReference
    rule_id: str


@dataclass(frozen=True, slots=True)
class MutualReception(SerializableFact):
    point_a: str
    point_b: str
    a_receives_b_by: tuple[DignityKind, ...]
    b_receives_a_by: tuple[DignityKind, ...]
    rule_id: str


@dataclass(frozen=True, slots=True)
class ReceptionResult(SerializableFact):
    receptions: tuple[Reception, ...]
    mutual_receptions: tuple[MutualReception, ...]
    aspect_required: bool
    algorithm_card_id: str
    rule_ids: tuple[str, ...]
    source_ids: tuple[str, ...]
    excluded_capabilities: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class SolarThresholdProfile(SerializableFact):
    profile_id: str
    version: str
    cazimi_deg: float
    combust_deg: float
    under_beams_deg: float
    source_ids: tuple[str, ...]
    content_hash: str

    def __post_init__(self) -> None:
        thresholds = (self.cazimi_deg, self.combust_deg, self.under_beams_deg)
        if not all(math.isfinite(value) for value in thresholds):
            raise ValueError("solar thresholds must be finite")
        if not 0 <= self.cazimi_deg <= self.combust_deg <= self.under_beams_deg <= 180:
            raise ValueError("solar thresholds must be ordered within 0 to 180 degrees")
        if not self.profile_id or not self.version or not self.source_ids:
            raise ValueError("solar profile id, version, and sources are required")
        if len(self.content_hash) != 64:
            raise ValueError("solar profile content hash must be a SHA-256 hex digest")


@dataclass(frozen=True, slots=True)
class SolarConditionResult(SerializableFact):
    point_id: str
    sun_longitude_deg: float
    point_longitude_deg: float
    separation_deg: float
    relation: SolarRelation
    threshold_profile: SolarThresholdProfile
    algorithm_card_id: str
    rule_ids: tuple[str, ...]
    source_ids: tuple[str, ...]
    excluded_capabilities: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class LotOperand(SerializableFact):
    point_id: str
    longitude_deg: float
    coefficient: int


@dataclass(frozen=True, slots=True)
class LotResult(SerializableFact):
    lot_id: LotId
    longitude_deg: float
    sign_id: str
    degree_in_sign: float
    sect: Sect
    formula_id: str
    formula_version: str
    formula_expression: str
    operands: tuple[LotOperand, ...]
    algorithm_card_id: str
    rule_ids: tuple[str, ...]
    source_ids: tuple[str, ...]
    excluded_capabilities: tuple[str, ...]
