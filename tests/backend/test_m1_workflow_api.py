from __future__ import annotations

from fastapi.testclient import TestClient

from interstellar_api.config import ApiSettings
from interstellar_api.main import create_app


def _client() -> TestClient:
    return TestClient(create_app(ApiSettings(environment="test")))


def _birth_payload(local_value: str = "1990-06-15T12:30") -> dict:
    return {
        "workspace_id": "workspace-test",
        "version": {
            "kind": "person",
            "display_name": "M1 Virtual Subject",
            "time_spec": {
                "calendar": "gregorian",
                "local_value": local_value,
                "precision": "minute",
                "timezone_id": "Asia/Shanghai",
                "utc_candidates": [],
                "selected_utc": None,
                "confidence": "high",
                "source": {"kind": "user_entered"},
                "warnings": [],
            },
            "location": {
                "name": "Shanghai",
                "country_code": "CN",
                "latitude": 31.2304,
                "longitude": 121.4737,
                "timezone_id": "Asia/Shanghai",
                "source": "test_fixture",
                "warnings": [],
            },
            "attributes": {},
            "source": {"kind": "user_entered"},
        },
    }


def test_birth_input_to_version_recipe_preflight_and_noncomputing_snapshot() -> None:
    with _client() as client:
        subject_response = client.post("/api/v1/subjects", json=_birth_payload())
        assert subject_response.status_code == 201
        saved = subject_response.json()
        version = saved["version"]
        assert version["version"] == 1
        assert version["content_hash"].startswith("sha256:")
        # China observed daylight-saving time on this historical date (UTC+09:00).
        assert version["time_spec"]["selected_utc"] == "1990-06-15T03:30:00+00:00"

        draft_response = client.post(
            "/api/v1/analysis-drafts",
            json={
                "workspace_id": "workspace-test",
                "entry_point_id": "entry.object_context",
                "selection": {"analysis_model_id": "natal.modern.v1"},
                "subject_roles": [
                    {"role": "primary", "subject_version_id": version["id"]}
                ],
                "requested_outputs": {"exports": ["json"]},
            },
        )
        assert draft_response.status_code == 201
        draft = draft_response.json()

        recipe_response = client.post(
            "/api/v1/analysis-recipes/resolve",
            json={"draft_id": draft["draft_id"], "draft_revision": 1},
        )
        assert recipe_response.status_code == 201
        recipe = recipe_response.json()
        assert recipe["status"] == "resolved"
        assert any(node["availability"] == "available" for node in recipe["nodes"])
        assert any(node["availability"] == "blocked" for node in recipe["nodes"])
        assert any(
            warning["code"] == "CAPABILITY_NOT_IMPLEMENTED"
            for warning in recipe["warnings"]
        )

        snapshot_response = client.post(
            f"/api/v1/analysis-recipes/{recipe['recipe_id']}/confirm",
            json={
                "recipe_content_hash": recipe["content_hash"],
                "outputs": ["snapshot"],
                "report_requests": [],
            },
        )
        assert snapshot_response.status_code == 201
        snapshot = snapshot_response.json()
        assert snapshot["status"] == "partial"
        assert snapshot["result"]["charts"] == []
        assert snapshot["warnings"][0]["code"] == "M1_CALCULATION_NOT_EXECUTED"

        get_response = client.get(f"/api/v1/calculations/{snapshot['id']}")
        assert get_response.status_code == 200
        assert get_response.json() == snapshot


def test_dst_gap_is_rejected_as_problem_details() -> None:
    payload = _birth_payload("2024-03-10T02:30")
    payload["version"]["time_spec"]["timezone_id"] = "America/New_York"
    with _client() as client:
        response = client.post("/api/v1/subjects", json=payload)

    assert response.status_code == 422
    assert response.headers["content-type"].startswith("application/problem+json")
    assert response.json()["fields"]["time_spec"]["code"] == "TIME_NONEXISTENT_LOCAL"


