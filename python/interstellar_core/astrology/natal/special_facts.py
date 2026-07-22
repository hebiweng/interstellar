"""Versioned, interpretation-free special-degree and mirror-point facts.

The calculations in this module are deliberately independent from report
copy.  They classify canonical ecliptic longitudes according to explicit,
immutable profiles and preserve every rule/source reference needed to
reproduce the result.

``critical degrees`` are not evaluated by the default profile.  The phrase is
used for several incompatible modern and traditional degree lists; publishing
one without selecting and sourcing a concrete table would create a false fact.
The result therefore carries a machine-readable ``not_evaluated`` status rather
than silently inventing a list.
"""

from __future__ import annotations

import hashlib
import json
import math
from collections.abc import Iterable, Mapping
from dataclasses import asdict, dataclass
from enum import StrEnum
from itertools import combinations
from typing import Any

from interstellar_core.astrology.classical.sources import (
    SRC_LILLY_CHRISTIAN_ASTROLOGY,
    SRC_PTOLEMY_TETRABIBLOS,
)
from interstellar_core.domain import DomainError

ALGORITHM_SPECIAL_DEGREES = "ALG-NATAL-SPECIAL-DEGREES-001"
ALGORITHM_MIRROR_POINTS = "ALG-NATAL-MIRROR-POINTS-001"

CAPABILITY_SPECIAL_DEGREES = "natal.special_degrees.v1"
CAPABILITY_MIRROR_POINTS = "aspect.mirror.v1"

SRC_INTERSTELLAR_ZODIAC_PARTITION = (
    "source.interstellar.canonical_zodiac_partition.v1"
)


def _content_hash(value: Any) -> str:
    """Return a stable SHA-256 hex digest for a JSON-compatible value."""

    payload = json.dumps(value, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode()).hexdigest()


