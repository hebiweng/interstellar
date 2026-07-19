"""Experimental Swiss Ephemeris adapter for geocentric apparent positions.

This module computes astronomy facts only. It does not assign houses, calculate aspects,
or perform astrological interpretation. Swiss Ephemeris may fall back to the built-in
Moshier ephemeris when external Swiss files are unavailable; that transition is always
recorded and can be configured as an error.
"""

from __future__ import annotations

import math
import threading
from collections.abc import Iterable
from dataclasses import asdict, dataclass
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path
from types import ModuleType
from typing import Any, Literal

import swisseph as swe

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


@dataclass(frozen=True, slots=True)
class BodyDefinition:
    point_id: str
    swiss_id: int
    kind: Literal[
        "luminary",
        "planet",
        "dwarf_planet",
        "asteroid",
        "centaur",
        "node",
        "lunar_point",
        "hypothetical",
    ]
    catalog_object_ref: str | None = None
    formula_ref: str = "ephemeris.swiss.geocentric_apparent.v1"


BODY_DEFINITIONS: tuple[BodyDefinition, ...] = (
    BodyDefinition("sun", swe.SUN, "luminary"),
    BodyDefinition("moon", swe.MOON, "luminary"),
    BodyDefinition("mercury", swe.MERCURY, "planet"),
    BodyDefinition("venus", swe.VENUS, "planet"),
    BodyDefinition("mars", swe.MARS, "planet"),
    BodyDefinition("jupiter", swe.JUPITER, "planet"),
    BodyDefinition("saturn", swe.SATURN, "planet"),
    BodyDefinition("uranus", swe.URANUS, "planet"),
    BodyDefinition("neptune", swe.NEPTUNE, "planet"),
    BodyDefinition("pluto", swe.PLUTO, "dwarf_planet"),
)

# Directly calculable Swiss objects. Opposite nodes and all chart-dependent
# points remain explicit derived facts in the chart pipeline.
EXTENDED_BODY_DEFINITIONS: tuple[BodyDefinition, ...] = (
    BodyDefinition("true_north_node", swe.TRUE_NODE, "node"),
    BodyDefinition("mean_north_node", swe.MEAN_NODE, "node"),
    BodyDefinition("mean_lilith", swe.MEAN_APOG, "lunar_point"),
    BodyDefinition("true_lilith", swe.OSCU_APOG, "lunar_point"),
    BodyDefinition("lunar_perigee", swe.INTP_PERG, "lunar_point"),
    BodyDefinition("chiron", swe.CHIRON, "centaur", "mpc:2060"),
    BodyDefinition("ceres", swe.CERES, "asteroid", "mpc:1"),
    BodyDefinition("pallas", swe.PALLAS, "asteroid", "mpc:2"),
    BodyDefinition("juno", swe.JUNO, "asteroid", "mpc:3"),
    BodyDefinition("vesta", swe.VESTA, "asteroid", "mpc:4"),
)

