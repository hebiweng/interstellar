from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi import FastAPI
from fastapi.testclient import TestClient

from interstellar_api.errors import install_problem_handlers
from interstellar_api.routers.m4_jobs import router
from interstellar_core.jobs import InMemoryJobStore, JobKind

NOW = datetime(2026, 7, 18, 0, 0, tzinfo=UTC)


def _client() -> tuple[TestClient, InMemoryJobStore]:
    app = FastAPI()
    store = InMemoryJobStore()
    app.state.job_store = store
    install_problem_handlers(app)
    app.include_router(router)
    return TestClient(app, raise_server_exceptions=False), store


def test_get_job_returns_canonical_job_shape() -> None:
    client, store = _client()
    store.create("job_api_get", JobKind.CALCULATION, now=NOW)

    response = client.get("/api/v1/jobs/job_api_get")
    assert response.status_code == 200
    payload = response.json()
    assert payload["id"] == "job_api_get"
    assert payload["status"] == "queued"
    assert payload["progress"] == 0
    assert payload["links"] == {
        "self": "/api/v1/jobs/job_api_get",
        "events": "/api/v1/jobs/job_api_get/events",
        "cancel": "/api/v1/jobs/job_api_get/cancel",
    }


def test_missing_job_is_canonical_problem_404() -> None:
    client, _ = _client()
    response = client.get("/api/v1/jobs/missing")

    assert response.status_code == 404
    assert response.headers["content-type"].startswith("application/problem+json")
    assert response.json()["code"] == "NOT_FOUND"
    assert response.json()["fields"]["domain_code"] == "JOB_NOT_FOUND"


def test_sse_replays_current_batch_then_closes_and_resumes() -> None:
    client, store = _client()
    store.create("job_api_events", JobKind.CALCULATION, now=NOW)
    _, token = store.acquire(
        "job_api_events", "worker", now=NOW, lease_for=timedelta(seconds=30)
    )
    store.update_progress(token, 40, "event_search", now=NOW + timedelta(seconds=1))

    first = client.get("/api/v1/jobs/job_api_events/events")
    assert first.status_code == 200
    assert first.headers["content-type"].startswith("text/event-stream")
    assert first.headers["cache-control"] == "no-cache"
    assert first.headers["x-interstellar-job-terminal"] == "false"
    event_ids = [line.removeprefix("id: ") for line in first.text.splitlines() if line.startswith("id: ")]
    assert len(event_ids) == 3
    assert "event: progress" in first.text

    store.complete(
        token,
        now=NOW + timedelta(seconds=2),
        resource_uri="/api/v1/calculations/calc_1",
    )
    resumed = client.get(
        "/api/v1/jobs/job_api_events/events",
        headers={"Last-Event-ID": event_ids[-1]},
    )
    assert resumed.status_code == 200
    assert resumed.headers["x-interstellar-job-terminal"] == "true"
    assert resumed.text.count("event: completed") == 1
    assert "calc_1" in resumed.text
    assert event_ids[-1] not in resumed.text


def test_invalid_or_ahead_last_event_id_maps_to_422_or_409() -> None:
    client, store = _client()
    store.create("job_api_cursor", JobKind.REPORT, now=NOW)

    malformed = client.get(
        "/api/v1/jobs/job_api_cursor/events",
        headers={"Last-Event-ID": "another-job:0000000000000001"},
    )
    assert malformed.status_code == 422
    assert malformed.json()["fields"]["domain_code"] == "JOB_EVENT_CURSOR_INVALID"

    ahead = client.get(
        "/api/v1/jobs/job_api_cursor/events",
        headers={"Last-Event-ID": "job_api_cursor:0000000000000099"},
    )
    assert ahead.status_code == 409
    assert ahead.json()["fields"]["domain_code"] == "JOB_EVENT_CURSOR_AHEAD"


def test_cancel_is_202_and_idempotent_without_duplicate_events() -> None:
    client, store = _client()
    store.create("job_api_cancel", JobKind.RENDER, now=NOW)

    first = client.post(
        "/api/v1/jobs/job_api_cancel/cancel",
        headers={"Idempotency-Key": "cancel-1"},
    )
    event_count = len(store.events_after("job_api_cancel").events)
    second = client.post(
        "/api/v1/jobs/job_api_cancel/cancel",
        headers={"Idempotency-Key": "cancel-1"},
    )

    assert first.status_code == second.status_code == 202
    assert first.json()["status"] == second.json()["status"] == "cancelled"
    assert len(store.events_after("job_api_cancel").events) == event_count == 2


def test_running_cancel_returns_cancelling_and_terminal_cancel_stays_terminal() -> None:
    client, store = _client()
    store.create("job_api_running", JobKind.BATCH, now=NOW)
    _, token = store.acquire(
        "job_api_running", "worker", now=NOW, lease_for=timedelta(days=3650)
    )
    cancelling = client.post("/api/v1/jobs/job_api_running/cancel")
    assert cancelling.status_code == 202
    assert cancelling.json()["status"] == "cancelling"
    store.acknowledge_cancel(token, now=NOW + timedelta(seconds=1))

    terminal = client.post("/api/v1/jobs/job_api_running/cancel")
    assert terminal.status_code == 202
    assert terminal.json()["status"] == "cancelled"


def test_router_reports_unconfigured_store_without_claiming_persistence() -> None:
    app = FastAPI()
    install_problem_handlers(app)
    app.include_router(router)
    client = TestClient(app, raise_server_exceptions=False)

    response = client.get("/api/v1/jobs/job_any")
    assert response.status_code == 500
    assert response.json()["code"] == "INTERNAL_ERROR"
    assert response.json()["retryable"] is True
