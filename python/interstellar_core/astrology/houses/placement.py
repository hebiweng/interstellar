"""Circular house placement with an explicit cusp convention."""

from __future__ import annotations

import math
from collections.abc import Iterable, Mapping

from interstellar_core.astrology.houses.models import HousePlacement

DEFAULT_CUSP_TOLERANCE_DEG = 1e-9


def circular_distance_deg(left: float, right: float) -> float:
    difference = abs((left - right) % 360)
    return min(difference, 360 - difference)


def assign_longitude_to_house(
    longitude_deg: float,
    cusps: Iterable[float],
    *,
    tolerance_deg: float = DEFAULT_CUSP_TOLERANCE_DEG,
) -> HousePlacement:
    """Assign longitude to `[cusp_n, cusp_n+1)`; a cusp belongs to its new house."""

    longitude = float(longitude_deg)
    cusp_values = tuple(float(cusp) % 360 for cusp in cusps)
    if not math.isfinite(longitude) or not all(math.isfinite(cusp) for cusp in cusp_values):
        raise ValueError("longitude and cusps must be finite")
    if len(cusp_values) != 12:
        raise ValueError("exactly 12 cusps are required")
    if not math.isfinite(tolerance_deg) or not 0 <= tolerance_deg < 1:
        raise ValueError("tolerance_deg must be finite and in [0, 1)")
    longitude %= 360

    for index, cusp in enumerate(cusp_values):
        if circular_distance_deg(longitude, cusp) <= tolerance_deg:
            return HousePlacement(
                house=index + 1,
                on_cusp=True,
                cusp_number=index + 1,
                tolerance_deg=tolerance_deg,
            )

    for index, start in enumerate(cusp_values):
        end = cusp_values[(index + 1) % 12]
        span = (end - start) % 360
        if span == 0:
            continue
        offset = (longitude - start) % 360
        if 0 < offset < span:
            return HousePlacement(
                house=index + 1,
                on_cusp=False,
                cusp_number=None,
                tolerance_deg=tolerance_deg,
            )
    raise ValueError("cusps do not form a complete non-overlapping zodiac partition")


def assign_points_to_houses(
    longitudes_deg: Mapping[str, float],
    cusps: Iterable[float],
    *,
    tolerance_deg: float = DEFAULT_CUSP_TOLERANCE_DEG,
) -> dict[str, HousePlacement]:
    cusp_values = tuple(cusps)
    return {
        point_id: assign_longitude_to_house(
            longitude,
            cusp_values,
            tolerance_deg=tolerance_deg,
        )
        for point_id, longitude in longitudes_deg.items()
    }