# Hamburg/Trans-Neptunian points use Swiss Ephemeris' published built-in
# hypothetical orbital elements (h40-h47). They are not physical objects and
# therefore remain explicitly typed and marked experimental in the natal point
# registry.  They are nevertheless deterministic Swiss calculations and do not
# require asteroid ephemeris files.
HAMBURG_TNP_DEFINITIONS: tuple[BodyDefinition, ...] = (
    BodyDefinition(
        "cupido",
        swe.CUPIDO,
        "hypothetical",
        "swiss:h40",
        "ephemeris.swiss.hypothetical_orbit.v1",
    ),
    BodyDefinition(
        "hades",
        swe.HADES,
        "hypothetical",
        "swiss:h41",
        "ephemeris.swiss.hypothetical_orbit.v1",
    ),
    BodyDefinition(
        "zeus",
        swe.ZEUS,
        "hypothetical",
        "swiss:h42",
        "ephemeris.swiss.hypothetical_orbit.v1",
    ),
    BodyDefinition(
        "kronos",
        swe.KRONOS,
        "hypothetical",
        "swiss:h43",
        "ephemeris.swiss.hypothetical_orbit.v1",
    ),
    BodyDefinition(
        "apollon",
        swe.APOLLON,
        "hypothetical",
        "swiss:h44",
        "ephemeris.swiss.hypothetical_orbit.v1",
    ),
    BodyDefinition(
        "admetos",
        swe.ADMETOS,
        "hypothetical",
        "swiss:h45",
        "ephemeris.swiss.hypothetical_orbit.v1",
    ),
    BodyDefinition(
        "vulkanus",
        swe.VULKANUS,
        "hypothetical",
        "swiss:h46",
        "ephemeris.swiss.hypothetical_orbit.v1",
    ),
    BodyDefinition(
        "poseidon",
        swe.POSEIDON,
        "hypothetical",
        "swiss:h47",
        "ephemeris.swiss.hypothetical_orbit.v1",
    ),
)
HAMBURG_TNP_POINT_IDS: tuple[str, ...] = tuple(
    definition.point_id for definition in HAMBURG_TNP_DEFINITIONS
)
DIRECT_POINT_DEFINITIONS: tuple[BodyDefinition, ...] = (
    *BODY_DEFINITIONS,
    *EXTENDED_BODY_DEFINITIONS,
    *HAMBURG_TNP_DEFINITIONS,
)
DIRECT_POINT_REGISTRY: dict[str, BodyDefinition] = {
    definition.point_id: definition for definition in DIRECT_POINT_DEFINITIONS
}
CORE_POINT_IDS: tuple[str, ...] = tuple(item.point_id for item in BODY_DEFINITIONS)
PROFESSIONAL_DIRECT_POINT_IDS: tuple[str, ...] = tuple(
    item.point_id for item in DIRECT_POINT_DEFINITIONS
)


class SwissEphemerisMode(StrEnum):
    SWISS = "swiss"
    MOSHIER = "moshier"


class SwissEphemerisError(RuntimeError):
    """Base adapter failure; callers must not substitute another engine silently."""


class EphemerisInputError(SwissEphemerisError, ValueError):
    """Input instant or Julian day is invalid or ambiguous."""


class EphemerisCalculationError(SwissEphemerisError):
    """The C binding could not calculate a requested body."""


class EphemerisFlagsError(SwissEphemerisError):
    """Returned flags do not preserve required calculation semantics."""


class EphemerisFallbackError(SwissEphemerisError):
    """Requested Swiss files were unavailable and fallback policy is `error`."""


@dataclass(frozen=True, slots=True)
class AdapterWarning:
    code: str
    message: str
    point_id: str | None = None


@dataclass(frozen=True, slots=True)
class PointFlagRecord:
    point_id: str
    requested_ecliptic_flags: int
    returned_ecliptic_flags: int
    requested_equatorial_flags: int
    returned_equatorial_flags: int
    actual_mode: str
    messages: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class AdapterProvenance:
    maturity: Literal["experimental"]
    engine_name: Literal["swiss_ephemeris"]
    swiss_c_library_version: str
    adapter_name: Literal["pysweph"]
    binding_version: str
    binding_library_path: str | None
    requested_mode: str
    actual_modes: tuple[str, ...]
    apparent: bool
    center: Literal["geocentric"]
    zodiac: Literal["tropical"]
    frame: Literal["true_ecliptic_of_date"]
    speed_requested: bool
    delta_t_function: Literal["swe_deltat_ex"]
    delta_t_model: Literal["automatic_ephemeris_dependent"]
    delta_t_ephemeris_mode: str
    ephemeris_path: str | None
    point_flags: tuple[PointFlagRecord, ...]


@dataclass(frozen=True, slots=True)
class EphemerisResult:
    julian_day_ut: float
    julian_day_tt: float
    delta_t_seconds: float
    utc_instant: str | None
    true_obliquity_deg: float | None
    mean_obliquity_deg: float | None
    nutation_longitude_deg: float | None
    nutation_obliquity_deg: float | None
    greenwich_sidereal_time_deg: float | None
    points: tuple[dict[str, Any], ...]
    provenance: AdapterProvenance
    warnings: tuple[AdapterWarning, ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "julian_day_ut": self.julian_day_ut,
            "julian_day_tt": self.julian_day_tt,
            "delta_t_seconds": self.delta_t_seconds,
            "utc_instant": self.utc_instant,
            "true_obliquity_deg": self.true_obliquity_deg,
            "mean_obliquity_deg": self.mean_obliquity_deg,
            "nutation_longitude_deg": self.nutation_longitude_deg,
            "nutation_obliquity_deg": self.nutation_obliquity_deg,
            "greenwich_sidereal_time_deg": self.greenwich_sidereal_time_deg,
            "points": list(self.points),
            "provenance": asdict(self.provenance),
            "warnings": [asdict(warning) for warning in self.warnings],
        }


