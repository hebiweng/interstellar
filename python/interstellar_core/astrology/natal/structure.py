"""Versioned, interpretation-free natal chart structure facts.

The module consumes canonical ``Point`` and ``Aspect`` mappings.  It never
recalculates astronomy and never assigns positive or negative meaning to a
shape.  Every classification threshold lives in an explicit profile so that
future traditions can coexist without changing historical snapshots.
"""

from __future__ import annotations

import hashlib
import json
import math
from collections import defaultdict
from collections.abc import Iterable, Mapping
from dataclasses import asdict, dataclass
from enum import StrEnum
from itertools import combinations
from typing import Any

from interstellar_core.domain.errors import DomainError


class StructureAvailability(StrEnum):
    AVAILABLE = "available"
    INDETERMINATE = "indeterminate"


class JonesShapeStatus(StrEnum):
    INDETERMINATE = "indeterminate"


@dataclass(frozen=True, slots=True)
class StructureProfile:
    profile_id: str
    version: str
    tradition: str
    participant_ids: tuple[str, ...]
    stellium_min_points: int = 3
    stellium_longitude_span_deg: float = 10.0
    angularity_on_angle_orb_deg: float = 5.0
    angularity_near_angle_orb_deg: float = 10.0
    description: str = ""

    def __post_init__(self) -> None:
        if not self.profile_id or not self.version or not self.tradition:
            raise ValueError("profile id, version, and tradition are required")
        if not self.participant_ids or len(set(self.participant_ids)) != len(
            self.participant_ids
        ):
            raise ValueError("profile participant ids must be non-empty and unique")
        if self.stellium_min_points < 3:
            raise ValueError("stellium_min_points must be at least three")
        if not math.isfinite(self.stellium_longitude_span_deg) or not (
            0 < self.stellium_longitude_span_deg < 30
        ):
            raise ValueError("stellium longitude span must be finite and in (0, 30)")
        if not math.isfinite(self.angularity_on_angle_orb_deg) or not math.isfinite(
            self.angularity_near_angle_orb_deg
        ):
            raise ValueError("angularity orbs must be finite")
        if not (
            0 <= self.angularity_on_angle_orb_deg
            <= self.angularity_near_angle_orb_deg
            < 90
        ):
            raise ValueError("angularity orbs must satisfy 0 <= on <= near < 90")

    @property
    def content_hash(self) -> str:
        payload = json.dumps(asdict(self), sort_keys=True, separators=(",", ":"))
        return f"sha256:{hashlib.sha256(payload.encode()).hexdigest()}"


MODERN_TEN_STRUCTURE_PROFILE_V1 = StructureProfile(
    profile_id="official.structure.modern_ten.v1",
    version="1.0.0",
    tradition="modern_western",
    participant_ids=(
        "sun",
        "moon",
        "mercury",
        "venus",
        "mars",
        "jupiter",
        "saturn",
        "uranus",
        "neptune",
        "pluto",
    ),
    description=(
        "Ten-body descriptive structure profile; classifications are geometry facts, "
        "not personality or outcome scores"
    ),
)


@dataclass(frozen=True, slots=True)
class StructureParticipant:
    point_id: str
    longitude_deg: float
    house: int | None


@dataclass(frozen=True, slots=True)
class CategoryCount:
    category_id: str
    point_ids: tuple[str, ...]
    count: int


@dataclass(frozen=True, slots=True)
class CategoricalStructure:
    dimension: str
    availability: StructureAvailability
    categories: tuple[CategoryCount, ...]
    evaluated_point_count: int
    missing_house_point_ids: tuple[str, ...]
    rule_ref: str


@dataclass(frozen=True, slots=True)
class AngularityFact:
    point_id: str
    house: int | None
    house_mode: str | None
    nearest_angle_id: str | None
    distance_to_angle_deg: float | None
    band: str


@dataclass(frozen=True, slots=True)
class AngularityResult:
    availability: StructureAvailability
    facts: tuple[AngularityFact, ...]
    evaluated_point_count: int
    available_angle_ids: tuple[str, ...]
    missing_house_point_ids: tuple[str, ...]
    rule_ref: str


@dataclass(frozen=True, slots=True)
class StelliumFact:
    stellium_id: str
    kind: str
    participant_ids: tuple[str, ...]
    sign_index: int | None
    house: int | None
    longitude_start_deg: float | None
    longitude_span_deg: float | None
    rule_ref: str


