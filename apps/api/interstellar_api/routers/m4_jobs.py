"""M4 Job read, finite SSE replay, and idempotent cancellation routes."""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime
from typing import cast

from fastapi import APIRouter, Header, Request, status
from fastapi.responses import StreamingResponse
from interstellar_core.domain import DomainError
from interstellar_core.jobs import JobStore

from interstellar_api.errors import ErrorCode, ProblemException

router = APIRouter(prefix="/api/v1", tags=["Jobs"])


def _job_store(request: Request) -> JobStore:
    store = getattr(request.app.state, "job_store", None)
    if store is None or not isinstance(store, JobStore):
        raise ProblemException(
            status=500,
            code=ErrorCode.INTERNAL_ERROR,
            title="Job store unavailable",
            detail="The Job domain store has not been configured for this application.",
            retryable=True,
        )
    return cast(JobStore, store)


def _problem(error: DomainError) -> ProblemException:
    if error.code == "JOB_NOT_FOUND":
        return ProblemException(
            status=404,
            code=ErrorCode.NOT_FOUND,
            detail=error.detail,
            fields={"domain_code": error.code},
        )
    if error.code in {
        "JOB_EVENT_CURSOR_AHEAD",
        "JOB_TRANSITION_INVALID",
        "JOB_REVISION_CONFLICT",
    }:
        return ProblemException(
            status=409,
            code=ErrorCode.INVALID_REQUEST,
            title="Job state conflict",
            detail=error.detail,
            fields={"domain_code": error.code},
        )
    return ProblemException(
        status=422,
        code=ErrorCode.INVALID_REQUEST,
        title="Invalid Job request",
        detail=error.detail,
        fields={"domain_code": error.code},
    )


@router.get("/jobs/{job_id}", status_code=status.HTTP_200_OK)
def get_job(job_id: str, request: Request) -> dict[str, object]:
    try:
        return _job_store(request).get(job_id).to_canonical()
    except DomainError as error:
        raise _problem(error) from error


@router.get("/jobs/{job_id}/events", status_code=status.HTTP_200_OK)
def get_job_events(
    job_id: str,
    request: Request,
    last_event_id: str | None = Header(default=None, alias="Last-Event-ID"),
) -> StreamingResponse:
    try:
        batch = _job_store(request).events_after(job_id, last_event_id)
    except DomainError as error:
        raise _problem(error) from error

    def current_batch() -> Iterator[str]:
        for event in batch.events:
            yield event.to_sse()

    return StreamingResponse(
        current_batch(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
            "X-Interstellar-Job-Terminal": "true" if batch.terminal else "false",
        },
    )


@router.post("/jobs/{job_id}/cancel", status_code=status.HTTP_202_ACCEPTED)
def cancel_job(
    job_id: str,
    request: Request,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
) -> dict[str, object]:
    # Cancellation is state-idempotent even without a key. The header is accepted
    # for OpenAPI compatibility; durable key replay belongs to the persistence adapter.
    del idempotency_key
    try:
        job = _job_store(request).request_cancel(job_id, now=datetime.now(UTC))
    except DomainError as error:
        raise _problem(error) from error
    return job.to_canonical()
