"""Canonical Job values plus internal retry and lease state."""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, replace
from datetime import UTC, datetime
from enum import StrEnum
from typing import Any


class JobKind(StrEnum):
    CALCULATION = "calculation"
    RENDER = "render"
    REPORT = "report"
    IMPORT = "import"
    EXPORT = "export"
    DATASET_SYNC = "dataset_sync"
    BATCH = "batch"


class JobStatus(StrEnum):
    QUEUED = "queued"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    PARTIAL = "partial"
    FAILED = "failed"
    CANCELLING = "cancelling"
    CANCELLED = "cancelled"
    TIMED_OUT = "timed_out"
    EXPIRED = "expired"


TERMINAL_STATUSES = frozenset(
    {
        JobStatus.SUCCEEDED,
        JobStatus.PARTIAL,
        JobStatus.FAILED,
        JobStatus.CANCELLED,
        JobStatus.TIMED_OUT,
        JobStatus.EXPIRED,
    }
)


def _iso(value: datetime | None) -> str | None:
    if value is None:
        return None
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


@dataclass(frozen=True, slots=True)
class JobLinks:
    self_uri: str
    events_uri: str
    cancel_uri: str


@dataclass(frozen=True, slots=True)
class JobError:
    code: str
    detail: str
    retryable: bool


@dataclass(frozen=True, slots=True)
class JobLease:
    worker_id: str
    generation: int
    acquired_at: datetime
    expires_at: datetime


@dataclass(frozen=True, slots=True)
class LeaseToken:
    job_id: str
    worker_id: str
    generation: int


@dataclass(frozen=True, slots=True)
class Job:
    id: str
    kind: JobKind
    status: JobStatus
    progress: float
    stage: str
    attempt: int
    max_attempts: int
    links: JobLinks
    created_at: datetime
    updated_at: datetime
    started_at: datetime | None
    finished_at: datetime | None
    expires_at: datetime | None
    timeout_at: datetime
    available_at: datetime
    resource_uri: str | None
    error: JobError | None
    lease: JobLease | None
    lease_generation: int
    retry_backoff_seconds: float
    retry_backoff_cap_seconds: float
    revision: int

    @property
    def terminal(self) -> bool:
        return self.status in TERMINAL_STATUSES

    @property
    def cancellable(self) -> bool:
        return self.status in {JobStatus.QUEUED, JobStatus.RUNNING}

    def to_canonical(self) -> dict[str, Any]:
        error: dict[str, Any] | None = None
        if self.error is not None:
            canonical_code = (
                "CALCULATION_TIMEOUT"
                if self.error.code == "JOB_TIMED_OUT"
                else "INTERNAL_ERROR"
            )
            error = {
                "type": f"https://interstellar.dev/problems/{canonical_code.lower()}",
                "title": self.error.code,
                "status": 504 if canonical_code == "CALCULATION_TIMEOUT" else 500,
                "detail": self.error.detail,
                "code": canonical_code,
                "instance": self.links.self_uri,
                "request_id": self.id,
                "retryable": self.error.retryable,
            }
        return {
            "id": self.id,
            "kind": self.kind.value,
            "status": self.status.value,
            "progress": self.progress,
            "stage": self.stage,
            "attempt": self.attempt,
            "max_attempts": self.max_attempts,
            "cancellable": self.cancellable,
            "resource_uri": self.resource_uri,
            "error": error,
            "links": {
                "self": self.links.self_uri,
                "events": self.links.events_uri,
                "cancel": self.links.cancel_uri,
            },
            "created_at": _iso(self.created_at),
            "updated_at": _iso(self.updated_at),
            "started_at": _iso(self.started_at),
            "finished_at": _iso(self.finished_at),
            "expires_at": _iso(self.expires_at),
        }

    def bumped(self, **changes: Any) -> Job:
        return replace(self, revision=self.revision + 1, **changes)


@dataclass(frozen=True, slots=True)
class JobEvent:
    job_id: str
    sequence: int
    name: str
    occurred_at: datetime
    data: dict[str, Any]

    @property
    def event_id(self) -> str:
        return f"{self.job_id}:{self.sequence:016d}"

    def to_sse(self) -> str:
        data = json.dumps(self.data, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        return f"id: {self.event_id}\nevent: {self.name}\ndata: {data}\n\n"


@dataclass(frozen=True, slots=True)
class EventBatch:
    events: tuple[JobEvent, ...]
    terminal: bool
    last_event_id: str | None


def event_payload(job: Job, **extra: Any) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "status": job.status.value,
        "progress": job.progress,
        "stage": job.stage,
        "attempt": job.attempt,
    }
    payload.update(extra)
    return payload


def error_payload(error: JobError) -> dict[str, Any]:
    return asdict(error)
