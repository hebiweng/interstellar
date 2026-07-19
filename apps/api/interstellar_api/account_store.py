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

EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


class AccountError(ValueError):
    """A user-facing account operation error with a stable code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def utc_now() -> datetime:
    return datetime.now(UTC)


def iso(value: datetime | None = None) -> str:
    return (value or utc_now()).isoformat().replace("+00:00", "Z")


class AccountStore:
    """Small SQLite repository with account isolation and latest-only natal results."""

    def __init__(self, database_path: str) -> None:
        self.path = Path(database_path).expanduser().resolve()
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.RLock()
        self._initialize()

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
                """
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

    def register(self, email_value: str, display_name_value: str, password: str) -> dict[str, str]:
        email = self.normalize_email(email_value)
        self.validate_password(password)
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
                        (email, display_name, password_salt, password_hash, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (email, display_name, salt.hex(), digest.hex(), now, now),
                )
        except sqlite3.IntegrityError as error:
            raise AccountError("EMAIL_EXISTS", "该邮箱已经注册，请直接登录。") from error
        return {"email": email, "displayName": display_name}

    def authenticate(self, email_value: str, password: str) -> dict[str, str] | None:
        email = self.normalize_email(email_value)
        with self._connect() as connection:
            row = connection.execute(
                """
                SELECT email, display_name, password_salt, password_hash
                FROM accounts WHERE email = ?
                """,
                (email,),
            ).fetchone()
        if row is None:
            return None
        actual = self._password_digest(password, bytes.fromhex(row["password_salt"]))
        if not hmac.compare_digest(actual.hex(), row["password_hash"]):
            return None
        return {"email": row["email"], "displayName": row["display_name"]}

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
                SELECT accounts.email, accounts.display_name, sessions.expires_at
                FROM sessions JOIN accounts ON accounts.email = sessions.owner_email
                WHERE sessions.token_hash = ?
                """,
                (token_hash,),
            ).fetchone()
        if row is None or row["expires_at"] <= iso():
            self.delete_session(raw_token)
            return None
        return {"email": row["email"], "displayName": row["display_name"]}

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
                SELECT p.id, p.person_json, p.updated_at,
                       n.snapshot_id, n.snapshot_json, n.settings_json, n.groups_json,
                       n.analysis_document, n.analysis_document_hash, n.ai_analysis_text,
                       n.ai_model_id, n.calculated_at
                FROM people AS p
                LEFT JOIN natal_results AS n
                    ON n.person_id = p.id AND n.owner_email = p.owner_email
                WHERE p.owner_email = ?
                ORDER BY p.updated_at DESC
                """,
                (owner_email,),
            ).fetchall()
        return [
            {
                "id": row["id"],
                "person": self._json(row["person_json"]),
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
                WHERE person_id = ? AND owner_email = ?
                """,
                (cleaned, model_id, person_id, owner_email),
            )
            if cursor.rowcount == 0:
                raise AccountError("NATAL_RESULT_NOT_FOUND", "请先为该人物完成本命盘计算。")

    def delete_person(self, owner_email: str, person_id: str) -> None:
        with self._lock, self._connect() as connection:
            connection.execute(
                "DELETE FROM people WHERE id = ? AND owner_email = ?",
                (person_id, owner_email),
            )
