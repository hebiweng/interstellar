"""Reusable cross-chart comparison facts for transit and progression techniques."""

from __future__ import annotations

import hashlib
from collections.abc import Mapping
from typing import Any

from interstellar_core.astrology.aspects import (
    AspectContext,
    AspectPoint,
    find_major_aspects,
)
from interstellar_core.astrology.houses import assign_longitude_to_house

from .astronomical_snapshot import (
    AstronomicalSnapshotInputError,
    resolve_aspect_profiles,
)


def _record(value: object, *, name: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise AstronomicalSnapshotInputError(f"{name} must be an object")
    return value


def _points(snapshot: Mapping[str, Any], *, name: str) -> tuple[Mapping[str, Any], ...]:
    result = _record(snapshot.get("result"), name=f"{name}.result")
    raw_points = result.get("points")
    if not isinstance(raw_points, list):
        raise AstronomicalSnapshotInputError(f"{name}.result.points must be an array")
    points = tuple(
        _record(point, name=f"{name}.result.points[{index}]")
        for index, point in enumerate(raw_points)
    )
    if not points:
        raise AstronomicalSnapshotInputError(f"{name} must contain at least one point")
    return points


def _longitude(point: Mapping[str, Any]) -> float:
    position = _record(point.get("position"), name="point.position")
    ecliptic = _record(position.get("ecliptic"), name="point.position.ecliptic")
    try:
        return float(ecliptic["longitude_deg"])
    except (KeyError, TypeError, ValueError) as exc:
        raise AstronomicalSnapshotInputError(
            "comparison points require finite ecliptic longitude"
        ) from exc


def _speed(point: Mapping[str, Any]) -> float | None:
    position = _record(point.get("position"), name="point.position")
    velocity = position.get("velocity")
    if not isinstance(velocity, Mapping):
        return None
    value = velocity.get("longitude_deg_per_day")
    return None if value is None else float(value)


def _comparison_id(
    context: AspectContext,
    moving_point_id: str,
    reference_point_id: str,
    aspect_type: str,
) -> str:
    readable = (
        f"aspect:{context.value}:{moving_point_id}:{reference_point_id}:{aspect_type}"
    )
    if len(readable) <= 160:
        return readable
    digest = hashlib.sha256(readable.encode("utf-8")).hexdigest()
    return f"aspect:{context.value}:{aspect_type}:sha256:{digest}"


def _natal_cusps(natal_snapshot: Mapping[str, Any]) -> tuple[float, ...]:
    result = _record(natal_snapshot.get("result"), name="natal_snapshot.result")
    houses = result.get("houses")
    if not isinstance(houses, list) or len(houses) != 12:
        raise AstronomicalSnapshotInputError(
            "cross-chart house placement requires twelve natal house cusps"
        )
    ordered = sorted(
        (_record(house, name="natal_snapshot.result.houses[]") for house in houses),
        key=lambda house: int(house["number"]),
    )
    return tuple(float(house["cusp_longitude_deg"]) for house in ordered)


def create_cross_chart_comparison(
    *,
    reference_snapshot: Mapping[str, Any],
    moving_snapshot: Mapping[str, Any],
    settings: Mapping[str, Any],
    context: AspectContext,
) -> dict[str, Any]:
    """Compare a moving chart to a fixed reference chart without recalculating either.

    Transit uses the target-time current-sky snapshot as the moving layer and the
    natal snapshot as the fixed reference. Secondary progressions can reuse the
    same function with ``AspectContext.PROGRESSION`` after their progressed
    single-chart time has been resolved.
    """

    reference_points = _points(reference_snapshot, name="reference_snapshot")
    moving_points = _points(moving_snapshot, name="moving_snapshot")
    aspect_profile, orb_profile, orb_overrides = resolve_aspect_profiles(settings)

    cross_aspects: list[dict[str, Any]] = []
    for moving in moving_points:
        moving_id = str(moving.get("point_id") or "")
        if not moving_id:
            continue
        moving_aspect_point = AspectPoint(
            id=f"moving.{moving_id}",
            longitude_deg=_longitude(moving),
            longitude_speed_deg_per_day=_speed(moving),
        )
        for reference in reference_points:
            reference_id = str(reference.get("point_id") or "")
            if not reference_id:
                continue
            reference_aspect_point = AspectPoint(
                id=f"reference.{reference_id}",
                longitude_deg=_longitude(reference),
                longitude_speed_deg_per_day=0.0,
            )
            for aspect in find_major_aspects(
                moving_aspect_point,
                reference_aspect_point,
                context=context,
                major_profile=aspect_profile,
                orb_profile=orb_profile,
                orb_overrides=orb_overrides,
            ):
                fact = aspect.to_dict()
                fact.update(
                    {
                        "aspect_id": _comparison_id(
                            context,
                            moving_id,
                            reference_id,
                            aspect.type,
                        ),
                        "moving_point_id": moving_id,
                        "reference_point_id": reference_id,
                        "point_a": moving_id,
                        "point_b": reference_id,
                    }
                )
                cross_aspects.append(fact)

    cross_aspects.sort(
        key=lambda item: (
            float(item["orb_deg"]),
            str(item["moving_point_id"]),
            str(item["reference_point_id"]),
        )
    )

    moving_house_placements: list[dict[str, Any]] = []
    if context in {AspectContext.TRANSIT, AspectContext.PROGRESSION}:
        cusps = _natal_cusps(reference_snapshot)
        for point in moving_points:
            point_id = str(point.get("point_id") or "")
            if not point_id:
                continue
            placement = assign_longitude_to_house(_longitude(point), cusps)
            moving_house_placements.append(
                {
                    "moving_point_id": point_id,
                    "reference_house": placement.house,
                    "on_cusp": placement.on_cusp,
                    "cusp_number": placement.cusp_number,
                    "rule_ref": "ALG-HOUSES-PLACEMENT-001",
                }
            )

    return {
        "context": context.value,
        "reference_snapshot_id": str(reference_snapshot.get("id") or ""),
        "moving_snapshot_id": str(moving_snapshot.get("id") or ""),
        "cross_aspects": cross_aspects,
        "moving_points_in_reference_houses": moving_house_placements,
        "provenance": {
            "aspect_profile": f"{aspect_profile.id}@{aspect_profile.version}",
            "orb_profile": f"{orb_profile.id}@{orb_profile.version}",
            "orb_override_set": f"{orb_overrides.id}@{orb_overrides.version}",
        },
    }
