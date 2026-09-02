from __future__ import annotations

import sqlite3

from fastapi.testclient import TestClient
from pydantic import SecretStr

from interstellar_api.account_store import AccountStore
from interstellar_api.config import ApiSettings
from interstellar_api.main import create_app

ADMIN_EMAIL = "root-admin@example.com"
ADMIN_PASSWORD = "correct-horse-battery-admin"


def admin_app(tmp_path, *, master_key: bool = True):
    settings = ApiSettings(
        environment="test",
        account_database_path=str(tmp_path / "accounts.sqlite3"),
        auth_cookie_secure=False,
        admin_bootstrap_email=ADMIN_EMAIL,
        admin_bootstrap_password=SecretStr(ADMIN_PASSWORD),
        admin_master_key=(SecretStr("m" * 48) if master_key else None),
    )
    return create_app(settings)


def login_admin(client: TestClient) -> None:
    response = client.post(
        "/api/v1/account/login",
        json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
    )
    assert response.status_code == 200, response.text
    assert response.json()["user"]["role"] == "super_admin"


def test_additive_account_migration_keeps_existing_accounts(tmp_path) -> None:
    path = tmp_path / "legacy.sqlite3"
    with sqlite3.connect(path) as connection:
        connection.execute(
            """
            CREATE TABLE accounts (
                email TEXT PRIMARY KEY, display_name TEXT NOT NULL,
                password_salt TEXT NOT NULL, password_hash TEXT NOT NULL,
                created_at TEXT NOT NULL, updated_at TEXT NOT NULL
            )
            """
        )
        connection.execute(
            """
            INSERT INTO accounts VALUES
                ('legacy@example.com', 'Legacy', '00', '00', '2026-01-01', '2026-01-01')
            """
        )
    store = AccountStore(str(path))
    migrated = store.get_user("legacy@example.com")
    assert migrated["role"] == "user"
    assert migrated["status"] == "active"


def test_admin_routes_are_server_authorized_and_last_super_admin_is_protected(tmp_path) -> None:
    app = admin_app(tmp_path)
    with TestClient(app) as anonymous:
        assert anonymous.get("/api/v1/admin/overview").status_code == 403

    with TestClient(app) as admin:
        login_admin(admin)
        created = admin.post(
            "/api/v1/admin/users",
            json={
                "email": "member@example.com",
                "display_name": "Member",
                "password": "member-password-123",
            },
        )
        assert created.status_code == 200, created.text
        disabled = admin.patch(
            "/api/v1/admin/users",
            json={
                "email": "member@example.com",
                "status": "disabled",
                "reason": "manual review",
            },
        )
        assert disabled.status_code == 200
        assert disabled.json()["status"] == "disabled"
        cannot_disable_self = admin.patch(
            "/api/v1/admin/users",
            json={"email": ADMIN_EMAIL, "status": "disabled"},
        )
        assert cannot_disable_self.status_code == 403
        cannot_remove_last = admin.patch(
            "/api/v1/admin/admins",
            json={"email": ADMIN_EMAIL, "role": "user"},
        )
        assert cannot_remove_last.status_code == 409

    with TestClient(app) as member:
        denied = member.post(
            "/api/v1/account/login",
            json={"email": "member@example.com", "password": "member-password-123"},
        )
        assert denied.status_code == 403


def test_analytics_accepts_only_allowlisted_metadata_and_admin_summarizes(tmp_path) -> None:
    app = admin_app(tmp_path)
    with TestClient(app) as visitor:
        accepted = visitor.post(
            "/api/v1/analytics/events",
            json={
                "event_name": "page_view",
                "duration_ms": 15,
                "metadata": {
                    "page": "/natal",
                    "password": "must-never-be-recorded",
                    "birth_document": {"secret": True},
                },
            },
        )
        assert accepted.status_code == 200
        assert "interstellar_visitor=" in accepted.headers["set-cookie"]
        rejected = visitor.post(
            "/api/v1/analytics/events", json={"event_name": "free_form_event"}
        )
        assert rejected.status_code == 422

    with TestClient(app) as admin:
        login_admin(admin)
        overview = admin.get("/api/v1/admin/overview").json()
        assert overview["analytics"]["pageViews"] == 1
        assert overview["analytics"]["uniqueVisitors"] == 1
    with sqlite3.connect(tmp_path / "accounts.sqlite3") as connection:
        metadata = connection.execute(
            "SELECT metadata_json FROM analytics_events WHERE event_name = 'page_view'"
        ).fetchone()[0]
    assert "must-never-be-recorded" not in metadata
    assert "birth_document" not in metadata


def test_provider_keys_are_encrypted_masked_and_prompts_are_versioned(tmp_path) -> None:
    app = admin_app(tmp_path)
    with TestClient(app) as admin:
        login_admin(admin)
        created = admin.post(
            "/api/v1/admin/providers",
            json={
                "provider_id": "example-ai",
                "display_name": "Example AI",
                "base_url": "https://ai.example.test/v1",
                "enabled": True,
                "default": True,
                "api_key": "secret-provider-key-1234",
                "timeout": 45,
                "models": [
                    {
                        "model_id": "example-pro",
                        "display_name": "Example Pro",
                        "purpose": "natal_analysis",
                        "enabled": True,
                        "default": True,
                        "prompt_override": "强调证据链。",
                    }
                ],
            },
        )
        assert created.status_code == 200, created.text
        body = created.json()
        assert body["key_configured"] is True
        assert body["key_last4"] == "1234"
        assert "secret-provider-key" not in created.text
        assert body["models"][0]["prompt_override"] == "强调证据链。"

        first = admin.patch(
            "/api/v1/admin/ai-prompt",
            json={"platform_prompt": "保持结构清楚。"},
        ).json()
        second = admin.patch(
            "/api/v1/admin/ai-prompt",
            json={"platform_prompt": "优先解释重点。"},
        ).json()
        assert first["version"] != second["version"]
        restored = admin.post("/api/v1/admin/ai-prompt/restore-default").json()
        assert "大白话" in restored["platform_prompt"]
        assert restored["platform_prompt"] != second["platform_prompt"]

    with sqlite3.connect(tmp_path / "accounts.sqlite3") as connection:
        encrypted = connection.execute(
            "SELECT api_key_ciphertext FROM provider_configs WHERE provider_id = 'example-ai'"
        ).fetchone()[0]
    assert encrypted != "secret-provider-key-1234"
    assert "secret-provider-key" not in encrypted


def test_provider_key_persistence_requires_master_key(tmp_path) -> None:
    app = admin_app(tmp_path, master_key=False)
    with TestClient(app) as admin:
        login_admin(admin)
        response = admin.post(
            "/api/v1/admin/providers",
            json={
                "provider_id": "blocked-ai",
                "display_name": "Blocked AI",
                "base_url": "https://ai.example.test/v1",
                "api_key": "not-allowed-without-master-key",
            },
        )
        assert response.status_code == 409
        assert "not-allowed-without-master-key" not in response.text
