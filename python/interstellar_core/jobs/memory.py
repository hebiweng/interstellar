"""Thread-safe, process-local Job adapter for tests and domain development.

This adapter is intentionally non-durable. It is not a substitute for the M4
PostgreSQL/Redis implementation and loses all state when the process exits.
"""

from __future__ import annotations

import threading
from datetime import datetime, timedelta

from interstellar_core.domain.errors import DomainError

from . import state_machine
from .models import (
    EventBatch,
    Job,
    JobError,
    JobEvent,
    JobKind,
    JobLinks,
    JobStatus,
    LeaseToken,
    error_payload,
    event_payload,
)


class InMemoryJobStore:
    """non-durable reference implementation of atomic JobStore operations."""

    def __init__(self) -> None:
        self._jobs: dict[str, Job] = {}
        self._events: dict[str, list[JobEvent]] = {}
        self._lock = threading.RLock()

    def create(
        self,
        job_id: str,
        kind: JobKind,
        *,
        now: datetime,
        max_attempts: int = 4,
        timeout: timedelta | None = None,
        expires_at: datetime | None = None,
    ) -> Job:
        with self._lock:
            if now.tzinfo is None or now.utcoffset() is None:
                raise DomainError("JOB_TIME_INVALID", "job timestamps must be timezone-aware")
            if not job_id:
                raise DomainError("JOB_ID_INVALID", "job id cannot be empty")
            if job_id in self._jobs:
                raise DomainError("JOB_ALREADY_EXISTS", f"job already exists: {job_id}")
            if max_attempts < 1:
                raise DomainError("JOB_ATTEMPTS_INVALID", "max_attempts must be at least one")
            effective_timeout = timeout or (
                timedelta(minutes=30) if kind is JobKind.BATCH else timedelta(minutes=5)
            )
            if effective_timeout.total_seconds() <= 0:
                raise DomainError("JOB_DURATION_INVALID", "timeout must be greater than zero")
            links = JobLinks(
                self_uri=f"/api/v1/jobs/{job_id}",
                events_uri=f"/api/v1/jobs/{job_id}/events",
                cancel_uri=f"/api/v1/jobs/{job_id}/cancel",
            )
            job = Job(
                id=job_id,
                kind=kind,
                status=JobStatus.QUEUED,
                progress=0.0,
                stage="queued",
                attempt=1,
                max_attempts=max_attempts,
                links=links,
                created_at=now,
                updated_at=now,
                started_at=None,
                finished_at=None,
                expires_at=expires_at,
                timeout_at=now + effective_timeout,
                available_at=now,
                resource_uri=None,
                error=None,
                lease=None,
                lease_generation=0,
                retry_backoff_seconds=1.0,
                retry_backoff_cap_seconds=60.0,
                revision=1,
            )
            self._jobs[job_id] = job
            self._events[job_id] = []
            self._append(job, "progress", now)
            return job

    def get(self, job_id: str) -> Job:
        with self._lock:
            return self._require(job_id)

    def acquire(
        self, job_id: str, worker_id: str, *, now: datetime, lease_for: timedelta
    ) -> tuple[Job, LeaseToken]:
        with self._lock:
            job, token = state_machine.acquire(self._require(job_id), worker_id, now, lease_for)
            self._save(job)
            self._append(job, "progress", now, worker_id=worker_id)
            return job, token

    def renew(self, token: LeaseToken, *, now: datetime, lease_for: timedelta) -> Job:
        with self._lock:
            job = state_machine.renew(self._require(token.job_id), token, now, lease_for)
            self._save(job)
            return job

    def update_progress(
        self, token: LeaseToken, progress: float, stage: str, *, now: datetime
    ) -> Job:
        with self._lock:
            job = state_machine.update_progress(
                self._require(token.job_id), token, progress, stage, now
            )
            self._save(job)
            self._append(job, "progress", now)
            return job

    def complete(
        self,
        token: LeaseToken,
        *,
        now: datetime,
        status: JobStatus = JobStatus.SUCCEEDED,
        resource_uri: str | None = None,
    ) -> Job:
        with self._lock:
            job = state_machine.complete(
                self._require(token.job_id), token, now, status, resource_uri
            )
            self._save(job)
            self._append(job, "completed", now, resource=resource_uri)
            return job

    def fail(self, token: LeaseToken, error: JobError, *, now: datetime) -> Job:
        with self._lock:
            job, retry_scheduled = state_machine.fail(
                self._require(token.job_id), token, error, now
            )
            self._save(job)
            if retry_scheduled:
                self._append(
                    job,
                    "warning",
                    now,
                    warning="retry_scheduled",
                    error=error_payload(error),
                    available_at=job.available_at.isoformat(),
                )
            else:
                self._append(job, "failed", now, error=error_payload(error))
            return job

    def request_cancel(self, job_id: str, *, now: datetime) -> Job:
        with self._lock:
            current = self._require(job_id)
            job, changed = state_machine.request_cancel(current, now)
            if not changed:
                return current
            self._save(job)
            event_name = "completed" if job.status is JobStatus.CANCELLED else "warning"
            self._append(job, event_name, now, warning="cancellation_requested")
            return job

    def acknowledge_cancel(self, token: LeaseToken, *, now: datetime) -> Job:
        with self._lock:
            job = state_machine.acknowledge_cancel(self._require(token.job_id), token, now)
            self._save(job)
            self._append(job, "completed", now)
            return job

    def events_after(self, job_id: str, last_event_id: str | None = None) -> EventBatch:
        with self._lock:
            job = self._require(job_id)
            events = self._events[job_id]
            sequence = self._parse_cursor(job_id, last_event_id)
            if sequence > len(events):
                raise DomainError(
                    "JOB_EVENT_CURSOR_AHEAD", "Last-Event-ID is ahead of the event stream"
                )
            selected = tuple(event for event in events if event.sequence > sequence)
            final_id = selected[-1].event_id if selected else last_event_id
            return EventBatch(events=selected, terminal=job.terminal, last_event_id=final_id)

    def recover_expired_leases(self, *, now: datetime) -> tuple[Job, ...]:
        recovered: list[Job] = []
        with self._lock:
            for current in tuple(self._jobs.values()):
                if (
                    current.status not in {JobStatus.RUNNING, JobStatus.CANCELLING}
                    or current.lease is None
                    or now < current.lease.expires_at
                ):
                    continue
                job, outcome = state_machine.recover_expired_lease(current, now)
                self._save(job)
                event_name = "failed" if outcome == "failed" else (
                    "completed" if outcome == "cancelled" else "warning"
                )
                self._append(job, event_name, now, recovery=outcome)
                recovered.append(job)
        return tuple(recovered)

    def time_out_due(self, *, now: datetime) -> tuple[Job, ...]:
        timed_out: list[Job] = []
        with self._lock:
            for current in tuple(self._jobs.values()):
                if current.terminal or now < current.timeout_at:
                    continue
                job = state_machine.time_out(current, now)
                self._save(job)
                self._append(job, "failed", now, error=error_payload(job.error))
                timed_out.append(job)
        return tuple(timed_out)

    def expire_due(self, *, now: datetime) -> tuple[Job, ...]:
        expired: list[Job] = []
        with self._lock:
            for current in tuple(self._jobs.values()):
                if (
                    not current.terminal
                    or current.status is JobStatus.EXPIRED
                    or current.expires_at is None
                    or now < current.expires_at
                ):
                    continue
                job = state_machine.expire(current, now)
                self._save(job)
                self._append(job, "completed", now)
                expired.append(job)
        return tuple(expired)

    def _require(self, job_id: str) -> Job:
        try:
            return self._jobs[job_id]
        except KeyError as exc:
            raise DomainError("JOB_NOT_FOUND", f"job not found: {job_id}") from exc

    def _save(self, job: Job) -> None:
        current = self._jobs[job.id]
        if job.revision != current.revision + 1:
            raise DomainError("JOB_REVISION_CONFLICT", "job revision is not the expected successor")
        self._jobs[job.id] = job

    def _append(self, job: Job, name: str, now: datetime, **extra: object) -> None:
        events = self._events[job.id]
        events.append(
            JobEvent(
                job_id=job.id,
                sequence=len(events) + 1,
                name=name,
                occurred_at=now,
                data=event_payload(job, **extra),
            )
        )

    @staticmethod
    def _parse_cursor(job_id: str, last_event_id: str | None) -> int:
        if last_event_id in {None, ""}:
            return 0
        prefix = f"{job_id}:"
        if not last_event_id.startswith(prefix):
            raise DomainError(
                "JOB_EVENT_CURSOR_INVALID", "Last-Event-ID belongs to another job or is malformed"
            )
        suffix = last_event_id[len(prefix) :]
        if len(suffix) != 16 or not suffix.isdigit():
            raise DomainError("JOB_EVENT_CURSOR_INVALID", "Last-Event-ID sequence is malformed")
        return int(suffix)
