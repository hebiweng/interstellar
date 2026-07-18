"""Pure Job transition functions with lease fencing."""

from __future__ import annotations

import math
from datetime import datetime, timedelta

from interstellar_core.domain.errors import DomainError

from .models import TERMINAL_STATUSES, Job, JobError, JobLease, JobStatus, LeaseToken


def _transition_error(job: Job, operation: str) -> DomainError:
    return DomainError(
        "JOB_TRANSITION_INVALID",
        f"cannot {operation} job {job.id} while status is {job.status.value}",
    )


def _positive_duration(value: timedelta, field: str) -> None:
    if value.total_seconds() <= 0:
        raise DomainError("JOB_DURATION_INVALID", f"{field} must be greater than zero")


def _assert_token(job: Job, token: LeaseToken, now: datetime) -> JobLease:
    lease = job.lease
    if (
        token.job_id != job.id
        or lease is None
        or token.worker_id != lease.worker_id
        or token.generation != lease.generation
    ):
        raise DomainError("JOB_STALE_WORKER", "worker lease token is stale or does not match")
    if now >= lease.expires_at:
        raise DomainError("JOB_LEASE_EXPIRED", "worker lease has expired")
    return lease


def acquire(
    job: Job, worker_id: str, now: datetime, lease_for: timedelta
) -> tuple[Job, LeaseToken]:
    if job.status is not JobStatus.QUEUED:
        raise _transition_error(job, "acquire")
    if now < job.available_at:
        raise DomainError("JOB_NOT_YET_AVAILABLE", "retry backoff has not elapsed")
    if now >= job.timeout_at:
        raise DomainError("JOB_TIMEOUT_DUE", "job timeout elapsed before lease acquisition")
    if not worker_id:
        raise DomainError("JOB_WORKER_INVALID", "worker id cannot be empty")
    _positive_duration(lease_for, "lease_for")
    generation = job.lease_generation + 1
    lease = JobLease(worker_id, generation, now, now + lease_for)
    started = job.started_at or now
    updated = job.bumped(
        status=JobStatus.RUNNING,
        stage="running",
        updated_at=now,
        started_at=started,
        lease=lease,
        lease_generation=generation,
        error=None,
    )
    return updated, LeaseToken(job.id, worker_id, generation)


def renew(job: Job, token: LeaseToken, now: datetime, lease_for: timedelta) -> Job:
    if job.status not in {JobStatus.RUNNING, JobStatus.CANCELLING}:
        raise _transition_error(job, "renew")
    _positive_duration(lease_for, "lease_for")
    lease = _assert_token(job, token, now)
    return job.bumped(
        updated_at=now,
        lease=JobLease(lease.worker_id, lease.generation, lease.acquired_at, now + lease_for),
    )


def update_progress(
    job: Job, token: LeaseToken, progress: float, stage: str, now: datetime
) -> Job:
    if job.status is not JobStatus.RUNNING:
        raise _transition_error(job, "update progress for")
    _assert_token(job, token, now)
    if not math.isfinite(progress) or not 0 <= progress <= 100:
        raise DomainError("JOB_PROGRESS_INVALID", "progress must be finite and between 0 and 100")
    if progress < job.progress:
        raise DomainError("JOB_PROGRESS_DECREASE", "job progress cannot decrease")
    if not stage:
        raise DomainError("JOB_STAGE_INVALID", "job stage cannot be empty")
    return job.bumped(progress=progress, stage=stage, updated_at=now)


def request_cancel(job: Job, now: datetime) -> tuple[Job, bool]:
    if job.terminal or job.status is JobStatus.CANCELLING:
        return job, False
    if job.status is JobStatus.QUEUED:
        return (
            job.bumped(
                status=JobStatus.CANCELLED,
                stage="cancelled",
                updated_at=now,
                finished_at=now,
                lease=None,
            ),
            True,
        )
    if job.status is JobStatus.RUNNING:
        return job.bumped(status=JobStatus.CANCELLING, stage="cancelling", updated_at=now), True
    raise _transition_error(job, "cancel")


def acknowledge_cancel(job: Job, token: LeaseToken, now: datetime) -> Job:
    if job.status is not JobStatus.CANCELLING:
        raise _transition_error(job, "acknowledge cancellation for")
    _assert_token(job, token, now)
    return job.bumped(
        status=JobStatus.CANCELLED,
        stage="cancelled",
        updated_at=now,
        finished_at=now,
        lease=None,
    )


