"""Persistence protocol for future PostgreSQL/Redis adapters."""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Protocol, runtime_checkable

from .models import EventBatch, Job, JobError, JobKind, JobStatus, LeaseToken


@runtime_checkable
class JobStore(Protocol):
    """Atomic Job operations; implementations own locking and persistence semantics."""

    def create(
        self,
        job_id: str,
        kind: JobKind,
        *,
        now: datetime,
        max_attempts: int = 4,
        timeout: timedelta | None = None,
        expires_at: datetime | None = None,
    ) -> Job: ...

    def get(self, job_id: str) -> Job: ...

    def acquire(
        self, job_id: str, worker_id: str, *, now: datetime, lease_for: timedelta
    ) -> tuple[Job, LeaseToken]: ...

    def renew(
        self, token: LeaseToken, *, now: datetime, lease_for: timedelta
    ) -> Job: ...

    def update_progress(
        self, token: LeaseToken, progress: float, stage: str, *, now: datetime
    ) -> Job: ...

    def complete(
        self,
        token: LeaseToken,
        *,
        now: datetime,
        status: JobStatus = JobStatus.SUCCEEDED,
        resource_uri: str | None = None,
    ) -> Job: ...

    def fail(self, token: LeaseToken, error: JobError, *, now: datetime) -> Job: ...

    def request_cancel(self, job_id: str, *, now: datetime) -> Job: ...

    def acknowledge_cancel(self, token: LeaseToken, *, now: datetime) -> Job: ...

    def events_after(self, job_id: str, last_event_id: str | None = None) -> EventBatch: ...

    def recover_expired_leases(self, *, now: datetime) -> tuple[Job, ...]: ...

    def time_out_due(self, *, now: datetime) -> tuple[Job, ...]: ...

    def expire_due(self, *, now: datetime) -> tuple[Job, ...]: ...