@dataclass(frozen=True, slots=True)
class _RawCalculation:
    values: tuple[float, float, float, float, float, float]
    returned_flags: int
    message: str


class SwissEphemerisAdapter:
    """Calculate a declared Swiss point projection with explicit provenance.

    The no-argument default remains the original ten-body projection for API
    compatibility. Extended points are opt-in; unsupported identifiers and
    missing ephemeris files are errors rather than silent omissions.
    """

    _backend_lock = threading.RLock()

    def __init__(
        self,
        *,
        mode: SwissEphemerisMode = SwissEphemerisMode.SWISS,
        moshier_fallback: Literal["record", "error"] = "record",
        stationary_threshold_deg_per_day: float = 1e-4,
        ephemeris_path: str | Path | None = None,
        _backend: ModuleType = swe,
    ) -> None:
        if moshier_fallback not in {"record", "error"}:
            raise EphemerisInputError("moshier_fallback must be 'record' or 'error'")
        if (
            not math.isfinite(stationary_threshold_deg_per_day)
            or stationary_threshold_deg_per_day <= 0
        ):
            raise EphemerisInputError("stationary threshold must be finite and greater than zero")
        self.mode = mode
        self.moshier_fallback = moshier_fallback
        self.stationary_threshold = stationary_threshold_deg_per_day
        self.ephemeris_path = (
            str(Path(ephemeris_path).expanduser().resolve()) if ephemeris_path else None
        )
        self._backend = _backend

    def calculate(
        self,
        *,
        utc_instant: datetime | None = None,
        julian_day_ut: float | None = None,
        point_ids: Iterable[str] | None = None,
    ) -> EphemerisResult:
        jd_ut, normalized_utc = self._normalize_time(
            utc_instant=utc_instant,
            julian_day_ut=julian_day_ut,
        )
        requested_mode_flag = self._requested_mode_flag()
        ecliptic_flags = requested_mode_flag | swe.FLG_SPEED
        equatorial_flags = ecliptic_flags | swe.FLG_EQUATORIAL
        points: list[dict[str, Any]] = []
        warnings: list[AdapterWarning] = []
        flag_records: list[PointFlagRecord] = []
        definitions = self._point_definitions(point_ids)

        with self._backend_lock:
            if self.ephemeris_path is not None:
                self._backend.set_ephe_path(self.ephemeris_path)
            for body in definitions:
                ecliptic = self._calculate_raw(jd_ut, body, ecliptic_flags)
                equatorial = self._calculate_raw(jd_ut, body, equatorial_flags)
                self._validate_return_flags(body, ecliptic, required_flags=swe.FLG_SPEED)
                self._validate_return_flags(
                    body,
                    equatorial,
                    required_flags=swe.FLG_SPEED | swe.FLG_EQUATORIAL,
                )
                actual_mode = self._mode_from_flags(ecliptic.returned_flags)
                equatorial_mode = self._mode_from_flags(equatorial.returned_flags)
                if equatorial_mode != actual_mode:
                    raise EphemerisFlagsError(
                        f"{body.point_id} coordinate calls used different ephemeris modes: "
                        f"{actual_mode} vs {equatorial_mode}"
                    )
                self._handle_mode(body, actual_mode, warnings)
                messages = tuple(
                    message for message in (ecliptic.message, equatorial.message) if message
                )
                if messages:
                    warnings.append(
                        AdapterWarning(
                            code="SWISS_EPHEMERIS_MESSAGE",
                            message=" | ".join(dict.fromkeys(messages)),
                            point_id=body.point_id,
                        )
                    )
                points.append(self._point_record(body, jd_ut, ecliptic, equatorial))
                flag_records.append(
                    PointFlagRecord(
                        point_id=body.point_id,
                        requested_ecliptic_flags=ecliptic_flags,
                        returned_ecliptic_flags=ecliptic.returned_flags,
                        requested_equatorial_flags=equatorial_flags,
                        returned_equatorial_flags=equatorial.returned_flags,
                        actual_mode=actual_mode,
                        messages=messages,
                    )
                )

            actual_modes = tuple(dict.fromkeys(record.actual_mode for record in flag_records))
            delta_t_days, delta_t_message = self._delta_t(jd_ut, actual_modes[0])
            earth_orientation = self._earth_orientation(jd_ut, requested_mode_flag)

        if delta_t_message:
            warnings.append(
                AdapterWarning(
                    code="DELTA_T_MESSAGE",
                    message=delta_t_message,
                )
            )
        delta_t_seconds = delta_t_days * 86_400
        provenance = AdapterProvenance(
            maturity="experimental",
            engine_name="swiss_ephemeris",
            swiss_c_library_version=str(getattr(self._backend, "version", "unknown")),
            adapter_name="pysweph",
            binding_version=self._binding_version(),
            binding_library_path=self._library_path(),
            requested_mode=self.mode.value,
            actual_modes=actual_modes,
            apparent=True,
            center="geocentric",
            zodiac="tropical",
            frame="true_ecliptic_of_date",
            speed_requested=True,
            delta_t_function="swe_deltat_ex",
            delta_t_model="automatic_ephemeris_dependent",
            delta_t_ephemeris_mode=actual_modes[0],
            ephemeris_path=self.ephemeris_path,
            point_flags=tuple(flag_records),
        )
        return EphemerisResult(
            julian_day_ut=jd_ut,
            julian_day_tt=jd_ut + delta_t_days,
            delta_t_seconds=delta_t_seconds,
            utc_instant=normalized_utc,
            true_obliquity_deg=earth_orientation[0],
            mean_obliquity_deg=earth_orientation[1],
            nutation_longitude_deg=earth_orientation[2],
            nutation_obliquity_deg=earth_orientation[3],
            greenwich_sidereal_time_deg=earth_orientation[4],
            points=tuple(points),
            provenance=provenance,
            warnings=tuple(warnings),
        )

    def _earth_orientation(
        self,
        julian_day_ut: float,
        mode_flag: int,
    ) -> tuple[float | None, float | None, float | None, float | None, float | None]:
        try:
            raw = self._backend.calc_ut(julian_day_ut, swe.ECL_NUT, mode_flag)
            values = raw[0]
            if not isinstance(values, (tuple, list)) or len(values) < 4:
                raise ValueError("ECL_NUT did not return four orientation values")
            orientation = tuple(float(value) for value in values[:4])
            if not all(math.isfinite(value) for value in orientation):
                raise ValueError("ECL_NUT returned non-finite values")
        except Exception:
            orientation = (None, None, None, None)
        sidtime = getattr(self._backend, "sidtime", None)
        if sidtime is None:
            gst = None
        else:
            try:
                gst = float(sidtime(julian_day_ut)) * 15 % 360
                if not math.isfinite(gst):
                    gst = None
            except Exception:
                gst = None
        return (*orientation, gst)

    def _point_definitions(
        self,
        point_ids: Iterable[str] | None,
    ) -> tuple[BodyDefinition, ...]:
        if point_ids is None:
            return BODY_DEFINITIONS
        normalized = tuple(str(point_id) for point_id in point_ids)
        if not normalized:
            raise EphemerisInputError("point_ids must contain at least one point")
        duplicates = sorted(
            point_id for point_id in set(normalized) if normalized.count(point_id) > 1
        )
        if duplicates:
            raise EphemerisInputError("point_ids contains duplicate ids: " + ", ".join(duplicates))
        unknown = sorted(set(normalized) - set(DIRECT_POINT_REGISTRY))
        if unknown:
            raise EphemerisInputError(
                "point_ids contains unsupported direct Swiss ids: " + ", ".join(unknown)
            )
        return tuple(DIRECT_POINT_REGISTRY[point_id] for point_id in normalized)

    def _delta_t(self, julian_day_ut: float, actual_mode: str) -> tuple[float, str]:
        mode_flag = {
            "swiss": swe.FLG_SWIEPH,
            "moshier": swe.FLG_MOSEPH,
            "jpl": swe.FLG_JPLEPH,
        }.get(actual_mode)
        if mode_flag is None:
            raise EphemerisFlagsError(f"cannot select Delta-T model for mode: {actual_mode}")
        try:
            raw = self._backend.deltat_ex(julian_day_ut, mode_flag)
        except Exception as exc:
            raise EphemerisCalculationError(
                f"Swiss Ephemeris Delta-T calculation failed: {type(exc).__name__}: {exc}"
            ) from exc
        if isinstance(raw, tuple):
            if len(raw) != 2:
                raise EphemerisCalculationError("Swiss Delta-T returned an unsupported payload")
            delta_t_days, message = raw
        else:
            delta_t_days, message = raw, ""
        value = float(delta_t_days)
        if not math.isfinite(value):
            raise EphemerisCalculationError("Swiss Delta-T returned a non-finite value")
        return value, str(message).strip()

    def _normalize_time(
        self,
        *,
        utc_instant: datetime | None,
        julian_day_ut: float | None,
    ) -> tuple[float, str | None]:
        if (utc_instant is None) == (julian_day_ut is None):
            raise EphemerisInputError("provide exactly one of utc_instant or julian_day_ut")
        if julian_day_ut is not None:
            jd = float(julian_day_ut)
            if not math.isfinite(jd):
                raise EphemerisInputError("julian_day_ut must be finite")
            return jd, None

        assert utc_instant is not None
        if utc_instant.tzinfo is None or utc_instant.utcoffset() is None:
            raise EphemerisInputError("utc_instant must be timezone-aware UTC")
        if utc_instant.utcoffset() != timedelta(0):
            raise EphemerisInputError("utc_instant must have a zero UTC offset")
        normalized = utc_instant.astimezone(UTC)
        hour = (
            normalized.hour
            + normalized.minute / 60
            + (normalized.second + normalized.microsecond / 1_000_000) / 3600
        )
        jd = float(
            self._backend.julday(
                normalized.year,
                normalized.month,
                normalized.day,
                hour,
                swe.GREG_CAL,
            )
        )
        return jd, normalized.isoformat().replace("+00:00", "Z")

    def _requested_mode_flag(self) -> int:
        if self.mode is SwissEphemerisMode.SWISS:
            return swe.FLG_SWIEPH
        if self.mode is SwissEphemerisMode.MOSHIER:
            return swe.FLG_MOSEPH
        raise EphemerisInputError(f"unsupported ephemeris mode: {self.mode}")

    def _calculate_raw(
        self,
        julian_day_ut: float,
        body: BodyDefinition,
        flags: int,
    ) -> _RawCalculation:
        try:
            raw = self._backend.calc_ut(julian_day_ut, body.swiss_id, flags)
        except Exception as exc:
            raise EphemerisCalculationError(
                f"Swiss Ephemeris failed for {body.point_id}: {type(exc).__name__}: {exc}"
            ) from exc
        if not isinstance(raw, tuple) or len(raw) not in {2, 3}:
            raise EphemerisCalculationError(
                f"Swiss Ephemeris returned an unsupported payload for {body.point_id}"
            )
        values_raw, returned_flags = raw[0], raw[1]
        message = str(raw[2]).strip() if len(raw) == 3 and raw[2] else ""
        if not isinstance(values_raw, (tuple, list)) or len(values_raw) != 6:
            value_count = len(values_raw) if hasattr(values_raw, "__len__") else "unknown"
            raise EphemerisCalculationError(
                f"Swiss Ephemeris returned {value_count} values for {body.point_id}; expected six"
            )
        values = tuple(float(value) for value in values_raw)
        if not all(math.isfinite(value) for value in values):
            raise EphemerisCalculationError(
                f"Swiss Ephemeris returned non-finite values for {body.point_id}"
            )
        return _RawCalculation(
            values=values,  # type: ignore[arg-type]
            returned_flags=int(returned_flags),
            message=message,
        )

    def _validate_return_flags(
        self,
        body: BodyDefinition,
        calculation: _RawCalculation,
        *,
        required_flags: int,
    ) -> None:
        if calculation.returned_flags & required_flags != required_flags:
            raise EphemerisFlagsError(
                f"{body.point_id} returned flags {calculation.returned_flags} do not include "
                f"required flags {required_flags}"
            )
        forbidden = swe.FLG_HELCTR | swe.FLG_TOPOCTR | swe.FLG_TRUEPOS | swe.FLG_J2000
        if calculation.returned_flags & forbidden:
            raise EphemerisFlagsError(
                f"{body.point_id} returned flags conflict with "
                "geocentric apparent-of-date semantics"
            )

    def _mode_from_flags(self, returned_flags: int) -> str:
        if returned_flags & swe.FLG_JPLEPH:
            return "jpl"
        if returned_flags & swe.FLG_SWIEPH:
            return "swiss"
        if returned_flags & swe.FLG_MOSEPH:
            return "moshier"
        raise EphemerisFlagsError(
            f"return flags {returned_flags} contain no recognized ephemeris mode"
        )

    def _handle_mode(
        self,
        body: BodyDefinition,
        actual_mode: str,
        warnings: list[AdapterWarning],
    ) -> None:
        if actual_mode == self.mode.value:
            return
        if self.mode is SwissEphemerisMode.SWISS and actual_mode == "moshier":
            message = (
                f"Swiss ephemeris files were unavailable for {body.point_id}; "
                "Swiss Ephemeris used the Moshier ephemeris."
            )
            if self.moshier_fallback == "error":
                raise EphemerisFallbackError(message)
            warnings.append(
                AdapterWarning(
                    code="EPHEMERIS_FALLBACK_MOSHIER",
                    message=message,
                    point_id=body.point_id,
                )
            )
            return
        raise EphemerisFlagsError(
            f"requested {self.mode.value} ephemeris but {body.point_id} returned {actual_mode}"
        )

    def _point_record(
        self,
        body: BodyDefinition,
        julian_day_ut: float,
        ecliptic: _RawCalculation,
        equatorial: _RawCalculation,
    ) -> dict[str, Any]:
        longitude, latitude, distance, lon_speed, lat_speed, distance_speed = ecliptic.values
        right_ascension, declination, eq_distance, ra_speed, dec_speed, _ = equatorial.values
        if not math.isclose(distance, eq_distance, rel_tol=0, abs_tol=1e-9):
            raise EphemerisCalculationError(
                f"coordinate distance mismatch for {body.point_id}: {distance} vs {eq_distance}"
            )
        normalized_longitude = longitude % 360
        sign_index = min(int(normalized_longitude // 30), 11)
        motion_state = self._motion_state(lon_speed)
        return {
            "point_id": body.point_id,
            "kind": body.kind,
            "position": {
                "ecliptic": {
                    "longitude_deg": normalized_longitude,
                    "latitude_deg": latitude,
                },
                "equatorial": {
                    "right_ascension_deg": right_ascension % 360,
                    "declination_deg": declination,
                },
                "distance_au": distance,
                "velocity": {
                    "longitude_deg_per_day": lon_speed,
                    "latitude_deg_per_day": lat_speed,
                    "right_ascension_deg_per_day": ra_speed,
                    "declination_deg_per_day": dec_speed,
                    "distance_au_per_day": distance_speed,
                },
                "motion_state": motion_state,
                "frame": "true_ecliptic_of_date",
                "center": "geocentric",
                "epoch": f"JDUT:{julian_day_ut:.9f}",
                "uncertainty_arcsec": None,
            },
            "sign": SIGN_IDS[sign_index],
            "degree_in_sign": normalized_longitude - sign_index * 30,
            "house": None,
            "distance_from_previous_cusp_deg": None,
            "distance_to_next_cusp_deg": None,
            "house_position_fraction": None,
            "retrograde": motion_state == "retrograde",
            "motion_interpretation": (
                "not_applicable" if body.point_id in {"sun", "moon"} else "meaningful"
            ),
            "out_of_bounds": None,
            "solar_relation": None,
            "solar_elongation_deg": None,
            "visibility_state": None,
            "oriental_occidental": None,
            "formula_ref": body.formula_ref,
            "catalog_object_ref": body.catalog_object_ref,
            "status_refs": [f"motion.{motion_state}"],
        }

    def _motion_state(self, longitude_speed: float) -> str:
        if abs(longitude_speed) <= self.stationary_threshold:
            return "stationary"
        return "retrograde" if longitude_speed < 0 else "direct"

    def _library_path(self) -> str | None:
        getter = getattr(self._backend, "get_library_path", None)
        if getter is None:
            return None
        try:
            return str(getter())
        except Exception:
            return None

    def _binding_version(self) -> str:
        try:
            return version("pysweph")
        except PackageNotFoundError as exc:
            raise EphemerisCalculationError(
                "pysweph package metadata is unavailable; an unversioned adapter run is forbidden"
            ) from exc