@dataclass(frozen=True, slots=True)
class StelliumResult:
    availability: StructureAvailability
    facts: tuple[StelliumFact, ...]
    evaluated_sign_group_count: int
    evaluated_house_group_count: int
    evaluated_longitude_window_count: int
    missing_house_point_ids: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class PatternRole:
    role_id: str
    point_ids: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class GeometricPatternFact:
    pattern_id: str
    pattern_type: str
    participant_ids: tuple[str, ...]
    roles: tuple[PatternRole, ...]
    evidence_aspect_ids: tuple[str, ...]
    rule_ref: str


@dataclass(frozen=True, slots=True)
class PatternEvaluationCount:
    pattern_type: str
    candidate_combination_count: int
    matched_pattern_count: int


@dataclass(frozen=True, slots=True)
class GeometricPatternResult:
    availability: StructureAvailability
    facts: tuple[GeometricPatternFact, ...]
    evaluations: tuple[PatternEvaluationCount, ...]
    expected_point_pair_count: int
    supplied_aspect_count: int
    usable_aspect_count: int
    excluded_aspect_count: int


@dataclass(frozen=True, slots=True)
class JonesShapeResult:
    status: JonesShapeStatus
    maturity: str
    shape_id: None
    evaluated_point_count: int
    reasons: tuple[str, ...]
    rule_ref: str


@dataclass(frozen=True, slots=True)
class StructureEvaluationCounts:
    supplied_point_count: int
    profile_expected_point_count: int
    profile_participant_count: int
    excluded_point_count: int
    expected_point_pair_count: int
    supplied_aspect_count: int
    usable_aspect_count: int


@dataclass(frozen=True, slots=True)
class StructureProvenance:
    algorithm_card_id: str
    capability_id: str
    calculation_ids: tuple[str, ...]
    implementation_version: str
    profile_id: str
    profile_version: str
    profile_content_hash: str
    expected_participant_ids: tuple[str, ...]
    supplied_participant_ids: tuple[str, ...]
    missing_participant_ids: tuple[str, ...]
    excluded_point_ids: tuple[str, ...]
    evaluation_counts: StructureEvaluationCounts
    interpretation_boundary: str


@dataclass(frozen=True, slots=True)
class NatalStructureResult:
    availability: StructureAvailability
    unavailable_reasons: tuple[str, ...]
    participants: tuple[StructureParticipant, ...]
    hemispheres: CategoricalStructure
    quadrants: CategoricalStructure
    house_modes: CategoricalStructure
    angularity: AngularityResult
    stelliums: StelliumResult
    geometric_patterns: GeometricPatternResult
    jones_shape: JonesShapeResult
    provenance: StructureProvenance

    def to_dict(self) -> dict[str, Any]:
        return json.loads(json.dumps(asdict(self), ensure_ascii=False))


@dataclass(frozen=True, slots=True)
class _CanonicalAspect:
    aspect_id: str
    point_a: str
    point_b: str
    type: str


@dataclass(frozen=True, slots=True)
class _AspectGraph:
    edge_types: dict[tuple[str, str], dict[str, tuple[str, ...]]]
    supplied_count: int
    usable_count: int
    excluded_count: int


_ANGLE_IDS = ("asc", "dsc", "mc", "ic")
_ANGULAR_HOUSES = frozenset({1, 4, 7, 10})
_SUCCEDENT_HOUSES = frozenset({2, 5, 8, 11})
_CADENT_HOUSES = frozenset({3, 6, 9, 12})
_PATTERN_TYPES = (
    "grand_trine",
    "t_square",
    "grand_cross",
    "yod",
    "kite",
    "mystic_rectangle",
)


