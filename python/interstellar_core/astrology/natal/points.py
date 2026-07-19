"""Canonical records for chart-dependent natal points.

Physical ephemeris objects are calculated by the astronomy adapter.  This
module owns mathematical points such as axes and opposite nodes so their
formula, null-distance semantics and motion applicability remain explicit.
"""

from __future__ import annotations

import math
from collections.abc import Mapping, Sequence
from copy import deepcopy
from typing import Any

from interstellar_core.astronomy.adapters import (
    CORE_POINT_IDS,
    PROFESSIONAL_DIRECT_POINT_IDS,
)

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

ANGLE_POINT_IDS: tuple[str, ...] = (
    "asc",
    "dsc",
    "mc",
    "ic",
    "vertex",
    "anti_vertex",
    "east_point",
    "west_point",
)
OPPOSITE_NODE_IDS: tuple[str, ...] = (
    "true_south_node",
    "mean_south_node",
)
DEFAULT_LOT_IDS: tuple[str, ...] = (
    "fortune",
    "spirit",
    "lot_basis",
    "lot_eros",
    "lot_necessity",
    "lot_courage",
    "lot_victory",
    "lot_nemesis",
    "lot_exaltation",
)
PROFESSIONAL_DERIVED_POINT_IDS: tuple[str, ...] = (
    *ANGLE_POINT_IDS,
    *OPPOSITE_NODE_IDS,
    *DEFAULT_LOT_IDS,
)
PROFESSIONAL_POINT_IDS: tuple[str, ...] = (
    *PROFESSIONAL_DIRECT_POINT_IDS,
    *ANGLE_POINT_IDS,
    *OPPOSITE_NODE_IDS,
    *DEFAULT_LOT_IDS,
)


def ecliptic_to_equatorial(
    longitude_deg: float,
    latitude_deg: float,
    obliquity_deg: float,
) -> tuple[float, float]:
    """Convert ecliptic-of-date angles to equatorial-of-date angles."""

    longitude = math.radians(float(longitude_deg) % 360)
    latitude = math.radians(float(latitude_deg))
    obliquity = math.radians(float(obliquity_deg))
    if not all(math.isfinite(value) for value in (longitude, latitude, obliquity)):
        raise ValueError("coordinate angles must be finite")
    right_ascension = math.atan2(
        math.sin(longitude) * math.cos(obliquity) - math.tan(latitude) * math.sin(obliquity),
        math.cos(longitude),
    )
    declination = math.asin(
        math.sin(latitude) * math.cos(obliquity)
        + math.cos(latitude) * math.sin(obliquity) * math.sin(longitude)
    )
    return math.degrees(right_ascension) % 360, math.degrees(declination)


