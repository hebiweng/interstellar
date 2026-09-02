"""Deterministic direct/indirect midpoint facts and midpoint-aspect hits."""

from __future__ import annotations

import math
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import asdict, dataclass
from typing import Any

from interstellar_core.astrology.aspects import MajorAspectProfile

ALGORITHM_MIDPOINTS = "ALG-NATAL-MIDPOINTS-001"
RULE_MIDPOINT_SHORTEST_ARC = "natal.midpoint.shortest_arc.direct_indirect.v1"
RULE_MIDPOINT_ASPECT_HIT = "natal.midpoint.aspect_hit.v1"


@dataclass(frozen=True, slots=True)
class MidpointFact:
    midpoint_id: str
    point_a: str
    point_b: str
    point_a_longitude_deg: float
    point_b_longitude_deg: float
    direct_midpoint_deg: float
    indirect_midpoint_deg: float
    ambiguous: bool
    rule_id: str = RULE_MIDPOINT_SHORTEST_ARC


@dataclass(frozen=True, slots=True)
class MidpointAspectHit:
    hit_id: str
    midpoint_id: str
    midpoint_type: str
    target_point_id: str
    aspect_id: str
    exact_angle_deg: float
    actual_angle_deg: float
    orb_deg: float
    orb_allowance_deg: float
    rule_id: str = RULE_MIDPOINT_ASPECT_HIT


@dataclass(frozen=True, slots=True)
class MidpointResult:
    midpoints: tuple[MidpointFact, ...]
    hits: tuple[MidpointAspectHit, ...]
    provenance: Mapping[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return {
            "midpoints": [asdict(item) for item in self.midpoints],
            "hits": [asdict(item) for item in self.hits],
            "provenance": dict(self.provenance),
        }


def _longitude(point: Mapping[str, Any]) -> float:
    position = point.get("position")
    ecliptic = position.get("ecliptic") if isinstance(position, Mapping) else None
    if not isinstance(ecliptic, Mapping):
        raise ValueError("midpoint point requires an ecliptic position")
    value = float(ecliptic["longitude_deg"])
    if not math.isfinite(value):
        raise ValueError("midpoint longitude must be finite")
    return value % 360


def direct_indirect_midpoint(
    longitude_a_deg: float,
    longitude_b_deg: float,
) -> tuple[float, float, bool]:
    """Return the shortest-arc midpoint, its opposite, and antipodal ambiguity."""

    left = float(longitude_a_deg) % 360
    right = float(longitude_b_deg) % 360
    if not math.isfinite(left) or not math.isfinite(right):
        raise ValueError("midpoint longitudes must be finite")
    delta = (right - left + 540) % 360 - 180
    ambiguous = math.isclose(abs(delta), 180, abs_tol=1e-12)
    direct = (left + delta / 2) % 360
    return direct, (direct + 180) % 360, ambiguous


def calculate_midpoints(
    points: Iterable[Mapping[str, Any]],
    *,
    source_point_ids: Sequence[str],
    aspect_profile: MajorAspectProfile,
    hit_orb_deg: float = 1.0,
) -> MidpointResult:
    """Calculate pair midpoints and selected-point contacts without interpretation."""

    allowance = float(hit_orb_deg)
    if not math.isfinite(allowance) or not 0 <= allowance <= 30:
        raise ValueError("midpoint hit orb must be in [0, 30]")
    point_rows = tuple(points)
    point_by_id = {str(point["point_id"]): point for point in point_rows}
    selected_ids = tuple(dict.fromkeys(str(item) for item in source_point_ids))
    available_ids = tuple(point_id for point_id in selected_ids if point_id in point_by_id)
    midpoints: list[MidpointFact] = []
    for left_index, point_a in enumerate(available_ids):
        for point_b in available_ids[left_index + 1 :]:
            longitude_a = _longitude(point_by_id[point_a])
            longitude_b = _longitude(point_by_id[point_b])
            direct, indirect, ambiguous = direct_indirect_midpoint(longitude_a, longitude_b)
            midpoints.append(
                MidpointFact(
                    midpoint_id=f"midpoint:{point_a}:{point_b}",
                    point_a=point_a,
                    point_b=point_b,
                    point_a_longitude_deg=longitude_a,
                    point_b_longitude_deg=longitude_b,
                    direct_midpoint_deg=direct,
                    indirect_midpoint_deg=indirect,
                    ambiguous=ambiguous,
                )
            )

    hits: list[MidpointAspectHit] = []
    for midpoint in midpoints:
        for midpoint_type, midpoint_longitude in (
            ("direct", midpoint.direct_midpoint_deg),
            ("indirect", midpoint.indirect_midpoint_deg),
        ):
            for target_id, target in point_by_id.items():
                if target_id in {midpoint.point_a, midpoint.point_b}:
                    continue
                separation = abs((midpoint_longitude - _longitude(target) + 180) % 360 - 180)
                for aspect in aspect_profile.aspects:
                    error = abs(separation - aspect.exact_angle_deg)
                    if error > allowance:
                        continue
                    hits.append(
                        MidpointAspectHit(
                            hit_id=(
                                f"{midpoint.midpoint_id}:{midpoint_type}:"
                                f"{target_id}:{aspect.id}"
                            ),
                            midpoint_id=midpoint.midpoint_id,
                            midpoint_type=midpoint_type,
                            target_point_id=target_id,
                            aspect_id=aspect.id,
                            exact_angle_deg=aspect.exact_angle_deg,
                            actual_angle_deg=separation,
                            orb_deg=error,
                            orb_allowance_deg=allowance,
                        )
                    )
    hits.sort(
        key=lambda item: (
            item.orb_deg,
            item.midpoint_id,
            item.target_point_id,
            item.aspect_id,
        )
    )
    return MidpointResult(
        midpoints=tuple(midpoints),
        hits=tuple(hits),
        provenance={
            "algorithm_card_id": ALGORITHM_MIDPOINTS,
            "capability_id": "natal.midpoints",
            "implementation_version": "1.0.0",
            "source_point_ids": list(available_ids),
            "aspect_profile_id": aspect_profile.id,
            "hit_orb_deg": allowance,
            "rule_ids": [RULE_MIDPOINT_SHORTEST_ARC, RULE_MIDPOINT_ASPECT_HIT],
            "interpretation_boundary": (
                "Geometric midpoint coordinates and within-orb contacts only; no event or "
                "personality claim is inferred"
            ),
        },
    )


__all__ = [
    "ALGORITHM_MIDPOINTS",
    "RULE_MIDPOINT_ASPECT_HIT",
    "RULE_MIDPOINT_SHORTEST_ARC",
    "MidpointAspectHit",
    "MidpointFact",
    "MidpointResult",
    "calculate_midpoints",
    "direct_indirect_midpoint",
]
