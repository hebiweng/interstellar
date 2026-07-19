"""Deterministic local-time normalization using the standard-library IANA database."""

from __future__ import annotations

from datetime import UTC, date, datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from .models import (
    Calendar,
    HistoricalConfidence,
    NormalizedTimeSpec,
    TimeConfidence,
    TimeNormalizationResult,
    TimeNormalizationStatus,
    TimePrecision,
    TimeSpecInput,
    TimeWarning,
    WarningSeverity,
)
from .tzdb import TZDB_DATASET_REFERENCE

_INSTANT_PRECISIONS = frozenset(
    {
        TimePrecision.SECOND,
        TimePrecision.MINUTE,
        TimePrecision.QUARTER_HOUR,
        TimePrecision.HOUR,
    }
)
_UNRESOLVED_PRECISIONS = frozenset({TimePrecision.DATE, TimePrecision.UNKNOWN})


def _coerce_enum[T: str](enum_type: type[T], value: T | str) -> T | None:
    try:
        return enum_type(value)
    except ValueError:
        return None


def _warning(
    code: str,
    message: str,
    *,
    severity: WarningSeverity = WarningSeverity.WARNING,
    details: dict[str, object] | None = None,
) -> TimeWarning:
    return TimeWarning(
        code=code,
        message=message,
        severity=severity,
        path="/local_value",
        details=details or {},
    )


def _format_utc(value: datetime) -> str:
    return value.astimezone(UTC).isoformat(timespec="seconds")


def _parse_local_datetime(value: str) -> datetime | None:
    if "T" not in value:
        return None
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return None
    if parsed.tzinfo is not None:
        return None
    return parsed


def _parse_date(value: str) -> date | None:
    if "T" in value:
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        return None


def _valid_utc_candidates(local_time: datetime, zone: ZoneInfo) -> tuple[str, ...]:
    candidates: set[str] = set()
    for fold in (0, 1):
        aware = local_time.replace(tzinfo=zone, fold=fold)
        utc_value = aware.astimezone(UTC)
        round_trip = utc_value.astimezone(zone)
        if round_trip.replace(tzinfo=None) == local_time and round_trip.fold == fold:
            candidates.add(_format_utc(utc_value))
    return tuple(sorted(candidates))


def _base_spec(
    spec: TimeSpecInput,
    *,
    calendar: Calendar,
    precision: TimePrecision,
    confidence: TimeConfidence,
    local_value: str,
    candidates: tuple[str, ...] = (),
    selected_utc: str | None = None,
    warnings: tuple[TimeWarning, ...] = (),
) -> NormalizedTimeSpec:
    historical_confidence = None
    if spec.historical_confidence is not None:
        historical_confidence = _coerce_enum(
            HistoricalConfidence, spec.historical_confidence
        )
    return NormalizedTimeSpec(
        calendar=calendar,
        local_value=local_value,
        precision=precision,
        timezone_id=spec.timezone_id,
        utc_candidates=candidates,
        selected_utc=selected_utc,
        confidence=confidence,
        source=spec.source,
        timezone_dataset=spec.timezone_dataset or TZDB_DATASET_REFERENCE,
        historical_confidence=historical_confidence,
        uncertainty_seconds=spec.uncertainty_seconds,
        warnings=warnings,
    )