def test_analysis_draft_get_patch_revision_and_recipe_get() -> None:
    with _client() as client:
        version = client.post("/api/v1/subjects", json=_birth_payload()).json()["version"]
        created = client.post(
            "/api/v1/analysis-drafts",
            json={
                "workspace_id": "workspace-test",
                "entry_point_id": "entry.object_context",
                "selection": {"analysis_model_id": "natal.modern.v1"},
                "subject_roles": [
                    {"role": "primary", "subject_version_id": version["id"]}
                ],
                "requested_outputs": {"exports": ["json"]},
            },
        ).json()

        fetched = client.get(f"/api/v1/analysis-drafts/{created['draft_id']}")
        updated = client.patch(
            f"/api/v1/analysis-drafts/{created['draft_id']}",
            headers={"If-Match": "1"},
            json={"optional_extensions": ["natal.patterns_distributions"]},
        )
        stale = client.patch(
            f"/api/v1/analysis-drafts/{created['draft_id']}",
            headers={"If-Match": "1"},
            json={"requested_outputs": {"exports": ["csv"]}},
        )

        recipe = client.post(
            "/api/v1/analysis-recipes/resolve",
            json={"draft_id": created["draft_id"], "draft_revision": 2},
        ).json()
        recipe_get = client.get(f"/api/v1/analysis-recipes/{recipe['recipe_id']}")

    assert fetched.status_code == 200
    assert fetched.json() == created
    assert updated.status_code == 200
    assert updated.json()["revision"] == 2
    assert updated.json()["optional_extensions"] == ["natal.patterns_distributions"]
    assert stale.status_code == 409
    assert recipe_get.status_code == 200
    assert recipe_get.json() == recipe


def test_six_product_entries_resolve_through_one_api_pipeline() -> None:
    cases = [
        ("entry.technique", {"technique_id": "natal.standard_chart"}),
        ("entry.topic_model", {"topic_model_id": "personality.modern.v1"}),
        ("entry.object_context", {"analysis_model_id": "natal.modern.v1"}),
        ("entry.personal_dashboard", {"analysis_model_id": "natal.modern.v1"}),
        ("entry.intent", {"analysis_intent_id": "intent.natal_overview"}),
        ("entry.context_shortcut", {"topic_model_id": "timing.short_term.v1"}),
    ]
    with _client() as client:
        version = client.post("/api/v1/subjects", json=_birth_payload()).json()["version"]
        for entry_point, selection in cases:
            draft = client.post(
                "/api/v1/analysis-drafts",
                json={
                    "workspace_id": "workspace-test",
                    "entry_point_id": entry_point,
                    "selection": selection,
                    "subject_roles": [
                        {"role": "primary", "subject_version_id": version["id"]}
                    ],
                    "requested_outputs": {"exports": ["json"]},
                },
            ).json()
            response = client.post(
                "/api/v1/analysis-recipes/resolve",
                json={"draft_id": draft["draft_id"], "draft_revision": 1},
            )
            assert response.status_code == 201, response.text
            recipe = response.json()
            assert recipe["entry_point_id"] == entry_point
            assert recipe["nodes"]
            assert recipe["content_hash"].startswith("sha256:")


def test_confirmed_recipe_can_create_async_job_and_stream_initial_event() -> None:
    with _client() as client:
        version = client.post("/api/v1/subjects", json=_birth_payload()).json()["version"]
        draft = client.post(
            "/api/v1/analysis-drafts",
            json={
                "workspace_id": "workspace-test",
                "entry_point_id": "entry.object_context",
                "selection": {"analysis_model_id": "natal.modern.v1"},
                "subject_roles": [
                    {"role": "primary", "subject_version_id": version["id"]}
                ],
                "requested_outputs": {"exports": ["json"]},
            },
        ).json()
        recipe = client.post(
            "/api/v1/analysis-recipes/resolve",
            json={"draft_id": draft["draft_id"], "draft_revision": 1},
        ).json()

        accepted = client.post(
            f"/api/v1/analysis-recipes/{recipe['recipe_id']}/confirm",
            headers={"Prefer": "respond-async"},
            json={
                "recipe_content_hash": recipe["content_hash"],
                "outputs": ["snapshot"],
                "report_requests": [],
            },
        )
        assert accepted.status_code == 202, accepted.text
        job = accepted.json()
        assert accepted.headers["location"] == job["links"]["self"]
        assert client.get(job["links"]["self"]).json() == job
        events = client.get(job["links"]["events"])
        assert events.status_code == 200
        assert "event: progress" in events.text

        confirmed = client.get(f"/api/v1/analysis-recipes/{recipe['recipe_id']}")
        assert confirmed.json()["status"] == "confirmed"