def complete(
    job: Job,
    token: LeaseToken,
    now: datetime,
    status: JobStatus,
    resource_uri: str | None,
) -> Job:
    if job.status is not JobStatus.RUNNING:
        raise _transition_error(job, "complete")
    if status not in {JobStatus.SUCCEEDED, JobStatus.PARTIAL}:
        raise DomainError(
            "JOB_COMPLETION_STATUS_INVALID", "completion must be succeeded or partial"
        )
    _assert_token(job, token, now)
    return job.bumped(
        status=status,
        progress=100.0,
        stage="completed",
        updated_at=now,
        finished_at=now,
        resource_uri=resource_uri,
        lease=None,
        error=None,
    )


def fail(job: Job, token: LeaseToken, error: JobError, now: datetime) -> tuple[Job, bool]:
    if job.status is not JobStatus.RUNNING:
        raise _transition_error(job, "fail")
    _assert_token(job, token, now)
    if error.retryable and job.attempt < job.max_attempts:
        delay = min(
            job.retry_backoff_seconds * 2 ** (job.attempt - 1),
            job.retry_backoff_cap_seconds,
        )
        return (
            job.bumped(
                status=JobStatus.QUEUED,
                stage="retry_wait",
                attempt=job.attempt + 1,
                updated_at=now,
                available_at=now + timedelta(seconds=delay),
                lease=None,
                error=None,
            ),
            True,
        )
    return (
        job.bumped(
            status=JobStatus.FAILED,
            stage="failed",
            updated_at=now,
            finished_at=now,
            lease=None,
            error=error,
        ),
        False,
    )


def time_out(job: Job, now: datetime) -> Job:
    if job.terminal:
        return job
    if now < job.timeout_at:
        raise DomainError("JOB_TIMEOUT_NOT_DUE", "job timeout has not elapsed")
    return job.bumped(
        status=JobStatus.TIMED_OUT,
        stage="timed_out",
        updated_at=now,
        finished_at=now,
        lease=None,
        error=JobError("JOB_TIMED_OUT", "job exceeded its execution timeout", False),
    )


def recover_expired_lease(job: Job, now: datetime) -> tuple[Job, str]:
    if job.status not in {JobStatus.RUNNING, JobStatus.CANCELLING} or job.lease is None:
        raise _transition_error(job, "recover lease for")
    if now < job.lease.expires_at:
        raise DomainError("JOB_LEASE_NOT_EXPIRED", "worker lease has not expired")
    if job.status is JobStatus.CANCELLING:
        return (
            job.bumped(
                status=JobStatus.CANCELLED,
                stage="cancelled_after_worker_loss",
                updated_at=now,
                finished_at=now,
                lease=None,
            ),
            "cancelled",
        )
    if job.attempt < job.max_attempts:
        delay = min(
            job.retry_backoff_seconds * 2 ** (job.attempt - 1),
            job.retry_backoff_cap_seconds,
        )
        return (
            job.bumped(
                status=JobStatus.QUEUED,
                stage="recovered_retry_wait",
                attempt=job.attempt + 1,
                updated_at=now,
                available_at=now + timedelta(seconds=delay),
                lease=None,
            ),
            "retry",
        )
    return (
        job.bumped(
            status=JobStatus.FAILED,
            stage="failed_worker_lost",
            updated_at=now,
            finished_at=now,
            lease=None,
            error=JobError(
                "WORKER_LEASE_EXPIRED",
                "worker lease expired and retry attempts are exhausted",
                False,
            ),
        ),
        "failed",
    )


def expire(job: Job, now: datetime) -> Job:
    if job.status is JobStatus.EXPIRED:
        return job
    if job.status not in TERMINAL_STATUSES:
        raise _transition_error(job, "expire")
    if job.expires_at is None or now < job.expires_at:
        raise DomainError("JOB_EXPIRY_NOT_DUE", "job expiry has not elapsed")
    return job.bumped(
        status=JobStatus.EXPIRED,
        stage="expired",
        updated_at=now,
        resource_uri=None,
        lease=None,
    )
