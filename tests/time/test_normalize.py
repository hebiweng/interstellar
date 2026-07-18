from __future__ import annotations

import pytest

from interstellar_core.time import (
    Calendar,
    SourceReference,
    TimeConfidence,
    TimeNormalizationStatus,
    TimePrecision,
    TimeSpecInput,
    normalize_time_spec,
)


SOURCE = SourceReference(kind="user_entered", description="Gold test fixture")


def make_input(
    local_value: str,
    timezone_id: str | None,
    *,
    precision: TimePrecision = TimePrecision.MINUTE,
    calendar: Calendar = Calendar.GREGORIAN,
    confidence: TimeConfidence = TimeConfidence.HIGH,
) -> TimeSpecInput:
    return TimeSpecInput(
        calendar=calendar,
        local_value=local_value,
        precision=precision,
        timezone_id=timezone_id,
        confidence=confidence,
        source=SOURCE,
    )


def test_asia_shanghai_normal_time_has_one_selected_utc_candidate() -> None:
    result = normalize_time_spec(make_input("2024-01-15T12:00", "Asia/Shanghai"))

    assert result.status is TimeNormalizationStatus.VALID
    assert result.is_resolved is True
    assert result.time_spec is not None
    assert result.time_spec.local_value == "2024-01-15T12:00:00"
    assert result.time_spec.utc_candidates == ("2024-01-15T04:00:00+00:00",)
    assert result.time_spec.selected_utc == "2024-01-15T04:00:00+00:00"
    assert result.time_spec.precision is TimePrecision.MINUTE
    assert result.time_spec.confidence is TimeConfidence.HIGH
    assert result.time_spec.source is SOURCE
    assert result.time_spec.warnings == ()


def test_new_york_dst_overlap_returns_two_candidates_without_selection() -> None:
    result = normalize_time_spec(make_input("2024-11-03T01:30", "America/New_York"))

    assert result.status is TimeNormalizationStatus.AMBIGUOUS
    assert result.time_spec is not None
    assert result.time_spec.utc_candidates == (
        "2024-11-03T05:30:00+00:00",
        "2024-11-03T06:30:00+00:00",
    )
    assert result.time_spec.selected_utc is None
    assert [warning.code for warning in result.time_spec.warnings] == [
        "TIME_AMBIGUOUS_LOCAL"
    ]
    assert result.error_code == "TIME_AMBIGUOUS_LOCAL"


def test_new_york_dst_gap_is_explicitly_nonexistent() -> None:
    result = normalize_time_spec(make_input("2024-03-10T02:30", "America/New_York"))

    assert result.status is TimeNormalizationStatus.NONEXISTENT
    assert result.is_resolved is False
    assert result.time_spec is not None
    assert result.time_spec.utc_candidates == ()
    assert result.time_spec.selected_utc is None
    assert [warning.code for warning in result.time_spec.warnings] == [
        "TIME_NONEXISTENT_LOCAL"
    ]
    assert result.error_code == "TIME_NONEXISTENT_LOCAL"


@pytest.mark.parametrize("precision", [TimePrecision.DATE, TimePrecision.UNKNOWN])
def test_date_only_and_unknown_never_invent_midnight_or_utc(
    precision: TimePrecision,
) -> None:
    result = normalize_time_spec(
        make_input("1990-06-15", "Asia/Shanghai", precision=precision)
    )

    assert result.status is TimeNormalizationStatus.UNRESOLVED
    assert result.time_spec is not None
    assert result.time_spec.local_value == "1990-06-15"
    assert "T00:00" not in result.time_spec.local_value
    assert result.time_spec.utc_candidates == ()
    assert result.time_spec.selected_utc is None
    assert result.time_spec.to_dict()["utc_candidates"] == []


@pytest.mark.parametrize(
    "calendar",
    [Calendar.JULIAN, Calendar.PROLEPTIC_GREGORIAN, Calendar.CUSTOM],
)
def test_non_gregorian_calendars_are_explicitly_unsupported(calendar: Calendar) -> None:
    result = normalize_time_spec(
        make_input("2024-01-15T12:00", "Asia/Shanghai", calendar=calendar)
    )

    assert result.status is TimeNormalizationStatus.UNSUPPORTED
    assert result.time_spec is not None
    assert result.time_spec.utc_candidates == ()
    assert result.time_spec.selected_utc is None
    assert result.error_code == "CALENDAR_UNSUPPORTED"


def test_contract_serialization_contains_required_fields_and_no_wrapper_status() -> None:
    result = normalize_time_spec(make_input("2024-01-15T12:00", "Asia/Shanghai"))
    assert result.time_spec is not None

    payload = result.time_spec.to_dict()
    assert {
        "calendar",
        "local_value",
        "precision",
        "utc_candidates",
        "confidence",
        "source",
        "warnings",
    } <= payload.keys()
    assert "status" not in payload
    assert payload["source"] == {
        "kind": "user_entered",
        "description": "Gold test fixture",
    }