def calculate_natal_structure(
    points: Iterable[Mapping[str, Any]],
    aspects: Iterable[Mapping[str, Any]],
    *,
    profile: StructureProfile = MODERN_TEN_STRUCTURE_PROFILE_V1,
) -> NatalStructureResult:
    """Return descriptive structure facts for one explicit point profile."""

    supplied_points = tuple(points)
    point_records = _canonical_points(supplied_points)
    supplied_by_id = {point.point_id: point for point in point_records}
    expected_ids = profile.participant_ids
    participants = tuple(
        supplied_by_id[point_id] for point_id in expected_ids if point_id in supplied_by_id
    )
    supplied_participant_ids = tuple(point.point_id for point in participants)
    missing_ids = tuple(point_id for point_id in expected_ids if point_id not in supplied_by_id)
    excluded_ids = tuple(sorted(set(supplied_by_id) - set(expected_ids)))
    aspect_records = _canonical_aspects(aspects, supplied_by_id)
    graph = _aspect_graph(aspect_records, set(supplied_participant_ids))

    missing_house_ids = tuple(
        point.point_id for point in participants if point.house is None
    )
    hemispheres = _hemispheres(participants, missing_house_ids)
    quadrants = _quadrants(participants, missing_house_ids)
    house_modes = _house_modes(participants, missing_house_ids)
    angularity = _angularity(
        participants,
        supplied_by_id,
        missing_house_ids,
        profile,
    )
    stelliums = _stelliums(participants, missing_house_ids, profile)
    geometric_patterns = _geometric_patterns(participants, graph)

    reasons: list[str] = []
    if missing_ids:
        reasons.append("MISSING_PROFILE_PARTICIPANTS")
    if missing_house_ids:
        reasons.append("MISSING_HOUSE_ASSIGNMENTS")
    availability = (
        StructureAvailability.INDETERMINATE
        if reasons
        else StructureAvailability.AVAILABLE
    )
    counts = StructureEvaluationCounts(
        supplied_point_count=len(point_records),
        profile_expected_point_count=len(expected_ids),
        profile_participant_count=len(participants),
        excluded_point_count=len(excluded_ids),
        expected_point_pair_count=_combination_count(len(participants), 2),
        supplied_aspect_count=graph.supplied_count,
        usable_aspect_count=graph.usable_count,
    )
    provenance = StructureProvenance(
        algorithm_card_id="ALG-NATAL-003",
        capability_id="natal.patterns_distributions",
        calculation_ids=(
            "distribution.hemisphere.v1",
            "distribution.quadrant.v1",
            "distribution.house_mode.v1",
            "structure.angularity.v1",
            "pattern.stellium.v1",
            "pattern.geometry.v1",
            "pattern.jones.v1",
        ),
        implementation_version="1.0.0",
        profile_id=profile.profile_id,
        profile_version=profile.version,
        profile_content_hash=profile.content_hash,
        expected_participant_ids=expected_ids,
        supplied_participant_ids=supplied_participant_ids,
        missing_participant_ids=missing_ids,
        excluded_point_ids=excluded_ids,
        evaluation_counts=counts,
        interpretation_boundary=(
            "Geometry and placement facts only; no personality, quality, or outcome meaning"
        ),
    )
    return NatalStructureResult(
        availability=availability,
        unavailable_reasons=tuple(reasons),
        participants=participants,
        hemispheres=hemispheres,
        quadrants=quadrants,
        house_modes=house_modes,
        angularity=angularity,
        stelliums=stelliums,
        geometric_patterns=geometric_patterns,
        jones_shape=JonesShapeResult(
            status=JonesShapeStatus.INDETERMINATE,
            maturity="experimental",
            shape_id=None,
            evaluated_point_count=len(participants),
            reasons=("NO_VERSIONED_JONES_CLASSIFICATION_RULE_IN_PROFILE",),
            rule_ref="ALG-NATAL-003:pattern.jones.v1:indeterminate",
        ),
        provenance=provenance,
    )


def _canonical_points(points: tuple[Mapping[str, Any], ...]) -> tuple[StructureParticipant, ...]:
    records: list[StructureParticipant] = []
    seen: set[str] = set()
    for point in points:
        try:
            point_id = str(point["point_id"])
            longitude = float(point["position"]["ecliptic"]["longitude_deg"])
        except (KeyError, TypeError, ValueError) as exc:
            raise DomainError(
                "NATAL_STRUCTURE_POINT_INVALID",
                "each point requires point_id and finite ecliptic longitude",
            ) from exc
        if not point_id or not math.isfinite(longitude):
            raise DomainError(
                "NATAL_STRUCTURE_POINT_INVALID",
                "each point requires point_id and finite ecliptic longitude",
            )
        if point_id in seen:
            raise DomainError(
                "NATAL_STRUCTURE_POINT_DUPLICATE",
                f"point supplied more than once: {point_id}",
            )
        seen.add(point_id)
        raw_house = point.get("house")
        if raw_house is None:
            house = None
        elif (
            isinstance(raw_house, bool)
            or not isinstance(raw_house, int)
            or not 1 <= raw_house <= 12
        ):
            raise DomainError(
                "NATAL_STRUCTURE_HOUSE_INVALID",
                f"house for {point_id} must be null or an integer in [1, 12]",
            )
        else:
            house = raw_house
        records.append(
            StructureParticipant(
                point_id=point_id,
                longitude_deg=longitude % 360.0,
                house=house,
            )
        )
    return tuple(records)


