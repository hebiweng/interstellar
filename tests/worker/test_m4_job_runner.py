from __future__ import annotations

from datetime import UTC, datetime, timedelta

from interstellar_core.jobs import InMemoryJobStore, JobKind, JobStatus
from interstellar_worker.job_runner import (
    DeterministicJobFailure,
    JobCancellationRequested,
    TransientJobFailure,
    WorkerJobRunner,
)


class Clock:
    def __init__(self) -> None:
        self.value = datetime(2026, 7, 18, tzinfo=UTC)

    def __call__(self) -> datetime:
        return self.value

    def advance(self, **kwargs: float) -> None:
        self.value += timedelta(**kwargs)


def test_runner_reports_progress_and_completes_with_resource() -> None:
    clock = Clock()
    store = InMemoryJobStore()
    store.create("job-1", JobKind.CALCULATION, now=clock())
    runner = WorkerJobRunner(store, worker_id="worker-1", now=clock)

    def handler(context):
        context.report_progress(50, "calculate")
        return "/api/v1/calculations/result-1"

    job = runner.execute("job-1", handler)
    assert job.status is JobStatus.SUCCEEDED
    assert job.resource_uri == "/api/v1/calculations/result-1"
    assert job.progress == 100


def test_transient_failure_requeues_but_deterministic_failure_terminates() -> None:
    clock = Clock()
    store = InMemoryJobStore()
    runner = WorkerJobRunner(store, worker_id="worker-1", now=clock)
    store.create("transient", JobKind.REPORT, now=clock())
    store.create("deterministic", JobKind.REPORT, now=clock())

    transient = runner.execute(
        "transient",
        lambda _context: (_ for _ in ()).throw(TransientJobFailure("network")),
    )
    deterministic = runner.execute(
        "deterministic",
        lambda _context: (_ for _ in ()).throw(DeterministicJobFailure("bad input")),
    )
    assert transient.status is JobStatus.QUEUED
    assert transient.attempt == 2
    assert deterministic.status is JobStatus.FAILED


def test_running_cancellation_is_cooperatively_acknowledged() -> None:
    clock = Clock()
    store = InMemoryJobStore()
    store.create("cancel", JobKind.RENDER, now=clock())
    runner = WorkerJobRunner(store, worker_id="worker-1", now=clock)

    def handler(context):
        store.request_cancel("cancel", now=clock())
        context.check_cancelled()
        raise AssertionError("unreachable")

    job = runner.execute("cancel", handler)
    assert job.status is JobStatus.CANCELLED


def test_handler_can_raise_explicit_cancellation() -> None:
    clock = Clock()
    store = InMemoryJobStore()
    store.create("cancel-explicit", JobKind.RENDER, now=clock())
    runner = WorkerJobRunner(store, worker_id="worker-1", now=clock)

    def handler(context):
        store.request_cancel("cancel-explicit", now=clock())
        raise JobCancellationRequested

    assert runner.execute("cancel-explicit", handler).status is JobStatus.CANCELLED


def test_maintenance_recovers_expired_lease_and_times_out_due_jobs() -> None:
    clock = Clock()
    store = InMemoryJobStore()
    store.create("leased", JobKind.CALCULATION, now=clock())
    store.acquire("leased", "dead-worker", now=clock(), lease_for=timedelta(seconds=5))
    store.create(
        "timeout",
        JobKind.CALCULATION,
        now=clock(),
        timeout=timedelta(seconds=3),
    )
    clock.advance(seconds=6)

    results = WorkerJobRunner(store, worker_id="maintenance", now=clock).maintain()
    assert {job.id for job in results} == {"leased", "timeout"}
    assert store.get("leased").status is JobStatus.QUEUED
    assert store.get("timeout").status is JobStatus.TIMED_OUT
