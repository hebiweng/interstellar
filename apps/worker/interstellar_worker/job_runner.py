"""Explicit leased-job execution adapter for the M4 JobStore port.

Queue discovery is deliberately outside this adapter. A broker consumer hands
it a concrete job id; this keeps lease, retry, cancellation and completion
semantics testable without pretending the process-local store is durable.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from interstellar_core.jobs import Job, JobError, JobStatus, JobStore, LeaseToken


class DeterministicJobFailure(RuntimeError):
    """The same input will fail again and must not be retried."""


class TransientJobFailure(RuntimeError):
    """An infrastructure failure that may succeed on a bounded retry."""


class JobCancellationRequested(RuntimeError):
    """Cooperative stop requested by the API or another control plane."""


@dataclass(slots=True)
class WorkerJobContext:
    store: JobStore
    token: LeaseToken
    now: Callable[[], datetime]

    def report_progress(self, progress: float, stage: str) -> Job:
        return self.store.update_progress(self.token, progress, stage, now=self.now())

    @property
    def cancellation_requested(self) -> bool:
        return self.store.get(self.token.job_id).status is JobStatus.CANCELLING

    def check_cancelled(self) -> None:
        if self.cancellation_requested:
            raise JobCancellationRequested("job cancellation was requested")


JobHandler = Callable[[WorkerJobContext], str | None]


class WorkerJobRunner:
    def __init__(
        self,
        store: JobStore,
        *,
        worker_id: str,
        lease_for: timedelta = timedelta(seconds=30),
        now: Callable[[], datetime] | None = None,
    ) -> None:
        self.store = store
        self.worker_id = worker_id
        self.lease_for = lease_for
        self.now = now or (lambda: datetime.now(UTC))

    def execute(self, job_id: str, handler: JobHandler) -> Job:
        _job, token = self.store.acquire(
            job_id,
            self.worker_id,
            now=self.now(),
            lease_for=self.lease_for,
        )
        context = WorkerJobContext(self.store, token, self.now)
        try:
            context.check_cancelled()
            resource_uri = handler(context)
            context.check_cancelled()
        except JobCancellationRequested:
            return self.store.acknowledge_cancel(token, now=self.now())
        except DeterministicJobFailure as exc:
            return self.store.fail(
                token,
                JobError("JOB_HANDLER_DETERMINISTIC", str(exc), False),
                now=self.now(),
            )
        except TransientJobFailure as exc:
            return self.store.fail(
                token,
                JobError("JOB_HANDLER_TRANSIENT", str(exc), True),
                now=self.now(),
            )
        return self.store.complete(token, now=self.now(), resource_uri=resource_uri)

    def maintain(self) -> tuple[Job, ...]:
        now = self.now()
        recovered = self.store.recover_expired_leases(now=now)
        timed_out = self.store.time_out_due(now=now)
        expired = self.store.expire_due(now=now)
        return (*recovered, *timed_out, *expired)