def _json_value(value: Any) -> Any:
    if isinstance(value, StrEnum):
        return value.value
    if isinstance(value, dict):
        return {key: _json_value(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_value(item) for item in value]
    return value


class SerializableFact:
    """JSON-safe projection shared by the public report contracts."""

    def to_dict(self) -> dict[str, Any]:
        return _json_value(asdict(self))


class RuleEvaluationStatus(StrEnum):
    AVAILABLE = "available"
    NOT_EVALUATED = "not_evaluated"


class MirrorContactType(StrEnum):
    ANTISCIA = "antiscia"
    CONTRA_ANTISCIA = "contra_antiscia"


@dataclass(frozen=True, slots=True)
class VersionedRule(SerializableFact):
    rule_id: str
    version: str
    source_ids: tuple[str, ...]
    definition: str
    content_hash: str

    def __post_init__(self) -> None:
        if not self.rule_id or not self.version or not self.source_ids:
            raise ValueError("rule id, version, and sources are required")
        if len(set(self.source_ids)) != len(self.source_ids):
            raise ValueError("rule source ids must be unique")
        if len(self.content_hash) != 64:
            raise ValueError("rule content hash must be a SHA-256 hex digest")


def _versioned_rule(
    rule_id: str,
    *,
    source_ids: tuple[str, ...],
    definition: str,
) -> VersionedRule:
    version = "1.0.0"
    return VersionedRule(
        rule_id=rule_id,
        version=version,
        source_ids=source_ids,
        definition=definition,
        content_hash=_content_hash(
            {
                "rule_id": rule_id,
                "version": version,
                "source_ids": source_ids,
                "definition": definition,
            }
        ),
    )


RULE_DECAN_INDEX_V1 = _versioned_rule(
    "natal.degree.decan_equal_ten_degree.v1",
    source_ids=(SRC_PTOLEMY_TETRABIBLOS,),
    definition=(
        "Partition each 30-degree zodiac sign into half-open intervals "
        "[0,10), [10,20), and [20,30), numbered 1, 2, and 3"
    ),
)
RULE_VIA_COMBUSTA_V1 = _versioned_rule(
    "natal.degree.via_combusta.libra15_scorpio15.v1",
    source_ids=(SRC_LILLY_CHRISTIAN_ASTROLOGY,),
    definition=(
        "Classify longitudes in the half-open tropical-zodiac interval "
        "[195,225) degrees (Libra 15 degrees through Scorpio 15 degrees)"
    ),
)
RULE_TERMINAL_29_V1 = _versioned_rule(
    "natal.degree.terminal_29_interval.v1",
    source_ids=(SRC_INTERSTELLAR_ZODIAC_PARTITION,),
    definition=(
        "Classify a point as being in a sign's terminal numbered degree when "
        "its sign-relative longitude is in the half-open interval [29,30)"
    ),
)
RULE_ANTISCIA_V1 = _versioned_rule(
    "aspect.mirror.antiscia.cancer_capricorn_axis.v1",
    source_ids=(SRC_PTOLEMY_TETRABIBLOS, SRC_LILLY_CHRISTIAN_ASTROLOGY),
    definition=(
        "Map ecliptic longitude lambda to (180 - lambda) mod 360; a contact "
        "exists when the circular separation from another point is within orb"
    ),
)
RULE_CONTRA_ANTISCIA_V1 = _versioned_rule(
    "aspect.mirror.contra_antiscia.aries_libra_axis.v1",
    source_ids=(SRC_LILLY_CHRISTIAN_ASTROLOGY,),
    definition=(
        "Map ecliptic longitude lambda to (360 - lambda) mod 360; a contact "
        "exists when the circular separation from another point is within orb"
    ),
)


@dataclass(frozen=True, slots=True)
class SpecialDegreeProfile(SerializableFact):
    profile_id: str
    version: str
    zodiac: str
    via_combusta_start_longitude_deg: float
    via_combusta_end_longitude_deg: float
    terminal_degree_start_deg: float
    decan_size_deg: float
    critical_degree_table_id: str | None
    rule_ids: tuple[str, ...]
    source_ids: tuple[str, ...]
    content_hash: str

    def __post_init__(self) -> None:
        if not self.profile_id or not self.version or not self.zodiac:
            raise ValueError("special-degree profile identity is required")
        if not all(
            math.isfinite(value)
            for value in (
                self.via_combusta_start_longitude_deg,
                self.via_combusta_end_longitude_deg,
                self.terminal_degree_start_deg,
                self.decan_size_deg,
            )
        ):
            raise ValueError("special-degree thresholds must be finite")
        if not (
            0 <= self.via_combusta_start_longitude_deg < 360
            and 0 <= self.via_combusta_end_longitude_deg < 360
            and self.via_combusta_start_longitude_deg
            != self.via_combusta_end_longitude_deg
        ):
            raise ValueError("via-combusta bounds must be distinct longitudes")
        if not 0 <= self.terminal_degree_start_deg < 30:
            raise ValueError("terminal-degree threshold must be in [0,30)")
        if not math.isclose(30 / self.decan_size_deg, 3):
            raise ValueError("the published decan profile must make three equal divisions")
        if not self.rule_ids or not self.source_ids:
            raise ValueError("special-degree profile rules and sources are required")
        if len(self.content_hash) != 64:
            raise ValueError("profile content hash must be a SHA-256 hex digest")


def _special_degree_profile() -> SpecialDegreeProfile:
    values = {
        "profile_id": "natal.special_degrees.lilly_equal_decans.v1",
        "version": "1.0.0",
        "zodiac": "tropical",
        "via_combusta_start_longitude_deg": 195.0,
        "via_combusta_end_longitude_deg": 225.0,
        "terminal_degree_start_deg": 29.0,
        "decan_size_deg": 10.0,
        "critical_degree_table_id": None,
        "rule_ids": (
            RULE_DECAN_INDEX_V1.rule_id,
            RULE_VIA_COMBUSTA_V1.rule_id,
            RULE_TERMINAL_29_V1.rule_id,
        ),
        "source_ids": (
            SRC_PTOLEMY_TETRABIBLOS,
            SRC_LILLY_CHRISTIAN_ASTROLOGY,
            SRC_INTERSTELLAR_ZODIAC_PARTITION,
        ),
    }
    return SpecialDegreeProfile(**values, content_hash=_content_hash(values))


DEFAULT_SPECIAL_DEGREE_PROFILE = _special_degree_profile()


@dataclass(frozen=True, slots=True)
class MirrorProfile(SerializableFact):
    profile_id: str
    version: str
    contact_orb_deg: float
    rule_ids: tuple[str, ...]
    source_ids: tuple[str, ...]
    content_hash: str

    def __post_init__(self) -> None:
        if not self.profile_id or not self.version:
            raise ValueError("mirror profile identity is required")
        if not math.isfinite(self.contact_orb_deg) or not (
            0 <= self.contact_orb_deg < 30
        ):
            raise ValueError("mirror contact orb must be finite and in [0,30)")
        if not self.rule_ids or not self.source_ids:
            raise ValueError("mirror profile rules and sources are required")
        if len(self.content_hash) != 64:
            raise ValueError("profile content hash must be a SHA-256 hex digest")


def mirror_profile(*, contact_orb_deg: float = 1.0) -> MirrorProfile:
    """Build a versioned mirror profile; the orb is part of its content hash."""

    values = {
        "profile_id": "aspect.mirror.classical_axes.v1",
        "version": "1.0.0",
        "contact_orb_deg": float(contact_orb_deg),
        "rule_ids": (RULE_ANTISCIA_V1.rule_id, RULE_CONTRA_ANTISCIA_V1.rule_id),
        "source_ids": (
            SRC_PTOLEMY_TETRABIBLOS,
            SRC_LILLY_CHRISTIAN_ASTROLOGY,
        ),
    }
    return MirrorProfile(**values, content_hash=_content_hash(values))


DEFAULT_MIRROR_PROFILE = mirror_profile()


@dataclass(frozen=True, slots=True)
class _InputPoint:
    point_id: str
    longitude_deg: float


@dataclass(frozen=True, slots=True)
class CriticalDegreeEvaluation(SerializableFact):
    status: RuleEvaluationStatus
    table_id: str | None
    reason_code: str | None
    rule_ids: tuple[str, ...]
    source_ids: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class SpecialDegreePointFact(SerializableFact):
    point_id: str
    longitude_deg: float
    sign_id: str
    degree_in_sign: float
    decan_index: int
    decan_start_deg: float
    decan_end_deg: float
    in_via_combusta: bool
    in_terminal_degree_29: bool
    critical_degree_match: bool | None
    rule_ids: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class SpecialDegreeProvenance(SerializableFact):
    algorithm_card_id: str
    capability_id: str
    implementation_version: str
    profile_id: str
    profile_version: str
    profile_content_hash: str
    rules: tuple[VersionedRule, ...]
    source_ids: tuple[str, ...]
    supplied_point_ids: tuple[str, ...]
    evaluated_point_count: int
    excluded_capabilities: tuple[str, ...]
    interpretation_boundary: str


@dataclass(frozen=True, slots=True)
class SpecialDegreeResult(SerializableFact):
    points: tuple[SpecialDegreePointFact, ...]
    critical_degrees: CriticalDegreeEvaluation
    provenance: SpecialDegreeProvenance


@dataclass(frozen=True, slots=True)
class MirrorPointFact(SerializableFact):
    point_id: str
    longitude_deg: float
    antiscia_longitude_deg: float
    antiscia_sign_id: str
    antiscia_degree_in_sign: float
    contra_antiscia_longitude_deg: float
    contra_antiscia_sign_id: str
    contra_antiscia_degree_in_sign: float
    rule_ids: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class MirrorContactFact(SerializableFact):
    contact_id: str
    contact_type: MirrorContactType
    point_a: str
    point_b: str
    point_a_longitude_deg: float
    point_b_longitude_deg: float
    point_a_mirror_longitude_deg: float
    point_b_mirror_longitude_deg: float
    separation_from_exact_deg: float
    orb_deg: float
    orb_fraction_remaining: float
    rule_id: str


@dataclass(frozen=True, slots=True)
class MirrorProvenance(SerializableFact):
    algorithm_card_id: str
    capability_id: str
    implementation_version: str
    profile_id: str
    profile_version: str
    profile_content_hash: str
    rules: tuple[VersionedRule, ...]
    source_ids: tuple[str, ...]
    supplied_point_ids: tuple[str, ...]
    evaluated_pair_count: int
    matched_contact_count: int
    interpretation_boundary: str


@dataclass(frozen=True, slots=True)
class MirrorResult(SerializableFact):
    mirror_points: tuple[MirrorPointFact, ...]
    contacts: tuple[MirrorContactFact, ...]
    provenance: MirrorProvenance


@dataclass(frozen=True, slots=True)
class NatalSpecialFactsReport(SerializableFact):
    """Integration-ready report contract for both pure rule engines."""

    special_degrees: SpecialDegreeResult
    mirrors: MirrorResult


SIGN_IDS: tuple[str, ...] = (
    "aries",
    "taurus",
    "gemini",
    "cancer",
    "leo",
    "virgo",
    "libra",
    "scorpio",
    "sagittarius",
    "capricorn",
    "aquarius",
    "pisces",
)


def _extract_points(points: Iterable[Mapping[str, Any]]) -> tuple[_InputPoint, ...]:
    extracted: list[_InputPoint] = []
    seen: set[str] = set()
    for raw in points:
        try:
            point_id = str(raw["point_id"])
            longitude = float(raw["position"]["ecliptic"]["longitude_deg"])
        except (KeyError, TypeError, ValueError) as exc:
            raise DomainError(
                "NATAL_SPECIAL_POINT_INVALID",
                "every point requires point_id and a numeric ecliptic longitude",
            ) from exc
        if not point_id:
            raise DomainError("NATAL_SPECIAL_POINT_INVALID", "point_id cannot be empty")
        if point_id in seen:
            raise DomainError(
                "NATAL_SPECIAL_POINT_DUPLICATE",
                f"point supplied more than once: {point_id}",
            )
        if not math.isfinite(longitude) or not 0 <= longitude < 360:
            raise DomainError(
                "NATAL_SPECIAL_LONGITUDE_INVALID",
                "ecliptic longitude must be finite and in [0,360)",
            )
        seen.add(point_id)
        extracted.append(_InputPoint(point_id, longitude))
    return tuple(sorted(extracted, key=lambda item: item.point_id))


def _sign_and_degree(longitude_deg: float) -> tuple[str, float]:
    sign_index = min(int(longitude_deg // 30), 11)
    return SIGN_IDS[sign_index], longitude_deg - sign_index * 30


def _in_circular_half_open_interval(value: float, start: float, end: float) -> bool:
    if start < end:
        return start <= value < end
    return value >= start or value < end


def _circular_distance(left: float, right: float) -> float:
    difference = abs(left - right) % 360
    return min(difference, 360 - difference)


def _antiscia(longitude_deg: float) -> float:
    return (180 - longitude_deg) % 360


def _contra_antiscia(longitude_deg: float) -> float:
    return (360 - longitude_deg) % 360


def calculate_special_degrees(
    points: Iterable[Mapping[str, Any]],
    *,
    profile: SpecialDegreeProfile = DEFAULT_SPECIAL_DEGREE_PROFILE,
) -> SpecialDegreeResult:
    """Classify point longitudes without adding interpretive meaning."""

    inputs = _extract_points(points)
    facts: list[SpecialDegreePointFact] = []
    for point in inputs:
        sign_id, degree = _sign_and_degree(point.longitude_deg)
        decan_index = min(int(degree // profile.decan_size_deg), 2) + 1
        decan_start = (decan_index - 1) * profile.decan_size_deg
        facts.append(
            SpecialDegreePointFact(
                point_id=point.point_id,
                longitude_deg=point.longitude_deg,
                sign_id=sign_id,
                degree_in_sign=degree,
                decan_index=decan_index,
                decan_start_deg=decan_start,
                decan_end_deg=decan_start + profile.decan_size_deg,
                in_via_combusta=_in_circular_half_open_interval(
                    point.longitude_deg,
                    profile.via_combusta_start_longitude_deg,
                    profile.via_combusta_end_longitude_deg,
                ),
                in_terminal_degree_29=(
                    profile.terminal_degree_start_deg <= degree < 30
                ),
                critical_degree_match=None,
                rule_ids=profile.rule_ids,
            )
        )

    critical = CriticalDegreeEvaluation(
        status=RuleEvaluationStatus.NOT_EVALUATED,
        table_id=None,
        reason_code="NO_VERSIONED_CRITICAL_DEGREE_TABLE_SELECTED",
        rule_ids=(),
        source_ids=(),
    )
    return SpecialDegreeResult(
        points=tuple(facts),
        critical_degrees=critical,
        provenance=SpecialDegreeProvenance(
            algorithm_card_id=ALGORITHM_SPECIAL_DEGREES,
            capability_id=CAPABILITY_SPECIAL_DEGREES,
            implementation_version="1.0.0",
            profile_id=profile.profile_id,
            profile_version=profile.version,
            profile_content_hash=profile.content_hash,
            rules=(RULE_DECAN_INDEX_V1, RULE_VIA_COMBUSTA_V1, RULE_TERMINAL_29_V1),
            source_ids=profile.source_ids,
            supplied_point_ids=tuple(point.point_id for point in inputs),
            evaluated_point_count=len(inputs),
            excluded_capabilities=("critical_degree_table",),
            interpretation_boundary=(
                "Degree intervals and partition indexes only; no outcome, strength, "
                "personality, or event claim is assigned"
            ),
        ),
    )


def calculate_mirror_points(
    points: Iterable[Mapping[str, Any]],
    *,
    profile: MirrorProfile = DEFAULT_MIRROR_PROFILE,
) -> MirrorResult:
    """Generate classical mirror longitudes and within-orb pair contacts."""

    inputs = _extract_points(points)
    mirror_points: list[MirrorPointFact] = []
    for point in inputs:
        antiscia = _antiscia(point.longitude_deg)
        contra = _contra_antiscia(point.longitude_deg)
        antiscia_sign, antiscia_degree = _sign_and_degree(antiscia)
        contra_sign, contra_degree = _sign_and_degree(contra)
        mirror_points.append(
            MirrorPointFact(
                point_id=point.point_id,
                longitude_deg=point.longitude_deg,
                antiscia_longitude_deg=antiscia,
                antiscia_sign_id=antiscia_sign,
                antiscia_degree_in_sign=antiscia_degree,
                contra_antiscia_longitude_deg=contra,
                contra_antiscia_sign_id=contra_sign,
                contra_antiscia_degree_in_sign=contra_degree,
                rule_ids=profile.rule_ids,
            )
        )

    contacts: list[MirrorContactFact] = []
    for left, right in combinations(inputs, 2):
        definitions = (
            (
                MirrorContactType.ANTISCIA,
                _antiscia,
                RULE_ANTISCIA_V1.rule_id,
            ),
            (
                MirrorContactType.CONTRA_ANTISCIA,
                _contra_antiscia,
                RULE_CONTRA_ANTISCIA_V1.rule_id,
            ),
        )
        for contact_type, transform, rule_id in definitions:
            left_mirror = transform(left.longitude_deg)
            right_mirror = transform(right.longitude_deg)
            error = _circular_distance(left.longitude_deg, right_mirror)
            if error > profile.contact_orb_deg:
                continue
            remaining = (
                1.0
                if profile.contact_orb_deg == 0 and math.isclose(error, 0.0, abs_tol=1e-12)
                else max(0.0, 1 - error / profile.contact_orb_deg)
            )
            contacts.append(
                MirrorContactFact(
                    contact_id=(
                        f"mirror:{contact_type.value}:{left.point_id}:{right.point_id}"
                    ),
                    contact_type=contact_type,
                    point_a=left.point_id,
                    point_b=right.point_id,
                    point_a_longitude_deg=left.longitude_deg,
                    point_b_longitude_deg=right.longitude_deg,
                    point_a_mirror_longitude_deg=left_mirror,
                    point_b_mirror_longitude_deg=right_mirror,
                    separation_from_exact_deg=error,
                    orb_deg=profile.contact_orb_deg,
                    orb_fraction_remaining=remaining,
                    rule_id=rule_id,
                )
            )

    contacts.sort(key=lambda item: (item.contact_type.value, item.point_a, item.point_b))
    pair_count = len(inputs) * (len(inputs) - 1) // 2
    return MirrorResult(
        mirror_points=tuple(mirror_points),
        contacts=tuple(contacts),
        provenance=MirrorProvenance(
            algorithm_card_id=ALGORITHM_MIRROR_POINTS,
            capability_id=CAPABILITY_MIRROR_POINTS,
            implementation_version="1.0.0",
            profile_id=profile.profile_id,
            profile_version=profile.version,
            profile_content_hash=profile.content_hash,
            rules=(RULE_ANTISCIA_V1, RULE_CONTRA_ANTISCIA_V1),
            source_ids=profile.source_ids,
            supplied_point_ids=tuple(point.point_id for point in inputs),
            evaluated_pair_count=pair_count,
            matched_contact_count=len(contacts),
            interpretation_boundary=(
                "Mirror coordinates and within-orb geometry only; contacts do not "
                "imply compatibility, benefit, harm, or event outcomes"
            ),
        ),
    )


def calculate_natal_special_facts(
    points: Iterable[Mapping[str, Any]],
    *,
    special_degree_profile: SpecialDegreeProfile = DEFAULT_SPECIAL_DEGREE_PROFILE,
    mirror_contact_profile: MirrorProfile = DEFAULT_MIRROR_PROFILE,
) -> NatalSpecialFactsReport:
    """Return the integration-ready, serializable natal special-facts report."""

    materialized = tuple(points)
    return NatalSpecialFactsReport(
        special_degrees=calculate_special_degrees(
            materialized,
            profile=special_degree_profile,
        ),
        mirrors=calculate_mirror_points(
            materialized,
            profile=mirror_contact_profile,
        ),
    )


__all__ = [
    "ALGORITHM_MIRROR_POINTS",
    "ALGORITHM_SPECIAL_DEGREES",
    "CAPABILITY_MIRROR_POINTS",
    "CAPABILITY_SPECIAL_DEGREES",
    "DEFAULT_MIRROR_PROFILE",
    "DEFAULT_SPECIAL_DEGREE_PROFILE",
    "RULE_ANTISCIA_V1",
    "RULE_CONTRA_ANTISCIA_V1",
    "RULE_DECAN_INDEX_V1",
    "RULE_TERMINAL_29_V1",
    "RULE_VIA_COMBUSTA_V1",
    "CriticalDegreeEvaluation",
    "MirrorContactFact",
    "MirrorContactType",
    "MirrorPointFact",
    "MirrorProfile",
    "MirrorProvenance",
    "MirrorResult",
    "NatalSpecialFactsReport",
    "RuleEvaluationStatus",
    "SpecialDegreePointFact",
    "SpecialDegreeProfile",
    "SpecialDegreeProvenance",
    "SpecialDegreeResult",
    "VersionedRule",
    "calculate_mirror_points",
    "calculate_natal_special_facts",
    "calculate_special_degrees",
    "mirror_profile",
]
