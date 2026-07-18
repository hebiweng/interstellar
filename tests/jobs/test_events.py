from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from interstellar_core.domain import DomainError
from interstellar_core.jobs import InMemoryJobStore, JobKind, JobStore

NOW = datetime(2026, 7, 18, 0, 0, tzinfo=UTC)


def test_memory_adapter_satisfies_protocol_but_is_process_local() -> None:
    store = InMemoryJobStore()
    assert isinstance(store, JobStore)
    assert "non-durable" in InMemoryJobStore.__doc__


def test_event_sequences_and_last_event_id_resume_are_deterministic() -> None:
    store = InMemoryJobStore()
    store.create("job_events", JobKind.CALCULATION, now=NOW)
    _, token = store.acquire(
        "job_events", "worker", now=NOW + timedelta(seconds=1), lease_for=timedelta(seconds=30)
    )
    store.update_progress(token, 20, "first", now=NOW + timedelta(seconds=2))
    store.update_progress(token, 40, "second", now=NOW + timedelta(seconds=3))

    all_events = store.events_after("job_events")
    assert [event.sequence for event in all_events.events] == [1, 2, 3, 4]
    cursor = all_events.events[1].event_id
    resumed = store.events_after("job_events", cursor)
    assert [event.sequence for event in resumed.events] == [3, 4]
    assert resumed.terminal is False
    assert resumed.events[0].to_sse().startswith(f"id: {resumed.events[0].event_id}\n")

    store.complete(token, now=NOW + timedelta(seconds=4))
    terminal = store.events_after("job_events", resumed.last_event_id)
    assert [event.name for event in terminal.events] == ["completed"]
    assert terminal.terminal is True


def test_last_event_id_cannot_cross_jobs_or_point_ahead() -> None:
    store = InMemoryJobStore()
    store.create("job_a", JobKind.REPORT, now=NOW)
    store.create("job_b", JobKind.REPORT, now=NOW)
    cursor_a = store.events_after("job_a").last_event_id
    with pytest.raises(DomainError) as wrong_job:
        store.events_after("job_b", cursor_a)
    assert wrong_job.value.code == "JOB_EVENT_CURSOR_INVALID"

    with pytest.raises(DomainError) as ahead:
        store.events_after("job_a", "job_a:0000000000000099")
    assert ahead.value.code == "JOB_EVENT_CURSOR_AHEAD"


def test_idempotent_cancel_does_not_duplicate_sse_events() -> None:
    store = InMemoryJobStore()
    store.create("job_cancel_events", JobKind.IMPORT, now=NOW)
    store.request_cancel("job_cancel_events", now=NOW + timedelta(seconds=1))
    first = store.events_after("job_cancel_events")
    store.request_cancel("job_cancel_events", now=NOW + timedelta(seconds=2))
    second = store.events_after("job_cancel_events")
    assert len(first.events) == len(second.events) == 2
