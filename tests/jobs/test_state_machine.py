from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from interstellar_core.domain import DomainError
from interstellar_core.jobs import InMemoryJobStore, JobError, JobKind, JobStatus

NOW = datetime(2026, 7, 18, 0, 0, tzinfo=UTC)


def test_happy_path_progress_is_monotonic_and_canonical() -> None:
    store = InMemoryJobStore()
    queued = store.create("job_happy", JobKind.CALCULATION, now=NOW)
    running, token = store.acquire(
        queued.id, "worker-a", now=NOW + timedelta(seconds=1), lease_for=timedelta(seconds=30)
    )
    progressed = store.update_progress(
        token, 42.0, "event_search", now=NOW + timedelta(seconds=2)
    )
    completed = store.complete(
        token,
        now=NOW + timedelta(seconds=3),
        resource_uri="/api/v1/calculations/calc_1",
    )

    assert running.status is JobStatus.RUNNING
    assert progressed.progress == 42.0
    assert completed.status is JobStatus.SUCCEEDED
    assert completed.progress == 100.0
    assert completed.terminal is True
    assert completed.lease is None
    canonical = completed.to_canonical()
    assert canonical["links"]["events"] == "/api/v1/jobs/job_happy/events"
    assert canonical["resource_uri"] == "/api/v1/calculations/calc_1"
    assert canonical["finished_at"].endswith("Z")


def test_progress_decrease_and_illegal_terminal_transition_are_rejected() -> None:
    store = InMemoryJobStore()
    store.create("job_progress", JobKind.RENDER, now=NOW)
    _, token = store.acquire(
        "job_progress", "worker", now=NOW, lease_for=timedelta(seconds=30)
    )
    store.update_progress(token, 50, "render", now=NOW + timedelta(seconds=1))
    with pytest.raises(DomainError) as decreased:
        store.update_progress(token, 49, "render", now=NOW + timedelta(seconds=2))
    assert decreased.value.code == "JOB_PROGRESS_DECREASE"

    store.complete(token, now=NOW + timedelta(seconds=3))
    with pytest.raises(DomainError) as terminal:
        store.complete(token, now=NOW + timedelta(seconds=4))
    assert terminal.value.code == "JOB_TRANSITION_INVALID"


def test_cancel_is_idempotent_for_queued_running_and_terminal_jobs() -> None:
    store = InMemoryJobStore()
    store.create("job_queued_cancel", JobKind.REPORT, now=NOW)
    first = store.request_cancel("job_queued_cancel", now=NOW)
    second = store.request_cancel("job_queued_cancel", now=NOW + timedelta(seconds=1))
    assert first is second
    assert second.status is JobStatus.CANCELLED
    assert len(store.events_after(second.id).events) == 2

    store.create("job_running_cancel", JobKind.REPORT, now=NOW)
    _, token = store.acquire(
        "job_running_cancel", "worker", now=NOW, lease_for=timedelta(seconds=30)
    )
    cancelling = store.request_cancel("job_running_cancel", now=NOW + timedelta(seconds=1))
    repeated = store.request_cancel("job_running_cancel", now=NOW + timedelta(seconds=2))
    assert cancelling is repeated
    assert cancelling.status is JobStatus.CANCELLING
    cancelled = store.acknowledge_cancel(token, now=NOW + timedelta(seconds=3))
    assert cancelled.status is JobStatus.CANCELLED


def test_deterministic_failure_is_terminal_without_retry() -> None:
    store = InMemoryJobStore()
    store.create("job_invalid", JobKind.CALCULATION, now=NOW, max_attempts=3)
    _, token = store.acquire(
        "job_invalid", "worker", now=NOW, lease_for=timedelta(seconds=30)
    )
    failed = store.fail(
        token,
        JobError("INVALID_INPUT", "input is deterministic", retryable=False),
        now=NOW + timedelta(seconds=1),
    )
    assert failed.status is JobStatus.FAILED
    assert failed.attempt == 1
    assert failed.error.code == "INVALID_INPUT"


def test_transient_failure_retries_with_backoff_and_is_bounded() -> None:
    store = InMemoryJobStore()
    store.create("job_retry", JobKind.IMPORT, now=NOW, max_attempts=2)
    _, first_token = store.acquire(
        "job_retry", "worker-a", now=NOW, lease_for=timedelta(seconds=30)
    )
    retry = store.fail(
        first_token,
        JobError("STORAGE_TEMPORARY", "object store unavailable", retryable=True),
        now=NOW + timedelta(seconds=1),
    )
    assert retry.status is JobStatus.QUEUED
    assert retry.attempt == 2
    assert retry.available_at == NOW + timedelta(seconds=2)
    with pytest.raises(DomainError) as early:
        store.acquire(
            "job_retry",
            "worker-b",
            now=NOW + timedelta(seconds=1, milliseconds=500),
            lease_for=timedelta(seconds=30),
        )
    assert early.value.code == "JOB_NOT_YET_AVAILABLE"

    _, second_token = store.acquire(
        "job_retry", "worker-b", now=NOW + timedelta(seconds=2), lease_for=timedelta(seconds=30)
    )
    exhausted = store.fail(
        second_token,
        JobError("STORAGE_TEMPORARY", "still unavailable", retryable=True),
        now=NOW + timedelta(seconds=3),
    )
    assert exhausted.status is JobStatus.FAILED
    assert exhausted.attempt == 2


def test_timeout_scans_queued_and_running_jobs() -> None:
    store = InMemoryJobStore()
    store.create(
        "job_timeout",
        JobKind.CALCULATION,
        now=NOW,
        timeout=timedelta(seconds=5),
    )
    assert store.time_out_due(now=NOW + timedelta(seconds=4)) == ()
    timed_out = store.time_out_due(now=NOW + timedelta(seconds=5))
    assert timed_out[0].status is JobStatus.TIMED_OUT
    assert timed_out[0].error.code == "JOB_TIMED_OUT"
    assert timed_out[0].to_canonical()["error"]["code"] == "CALCULATION_TIMEOUT"
    assert timed_out[0].to_canonical()["error"]["request_id"] == "job_timeout"


def test_completed_job_can_expire_without_reopening_work() -> None:
    store = InMemoryJobStore()
    store.create(
        "job_expiry",
        JobKind.EXPORT,
        now=NOW,
        expires_at=NOW + timedelta(minutes=10),
    )
    _, token = store.acquire(
        "job_expiry", "worker", now=NOW, lease_for=timedelta(seconds=30)
    )
    store.complete(token, now=NOW + timedelta(seconds=1), resource_uri="/artifact/1")
    expired = store.expire_due(now=NOW + timedelta(minutes=10))
    assert expired[0].status is JobStatus.EXPIRED
    assert expired[0].resource_uri is None
