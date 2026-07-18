"""Immutable time normalization domain models aligned with TimeSpec JSON Schema."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from enum import StrEnum
from typing import Any


class Calendar(StrEnum):
    GREGORIAN = "gregorian"
    JULIAN = "julian"
    PROLEPTIC_GREGORIAN = "proleptic_gregorian"
    CUSTOM = "custom"


class TimePrecision(StrEnum):
    SECOND = "second"
    MINUTE = "minute"
    QUARTER_HOUR = "quarter_hour"
    HOUR = "hour"
    PART_OF_DAY = "part_of_day"
    DATE = "date"
    INTERVAL = "interval"
    UNKNOWN = "unknown"


class TimeConfidence(StrEnum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"
    DISPUTED = "disputed"
    UNKNOWN = "unknown"


class HistoricalConfidence(StrEnum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"
    UNKNOWN = "unknown"


class WarningSeverity(StrEnum):
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"


class TimeNormalizationStatus(StrEnum):
    VALID = "valid"
    AMBIGUOUS = "ambiguous"
    NONEXISTENT = "nonexistent"
    UNRESOLVED = "unresolved"
    UNSUPPORTED = "unsupported"
    INVALID = "invalid"


@dataclass(frozen=True, slots=True)
class SourceReference:
    kind: str
    description: str | None = None
    uri: str | None = None
    version: str | None = None
    license: str | None = None
    retrieved_at: str | None = None

    def to_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {"kind": self.kind}
        for name in ("description", "uri", "version", "license", "retrieved_at"):
            value = getattr(self, name)
            if value is not None:
                result[name] = value
        return result


@dataclass(frozen=True, slots=True)
class DatasetReference:
    id: str
    version: str
    checksum: str | None = None
    license: str | None = None
    source_uri: str | None = None

    def to_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {"id": self.id, "version": self.version}
        for name in ("checksum", "license", "source_uri"):
            value = getattr(self, name)
            if value is not None:
                result[name] = value
        return result


@dataclass(frozen=True, slots=True)
class TimeWarning:
    code: str
    message: str
    severity: WarningSeverity = WarningSeverity.WARNING
    path: str | None = None
    details: Mapping[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {
            "code": self.code,
            "message": self.message,
            "severity": self.severity.value,
        }
        if self.path is not None:
            result["path"] = self.path
        if self.details:
            result["details"] = dict(self.details)
        return result


@dataclass(frozen=True, slots=True)
class TimeSpecInput:
    calendar: Calendar | str
    local_value: str
    precision: TimePrecision | str
    confidence: TimeConfidence | str
    source: SourceReference
    timezone_id: str | None = None
    timezone_dataset: DatasetReference | None = None
    historical_confidence: HistoricalConfidence | str | None = None
    uncertainty_seconds: int | None = None


@dataclass(frozen=True, slots=True)
class NormalizedTimeSpec:
    calendar: Calendar
    local_value: str
    precision: TimePrecision
    utc_candidates: tuple[str, ...]
    confidence: TimeConfidence
    source: SourceReference
    warnings: tuple[TimeWarning, ...]
    timezone_id: str | None = None
    selected_utc: str | None = None
    timezone_dataset: DatasetReference | None = None
    historical_confidence: HistoricalConfidence | None = None
    uncertainty_seconds: int | None = None

    def to_dict(self) -> dict[str, Any]:
        """Return only fields permitted by time-spec.schema.json."""
        result: dict[str, Any] = {
            "calendar": self.calendar.value,
            "local_value": self.local_value,
            "precision": self.precision.value,
            "timezone_id": self.timezone_id,
            "utc_candidates": list(self.utc_candidates),
            "selected_utc": self.selected_utc,
            "confidence": self.confidence.value,
            "source": self.source.to_dict(),
            "warnings": [warning.to_dict() for warning in self.warnings],
        }
        if self.timezone_dataset is not None:
            result["timezone_dataset"] = self.timezone_dataset.to_dict()
        if self.historical_confidence is not None:
            result["historical_confidence"] = self.historical_confidence.value
        if self.uncertainty_seconds is not None:
            result["uncertainty_seconds"] = self.uncertainty_seconds
        return result


@dataclass(frozen=True, slots=True)
class TimeNormalizationResult:
    status: TimeNormalizationStatus
    time_spec: NormalizedTimeSpec | None
    error_code: str | None = None
    error_detail: str | None = None

    @property
    def is_resolved(self) -> bool:
        return self.status is TimeNormalizationStatus.VALID
