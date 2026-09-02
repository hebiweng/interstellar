from __future__ import annotations

from fastapi.testclient import TestClient

from interstellar_api.config import ApiSettings
from interstellar_api.main import create_app


def client(tmp_path) -> TestClient:
    settings = ApiSettings(
        environment="test",
        account_database_path=str(tmp_path / "accounts.sqlite3"),
        auth_cookie_secure=False,
    )
    return TestClient(create_app(settings))


def register(test_client: TestClient, email: str = "owner@example.com") -> None:
    response = test_client.post(
        "/api/v1/account/register",
        json={
            "email": email,
            "password": "correct-horse-battery",
            "display_name": "测试用户",
        },
    )
    assert response.status_code == 200
    assert response.json()["authenticated"] is True
    assert "interstellar_session=" in response.headers["set-cookie"]


def test_guest_workspace_is_empty_and_non_persistent(tmp_path) -> None:
    with client(tmp_path) as test_client:
        response = test_client.get("/api/v1/account/workspace")
        assert response.status_code == 200
        assert response.json() == {
            "authenticated": False,
            "user": None,
            "people": [],
        }
        denied = test_client.post(
            "/api/v1/account/workspace",
            json={"action": "save_person", "person": {"displayName": "游客"}},
        )
        assert denied.status_code == 401


def test_registration_login_logout_and_duplicate_email(tmp_path) -> None:
    with client(tmp_path) as test_client:
        register(test_client)
        duplicate = test_client.post(
            "/api/v1/account/register",
            json={
                "email": "OWNER@example.com",
                "password": "another-password",
                "display_name": "重复账户",
            },
        )
        assert duplicate.status_code == 409

        logout = test_client.post("/api/v1/account/logout")
        assert logout.status_code == 200
        assert test_client.get("/api/v1/account/workspace").json()["authenticated"] is False

        failed = test_client.post(
            "/api/v1/account/login",
            json={"email": "owner@example.com", "password": "wrong-password"},
        )
        assert failed.status_code == 401
        logged_in = test_client.post(
            "/api/v1/account/login",
            json={
                "email": "owner@example.com",
                "password": "correct-horse-battery",
            },
        )
        assert logged_in.status_code == 200


def test_latest_natal_overwrites_and_accounts_are_isolated(tmp_path) -> None:
    first = client(tmp_path)
    second = client(tmp_path)
    with first, second:
        register(first, "first@example.com")
        saved = first.post(
            "/api/v1/account/workspace",
            json={
                "action": "save_person",
                "person": {
                    "displayName": "小王",
                    "relation": "self",
                    "localDate": "2000-03-01",
                },
            },
        )
        assert saved.status_code == 200
        person_id = saved.json()["id"]

        for snapshot_id in ("calculation-first", "calculation-latest"):
            result = first.post(
                "/api/v1/account/workspace",
                json={
                    "action": "save_latest_natal",
                    "personId": person_id,
                    "snapshot": {"id": snapshot_id, "result": {}},
                    "settings": {"zodiac": "tropical"},
                    "groups": {"core": True},
                    "analysisDocument": f"# {snapshot_id}",
                    "analysisDocumentHash": snapshot_id,
                },
            )
            assert result.status_code == 200

        workspace = first.get("/api/v1/account/workspace").json()
        assert len(workspace["people"]) == 1
        assert workspace["people"][0]["latestNatal"]["snapshotId"] == "calculation-latest"

        stale_analysis = first.post(
            "/api/v1/account/workspace",
            json={
                "action": "save_ai_analysis",
                "personId": person_id,
                "snapshotId": "calculation-first",
                "aiAnalysisText": "这份迟到的旧分析不能覆盖最新结果。",
                "aiModelId": "deepseek-test",
            },
        )
        assert stale_analysis.status_code == 409
        assert stale_analysis.json()["error"] == "STALE_AI_ANALYSIS"

        latest_analysis = first.post(
            "/api/v1/account/workspace",
            json={
                "action": "save_ai_analysis",
                "personId": person_id,
                "snapshotId": "calculation-latest",
                "aiAnalysisText": "只保存当前星盘的最后一次分析。",
                "aiModelId": "deepseek-test",
            },
        )
        assert latest_analysis.status_code == 200
        refreshed = first.get("/api/v1/account/workspace").json()
        assert refreshed["people"][0]["latestNatal"]["aiAnalysisText"] == (
            "只保存当前星盘的最后一次分析。"
        )

        register(second, "second@example.com")
        isolated = second.get("/api/v1/account/workspace").json()
        assert isolated["people"] == []
        forbidden = second.post(
            "/api/v1/account/workspace",
            json={
                "action": "save_latest_natal",
                "personId": person_id,
                "snapshot": {"id": "cross-account"},
                "analysisDocument": "not allowed",
            },
        )
        assert forbidden.status_code == 404


def test_account_preferences_validate_default_person_and_clear_on_delete(tmp_path) -> None:
    with client(tmp_path) as test_client:
        register(test_client)
        initial = test_client.get("/api/v1/account/workspace").json()
        assert initial["preferences"] == {
            "defaultPersonId": None,
            "sampleVisible": True,
        }
        saved = test_client.post(
            "/api/v1/account/workspace",
            json={
                "action": "save_person",
                "person": {"displayName": "默认人物", "relation": "self"},
            },
        ).json()
        person_id = saved["id"]
        preferences = test_client.patch(
            "/api/v1/account/preferences",
            json={"default_person_id": person_id, "sample_visible": False},
        )
        assert preferences.status_code == 200
        assert preferences.json()["preferences"] == {
            "defaultPersonId": person_id,
            "sampleVisible": False,
        }
        invalid = test_client.patch(
            "/api/v1/account/preferences",
            json={"default_person_id": "somebody-elses-person"},
        )
        assert invalid.status_code == 404
        deleted = test_client.post(
            "/api/v1/account/workspace",
            json={"action": "delete_person", "personId": person_id},
        )
        assert deleted.status_code == 200
        after = test_client.get("/api/v1/account/preferences").json()["preferences"]
        assert after == {"defaultPersonId": None, "sampleVisible": False}