def _canonical_aspects(
    aspects: Iterable[Mapping[str, Any]],
    supplied_points: Mapping[str, StructureParticipant],
) -> tuple[_CanonicalAspect, ...]:
    records: list[_CanonicalAspect] = []
    seen_ids: set[str] = set()
    for aspect in aspects:
        try:
            aspect_id = str(aspect["aspect_id"])
            point_a = str(aspect["point_a"])
            point_b = str(aspect["point_b"])
            aspect_type = str(aspect["type"])
        except (KeyError, TypeError) as exc:
            raise DomainError(
                "NATAL_STRUCTURE_ASPECT_INVALID",
                "each aspect requires aspect_id, point_a, point_b, and type",
            ) from exc
        if not aspect_id or not point_a or not point_b or not aspect_type or point_a == point_b:
            raise DomainError(
                "NATAL_STRUCTURE_ASPECT_INVALID",
                "aspect ids, endpoints, and type must be non-empty and endpoints distinct",
            )
        if aspect_id in seen_ids:
            raise DomainError(
                "NATAL_STRUCTURE_ASPECT_DUPLICATE",
                f"aspect supplied more than once: {aspect_id}",
            )
        unknown = sorted({point_a, point_b} - set(supplied_points))
        if unknown:
            raise DomainError(
                "NATAL_STRUCTURE_ASPECT_POINT_UNKNOWN",
                "aspect references points not present in canonical points: " + ", ".join(unknown),
            )
        seen_ids.add(aspect_id)
        records.append(_CanonicalAspect(aspect_id, point_a, point_b, aspect_type))
    return tuple(records)


def _categorical(
    dimension: str,
    participants: tuple[StructureParticipant, ...],
    categories: tuple[tuple[str, frozenset[int]], ...],
    missing_house_ids: tuple[str, ...],
    rule_ref: str,
) -> CategoricalStructure:
    available = tuple(point for point in participants if point.house is not None)
    values = tuple(
        CategoryCount(
            category_id=category_id,
            point_ids=tuple(
                point.point_id for point in available if point.house in house_numbers
            ),
            count=sum(point.house in house_numbers for point in available),
        )
        for category_id, house_numbers in categories
    )
    return CategoricalStructure(
        dimension=dimension,
        availability=(
            StructureAvailability.INDETERMINATE
            if missing_house_ids
            else StructureAvailability.AVAILABLE
        ),
        categories=values,
        evaluated_point_count=len(available),
        missing_house_point_ids=missing_house_ids,
        rule_ref=rule_ref,
    )


def _hemispheres(
    participants: tuple[StructureParticipant, ...],
    missing_house_ids: tuple[str, ...],
) -> CategoricalStructure:
    return _categorical(
        "hemispheres",
        participants,
        (
            ("below_horizon", frozenset(range(1, 7))),
            ("above_horizon", frozenset(range(7, 13))),
            ("eastern", frozenset({10, 11, 12, 1, 2, 3})),
            ("western", frozenset({4, 5, 6, 7, 8, 9})),
        ),
        missing_house_ids,
        "ALG-NATAL-003:distribution.hemisphere.v1",
    )


def _quadrants(
    participants: tuple[StructureParticipant, ...],
    missing_house_ids: tuple[str, ...],
) -> CategoricalStructure:
    return _categorical(
        "quadrants",
        participants,
        (
            ("quadrant_1", frozenset({1, 2, 3})),
            ("quadrant_2", frozenset({4, 5, 6})),
            ("quadrant_3", frozenset({7, 8, 9})),
            ("quadrant_4", frozenset({10, 11, 12})),
        ),
        missing_house_ids,
        "ALG-NATAL-003:distribution.quadrant.v1",
    )


def _house_modes(
    participants: tuple[StructureParticipant, ...],
    missing_house_ids: tuple[str, ...],
) -> CategoricalStructure:
    return _categorical(
        "house_modes",
        participants,
        (
            ("angular", _ANGULAR_HOUSES),
            ("succedent", _SUCCEDENT_HOUSES),
            ("cadent", _CADENT_HOUSES),
        ),
        missing_house_ids,
        "ALG-NATAL-003:distribution.house_mode.v1",
    )


def _house_mode(house: int | None) -> str | None:
    if house in _ANGULAR_HOUSES:
        return "angular"
    if house in _SUCCEDENT_HOUSES:
        return "succedent"
    if house in _CADENT_HOUSES:
        return "cadent"
    return None