def _calculated_point(
    *,
    point_id: str,
    kind: str,
    longitude_deg: float,
    latitude_deg: float,
    longitude_speed_deg_per_day: float | None,
    latitude_speed_deg_per_day: float | None,
    obliquity_deg: float,
    julian_day_ut: float,
    formula_ref: str,
    motion_interpretation: str,
) -> dict[str, Any]:
    longitude = float(longitude_deg) % 360
    latitude = float(latitude_deg)
    right_ascension, declination = ecliptic_to_equatorial(
        longitude,
        latitude,
        obliquity_deg,
    )
    sign_index = min(int(longitude // 30), 11)
    if longitude_speed_deg_per_day is None:
        motion_state = "not_applicable"
    elif abs(longitude_speed_deg_per_day) <= 1e-4:
        motion_state = "stationary"
    elif longitude_speed_deg_per_day < 0:
        motion_state = "retrograde"
    else:
        motion_state = "direct"
    return {
        "point_id": point_id,
        "kind": kind,
        "position": {
            "ecliptic": {
                "longitude_deg": longitude,
                "latitude_deg": latitude,
            },
            "equatorial": {
                "right_ascension_deg": right_ascension,
                "declination_deg": declination,
            },
            "distance_au": None,
            "velocity": {
                "longitude_deg_per_day": longitude_speed_deg_per_day,
                "latitude_deg_per_day": latitude_speed_deg_per_day,
                "right_ascension_deg_per_day": None,
                "declination_deg_per_day": None,
                "distance_au_per_day": None,
            },
            "motion_state": motion_state,
            "frame": "true_ecliptic_of_date",
            "center": "geocentric",
            "epoch": f"JDUT:{float(julian_day_ut):.9f}",
            "uncertainty_arcsec": None,
        },
        "sign": SIGN_IDS[sign_index],
        "degree_in_sign": longitude - sign_index * 30,
        "house": None,
        "distance_from_previous_cusp_deg": None,
        "distance_to_next_cusp_deg": None,
        "house_position_fraction": None,
        "retrograde": motion_state == "retrograde",
        "motion_interpretation": motion_interpretation,
        "out_of_bounds": abs(declination) > abs(float(obliquity_deg)),
        "solar_relation": "not_applicable",
        "solar_elongation_deg": None,
        "visibility_state": "not_applicable",
        "oriental_occidental": "not_applicable",
        "formula_ref": formula_ref,
        "catalog_object_ref": None,
        "status_refs": [f"motion.{motion_state}", f"formula.{formula_ref}"],
    }


def add_opposite_nodes(
    points: Sequence[Mapping[str, Any]],
    *,
    obliquity_deg: float,
    julian_day_ut: float,
) -> list[dict[str, Any]]:
    """Append south nodes only when their corresponding north node exists."""

    result = [deepcopy(dict(point)) for point in points]
    by_id = {str(point["point_id"]): point for point in points}
    pairs = (
        ("true_north_node", "true_south_node", "node.true.opposition.v1"),
        ("mean_north_node", "mean_south_node", "node.mean.opposition.v1"),
    )
    for north_id, south_id, formula_ref in pairs:
        north = by_id.get(north_id)
        if north is None:
            continue
        ecliptic = north["position"]["ecliptic"]
        velocity = north["position"]["velocity"]
        result.append(
            _calculated_point(
                point_id=south_id,
                kind="node",
                longitude_deg=float(ecliptic["longitude_deg"]) + 180,
                latitude_deg=-float(ecliptic["latitude_deg"]),
                longitude_speed_deg_per_day=velocity.get("longitude_deg_per_day"),
                latitude_speed_deg_per_day=(
                    -float(velocity["latitude_deg_per_day"])
                    if velocity.get("latitude_deg_per_day") is not None
                    else None
                ),
                obliquity_deg=obliquity_deg,
                julian_day_ut=julian_day_ut,
                formula_ref=formula_ref,
                motion_interpretation="meaningful",
            )
        )
    return result


def angle_points_from_house_result(
    house_result: Any,
    *,
    obliquity_deg: float,
    julian_day_ut: float,
) -> list[dict[str, Any]]:
    """Promote house axes and named sensitive points to canonical Point records."""

    if house_result.house_set is None:
        return []
    house_set = house_result.house_set
    angles = house_set["angles"]
    sensitive = house_set["sensitive_points"]
    speed_values = tuple(house_result.sensitive_point_speeds_deg_per_day)
    speed_by_key = {
        key: speed_values[index] if index < len(speed_values) else None
        for index, key in enumerate(
            (
                "asc",
                "mc",
                "armc",
                "vertex",
                "equatorial_ascendant",
                "co_ascendant_koch",
                "co_ascendant_munkasey",
                "polar_ascendant",
            )
        )
    }
    definitions = (
        ("asc", angles["asc"], speed_by_key["asc"], "angle.ascendant.swiss.v1"),
        ("dsc", angles["dsc"], speed_by_key["asc"], "angle.descendant.opposition.v1"),
        ("mc", angles["mc"], speed_by_key["mc"], "angle.midheaven.swiss.v1"),
        ("ic", angles["ic"], speed_by_key["mc"], "angle.imum_coeli.opposition.v1"),
        (
            "vertex",
            sensitive["vertex"],
            speed_by_key["vertex"],
            "angle.vertex.swiss.v1",
        ),
        (
            "anti_vertex",
            (float(sensitive["vertex"]) + 180) % 360,
            speed_by_key["vertex"],
            "angle.anti_vertex.opposition.v1",
        ),
        (
            "east_point",
            sensitive["equatorial_ascendant"],
            speed_by_key["equatorial_ascendant"],
            "angle.east_point.swiss.v1",
        ),
        (
            "west_point",
            (float(sensitive["equatorial_ascendant"]) + 180) % 360,
            speed_by_key["equatorial_ascendant"],
            "angle.west_point.opposition.v1",
        ),
    )
    return [
        _calculated_point(
            point_id=point_id,
            kind="angle",
            longitude_deg=float(longitude),
            latitude_deg=0,
            # Axis speeds are retained as astronomical metadata, but natal
            # retrograde/applying interpretation is explicitly not applicable.
            longitude_speed_deg_per_day=(
                float(speed) if speed is not None and math.isfinite(float(speed)) else None
            ),
            latitude_speed_deg_per_day=0,
            obliquity_deg=obliquity_deg,
            julian_day_ut=julian_day_ut,
            formula_ref=formula_ref,
            motion_interpretation="not_applicable",
        )
        for point_id, longitude, speed, formula_ref in definitions
    ]


def core_point_ids() -> tuple[str, ...]:
    """Return the stable legacy ten-point profile."""

    return CORE_POINT_IDS


def lot_point_from_fact(
    lot_fact: Any,
    *,
    obliquity_deg: float,
    julian_day_ut: float,
) -> dict[str, Any]:
    """Promote a versioned classical Lot fact to a canonical chart Point."""

    raw = lot_fact.to_dict() if hasattr(lot_fact, "to_dict") else dict(lot_fact)
    return _calculated_point(
        point_id=str(raw["lot_id"]),
        kind="lot",
        longitude_deg=float(raw["longitude_deg"]),
        latitude_deg=0,
        longitude_speed_deg_per_day=None,
        latitude_speed_deg_per_day=None,
        obliquity_deg=obliquity_deg,
        julian_day_ut=julian_day_ut,
        formula_ref=str(raw["formula_id"]),
        motion_interpretation="not_applicable",
    )
