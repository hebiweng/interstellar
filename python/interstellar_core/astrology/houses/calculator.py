"""Swiss house adapter plus the Interstellar Whole Sign implementation."""

from __future__ import annotations

import math
import threading
from importlib.metadata import PackageNotFoundError, version
from types import ModuleType
from typing import Any

import swisseph as swe

from interstellar_core.astrology.houses.models import (
    HouseCalculationResult,
    HouseProvenance,
    HouseSystem,
    HouseWarning,
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

SWISS_HOUSE_CODES: dict[HouseSystem, bytes] = {
    HouseSystem.PLACIDUS: b"P",
    HouseSystem.KOCH: b"K",
    HouseSystem.PORPHYRY: b"O",
    HouseSystem.REGIOMONTANUS: b"R",
    HouseSystem.CAMPANUS: b"C",
    HouseSystem.EQUAL: b"E",
    HouseSystem.ALCABITIUS: b"B",
    HouseSystem.TOPOCENTRIC: b"T",
    HouseSystem.MORINUS: b"M",
    HouseSystem.KRUSINSKI: b"U",
    HouseSystem.VEHLOW: b"V",
}

SENSITIVE_POINT_IDS: tuple[str, ...] = (
    "asc",
    "mc",
    "armc",
    "vertex",
    "equatorial_ascendant",
    "co_ascendant_koch",
    "co_ascendant_munkasey",
    "polar_ascendant",
)


class HouseCalculationError(RuntimeError):
    """House calculation input or engine failure."""


class HouseInputError(HouseCalculationError, ValueError):
    """House input is outside the explicit supported domain."""


class HouseCalculator:
    """Return canonical HouseSet data without interpretation or scoring."""

    _backend_lock = threading.RLock()

    def __init__(self, *, _backend: ModuleType = swe) -> None:
        self._backend = _backend

    def calculate(
        self,
        *,
        julian_day_ut: float,
        latitude_deg: float,
        longitude_deg: float,
        system: HouseSystem | str = HouseSystem.PLACIDUS,
        flags: int = 0,
        allow_fallback_whole_sign: bool = False,
    ) -> HouseCalculationResult:
        jd, latitude, longitude, requested = self._validate_inputs(
            julian_day_ut,
            latitude_deg,
            longitude_deg,
            system,
            flags,
        )
        if requested is HouseSystem.WHOLE_SIGN:
            return self._calculate_whole_sign(
                jd,
                latitude,
                longitude,
                flags,
                requested_system=requested,
                status="available",
                polar_status="normal",
                warnings=(),
            )

        house_code = SWISS_HOUSE_CODES[requested]
        try:
            raw = self._houses_ex2(jd, latitude, longitude, house_code, flags)
        except Exception as exc:
            if not self._is_polar_failure(exc):
                raise HouseCalculationError(
                    f"Swiss houses_ex2 failed for {requested.value}: {type(exc).__name__}: {exc}"
                ) from exc
            warning = HouseWarning(
                code="HOUSE_SYSTEM_UNAVAILABLE_AT_LATITUDE",
                message=(
                    f"{requested.value} is unavailable at latitude {latitude}; "
                    "no house system was substituted automatically."
                ),
                severity="error" if not allow_fallback_whole_sign else "warning",
                details={"latitude_deg": latitude, "engine_message": str(exc)},
            )
            if allow_fallback_whole_sign:
                return self._calculate_whole_sign(
                    jd,
                    latitude,
                    longitude,
                    flags,
                    requested_system=requested,
                    status="degraded",
                    polar_status="degraded",
                    warnings=(warning,),
                )
            return self._unavailable(
                requested=requested,
                code=house_code,
                flags=flags,
                warning=warning,
            )

        cusps_raw, ascmc_raw, cusp_speeds_raw, ascmc_speeds_raw = raw
        cusps = self._normalize_cusps(cusps_raw)
        ascmc = self._normalize_ascmc(ascmc_raw)
        house_set = self._house_set(
            requested,
            cusps,
            ascmc,
            polar_status="normal",
            warnings=(),
        )
        return HouseCalculationResult(
            status="available",
            requested_system=requested.value,
            actual_system=requested.value,
            house_set=house_set,
            cusp_speeds_deg_per_day=self._normalize_cusps(cusp_speeds_raw, normalize=False),
            sensitive_point_speeds_deg_per_day=tuple(float(value) for value in ascmc_speeds_raw),
            warnings=(),
            provenance=self._provenance(
                requested=requested,
                requested_code=house_code.decode("ascii"),
                actual=requested,
                actual_code=house_code.decode("ascii"),
                implementation="swiss_houses_ex2",
                flags=flags,
            ),
        )

    def _calculate_whole_sign(
        self,
        jd: float,
        latitude: float,
        longitude: float,
        flags: int,
        *,
        requested_system: HouseSystem,
        status: str,
        polar_status: str,
        warnings: tuple[HouseWarning, ...],
    ) -> HouseCalculationResult:
        # Swiss supplies only the astronomical axes; Interstellar derives all 12 cusps.
        _, ascmc_raw, _, ascmc_speeds_raw = self._houses_ex2(
            jd,
            latitude,
            longitude,
            b"W",
            flags,
        )
        ascmc = self._normalize_ascmc(ascmc_raw)
        cusps = whole_sign_cusps(ascmc[0])
        house_set = self._house_set(
            HouseSystem.WHOLE_SIGN,
            cusps,
            ascmc,
            polar_status=polar_status,
            warnings=warnings,
        )
        return HouseCalculationResult(
            status=status,  # type: ignore[arg-type]
            requested_system=requested_system.value,
            actual_system=HouseSystem.WHOLE_SIGN.value,
            house_set=house_set,
            cusp_speeds_deg_per_day=tuple(0.0 for _ in range(12)),
            sensitive_point_speeds_deg_per_day=tuple(float(value) for value in ascmc_speeds_raw),
            warnings=warnings,
            provenance=self._provenance(
                requested=requested_system,
                requested_code=(
                    "W"
                    if requested_system is HouseSystem.WHOLE_SIGN
                    else SWISS_HOUSE_CODES[requested_system].decode("ascii")
                ),
                actual=HouseSystem.WHOLE_SIGN,
                actual_code="self:whole_sign",
                implementation="interstellar_whole_sign",
                flags=flags,
            ),
        )

    def _unavailable(
        self,
        *,
        requested: HouseSystem,
        code: bytes,
        flags: int,
        warning: HouseWarning,
    ) -> HouseCalculationResult:
        return HouseCalculationResult(
            status="unavailable",
            requested_system=requested.value,
            actual_system=None,
            house_set=None,
            cusp_speeds_deg_per_day=(),
            sensitive_point_speeds_deg_per_day=(),
            warnings=(warning,),
            provenance=self._provenance(
                requested=requested,
                requested_code=code.decode("ascii"),
                actual=None,
                actual_code=None,
                implementation="unavailable",
                flags=flags,
            ),
        )

    def _houses_ex2(
        self,
        jd: float,
        latitude: float,
        longitude: float,
        code: bytes,
        flags: int,
    ) -> tuple[Any, Any, Any, Any]:
        with self._backend_lock:
            result = self._backend.houses_ex2(jd, latitude, longitude, code, flags)
        if not isinstance(result, tuple) or len(result) != 4:
            raise HouseCalculationError("Swiss houses_ex2 returned an unsupported payload")
        return result

    def _validate_inputs(
        self,
        julian_day_ut: float,
        latitude_deg: float,
        longitude_deg: float,
        system: HouseSystem | str,
        flags: int,
    ) -> tuple[float, float, float, HouseSystem]:
        values = (float(julian_day_ut), float(latitude_deg), float(longitude_deg))
        if not all(math.isfinite(value) for value in values):
            raise HouseInputError("Julian day, latitude, and longitude must be finite")
        jd, latitude, longitude = values
        if not -90 <= latitude <= 90:
            raise HouseInputError("latitude_deg must be between -90 and 90")
        if not -180 <= longitude < 180:
            raise HouseInputError("longitude_deg must be in [-180, 180)")
        if not isinstance(flags, int) or flags < 0:
            raise HouseInputError("flags must be a non-negative integer")
        try:
            requested = system if isinstance(system, HouseSystem) else HouseSystem(system)
        except ValueError as exc:
            raise HouseInputError(f"unsupported house system: {system}") from exc
        return jd, latitude, longitude, requested

    def _normalize_cusps(
        self,
        raw: Any,
        *,
        normalize: bool = True,
    ) -> tuple[float, ...]:
        if not isinstance(raw, (tuple, list)) or len(raw) != 13:
            raise HouseCalculationError("Swiss houses_ex2 must return 13 cusp slots")
        values = tuple(float(value) for value in raw[1:13])
        if not all(math.isfinite(value) for value in values):
            raise HouseCalculationError("Swiss houses_ex2 returned non-finite cusps")
        return tuple(value % 360 for value in values) if normalize else values

    def _normalize_ascmc(self, raw: Any) -> tuple[float, ...]:
        if not isinstance(raw, (tuple, list)) or len(raw) != 8:
            raise HouseCalculationError("Swiss houses_ex2 must return eight sensitive points")
        values = tuple(float(value) for value in raw)
        if not all(math.isfinite(value) for value in values):
            raise HouseCalculationError("Swiss houses_ex2 returned non-finite sensitive points")
        return tuple(value % 360 for value in values)

    def _house_set(
        self,
        system: HouseSystem,
        cusps: tuple[float, ...],
        ascmc: tuple[float, ...],
        *,
        polar_status: str,
        warnings: tuple[HouseWarning, ...],
    ) -> dict[str, Any]:
        houses = []
        for index, cusp in enumerate(cusps):
            sign_index = min(int(cusp // 30), 11)
            houses.append(
                {
                    "number": index + 1,
                    "cusp_longitude_deg": cusp,
                    "sign": SIGN_IDS[sign_index],
                    "degree_in_sign": cusp - sign_index * 30,
                    "ruler_ids": [],
                    "point_ids": [],
                    "intercepted_signs": [],
                }
            )
        asc, mc = ascmc[0], ascmc[1]
        return {
            "system": system.value,
            "houses": houses,
            "angles": {
                "asc": asc,
                "dsc": (asc + 180) % 360,
                "mc": mc,
                "ic": (mc + 180) % 360,
            },
            "sensitive_points": {
                point_id: ascmc[index] for index, point_id in enumerate(SENSITIVE_POINT_IDS)
            },
            "polar_status": polar_status,
            "warnings": [warning.to_canonical() for warning in warnings],
        }

    def _is_polar_failure(self, error: Exception) -> bool:
        message = str(error).lower()
        return "polar" in message or "circumpolar" in message

    def _provenance(
        self,
        *,
        requested: HouseSystem,
        requested_code: str,
        actual: HouseSystem | None,
        actual_code: str | None,
        implementation: str,
        flags: int,
    ) -> HouseProvenance:
        try:
            binding_version = version("pysweph")
        except PackageNotFoundError as exc:
            raise HouseCalculationError("pysweph package metadata is unavailable") from exc
        library_path = None
        getter = getattr(self._backend, "get_library_path", None)
        if getter is not None:
            try:
                library_path = str(getter())
            except Exception:
                library_path = None
        return HouseProvenance(
            maturity="experimental",
            algorithm_card="ALG-ASTRONOMY-003",
            engine_name="swiss_ephemeris",
            swiss_c_library_version=str(getattr(self._backend, "version", "unknown")),
            adapter_name="pysweph",
            binding_version=binding_version,
            binding_library_path=library_path,
            requested_system=requested.value,
            requested_house_code=requested_code,
            actual_system=actual.value if actual else None,
            actual_house_code=actual_code,
            implementation=implementation,  # type: ignore[arg-type]
            flags=flags,
        )


def whole_sign_cusps(ascendant_longitude_deg: float) -> tuple[float, ...]:
    """Derive 12 tropical Whole Sign cusps from the Ascendant's sign."""

    ascendant = float(ascendant_longitude_deg)
    if not math.isfinite(ascendant):
        raise HouseInputError("ascendant longitude must be finite")
    ascendant %= 360
    first_cusp = math.floor(ascendant / 30) * 30
    return tuple((first_cusp + index * 30) % 360 for index in range(12))