def _circular_distance(left: float, right: float) -> float:
    difference = abs((left - right) % 360.0)
    return min(difference, 360.0 - difference)


def _angularity(
    participants: tuple[StructureParticipant, ...],
    supplied_by_id: Mapping[str, StructureParticipant],
    missing_house_ids: tuple[str, ...],
    profile: StructureProfile,
) -> AngularityResult:
    angle_points = tuple(
        supplied_by_id[point_id] for point_id in _ANGLE_IDS if point_id in supplied_by_id
    )
    facts: list[AngularityFact] = []
    for point in participants:
        if not angle_points:
            nearest_id = None
            distance = None
            band = "indeterminate"
        else:
            nearest = min(
                angle_points,
                key=lambda angle: (
                    _circular_distance(point.longitude_deg, angle.longitude_deg),
                    _ANGLE_IDS.index(angle.point_id),
                ),
            )
            nearest_id = nearest.point_id
            distance = _circular_distance(point.longitude_deg, nearest.longitude_deg)
            if distance <= profile.angularity_on_angle_orb_deg:
                band = "on_angle"
            elif distance <= profile.angularity_near_angle_orb_deg:
                band = "near_angle"
            else:
                band = "not_near_angle"
        facts.append(
            AngularityFact(
                point_id=point.point_id,
                house=point.house,
                house_mode=_house_mode(point.house),
                nearest_angle_id=nearest_id,
                distance_to_angle_deg=distance,
                band=band,
            )
        )
    return AngularityResult(
        availability=(
            StructureAvailability.INDETERMINATE
            if missing_house_ids or not angle_points
            else StructureAvailability.AVAILABLE
        ),
        facts=tuple(facts),
        evaluated_point_count=len(participants),
        available_angle_ids=tuple(point.point_id for point in angle_points),
        missing_house_point_ids=missing_house_ids,
        rule_ref="ALG-NATAL-003:structure.angularity.v1",
    )