def normalize_time_spec(spec: TimeSpecInput) -> TimeNormalizationResult:
    """Normalize a TimeSpec without guessing an instant.

    Normal instants select their sole UTC candidate. DST overlaps expose both candidates
    and leave ``selected_utc`` unset. DST gaps expose no candidates and return the
    ``nonexistent`` status. Date-only and unknown precision remain unresolved.
    """
    calendar = _coerce_enum(Calendar, spec.calendar)
    precision = _coerce_enum(TimePrecision, spec.precision)
    confidence = _coerce_enum(TimeConfidence, spec.confidence)
    if calendar is None or precision is None or confidence is None:
        return TimeNormalizationResult(
            status=TimeNormalizationStatus.INVALID,
            time_spec=None,
            error_code="INVALID_TIME_SPEC_ENUM",
            error_detail="calendar, precision, or confidence is not a supported contract value",
        )

    if calendar is not Calendar.GREGORIAN:
        warning = _warning(
            "CALENDAR_UNSUPPORTED",
            f"Calendar {calendar.value!r} is declared by the contract but not implemented.",
            severity=WarningSeverity.ERROR,
            details={"calendar": calendar.value, "supported": [Calendar.GREGORIAN.value]},
        )
        time_spec = _base_spec(
            spec,
            calendar=calendar,
            precision=precision,
            confidence=confidence,
            local_value=spec.local_value,
            warnings=(warning,),
        )
        return TimeNormalizationResult(
            status=TimeNormalizationStatus.UNSUPPORTED,
            time_spec=time_spec,
            error_code="CALENDAR_UNSUPPORTED",
            error_detail=warning.message,
        )

    if precision in _UNRESOLVED_PRECISIONS:
        parsed_date = _parse_date(spec.local_value)
        if parsed_date is None:
            return TimeNormalizationResult(
                status=TimeNormalizationStatus.INVALID,
                time_spec=None,
                error_code="INVALID_LOCAL_DATE",
                error_detail="date-only and unknown precision require an ISO date without a time",
            )
        warning = _warning(
            "TIME_PRECISION_INSUFFICIENT",
            "The supplied precision does not identify an instant; no UTC value was created.",
            severity=WarningSeverity.INFO,
            details={"precision": precision.value},
        )
        return TimeNormalizationResult(
            status=TimeNormalizationStatus.UNRESOLVED,
            time_spec=_base_spec(
                spec,
                calendar=calendar,
                precision=precision,
                confidence=confidence,
                local_value=parsed_date.isoformat(),
                warnings=(warning,),
            ),
        )

    if precision not in _INSTANT_PRECISIONS:
        warning = _warning(
            "TIME_PRECISION_UNSUPPORTED",
            f"Precision {precision.value!r} cannot yet be normalized to one instant.",
            severity=WarningSeverity.ERROR,
            details={"precision": precision.value},
        )
        return TimeNormalizationResult(
            status=TimeNormalizationStatus.UNSUPPORTED,
            time_spec=_base_spec(
                spec,
                calendar=calendar,
                precision=precision,
                confidence=confidence,
                local_value=spec.local_value,
                warnings=(warning,),
            ),
            error_code="TIME_PRECISION_UNSUPPORTED",
            error_detail=warning.message,
        )

    local_time = _parse_local_datetime(spec.local_value)
    if local_time is None:
        return TimeNormalizationResult(
            status=TimeNormalizationStatus.INVALID,
            time_spec=None,
            error_code="INVALID_LOCAL_DATETIME",
            error_detail="instant precision requires an ISO local date-time without UTC offset",
        )
    canonical_local = local_time.isoformat(timespec="seconds")

    if spec.timezone_id is None:
        warning = _warning(
            "TIMEZONE_REQUIRED",
            "An IANA timezone is required to calculate UTC candidates.",
            severity=WarningSeverity.ERROR,
        )
        return TimeNormalizationResult(
            status=TimeNormalizationStatus.UNRESOLVED,
            time_spec=_base_spec(
                spec,
                calendar=calendar,
                precision=precision,
                confidence=confidence,
                local_value=canonical_local,
                warnings=(warning,),
            ),
            error_code="TIMEZONE_REQUIRED",
            error_detail=warning.message,
        )

    try:
        zone = ZoneInfo(spec.timezone_id)
    except ZoneInfoNotFoundError:
        warning = _warning(
            "TIMEZONE_UNKNOWN",
            f"IANA timezone {spec.timezone_id!r} is unavailable.",
            severity=WarningSeverity.ERROR,
            details={"timezone_id": spec.timezone_id},
        )
        return TimeNormalizationResult(
            status=TimeNormalizationStatus.INVALID,
            time_spec=_base_spec(
                spec,
                calendar=calendar,
                precision=precision,
                confidence=confidence,
                local_value=canonical_local,
                warnings=(warning,),
            ),
            error_code="TIMEZONE_UNKNOWN",
            error_detail=warning.message,
        )

    candidates = _valid_utc_candidates(local_time, zone)
    if not candidates:
        warning = _warning(
            "TIME_NONEXISTENT_LOCAL",
            "The local wall time falls inside a daylight-saving gap and never occurred.",
            severity=WarningSeverity.ERROR,
            details={"timezone_id": spec.timezone_id},
        )
        return TimeNormalizationResult(
            status=TimeNormalizationStatus.NONEXISTENT,
            time_spec=_base_spec(
                spec,
                calendar=calendar,
                precision=precision,
                confidence=confidence,
                local_value=canonical_local,
                warnings=(warning,),
            ),
            error_code="TIME_NONEXISTENT_LOCAL",
            error_detail=warning.message,
        )

    if len(candidates) == 2:
        warning = _warning(
            "TIME_AMBIGUOUS_LOCAL",
            "The local wall time occurs twice; select one UTC candidate explicitly.",
            details={"timezone_id": spec.timezone_id, "candidate_count": 2},
        )
        return TimeNormalizationResult(
            status=TimeNormalizationStatus.AMBIGUOUS,
            time_spec=_base_spec(
                spec,
                calendar=calendar,
                precision=precision,
                confidence=confidence,
                local_value=canonical_local,
                candidates=candidates,
                selected_utc=None,
                warnings=(warning,),
            ),
            error_code="TIME_AMBIGUOUS_LOCAL",
            error_detail=warning.message,
        )

    return TimeNormalizationResult(
        status=TimeNormalizationStatus.VALID,
        time_spec=_base_spec(
            spec,
            calendar=calendar,
            precision=precision,
            confidence=confidence,
            local_value=canonical_local,
            candidates=candidates,
            selected_utc=candidates[0],
        ),
    )
