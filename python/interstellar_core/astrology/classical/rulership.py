"""Traditional and modern sign/house rulership assignments."""

from __future__ import annotations

from collections.abc import Iterable

from interstellar_core.astrology.classical.models import HouseRulerAssignment
from interstellar_core.astrology.classical.sources import (
    RULE_MODERN_RULERSHIP_V1,
    RULE_TRADITIONAL_RULERSHIP_V1,
)
from interstellar_core.astrology.classical.tables import (
    MODERN_RULERS_BY_SIGN,
    MODERN_RULERSHIP_TABLE_REF,
    TRADITIONAL_RULERS_BY_SIGN,
    TRADITIONAL_RULERSHIP_TABLE_REF,
    sign_and_degree,
)
from interstellar_core.domain import DomainError


def traditional_rulers(sign_id: str) -> tuple[str, ...]:
    try:
        return TRADITIONAL_RULERS_BY_SIGN[sign_id]
    except KeyError as exc:
        raise DomainError("CLASSICAL_SIGN_UNKNOWN", f"unknown sign id: {sign_id}") from exc


def modern_rulers(sign_id: str) -> tuple[str, ...]:
    try:
        return MODERN_RULERS_BY_SIGN[sign_id]
    except KeyError as exc:
        raise DomainError("CLASSICAL_SIGN_UNKNOWN", f"unknown sign id: {sign_id}") from exc


def assign_house_rulers(cusp_longitudes_deg: Iterable[float]) -> tuple[HouseRulerAssignment, ...]:
    cusps = tuple(cusp_longitudes_deg)
    if len(cusps) != 12:
        raise DomainError("CLASSICAL_HOUSE_COUNT_INVALID", "exactly 12 house cusps are required")
    result = []
    for index, longitude in enumerate(cusps):
        sign_id, _ = sign_and_degree(longitude)
        result.append(
            HouseRulerAssignment(
                house_number=index + 1,
                cusp_longitude_deg=longitude,
                sign_id=sign_id,
                traditional_ruler_ids=traditional_rulers(sign_id),
                modern_ruler_ids=modern_rulers(sign_id),
                traditional_table_ref=TRADITIONAL_RULERSHIP_TABLE_REF,
                modern_table_ref=MODERN_RULERSHIP_TABLE_REF,
                rule_ids=(RULE_TRADITIONAL_RULERSHIP_V1, RULE_MODERN_RULERSHIP_V1),
            )
        )
    return tuple(result)