def _stelliums(
    participants: tuple[StructureParticipant, ...],
    missing_house_ids: tuple[str, ...],
    profile: StructureProfile,
) -> StelliumResult:
    facts: list[StelliumFact] = []
    for sign_index in range(12):
        members = tuple(
            point.point_id
            for point in participants
            if int(point.longitude_deg // 30.0) == sign_index
        )
        if len(members) >= profile.stellium_min_points:
            facts.append(
                _stellium_fact(
                    "sign",
                    members,
                    sign_index=sign_index,
                    rule_ref="ALG-NATAL-003:pattern.stellium.sign.v1",
                )
            )
    for house in range(1, 13):
        members = tuple(point.point_id for point in participants if point.house == house)
        if len(members) >= profile.stellium_min_points:
            facts.append(
                _stellium_fact(
                    "house",
                    members,
                    house=house,
                    rule_ref="ALG-NATAL-003:pattern.stellium.house.v1",
                )
            )
    for member_ids, start, span in _circular_stellium_windows(participants, profile):
        facts.append(
            _stellium_fact(
                "longitude_cluster",
                member_ids,
                longitude_start_deg=start,
                longitude_span_deg=span,
                rule_ref="ALG-NATAL-003:pattern.stellium.longitude_cluster.v1",
            )
        )
    facts.sort(key=lambda fact: (fact.kind, fact.participant_ids, fact.stellium_id))
    return StelliumResult(
        availability=(
            StructureAvailability.INDETERMINATE
            if missing_house_ids
            else StructureAvailability.AVAILABLE
        ),
        facts=tuple(facts),
        evaluated_sign_group_count=12,
        evaluated_house_group_count=12 if not missing_house_ids else 0,
        evaluated_longitude_window_count=len(participants),
        missing_house_point_ids=missing_house_ids,
    )


def _stellium_fact(
    kind: str,
    participant_ids: tuple[str, ...],
    *,
    sign_index: int | None = None,
    house: int | None = None,
    longitude_start_deg: float | None = None,
    longitude_span_deg: float | None = None,
    rule_ref: str,
) -> StelliumFact:
    ordered = tuple(sorted(participant_ids))
    identity = json.dumps(
        {
            "kind": kind,
            "participants": ordered,
            "sign": sign_index,
            "house": house,
            "start": longitude_start_deg,
            "span": longitude_span_deg,
        },
        sort_keys=True,
        separators=(",", ":"),
    )
    digest = hashlib.sha256(identity.encode()).hexdigest()[:20]
    return StelliumFact(
        stellium_id=f"stellium:{kind}:sha256:{digest}",
        kind=kind,
        participant_ids=ordered,
        sign_index=sign_index,
        house=house,
        longitude_start_deg=longitude_start_deg,
        longitude_span_deg=longitude_span_deg,
        rule_ref=rule_ref,
    )


def _circular_stellium_windows(
    participants: tuple[StructureParticipant, ...],
    profile: StructureProfile,
) -> tuple[tuple[tuple[str, ...], float, float], ...]:
    if not participants:
        return ()
    ordered = sorted(participants, key=lambda point: (point.longitude_deg, point.point_id))
    size = len(ordered)
    candidates: dict[frozenset[str], tuple[float, float]] = {}
    for start_index, start_point in enumerate(ordered):
        members: list[StructureParticipant] = []
        for offset in range(size):
            candidate = ordered[(start_index + offset) % size]
            unwrapped = candidate.longitude_deg
            if start_index + offset >= size:
                unwrapped += 360.0
            span = unwrapped - start_point.longitude_deg
            if span > profile.stellium_longitude_span_deg:
                break
            members.append(candidate)
        if len(members) >= profile.stellium_min_points:
            key = frozenset(point.point_id for point in members)
            span = (
                members[-1].longitude_deg - start_point.longitude_deg
            ) % 360.0
            previous = candidates.get(key)
            if previous is None or span < previous[1]:
                candidates[key] = (start_point.longitude_deg, span)
    maximal = {
        member_ids: values
        for member_ids, values in candidates.items()
        if not any(member_ids < other_ids for other_ids in candidates)
    }
    return tuple(
        (tuple(sorted(member_ids)), values[0], values[1])
        for member_ids, values in sorted(
            maximal.items(), key=lambda item: (tuple(sorted(item[0])), item[1])
        )
    )


def _aspect_graph(
    aspects: tuple[_CanonicalAspect, ...],
    participant_ids: set[str],
) -> _AspectGraph:
    mutable: dict[tuple[str, str], dict[str, list[str]]] = defaultdict(
        lambda: defaultdict(list)
    )
    usable = 0
    for aspect in aspects:
        if aspect.point_a not in participant_ids or aspect.point_b not in participant_ids:
            continue
        usable += 1
        pair = tuple(sorted((aspect.point_a, aspect.point_b)))
        mutable[pair][aspect.type].append(aspect.aspect_id)
    frozen = {
        pair: {
            aspect_type: tuple(sorted(aspect_ids))
            for aspect_type, aspect_ids in sorted(types.items())
        }
        for pair, types in sorted(mutable.items())
    }
    return _AspectGraph(
        edge_types=frozen,
        supplied_count=len(aspects),
        usable_count=usable,
        excluded_count=len(aspects) - usable,
    )


def _geometric_patterns(
    participants: tuple[StructureParticipant, ...],
    graph: _AspectGraph,
) -> GeometricPatternResult:
    point_ids = tuple(point.point_id for point in participants)
    facts: list[GeometricPatternFact] = []
    facts.extend(_grand_trines(point_ids, graph))
    facts.extend(_t_squares(point_ids, graph))
    facts.extend(_grand_crosses(point_ids, graph))
    facts.extend(_yods(point_ids, graph))
    facts.extend(_kites(point_ids, graph))
    facts.extend(_mystic_rectangles(point_ids, graph))
    unique = {fact.pattern_id: fact for fact in facts}
    ordered = tuple(
        sorted(
            unique.values(),
            key=lambda fact: (fact.pattern_type, fact.participant_ids, fact.pattern_id),
        )
    )
    match_counts = defaultdict(int)
    for fact in ordered:
        match_counts[fact.pattern_type] += 1
    triple_count = _combination_count(len(point_ids), 3)
    quadruple_count = _combination_count(len(point_ids), 4)
    evaluations = tuple(
        PatternEvaluationCount(
            pattern_type=pattern_type,
            candidate_combination_count=(
                triple_count
                if pattern_type in {"grand_trine", "t_square", "yod"}
                else quadruple_count
            ),
            matched_pattern_count=match_counts[pattern_type],
        )
        for pattern_type in _PATTERN_TYPES
    )
    return GeometricPatternResult(
        availability=StructureAvailability.AVAILABLE,
        facts=ordered,
        evaluations=evaluations,
        expected_point_pair_count=_combination_count(len(point_ids), 2),
        supplied_aspect_count=graph.supplied_count,
        usable_aspect_count=graph.usable_count,
        excluded_aspect_count=graph.excluded_count,
    )


def _pair(left: str, right: str) -> tuple[str, str]:
    return tuple(sorted((left, right)))


def _has(graph: _AspectGraph, left: str, right: str, aspect_type: str) -> bool:
    return aspect_type in graph.edge_types.get(_pair(left, right), {})


def _evidence(
    graph: _AspectGraph,
    requirements: Iterable[tuple[str, str, str]],
) -> tuple[str, ...]:
    ids: list[str] = []
    for left, right, aspect_type in requirements:
        ids.extend(graph.edge_types[_pair(left, right)][aspect_type])
    return tuple(sorted(set(ids)))


def _pattern(
    pattern_type: str,
    participant_ids: Iterable[str],
    roles: Iterable[PatternRole],
    evidence_ids: tuple[str, ...],
) -> GeometricPatternFact:
    ordered_participants = tuple(sorted(participant_ids))
    ordered_roles = tuple(sorted(roles, key=lambda role: (role.role_id, role.point_ids)))
    identity = json.dumps(
        {
            "type": pattern_type,
            "participants": ordered_participants,
            "roles": [asdict(role) for role in ordered_roles],
        },
        sort_keys=True,
        separators=(",", ":"),
    )
    digest = hashlib.sha256(identity.encode()).hexdigest()[:20]
    return GeometricPatternFact(
        pattern_id=f"pattern:{pattern_type}:sha256:{digest}",
        pattern_type=pattern_type,
        participant_ids=ordered_participants,
        roles=ordered_roles,
        evidence_aspect_ids=evidence_ids,
        rule_ref=f"ALG-NATAL-003:pattern.geometry.{pattern_type}.v1",
    )


def _grand_trines(point_ids: tuple[str, ...], graph: _AspectGraph) -> list[GeometricPatternFact]:
    result: list[GeometricPatternFact] = []
    for triple in combinations(point_ids, 3):
        requirements = tuple((left, right, "trine") for left, right in combinations(triple, 2))
        if all(_has(graph, *requirement) for requirement in requirements):
            result.append(
                _pattern(
                    "grand_trine",
                    triple,
                    (PatternRole("trine_members", tuple(sorted(triple))),),
                    _evidence(graph, requirements),
                )
            )
    return result


def _t_squares(point_ids: tuple[str, ...], graph: _AspectGraph) -> list[GeometricPatternFact]:
    result: list[GeometricPatternFact] = []
    for triple in combinations(point_ids, 3):
        for left, right in combinations(triple, 2):
            apex = next(point_id for point_id in triple if point_id not in {left, right})
            requirements = (
                (left, right, "opposition"),
                (left, apex, "square"),
                (right, apex, "square"),
            )
            if all(_has(graph, *requirement) for requirement in requirements):
                result.append(
                    _pattern(
                        "t_square",
                        triple,
                        (
                            PatternRole("opposition_axis", tuple(sorted((left, right)))),
                            PatternRole("square_apex", (apex,)),
                        ),
                        _evidence(graph, requirements),
                    )
                )
    return result


def _perfect_matchings(quadruple: tuple[str, ...]) -> tuple[tuple[tuple[str, str], ...], ...]:
    first, second, third, fourth = quadruple
    return (
        (_pair(first, second), _pair(third, fourth)),
        (_pair(first, third), _pair(second, fourth)),
        (_pair(first, fourth), _pair(second, third)),
    )


def _cross_pairs(
    first_axis: tuple[str, str], second_axis: tuple[str, str]
) -> tuple[tuple[str, str], ...]:
    return tuple(_pair(left, right) for left in first_axis for right in second_axis)


def _grand_crosses(
    point_ids: tuple[str, ...], graph: _AspectGraph
) -> list[GeometricPatternFact]:
    result: list[GeometricPatternFact] = []
    for quadruple in combinations(point_ids, 4):
        for first_axis, second_axis in _perfect_matchings(quadruple):
            requirements = (
                (first_axis[0], first_axis[1], "opposition"),
                (second_axis[0], second_axis[1], "opposition"),
                *(
                    (left, right, "square")
                    for left, right in _cross_pairs(first_axis, second_axis)
                ),
            )
            if all(_has(graph, *requirement) for requirement in requirements):
                result.append(
                    _pattern(
                        "grand_cross",
                        quadruple,
                        (
                            PatternRole("opposition_axis", first_axis),
                            PatternRole("opposition_axis", second_axis),
                        ),
                        _evidence(graph, requirements),
                    )
                )
    return result


def _yods(point_ids: tuple[str, ...], graph: _AspectGraph) -> list[GeometricPatternFact]:
    result: list[GeometricPatternFact] = []
    for triple in combinations(point_ids, 3):
        for apex in triple:
            base = tuple(point_id for point_id in triple if point_id != apex)
            requirements = (
                (base[0], base[1], "sextile"),
                (apex, base[0], "quincunx"),
                (apex, base[1], "quincunx"),
            )
            if all(_has(graph, *requirement) for requirement in requirements):
                result.append(
                    _pattern(
                        "yod",
                        triple,
                        (
                            PatternRole("sextile_base", tuple(sorted(base))),
                            PatternRole("quincunx_apex", (apex,)),
                        ),
                        _evidence(graph, requirements),
                    )
                )
    return result


def _kites(point_ids: tuple[str, ...], graph: _AspectGraph) -> list[GeometricPatternFact]:
    result: list[GeometricPatternFact] = []
    for quadruple in combinations(point_ids, 4):
        for trine_members in combinations(quadruple, 3):
            focus = next(point_id for point_id in quadruple if point_id not in trine_members)
            trine_requirements = tuple(
                (left, right, "trine") for left, right in combinations(trine_members, 2)
            )
            if not all(_has(graph, *requirement) for requirement in trine_requirements):
                continue
            for opposed_member in trine_members:
                sextile_members = tuple(
                    point_id for point_id in trine_members if point_id != opposed_member
                )
                requirements = (
                    *trine_requirements,
                    (focus, opposed_member, "opposition"),
                    (focus, sextile_members[0], "sextile"),
                    (focus, sextile_members[1], "sextile"),
                )
                if all(_has(graph, *requirement) for requirement in requirements):
                    result.append(
                        _pattern(
                            "kite",
                            quadruple,
                            (
                                PatternRole("trine_members", tuple(sorted(trine_members))),
                                PatternRole("opposed_trine_member", (opposed_member,)),
                                PatternRole("opposition_focus", (focus,)),
                            ),
                            _evidence(graph, requirements),
                        )
                    )
    return result


def _mystic_rectangles(
    point_ids: tuple[str, ...], graph: _AspectGraph
) -> list[GeometricPatternFact]:
    result: list[GeometricPatternFact] = []
    for quadruple in combinations(point_ids, 4):
        for first_axis, second_axis in _perfect_matchings(quadruple):
            if not _has(graph, *first_axis, "opposition") or not _has(
                graph, *second_axis, "opposition"
            ):
                continue
            cross_pairs = _cross_pairs(first_axis, second_axis)
            cross_types: dict[tuple[str, str], str] = {}
            for pair in cross_pairs:
                types = {
                    aspect_type
                    for aspect_type in ("trine", "sextile")
                    if _has(graph, *pair, aspect_type)
                }
                if len(types) != 1:
                    break
                cross_types[pair] = next(iter(types))
            if len(cross_types) != 4 or list(cross_types.values()).count("trine") != 2:
                continue
            if list(cross_types.values()).count("sextile") != 2:
                continue
            if any(
                {
                    cross_types[pair]
                    for pair in cross_pairs
                    if point_id in pair
                }
                != {"trine", "sextile"}
                for point_id in quadruple
            ):
                continue
            requirements = (
                (first_axis[0], first_axis[1], "opposition"),
                (second_axis[0], second_axis[1], "opposition"),
                *((left, right, cross_types[(left, right)]) for left, right in cross_pairs),
            )
            result.append(
                _pattern(
                    "mystic_rectangle",
                    quadruple,
                    (
                        PatternRole("opposition_axis", first_axis),
                        PatternRole("opposition_axis", second_axis),
                    ),
                    _evidence(graph, requirements),
                )
            )
    return result


def _combination_count(item_count: int, selection_count: int) -> int:
    if item_count < selection_count:
        return 0
    return math.comb(item_count, selection_count)


__all__ = [
    "MODERN_TEN_STRUCTURE_PROFILE_V1",
    "AngularityFact",
    "AngularityResult",
    "CategoricalStructure",
    "CategoryCount",
    "GeometricPatternFact",
    "GeometricPatternResult",
    "JonesShapeResult",
    "JonesShapeStatus",
    "NatalStructureResult",
    "PatternEvaluationCount",
    "PatternRole",
    "StelliumFact",
    "StelliumResult",
    "StructureAvailability",
    "StructureEvaluationCounts",
    "StructureParticipant",
    "StructureProfile",
    "StructureProvenance",
    "calculate_natal_structure",
]
