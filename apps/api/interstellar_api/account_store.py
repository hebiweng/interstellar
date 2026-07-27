"""Durable account, person, and latest-natal persistence for one deployment."""

from __future__ import annotations

import hashlib
import hmac
import json
import re
import secrets
import sqlite3
import threading
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

from cryptography.fernet import Fernet, InvalidToken

EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
ACCOUNT_ROLES = {"user", "admin", "super_admin"}
ACCOUNT_STATUSES = {"active", "disabled", "suspended", "pending_deletion"}
ANALYTICS_EVENT_NAMES = {
    "page_view",
    "analysis_started",
    "calculation_completed",
    "calculation_failed",
    "report_generated",
    "report_exported",
    "ai_requested",
    "ai_completed",
    "ai_failed",
    "object_created",
    "object_updated",
    "object_deleted",
    "account_registered",
    "account_login",
}
ANALYTICS_METADATA_KEYS = {
    "page",
    "route",
    "analysis_type",
    "chart_family",
    "technique",
    "provider_id",
    "model_id",
    "export_format",
    "object_type",
    "error_code",
    "prompt_version",
    "prompt_hash",
    "input_tokens",
    "output_tokens",
    "total_tokens",
}


class AccountError(ValueError):
    """A user-facing account operation error with a stable code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def utc_now() -> datetime:
    return datetime.now(UTC)


def iso(value: datetime | None = None) -> str:
    return (value or utc_now()).isoformat().replace("+00:00", "Z")


DEFAULT_PLATFORM_AI_PROMPT = (
    "请用大白话、结构清晰的方式给出占星解读。"
    "先给出核心结论，再解释原因，最后给出1-3条可执行的建议。"
    "避免使用难懂的行业术语；如果必须使用，请在括号里给出通俗解释。"
    "保持亲切、克制，不制造焦虑，不说绝对化的命运预言。"
)

class AccountStore:
    """Small SQLite repository with account isolation and latest-only natal results."""

    def __init__(self, database_path: str, *, master_key: str | None = None) -> None:
        self.path = Path(database_path).expanduser().resolve()
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.RLock()
        self._secret_box = self._build_secret_box(master_key)
        self._initialize()

    @staticmethod
    def _build_secret_box(master_key: str | None) -> Fernet | None:
        if not master_key:
            return None
        if len(master_key) < 32:
            raise ValueError("INTERSTELLAR_ADMIN_MASTER_KEY must contain at least 32 characters")
        import base64

        derived = base64.urlsafe_b64encode(hashlib.sha256(master_key.encode("utf-8")).digest())
        return Fernet(derived)

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path, timeout=15)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA busy_timeout = 15000")
        return connection

    def _initialize(self) -> None:
        with self._lock, self._connect() as connection:
            connection.execute("PRAGMA journal_mode = WAL")
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS accounts (
                    email TEXT PRIMARY KEY,
                    display_name TEXT NOT NULL,
                    password_salt TEXT NOT NULL,
                    password_hash TEXT NOT NULL,
                    role TEXT NOT NULL DEFAULT 'user',
                    status TEXT NOT NULL DEFAULT 'active',
                    last_login_at TEXT,
                    suspended_until TEXT,
                    status_reason TEXT,
                    disabled_at TEXT,
                    delete_requested_at TEXT,
                    default_person_id TEXT,
                    sample_visible INTEGER NOT NULL DEFAULT 1,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS sessions (
                    token_hash TEXT PRIMARY KEY,
                    owner_email TEXT NOT NULL REFERENCES accounts(email) ON DELETE CASCADE,
                    expires_at TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS sessions_owner_email_idx
                    ON sessions(owner_email);
                CREATE TABLE IF NOT EXISTS people (
                    id TEXT PRIMARY KEY,
                    owner_email TEXT NOT NULL REFERENCES accounts(email) ON DELETE CASCADE,
                    display_name TEXT NOT NULL,
                    relation TEXT NOT NULL,
                    person_json TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS people_owner_email_idx
                    ON people(owner_email);
                CREATE TABLE IF NOT EXISTS natal_results (
                    person_id TEXT PRIMARY KEY REFERENCES people(id) ON DELETE CASCADE,
                    owner_email TEXT NOT NULL,
                    snapshot_id TEXT NOT NULL,
                    snapshot_json TEXT NOT NULL,
                    settings_json TEXT NOT NULL,
                    groups_json TEXT NOT NULL,
                    analysis_document TEXT NOT NULL,
                    analysis_document_hash TEXT NOT NULL,
                    ai_analysis_text TEXT,
                    ai_model_id TEXT,
                    calculated_at TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS natal_results_owner_email_idx
                    ON natal_results(owner_email);
                CREATE TABLE IF NOT EXISTS analytics_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    event_name TEXT NOT NULL,
                    actor_email TEXT,
                    visitor_hash TEXT,
                    success INTEGER,
                    duration_ms INTEGER,
                    metadata_json TEXT NOT NULL DEFAULT '{}',
                    created_at TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS analytics_events_created_at_idx
                    ON analytics_events(created_at);
                CREATE INDEX IF NOT EXISTS analytics_events_actor_email_idx
                    ON analytics_events(actor_email);
                CREATE TABLE IF NOT EXISTS admin_audit_logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    actor_email TEXT NOT NULL,
                    action TEXT NOT NULL,
                    target_type TEXT NOT NULL,
                    target_id TEXT NOT NULL,
                    details_json TEXT NOT NULL DEFAULT '{}',
                    created_at TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS admin_audit_logs_created_at_idx
                    ON admin_audit_logs(created_at);
                CREATE TABLE IF NOT EXISTS provider_configs (
                    provider_id TEXT PRIMARY KEY,
                    display_name TEXT NOT NULL,
                    base_url TEXT NOT NULL,
                    enabled INTEGER NOT NULL DEFAULT 0,
                    is_default INTEGER NOT NULL DEFAULT 0,
                    api_key_ciphertext TEXT,
                    api_key_last4 TEXT,
                    timeout_seconds INTEGER NOT NULL DEFAULT 90,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS model_configs (
                    provider_id TEXT NOT NULL REFERENCES provider_configs(provider_id)
                        ON DELETE CASCADE,
                    model_id TEXT NOT NULL,
                    display_name TEXT NOT NULL,
                    purpose TEXT NOT NULL DEFAULT 'natal_analysis',
                    enabled INTEGER NOT NULL DEFAULT 1,
                    is_default INTEGER NOT NULL DEFAULT 0,
                    options_json TEXT NOT NULL DEFAULT '{}',
                    pre_analysis_prompt TEXT,
                    prompt_version TEXT,
                    updated_by TEXT,
                    updated_at TEXT NOT NULL,
                    PRIMARY KEY (provider_id, model_id)
                );
                CREATE TABLE IF NOT EXISTS platform_settings (
                    setting_key TEXT PRIMARY KEY,
                    setting_value TEXT NOT NULL,
                    version TEXT NOT NULL,
                    updated_by TEXT,
                    updated_at TEXT NOT NULL
                );
                
                CREATE TABLE IF NOT EXISTS feedback (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    type TEXT NOT NULL,
                    content TEXT NOT NULL,
                    contact TEXT,
                    user_email TEXT,
                    status TEXT NOT NULL DEFAULT 'pending',
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS feedback_status_idx
                    ON feedback(status);
                CREATE INDEX IF NOT EXISTS feedback_created_at_idx
                    ON feedback(created_at);
"""            )
            self._migrate_accounts(connection)
            self._migrate_model_configs(connection)
            self._migrate_provider_configs(connection)

    @staticmethod
    def _migrate_accounts(connection: sqlite3.Connection) -> None:
        """Apply additive migrations so existing single-user databases remain usable."""

        existing = {
            row["name"] for row in connection.execute("PRAGMA table_info(accounts)").fetchall()
        }
        additions = {
            "role": "TEXT NOT NULL DEFAULT 'user'",
            "status": "TEXT NOT NULL DEFAULT 'active'",
            "last_login_at": "TEXT",
            "suspended_until": "TEXT",
            "status_reason": "TEXT",
            "disabled_at": "TEXT",
            "delete_requested_at": "TEXT",
            "default_person_id": "TEXT",
            "sample_visible": "INTEGER NOT NULL DEFAULT 1",
        }
        for name, declaration in additions.items():
            if name not in existing:
                connection.execute(f"ALTER TABLE accounts ADD COLUMN {name} {declaration}")

    @staticmethod
    def _migrate_model_configs(connection: sqlite3.Connection) -> None:
        existing = {
            row["name"]
            for row in connection.execute("PRAGMA table_info(model_configs)").fetchall()
        }
        additions = {
            "pre_analysis_prompt": "TEXT",
            "prompt_version": "TEXT",
            "updated_by": "TEXT",
            "updated_at": "TEXT NOT NULL DEFAULT ''",
        }
        for name, declaration in additions.items():
            if name not in existing:
                connection.execute(
                    f"ALTER TABLE model_configs ADD COLUMN {name} {declaration}"
                )

    @staticmethod
    def _migrate_provider_configs(connection: sqlite3.Connection) -> None:
        existing = {
            row["name"]
            for row in connection.execute("PRAGMA table_info(provider_configs)").fetchall()
        }
        if "is_default" not in existing:
            connection.execute(
                "ALTER TABLE provider_configs ADD COLUMN is_default INTEGER NOT NULL DEFAULT 0"
            )

    @staticmethod
    def normalize_email(value: str) -> str:
        email = value.strip().lower()
        if len(email) > 254 or not EMAIL_RE.fullmatch(email):
            raise AccountError("INVALID_EMAIL", "请输入有效的邮箱地址。")
        return email

    @staticmethod
    def validate_password(value: str) -> None:
        if len(value) < 8 or len(value) > 128:
            raise AccountError("INVALID_PASSWORD", "密码长度需为 8—128 个字符。")

    @staticmethod
    def _password_digest(password: str, salt: bytes) -> bytes:
        return hashlib.scrypt(
            password.encode("utf-8"),
            salt=salt,
            n=2**14,
            r=8,
            p=1,
            dklen=32,
        )

    def register(
        self,
        email_value: str,
        display_name_value: str,
        password: str,
        *,
        role: str = "user",
        status: str = "active",
    ) -> dict[str, str]:
        email = self.normalize_email(email_value)
        self.validate_password(password)
        if role not in ACCOUNT_ROLES:
            raise AccountError("INVALID_ROLE", "账户角色无效。")
        if status not in ACCOUNT_STATUSES:
            raise AccountError("INVALID_STATUS", "账户状态无效。")
        display_name = display_name_value.strip() or email.split("@", 1)[0]
        if len(display_name) > 80:
            raise AccountError("INVALID_DISPLAY_NAME", "昵称不能超过 80 个字符。")
        salt = secrets.token_bytes(16)
        digest = self._password_digest(password, salt)
        now = iso()
        try:
            with self._lock, self._connect() as connection:
                connection.execute(
                    """
                    INSERT INTO accounts
                        (email, display_name, password_salt, password_hash, role, status,
                         created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (email, display_name, salt.hex(), digest.hex(), role, status, now, now),
                )
        except sqlite3.IntegrityError as error:
            raise AccountError("EMAIL_EXISTS", "该邮箱已经注册，请直接登录。") from error
        return {
            "email": email,
            "displayName": display_name,
            "role": role,
            "status": status,
        }

    def authenticate(self, email_value: str, password: str) -> dict[str, str] | None:
        email = self.normalize_email(email_value)
        with self._connect() as connection:
            row = connection.execute(
                """
                SELECT email, display_name, password_salt, password_hash, role, status,
                       suspended_until
                FROM accounts WHERE email = ?
                """,
                (email,),
            ).fetchone()
        if row is None:
            return None
        status = row["status"]
        if status == "suspended" and row["suspended_until"] and row["suspended_until"] <= iso():
            with self._lock, self._connect() as connection:
                connection.execute(
                    """
                    UPDATE accounts SET status = 'active', suspended_until = NULL,
                        status_reason = NULL, updated_at = ? WHERE email = ?
                    """,
                    (iso(), email),
                )
            status = "active"
        if status != "active":
            code = "ACCOUNT_SUSPENDED" if status == "suspended" else "ACCOUNT_DISABLED"
            raise AccountError(code, "该账户当前不可登录，请联系管理员。")
        actual = self._password_digest(password, bytes.fromhex(row["password_salt"]))
        if not hmac.compare_digest(actual.hex(), row["password_hash"]):
            return None
        now = iso()
        with self._lock, self._connect() as connection:
            connection.execute(
                "UPDATE accounts SET last_login_at = ?, updated_at = ? WHERE email = ?",
                (now, now, email),
            )
        return {
            "email": row["email"],
            "displayName": row["display_name"],
            "role": row["role"],
            "status": status,
        }

    def create_session(self, email: str, *, lifetime_days: int) -> tuple[str, datetime]:
        raw_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw_token.encode("utf-8")).hexdigest()
        expires_at = utc_now() + timedelta(days=lifetime_days)
        with self._lock, self._connect() as connection:
            connection.execute("DELETE FROM sessions WHERE expires_at <= ?", (iso(),))
            connection.execute(
                """
                INSERT INTO sessions (token_hash, owner_email, expires_at, created_at)
                VALUES (?, ?, ?, ?)
                """,
                (token_hash, email, iso(expires_at), iso()),
            )
        return raw_token, expires_at

    def resolve_session(self, raw_token: str | None) -> dict[str, str] | None:
        if not raw_token:
            return None
        token_hash = hashlib.sha256(raw_token.encode("utf-8")).hexdigest()
        with self._connect() as connection:
            row = connection.execute(
                """
                SELECT accounts.email, accounts.display_name, accounts.role, accounts.status,
                       accounts.suspended_until, sessions.expires_at
                FROM sessions JOIN accounts ON accounts.email = sessions.owner_email
                WHERE sessions.token_hash = ?
                """,
                (token_hash,),
            ).fetchone()
        if (
            row is None
            or row["expires_at"] <= iso()
            or row["status"] != "active"
            or (
                row["status"] == "suspended"
                and (not row["suspended_until"] or row["suspended_until"] > iso())
            )
        ):
            self.delete_session(raw_token)
            return None
        return {
            "email": row["email"],
            "displayName": row["display_name"],
            "role": row["role"],
            "status": row["status"],
        }

    def delete_session(self, raw_token: str | None) -> None:
        if not raw_token:
            return
        token_hash = hashlib.sha256(raw_token.encode("utf-8")).hexdigest()
        with self._lock, self._connect() as connection:
            connection.execute("DELETE FROM sessions WHERE token_hash = ?", (token_hash,))

    @staticmethod
    def _json(value: str | None) -> Any:
        if value is None:
            return None
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return None

    def workspace(self, owner_email: str) -> list[dict[str, Any]]:
        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT p.id, p.person_json, p.created_at, p.updated_at,
                       n.snapshot_id, n.snapshot_json, n.settings_json, n.groups_json,
                       n.analysis_document, n.analysis_document_hash, n.ai_analysis_text,
                       n.ai_model_id, n.calculated_at
                FROM people AS p
                LEFT JOIN natal_results AS n
                    ON n.person_id = p.id AND n.owner_email = p.owner_email
                WHERE p.owner_email = ?
                ORDER BY p.created_at DESC
                """,
                (owner_email,),
            ).fetchall()
        return [
            {
                "id": row["id"],
                "person": self._json(row["person_json"]),
                "createdAt": row["created_at"],
                "savedAt": row["updated_at"],
                "latestNatal": (
                    {
                        "snapshotId": row["snapshot_id"],
                        "snapshot": self._json(row["snapshot_json"]),
                        "settings": self._json(row["settings_json"]),
                        "groups": self._json(row["groups_json"]),
                        "analysisDocument": row["analysis_document"],
                        "analysisDocumentHash": row["analysis_document_hash"],
                        "aiAnalysisText": row["ai_analysis_text"],
                        "aiModelId": row["ai_model_id"],
                        "calculatedAt": row["calculated_at"],
                    }
                    if row["snapshot_id"]
                    else None
                ),
            }
            for row in rows
        ]

    def preferences(self, owner_email: str) -> dict[str, Any]:
        with self._connect() as connection:
            row = connection.execute(
                "SELECT default_person_id, sample_visible FROM accounts WHERE email = ?",
                (owner_email,),
            ).fetchone()
        if row is None:
            raise AccountError("ACCOUNT_NOT_FOUND", "账户不存在。")
        return {
            "defaultPersonId": row["default_person_id"],
            "sampleVisible": bool(row["sample_visible"]),
        }

    def set_default_person(self, owner_email: str, person_id: str | None) -> dict[str, Any]:
        with self._lock, self._connect() as connection:
            if person_id is not None:
                self._require_person(connection, owner_email, person_id)
            connection.execute(
                "UPDATE accounts SET default_person_id = ?, updated_at = ? WHERE email = ?",
                (person_id, iso(), owner_email),
            )
        return self.preferences(owner_email)

    def set_sample_visibility(self, owner_email: str, visible: bool) -> dict[str, Any]:
        with self._lock, self._connect() as connection:
            connection.execute(
                "UPDATE accounts SET sample_visible = ?, updated_at = ? WHERE email = ?",
                (int(visible), iso(), owner_email),
            )
        return self.preferences(owner_email)

    def save_person(
        self,
        owner_email: str,
        person: dict[str, Any],
        person_id: str | None = None,
    ) -> tuple[str, str]:
        display_name = str(person.get("displayName", "")).strip()
        if not display_name:
            raise AccountError("INVALID_PERSON", "人物姓名不能为空。")
        identifier = person_id or secrets.token_urlsafe(18)
        relation = str(person.get("relation", "other"))
        now = iso()
        with self._lock, self._connect() as connection:
            existing = connection.execute(
                "SELECT owner_email FROM people WHERE id = ?", (identifier,)
            ).fetchone()
            if existing is not None and existing["owner_email"] != owner_email:
                raise AccountError("FORBIDDEN", "无权修改其他账户的人物。")
            connection.execute(
                """
                INSERT INTO people
                    (id, owner_email, display_name, relation, person_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    display_name = excluded.display_name,
                    relation = excluded.relation,
                    person_json = excluded.person_json,
                    updated_at = excluded.updated_at
                """,
                (
                    identifier,
                    owner_email,
                    display_name,
                    relation,
                    json.dumps(person, ensure_ascii=False),
                    now,
                    now,
                ),
            )
        return identifier, now

    def _require_person(
        self,
        connection: sqlite3.Connection,
        owner_email: str,
        person_id: str,
    ) -> None:
        row = connection.execute(
            "SELECT id FROM people WHERE id = ? AND owner_email = ?",
            (person_id, owner_email),
        ).fetchone()
        if row is None:
            raise AccountError("PERSON_NOT_FOUND", "未找到当前账户中的人物。")

    def save_latest_natal(
        self,
        owner_email: str,
        person_id: str,
        payload: dict[str, Any],
    ) -> dict[str, str]:
        snapshot = payload.get("snapshot")
        analysis_document = payload.get("analysisDocument")
        if not isinstance(snapshot, dict) or not isinstance(analysis_document, str):
            raise AccountError("INVALID_NATAL_RESULT", "本命盘结果格式无效。")
        now = iso()
        snapshot_id = str(snapshot.get("id", "unknown"))
        with self._lock, self._connect() as connection:
            self._require_person(connection, owner_email, person_id)
            values = (
                person_id,
                owner_email,
                snapshot_id,
                json.dumps(snapshot, ensure_ascii=False),
                json.dumps(payload.get("settings") or {}, ensure_ascii=False),
                json.dumps(payload.get("groups") or {}, ensure_ascii=False),
                analysis_document,
                str(payload.get("analysisDocumentHash", "")),
                payload.get("aiAnalysisText"),
                payload.get("aiModelId"),
                now,
            )
            connection.execute(
                """
                INSERT INTO natal_results
                    (person_id, owner_email, snapshot_id, snapshot_json, settings_json,
                     groups_json, analysis_document, analysis_document_hash,
                     ai_analysis_text, ai_model_id, calculated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(person_id) DO UPDATE SET
                    owner_email = excluded.owner_email,
                    snapshot_id = excluded.snapshot_id,
                    snapshot_json = excluded.snapshot_json,
                    settings_json = excluded.settings_json,
                    groups_json = excluded.groups_json,
                    analysis_document = excluded.analysis_document,
                    analysis_document_hash = excluded.analysis_document_hash,
                    ai_analysis_text = excluded.ai_analysis_text,
                    ai_model_id = excluded.ai_model_id,
                    calculated_at = excluded.calculated_at
                """,
                values,
            )
            connection.execute(
                "UPDATE people SET updated_at = ? WHERE id = ? AND owner_email = ?",
                (now, person_id, owner_email),
            )
        return {"personId": person_id, "snapshotId": snapshot_id, "calculatedAt": now}

    def save_ai_analysis(
        self,
        owner_email: str,
        person_id: str,
        snapshot_id: str,
        text: str,
        model_id: str | None,
    ) -> None:
        cleaned = text.strip()
        if not cleaned:
            raise AccountError("INVALID_AI_ANALYSIS", "AI 分析文本不能为空。")
        with self._lock, self._connect() as connection:
            self._require_person(connection, owner_email, person_id)
            cursor = connection.execute(
                """
                UPDATE natal_results SET ai_analysis_text = ?, ai_model_id = ?
                WHERE person_id = ? AND owner_email = ? AND snapshot_id = ?
                """,
                (cleaned, model_id, person_id, owner_email, snapshot_id),
            )
            if cursor.rowcount == 0:
                latest = connection.execute(
                    "SELECT snapshot_id FROM natal_results WHERE person_id = ? AND owner_email = ?",
                    (person_id, owner_email),
                ).fetchone()
                if latest is None:
                    raise AccountError("NATAL_RESULT_NOT_FOUND", "请先为该人物完成本命盘计算。")
                raise AccountError(
                    "STALE_AI_ANALYSIS",
                    "星盘已重新计算，这次旧版本分析没有覆盖最新结果。",
                )

    def delete_person(self, owner_email: str, person_id: str) -> None:
        with self._lock, self._connect() as connection:
            connection.execute(
                "DELETE FROM people WHERE id = ? AND owner_email = ?",
                (person_id, owner_email),
            )
            connection.execute(
                """
                UPDATE accounts SET default_person_id = NULL, updated_at = ?
                WHERE email = ? AND default_person_id = ?
                """,
                (iso(), owner_email, person_id),
            )

    # -- Administration -------------------------------------------------

    def ensure_super_admin(
        self,
        email_value: str,
        password: str | None,
        *,
        display_name: str = "平台超级管理员",
    ) -> dict[str, str]:
        """Idempotently bootstrap one super administrator from process configuration."""

        email = self.normalize_email(email_value)
        with self._connect() as connection:
            existing = connection.execute(
                "SELECT email, display_name FROM accounts WHERE email = ?", (email,)
            ).fetchone()
        if existing is None:
            if not password:
                raise ValueError(
                    "INTERSTELLAR_ADMIN_BOOTSTRAP_PASSWORD is required for a new bootstrap account"
                )
            return self.register(email, display_name, password, role="super_admin")
        now = iso()
        with self._lock, self._connect() as connection:
            connection.execute(
                """
                UPDATE accounts SET role = 'super_admin', status = 'active',
                    suspended_until = NULL, status_reason = NULL, updated_at = ?
                WHERE email = ?
                """,
                (now, email),
            )
        return {
            "email": email,
            "displayName": existing["display_name"],
            "role": "super_admin",
            "status": "active",
        }

    def _account_public(self, row: sqlite3.Row) -> dict[str, Any]:
        return {
            "email": row["email"],
            "displayName": row["display_name"],
            "role": row["role"],
            "status": row["status"],
            "lastLoginAt": row["last_login_at"],
            "suspendedUntil": row["suspended_until"],
            "statusReason": row["status_reason"],
            "createdAt": row["created_at"],
            "updatedAt": row["updated_at"],
        }

    def list_users(
        self,
        *,
        query: str = "",
        role: str | None = None,
        status: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> dict[str, Any]:
        clauses: list[str] = []
        values: list[Any] = []
        if query.strip():
            clauses.append("(a.email LIKE ? OR a.display_name LIKE ?)")
            needle = f"%{query.strip()}%"
            values.extend((needle, needle))
        if role:
            if role not in ACCOUNT_ROLES:
                raise AccountError("INVALID_ROLE", "账户角色无效。")
            clauses.append("a.role = ?")
            values.append(role)
        if status:
            if status not in ACCOUNT_STATUSES:
                raise AccountError("INVALID_STATUS", "账户状态无效。")
            clauses.append("a.status = ?")
            values.append(status)
        where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        with self._connect() as connection:
            total = connection.execute(
                f"SELECT COUNT(*) AS count FROM accounts AS a {where}", values
            ).fetchone()["count"]
            rows = connection.execute(
                f"""
                SELECT a.*,
                    (SELECT COUNT(*) FROM people p WHERE p.owner_email = a.email) AS object_count,
                    (SELECT COUNT(*) FROM natal_results n WHERE n.owner_email = a.email)
                        AS calculation_count,
                    (SELECT COUNT(*) FROM analytics_events e
                     WHERE e.actor_email = a.email AND e.event_name = 'ai_completed') AS ai_count
                FROM accounts AS a {where}
                ORDER BY a.created_at DESC LIMIT ? OFFSET ?
                """,
                [*values, limit, offset],
            ).fetchall()
        items = []
        for row in rows:
            item = self._account_public(row)
            item["usage"] = {
                "objects": row["object_count"],
                "calculations": row["calculation_count"],
                "aiCalls": row["ai_count"],
            }
            items.append(item)
        return {"items": items, "total": total, "limit": limit, "offset": offset}

    def get_user(self, email_value: str) -> dict[str, Any]:
        email = self.normalize_email(email_value)
        result = self.list_users(query=email, limit=100)
        for item in result["items"]:
            if item["email"] == email:
                return item
        raise AccountError("ACCOUNT_NOT_FOUND", "账户不存在。")

    def user_activity(self, email_value: str, *, limit: int = 100) -> list[dict[str, Any]]:
        email = self.normalize_email(email_value)
        self.get_user(email)
        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT id, event_name, success, duration_ms, metadata_json, created_at
                FROM analytics_events WHERE actor_email = ?
                ORDER BY id DESC LIMIT ?
                """,
                (email, limit),
            ).fetchall()
        return [
            {
                "id": row["id"],
                "eventName": row["event_name"],
                "success": None if row["success"] is None else bool(row["success"]),
                "durationMs": row["duration_ms"],
                "metadata": self._json(row["metadata_json"]) or {},
                "createdAt": row["created_at"],
            }
            for row in rows
        ]

    def set_account_status(
        self,
        email_value: str,
        status: str,
        *,
        reason: str | None,
        suspended_until: str | None,
        actor_email: str,
    ) -> dict[str, Any]:
        email = self.normalize_email(email_value)
        if status not in ACCOUNT_STATUSES:
            raise AccountError("INVALID_STATUS", "账户状态无效。")
        if email == actor_email and status != "active":
            raise AccountError("FORBIDDEN", "管理员不能停用自己的当前账户。")
        if status == "suspended" and not suspended_until:
            raise AccountError("INVALID_STATUS", "暂停账户必须指定结束时间。")
        now = iso()
        with self._lock, self._connect() as connection:
            row = connection.execute(
                "SELECT role FROM accounts WHERE email = ?", (email,)
            ).fetchone()
            if row is None:
                raise AccountError("ACCOUNT_NOT_FOUND", "账户不存在。")
            if row["role"] == "super_admin" and status != "active":
                remaining = connection.execute(
                    """
                    SELECT COUNT(*) AS count FROM accounts
                    WHERE role = 'super_admin' AND status = 'active' AND email != ?
                    """,
                    (email,),
                ).fetchone()["count"]
                if remaining == 0:
                    raise AccountError("LAST_SUPER_ADMIN", "不能停用最后一个超级管理员。")
            connection.execute(
                """
                UPDATE accounts SET status = ?, suspended_until = ?, status_reason = ?,
                    disabled_at = ?, delete_requested_at = ?, updated_at = ? WHERE email = ?
                """,
                (
                    status,
                    suspended_until if status == "suspended" else None,
                    reason.strip()[:500] if reason else None,
                    now if status == "disabled" else None,
                    now if status == "pending_deletion" else None,
                    now,
                    email,
                ),
            )
            if status != "active":
                connection.execute("DELETE FROM sessions WHERE owner_email = ?", (email,))
            self._audit_in_connection(
                connection,
                actor_email,
                "account.status_changed",
                "account",
                email,
                {"status": status, "reason": reason, "suspended_until": suspended_until},
            )
        return self.get_user(email)

    def set_account_role(
        self, email_value: str, role: str, *, actor_email: str
    ) -> dict[str, Any]:
        email = self.normalize_email(email_value)
        if role not in ACCOUNT_ROLES:
            raise AccountError("INVALID_ROLE", "账户角色无效。")
        with self._lock, self._connect() as connection:
            actor = connection.execute(
                "SELECT role FROM accounts WHERE email = ?", (actor_email,)
            ).fetchone()
            if actor is None or actor["role"] != "super_admin":
                raise AccountError("FORBIDDEN", "只有超级管理员可以变更管理员角色。")
            current = connection.execute(
                "SELECT role FROM accounts WHERE email = ?", (email,)
            ).fetchone()
            if current is None:
                raise AccountError("ACCOUNT_NOT_FOUND", "账户不存在。")
            if current["role"] == "super_admin" and role != "super_admin":
                remaining = connection.execute(
                    """
                    SELECT COUNT(*) AS count FROM accounts
                    WHERE role = 'super_admin' AND email != ?
                    """,
                    (email,),
                ).fetchone()["count"]
                if remaining == 0:
                    raise AccountError("LAST_SUPER_ADMIN", "不能移除最后一个超级管理员。")
            connection.execute(
                "UPDATE accounts SET role = ?, updated_at = ? WHERE email = ?",
                (role, iso(), email),
            )
            self._audit_in_connection(
                connection,
                actor_email,
                "account.role_changed",
                "account",
                email,
                {"role": role},
            )
        return self.get_user(email)

    def force_logout(self, email_value: str, *, actor_email: str) -> int:
        email = self.normalize_email(email_value)
        with self._lock, self._connect() as connection:
            cursor = connection.execute("DELETE FROM sessions WHERE owner_email = ?", (email,))
            self._audit_in_connection(
                connection, actor_email, "account.sessions_revoked", "account", email, {}
            )
            return cursor.rowcount

    # -- Privacy-preserving operational analytics ----------------------

    @staticmethod
    def _clean_analytics_metadata(metadata: dict[str, Any] | None) -> dict[str, Any]:
        cleaned: dict[str, Any] = {}
        for key, value in (metadata or {}).items():
            if key not in ANALYTICS_METADATA_KEYS or not isinstance(
                value, (str, int, float, bool)
            ):
                continue
            cleaned[key] = value[:200] if isinstance(value, str) else value
        return cleaned

    def record_event(
        self,
        event_name: str,
        *,
        actor_email: str | None = None,
        visitor_id: str | None = None,
        success: bool | None = None,
        duration_ms: int | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> None:
        if event_name not in ANALYTICS_EVENT_NAMES:
            raise AccountError("INVALID_ANALYTICS_EVENT", "不支持的行为事件。")
        visitor_hash = (
            hashlib.sha256(f"interstellar:{visitor_id}".encode()).hexdigest()
            if visitor_id
            else None
        )
        clean_duration = None if duration_ms is None else max(0, min(duration_ms, 3_600_000))
        with self._lock, self._connect() as connection:
            connection.execute(
                """
                INSERT INTO analytics_events
                    (event_name, actor_email, visitor_hash, success, duration_ms,
                     metadata_json, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    event_name,
                    actor_email,
                    visitor_hash,
                    None if success is None else int(success),
                    clean_duration,
                    json.dumps(self._clean_analytics_metadata(metadata), ensure_ascii=False),
                    iso(),
                ),
            )

    def analytics_summary(self, *, since: str) -> dict[str, Any]:
        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT event_name, COUNT(*) AS count,
                    SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) AS succeeded,
                    SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) AS failed,
                    AVG(duration_ms) AS average_duration_ms
                FROM analytics_events WHERE created_at >= ? GROUP BY event_name
                """,
                (since,),
            ).fetchall()
            page = connection.execute(
                """
                SELECT COUNT(*) AS pv,
                    COUNT(DISTINCT COALESCE(actor_email, visitor_hash)) AS uv
                FROM analytics_events
                WHERE created_at >= ? AND event_name = 'page_view'
                """,
                (since,),
            ).fetchone()
            registrations = connection.execute(
                "SELECT COUNT(*) AS count FROM accounts WHERE created_at >= ?", (since,)
            ).fetchone()["count"]
            active_users = connection.execute(
                """
                SELECT COUNT(DISTINCT actor_email) AS count FROM analytics_events
                WHERE created_at >= ? AND actor_email IS NOT NULL
                """,
                (since,),
            ).fetchone()["count"]
            ai = connection.execute(
                """
                SELECT
                    SUM(CASE WHEN event_name = 'ai_completed' THEN 1 ELSE 0 END) AS completed,
                    SUM(CASE WHEN event_name = 'ai_failed' THEN 1 ELSE 0 END) AS failed,
                    AVG(CASE WHEN event_name IN ('ai_completed', 'ai_failed')
                        THEN duration_ms END) AS average_duration_ms,
                    SUM(CASE WHEN event_name = 'ai_completed'
                        THEN COALESCE(json_extract(metadata_json, '$.input_tokens'), 0)
                        ELSE 0 END) AS input_tokens,
                    SUM(CASE WHEN event_name = 'ai_completed'
                        THEN COALESCE(json_extract(metadata_json, '$.output_tokens'), 0)
                        ELSE 0 END) AS output_tokens,
                    SUM(CASE WHEN event_name = 'ai_completed'
                        THEN COALESCE(json_extract(metadata_json, '$.total_tokens'), 0)
                        ELSE 0 END) AS total_tokens
                FROM analytics_events WHERE created_at >= ?
                """,
                (since,),
            ).fetchone()
        return {
            "since": since,
            "pageViews": page["pv"],
            "uniqueVisitors": page["uv"],
            "newUsers": registrations,
            "activeUsers": active_users,
            "aiUsage": {
                "completed": ai["completed"] or 0,
                "failed": ai["failed"] or 0,
                "averageDurationMs": (
                    round(ai["average_duration_ms"], 2)
                    if ai["average_duration_ms"] is not None
                    else None
                ),
                "inputTokens": ai["input_tokens"] or 0,
                "outputTokens": ai["output_tokens"] or 0,
                "totalTokens": ai["total_tokens"] or 0,
            },
            "events": {
                row["event_name"]: {
                    "count": row["count"],
                    "succeeded": row["succeeded"],
                    "failed": row["failed"],
                    "averageDurationMs": (
                        round(row["average_duration_ms"], 2)
                        if row["average_duration_ms"] is not None
                        else None
                    ),
                }
                for row in rows
            },
        }

    def account_summary(self) -> dict[str, Any]:
        with self._connect() as connection:
            total = connection.execute("SELECT COUNT(*) AS count FROM accounts").fetchone()[
                "count"
            ]
            statuses = connection.execute(
                "SELECT status, COUNT(*) AS count FROM accounts GROUP BY status"
            ).fetchall()
            roles = connection.execute(
                "SELECT role, COUNT(*) AS count FROM accounts GROUP BY role"
            ).fetchall()
            sessions = connection.execute(
                "SELECT COUNT(*) AS count FROM sessions WHERE expires_at > ?", (iso(),)
            ).fetchone()["count"]
        return {
            "totalUsers": total,
            "activeSessions": sessions,
            "byStatus": {row["status"]: row["count"] for row in statuses},
            "byRole": {row["role"]: row["count"] for row in roles},
        }


    # -- Feedback -------------------------------------------------------

    def save_feedback(
        self,
        type_value: str,
        content_value: str,
        contact_value: str | None = None,
        user_email_value: str | None = None,
    ) -> dict[str, Any]:
        feedback_type = str(type_value).strip()
        if feedback_type not in {"bug", "feature", "other"}:
            feedback_type = "other"
        content = str(content_value).strip()
        if not content or len(content) > 5000:
            raise AccountError("INVALID_FEEDBACK", "反馈内容不能为空，且不能超过 5000 字。")
        contact = str(contact_value).strip() if contact_value else None
        user_email = None
        if user_email_value:
            user_email = self.normalize_email(user_email_value)
        now = iso()
        with self._lock, self._connect() as connection:
            cursor = connection.execute(
                """
                INSERT INTO feedback
                    (type, content, contact, user_email, status, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (feedback_type, content, contact, user_email, "pending", now, now),
            )
            feedback_id = cursor.lastrowid
        return {
            "id": feedback_id,
            "type": feedback_type,
            "content": content,
            "contact": contact,
            "userEmail": user_email,
            "status": "pending",
            "createdAt": now,
            "updatedAt": now,
        }

    def list_feedback(
        self,
        *,
        status: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> dict[str, Any]:
        clauses = ["1 = 1"]
        values: list[Any] = []
        if status:
            clauses.append("status = ?")
            values.append(status)
        where = " AND ".join(clauses)
        with self._connect() as connection:
            total = connection.execute(
                f"SELECT COUNT(*) AS count FROM feedback WHERE {where}", values
            ).fetchone()["count"]
            rows = connection.execute(
                f"""
                SELECT id, type, content, contact, user_email, status, created_at, updated_at
                FROM feedback WHERE {where}
                ORDER BY created_at DESC
                LIMIT ? OFFSET ?
                """,
                (*values, limit, offset),
            ).fetchall()
        return {
            "total": total,
            "limit": limit,
            "offset": offset,
            "items": [
                {
                    "id": row["id"],
                    "type": row["type"],
                    "content": row["content"],
                    "contact": row["contact"],
                    "userEmail": row["user_email"],
                    "status": row["status"],
                    "createdAt": row["created_at"],
                    "updatedAt": row["updated_at"],
                }
                for row in rows
            ],
        }

    def update_feedback_status(self, feedback_id: int, status_value: str) -> dict[str, Any]:
        status = str(status_value).strip()
        if status not in {"pending", "resolved"}:
            raise AccountError("INVALID_FEEDBACK_STATUS", "反馈状态只能是 pending 或 resolved。")
        now = iso()
        with self._lock, self._connect() as connection:
            connection.execute(
                "UPDATE feedback SET status = ?, updated_at = ? WHERE id = ?",
                (status, now, feedback_id),
            )
            row = connection.execute(
                """SELECT id, type, content, contact, user_email, status, created_at, updated_at
                FROM feedback WHERE id = ?""",
                (feedback_id,),
            ).fetchone()
        if row is None:
            raise AccountError("FEEDBACK_NOT_FOUND", "反馈不存在。")
        return {
            "id": row["id"],
            "type": row["type"],
            "content": row["content"],
            "contact": row["contact"],
            "userEmail": row["user_email"],
            "status": row["status"],
            "createdAt": row["created_at"],
            "updatedAt": row["updated_at"],
        }

    # -- Provider and prompt configuration ------------------------------

    def _encrypt_secret(self, value: str) -> str:
        if self._secret_box is None:
            raise AccountError(
                "MASTER_KEY_REQUIRED",
                "未配置服务器主密钥，禁止持久化 API 密钥。",
            )
        return self._secret_box.encrypt(value.encode("utf-8")).decode("ascii")

    def _decrypt_secret(self, value: str | None) -> str | None:
        if not value:
            return None
        if self._secret_box is None:
            raise AccountError("MASTER_KEY_REQUIRED", "服务器主密钥未配置。")
        try:
            return self._secret_box.decrypt(value.encode("ascii")).decode("utf-8")
        except InvalidToken as error:
            raise AccountError("SECRET_DECRYPTION_FAILED", "API 密钥无法解密。") from error

    def upsert_provider(
        self,
        provider: dict[str, Any],
        *,
        actor_email: str,
        api_key: str | None = None,
    ) -> dict[str, Any]:
        provider_id = str(provider.get("provider_id", "")).strip().lower()
        if not re.fullmatch(r"[a-z0-9][a-z0-9_-]{1,63}", provider_id):
            raise AccountError("INVALID_PROVIDER", "供应商 ID 格式无效。")
        display_name = str(provider.get("display_name", "")).strip()
        base_url = str(provider.get("base_url", "")).strip().rstrip("/")
        if not display_name or not base_url.startswith(("https://", "http://localhost", "http://127.0.0.1")):
            raise AccountError("INVALID_PROVIDER", "供应商名称或 HTTPS 地址无效。")
        timeout = max(1, min(int(provider.get("timeout", 90)), 600))
        encrypted = self._encrypt_secret(api_key.strip()) if api_key and api_key.strip() else None
        last4 = api_key.strip()[-4:] if api_key and api_key.strip() else None
        now = iso()
        with self._lock, self._connect() as connection:
            previous = connection.execute(
                """
                SELECT api_key_ciphertext, api_key_last4
                FROM provider_configs WHERE provider_id = ?
                """,
                (provider_id,),
            ).fetchone()
            if bool(provider.get("default")):
                connection.execute("UPDATE provider_configs SET is_default = 0")
            connection.execute(
                """
                INSERT INTO provider_configs
                    (provider_id, display_name, base_url, enabled, is_default,
                     api_key_ciphertext, api_key_last4, timeout_seconds, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(provider_id) DO UPDATE SET
                    display_name = excluded.display_name,
                    base_url = excluded.base_url,
                    enabled = excluded.enabled,
                    is_default = excluded.is_default,
                    api_key_ciphertext = excluded.api_key_ciphertext,
                    api_key_last4 = excluded.api_key_last4,
                    timeout_seconds = excluded.timeout_seconds,
                    updated_at = excluded.updated_at
                """,
                (
                    provider_id,
                    display_name,
                    base_url,
                    int(bool(provider.get("enabled", False))),
                    int(bool(provider.get("default", False))),
                    encrypted or (previous["api_key_ciphertext"] if previous else None),
                    last4 or (previous["api_key_last4"] if previous else None),
                    timeout,
                    now,
                    now,
                ),
            )
            self._audit_in_connection(
                connection,
                actor_email,
                "provider.saved",
                "provider",
                provider_id,
                {
                    "key_rotated": bool(api_key),
                    "enabled": bool(provider.get("enabled")),
                    "default": bool(provider.get("default")),
                },
            )
        return self.get_provider(provider_id, include_models=True)

    def upsert_model(
        self,
        provider_id: str,
        model: dict[str, Any],
        *,
        actor_email: str,
    ) -> dict[str, Any]:
        model_id = str(model.get("model_id", "")).strip()
        if not model_id or len(model_id) > 160:
            raise AccountError("INVALID_MODEL", "模型 ID 格式无效。")
        display_name = str(model.get("display_name", "")).strip()
        purpose = str(model.get("purpose", "natal_analysis")).strip() or "natal_analysis"
        prompt = model.get("pre_analysis_prompt")
        prompt_text = str(prompt).strip() if prompt is not None else None
        if prompt_text and len(prompt_text) > 20_000:
            raise AccountError("INVALID_MODEL", "管理员提示词不能超过 20,000 字符。")
        prompt_version = str(model.get("prompt_version") or iso()).strip()[:80]
        options = model.get("options") if isinstance(model.get("options"), dict) else {}
        now = iso()
        with self._lock, self._connect() as connection:
            if connection.execute(
                "SELECT 1 FROM provider_configs WHERE provider_id = ?", (provider_id,)
            ).fetchone() is None:
                raise AccountError("PROVIDER_NOT_FOUND", "供应商不存在。")
            if bool(model.get("default")):
                connection.execute(
                    "UPDATE model_configs SET is_default = 0 WHERE provider_id = ?",
                    (provider_id,),
                )
            connection.execute(
                """
                INSERT INTO model_configs
                    (provider_id, model_id, display_name, purpose, enabled, is_default,
                     options_json, pre_analysis_prompt, prompt_version, updated_by, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(provider_id, model_id) DO UPDATE SET
                    display_name = excluded.display_name,
                    purpose = excluded.purpose,
                    enabled = excluded.enabled,
                    is_default = excluded.is_default,
                    options_json = excluded.options_json,
                    pre_analysis_prompt = excluded.pre_analysis_prompt,
                    prompt_version = excluded.prompt_version,
                    updated_by = excluded.updated_by,
                    updated_at = excluded.updated_at
                """,
                (
                    provider_id,
                    model_id,
                    display_name or model_id,
                    purpose,
                    int(bool(model.get("enabled", True))),
                    int(bool(model.get("default", False))),
                    json.dumps(options, ensure_ascii=False),
                    prompt_text,
                    prompt_version,
                    actor_email,
                    now,
                ),
            )
            self._audit_in_connection(
                connection,
                actor_email,
                "model.saved",
                "model",
                f"{provider_id}:{model_id}",
                {"prompt_version": prompt_version, "enabled": bool(model.get("enabled", True))},
            )
        return self.get_model_config(provider_id, model_id, include_secret=False)

    def get_provider(self, provider_id: str, *, include_models: bool) -> dict[str, Any]:
        with self._connect() as connection:
            row = connection.execute(
                "SELECT * FROM provider_configs WHERE provider_id = ?", (provider_id,)
            ).fetchone()
            if row is None:
                raise AccountError("PROVIDER_NOT_FOUND", "供应商不存在。")
            model_rows = (
                connection.execute(
                    """
                    SELECT * FROM model_configs WHERE provider_id = ?
                    ORDER BY is_default DESC, model_id
                    """,
                    (provider_id,),
                ).fetchall()
                if include_models
                else []
            )
        return {
            "provider_id": row["provider_id"],
            "display_name": row["display_name"],
            "base_url": row["base_url"],
            "enabled": bool(row["enabled"]),
            "default": bool(row["is_default"]),
            "timeout": row["timeout_seconds"],
            "key_configured": bool(row["api_key_ciphertext"]),
            "key_last4": row["api_key_last4"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
            "models": [self._model_public(model, admin=True) for model in model_rows],
        }

    @staticmethod
    def _model_public(row: sqlite3.Row, *, admin: bool) -> dict[str, Any]:
        result = {
            "model_id": row["model_id"],
            "display_name": row["display_name"],
            "purpose": row["purpose"],
            "enabled": bool(row["enabled"]),
            "default": bool(row["is_default"]),
            "options": AccountStore._json(row["options_json"]) or {},
            "prompt_version": row["prompt_version"],
        }
        if admin:
            result.update(
                {
                    "pre_analysis_prompt": row["pre_analysis_prompt"],
                    "prompt_override": row["pre_analysis_prompt"],
                    "updated_by": row["updated_by"],
                    "updated_at": row["updated_at"],
                }
            )
        return result

    def list_providers(self, *, admin: bool) -> list[dict[str, Any]]:
        with self._connect() as connection:
            rows = connection.execute(
                "SELECT provider_id FROM provider_configs ORDER BY display_name"
            ).fetchall()
        providers = [self.get_provider(row["provider_id"], include_models=True) for row in rows]
        if admin:
            return providers
        return [
            {
                **{key: value for key, value in provider.items() if key not in {"key_last4"}},
                "models": [
                    {
                        key: value
                        for key, value in model.items()
                        if key
                        not in {
                            "pre_analysis_prompt",
                            "prompt_override",
                            "updated_by",
                            "updated_at",
                        }
                    }
                    for model in provider["models"]
                    if model["enabled"]
                ],
            }
            for provider in providers
            if provider["enabled"] and provider["key_configured"]
        ]

    def get_model_config(
        self, provider_id: str, model_id: str, *, include_secret: bool
    ) -> dict[str, Any]:
        with self._connect() as connection:
            provider = connection.execute(
                "SELECT * FROM provider_configs WHERE provider_id = ?", (provider_id,)
            ).fetchone()
            model = connection.execute(
                "SELECT * FROM model_configs WHERE provider_id = ? AND model_id = ?",
                (provider_id, model_id),
            ).fetchone()
        if provider is None or model is None:
            raise AccountError("MODEL_NOT_FOUND", "模型配置不存在。")
        result = {
            "provider_id": provider_id,
            "display_name": provider["display_name"],
            "base_url": provider["base_url"],
            "timeout": provider["timeout_seconds"],
            "provider_enabled": bool(provider["enabled"]),
            **self._model_public(model, admin=True),
        }
        if include_secret:
            result["api_key"] = self._decrypt_secret(provider["api_key_ciphertext"])
        return result

    def restore_model_prompt(
        self, provider_id: str, model_id: str, *, actor_email: str
    ) -> dict[str, Any]:
        with self._lock, self._connect() as connection:
            cursor = connection.execute(
                """
                UPDATE model_configs SET pre_analysis_prompt = NULL, prompt_version = ?,
                    updated_by = ?, updated_at = ?
                WHERE provider_id = ? AND model_id = ?
                """,
                ("platform-default", actor_email, iso(), provider_id, model_id),
            )
            if cursor.rowcount == 0:
                raise AccountError("MODEL_NOT_FOUND", "模型配置不存在。")
            self._audit_in_connection(
                connection,
                actor_email,
                "model.prompt_restored",
                "model",
                f"{provider_id}:{model_id}",
                {},
            )
        return self.get_model_config(provider_id, model_id, include_secret=False)



    def get_platform_ai_prompt(self) -> dict[str, Any]:
        with self._connect() as connection:
            row = connection.execute(
                "SELECT * FROM platform_settings WHERE setting_key = 'ai_pre_analysis_prompt'"
            ).fetchone()
        if row is None:
            return {
                "platform_prompt": "",
                "version": "platform-default",
                "updated_by": None,
                "updated_at": None,
            }
        return {
            "platform_prompt": row["setting_value"],
            "version": row["version"],
            "updated_by": row["updated_by"],
            "updated_at": row["updated_at"],
        }

    def set_platform_ai_prompt(
        self, prompt: str, version: str | None, *, actor_email: str
    ) -> dict[str, Any]:
        cleaned = prompt.strip()
        if len(cleaned) > 20_000:
            raise AccountError("INVALID_PROMPT", "平台提示词不能超过 20,000 字符。")
        now = iso()
        resolved_version = (
            version.strip()[:80]
            if version and version.strip()
            else f"prompt-{now}-{hashlib.sha256(cleaned.encode()).hexdigest()[:12]}"
        )
        with self._lock, self._connect() as connection:
            connection.execute(
                """
                INSERT INTO platform_settings
                    (setting_key, setting_value, version, updated_by, updated_at)
                VALUES ('ai_pre_analysis_prompt', ?, ?, ?, ?)
                ON CONFLICT(setting_key) DO UPDATE SET
                    setting_value = excluded.setting_value,
                    version = excluded.version,
                    updated_by = excluded.updated_by,
                    updated_at = excluded.updated_at
                """,
                (cleaned, resolved_version, actor_email, now),
            )
            self._audit_in_connection(
                connection,
                actor_email,
                "ai_prompt.saved",
                "platform_setting",
                "ai_pre_analysis_prompt",
                {"version": resolved_version},
            )
        return self.get_platform_ai_prompt()

    def restore_platform_ai_prompt(self, *, actor_email: str) -> dict[str, Any]:
        return self.set_platform_ai_prompt(
            DEFAULT_PLATFORM_AI_PROMPT,
            None,
            actor_email=actor_email,
        )

    @staticmethod
    def _audit_in_connection(
        connection: sqlite3.Connection,
        actor_email: str,
        action: str,
        target_type: str,
        target_id: str,
        details: dict[str, Any],
    ) -> None:
        connection.execute(
            """
            INSERT INTO admin_audit_logs
                (actor_email, action, target_type, target_id, details_json, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                actor_email,
                action,
                target_type,
                target_id,
                json.dumps(details, ensure_ascii=False),
                iso(),
            ),
        )

    def list_audit_logs(self, *, limit: int = 100) -> list[dict[str, Any]]:
        with self._connect() as connection:
            rows = connection.execute(
                "SELECT * FROM admin_audit_logs ORDER BY id DESC LIMIT ?", (limit,)
            ).fetchall()
        return [
            {
                "id": row["id"],
                "actorEmail": row["actor_email"],
                "action": row["action"],
                "targetType": row["target_type"],
                "targetId": row["target_id"],
                "details": self._json(row["details_json"]) or {},
                "createdAt": row["created_at"],
            }
            for row in rows
        ]
