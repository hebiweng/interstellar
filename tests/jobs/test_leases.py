from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from interstellar_core.domain import DomainError
from interstellar_core.jobs import InMemoryJobStore, JobKind, JobStatus

NOW = datetime(2026, 7, 18, 0, 0, tzinfo=UTC)


def test_lease_can_be_renewed_but_expired_token_is_rejected() -> None:
    store = InMemoryJobStore()
    store.create("job_lease", JobKind.BATCH, now=NOW)
    _, token = store.acquire(
        "job_lease", "worker-a", now=NOW, lease_for=timedelta(seconds=30)
    )
    renewed = store.renew(
        token, now=NOW + timedelta(seconds=20), lease_for=timedelta(seconds=30)
    )
    assert renewed.lease.expires_at == NOW + timedelta(seconds=50)

    with pytest.raises(DomainError) as expired:
        store.update_progress(token, 10, "late", now=NOW + timedelta(seconds=50))
    assert expired.value.code == "JOB_LEASE_EXPIRED"


def test_crashed_worker_is_requeued_and_stale_worker_cannot_write() -> None:
    store = InMemoryJobStore()
    store.create("job_crash", JobKind.BATCH, now=NOW, max_attempts=3)
    _, stale_token = store.acquire(
        "job_crash", "worker-old", now=NOW, lease_for=timedelta(seconds=10)
    )
    recovered = store.recover_expired_leases(now=NOW + timedelta(seconds=10))[0]
    assert recovered.status is JobStatus.QUEUED
    assert recovered.attempt == 2

    _, new_token = store.acquire(
        "job_crash",
        "worker-new",
        now=NOW + timedelta(seconds=11),
        lease_for=timedelta(seconds=30),
    )
    assert new_token.generation > stale_token.generation
    with pytest.raises(DomainError) as stale:
        store.update_progress(
            stale_token, 90, "stale", now=NOW + timedelta(seconds=12)
        )
    assert stale.value.code == "JOB_STALE_WORKER"


def test_crash_recovery_respects_attempt_limit() -> None:
    store = InMemoryJobStore()
    store.create("job_crash_final", JobKind.BATCH, now=NOW, max_attempts=1)
    store.acquire(
        "job_crash_final", "worker", now=NOW, lease_for=timedelta(seconds=10)
    )
    failed = store.recover_expired_leases(now=NOW + timedelta(seconds=10))[0]
    assert failed.status is JobStatus.FAILED
    assert failed.error.code == "WORKER_LEASE_EXPIRED"


def test_cancelling_job_becomes_cancelled_when_worker_lease_expires() -> None:
    store = InMemoryJobStore()
    store.create("job_cancel_crash", JobKind.RENDER, now=NOW)
    store.acquire(
        "job_cancel_crash", "worker", now=NOW, lease_for=timedelta(seconds=10)
    )
    store.request_cancel("job_cancel_crash", now=NOW + timedelta(seconds=1))
    recovered = store.recover_expired_leases(now=NOW + timedelta(seconds=10))[0]
    assert recovered.status is JobStatus.CANCELLED
    assert recovered.stage == "cancelled_after_worker_loss"
