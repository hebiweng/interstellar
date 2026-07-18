"""Canonical house result values."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import StrEnum
from typing import Any, Literal


class HouseSystem(StrEnum):
    PLACIDUS = "placidus"
    WHOLE_SIGN = "whole_sign"
    KOCH = "koch"
    PORPHYRY = "porphyry"
    REGIOMONTANUS = "regiomontanus"
    CAMPANUS = "campanus"
    EQUAL = "equal"
    ALCABITIUS = "alcabitius"
    TOPOCENTRIC = "topocentric"
    MORINUS = "morinus"
    KRUSINSKI = "krusinski"
    VEHLOW = "vehlow"


@dataclass(frozen=True, slots=True)
class HouseWarning:
    code: str
    message: str
    severity: Literal["info", "warning", "error"] = "warning"
    details: dict[str, Any] | None = None

    def to_canonical(self) -> dict[str, Any]:
        payload = asdict(self)
        if self.details is None:
            payload.pop("details")
        return payload


@dataclass(frozen=True, slots=True)
class HouseProvenance:
    maturity: Literal["experimental"]
    algorithm_card: Literal["ALG-ASTRONOMY-003"]
    engine_name: Literal["swiss_ephemeris"]
    swiss_c_library_version: str
    adapter_name: Literal["pysweph"]
    binding_version: str
    binding_library_path: str | None
    requested_system: str
    requested_house_code: str
    actual_system: str | None
    actual_house_code: str | None
    implementation: Literal["swiss_houses_ex2", "interstellar_whole_sign", "unavailable"]
    flags: int


@dataclass(frozen=True, slots=True)
class HouseCalculationResult:
    status: Literal["available", "degraded", "unavailable"]
    requested_system: str
    actual_system: str | None
    house_set: dict[str, Any] | None
    cusp_speeds_deg_per_day: tuple[float, ...]
    sensitive_point_speeds_deg_per_day: tuple[float, ...]
    warnings: tuple[HouseWarning, ...]
    provenance: HouseProvenance

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": self.status,
            "requested_system": self.requested_system,
            "actual_system": self.actual_system,
            "house_set": self.house_set,
            "cusp_speeds_deg_per_day": list(self.cusp_speeds_deg_per_day),
            "sensitive_point_speeds_deg_per_day": list(self.sensitive_point_speeds_deg_per_day),
            "warnings": [warning.to_canonical() for warning in self.warnings],
            "provenance": asdict(self.provenance),
        }


@dataclass(frozen=True, slots=True)
class HousePlacement:
    house: int
    on_cusp: bool
    cusp_number: int | None
    tolerance_deg: float


@dataclass(frozen=True, slots=True)
class DerivedHouseResult:
    starting_house: int
    relative_house: int
    absolute_house: int
