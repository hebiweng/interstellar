"""Disposable PostgreSQL database fixtures for migration integration tests."""

from __future__ import annotations

import os
import sys
from collections.abc import Iterator
from pathlib import Path
from uuid import uuid4

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "python"))


@pytest.fixture()
def postgres_database(monkeypatch: pytest.MonkeyPatch) -> Iterator[str]:
    psycopg = pytest.importorskip("psycopg")
    sqlalchemy = pytest.importorskip("sqlalchemy")
    base_url = os.environ.get("INTERSTELLAR_TEST_DATABASE_URL", "").strip()
    if not base_url:
        pytest.skip("INTERSTELLAR_TEST_DATABASE_URL is not configured")

    source_url = sqlalchemy.engine.make_url(base_url)
    admin_database = os.environ.get("INTERSTELLAR_TEST_ADMIN_DATABASE", "postgres")
    admin_url = source_url.set(database=admin_database)
    database_name = f"interstellar_m1_{uuid4().hex[:16]}"
    test_url = source_url.set(database=database_name)

    with psycopg.connect(admin_url.render_as_string(hide_password=False), autocommit=True) as connection:
        connection.execute(
            psycopg.sql.SQL("CREATE DATABASE {}").format(psycopg.sql.Identifier(database_name))
        )

    monkeypatch.setenv(
        "INTERSTELLAR_DATABASE_URL",
        test_url.render_as_string(hide_password=False),
    )
    try:
        yield test_url.render_as_string(hide_password=False)
    finally:
        with psycopg.connect(
            admin_url.render_as_string(hide_password=False), autocommit=True
        ) as connection:
            connection.execute(
                "SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
                "WHERE datname = %s AND pid <> pg_backend_pid()",
                (database_name,),
            )
            connection.execute(
                psycopg.sql.SQL("DROP DATABASE IF EXISTS {}").format(
                    psycopg.sql.Identifier(database_name)
                )
            )


@pytest.fixture()
def migrated_database(postgres_database: str) -> str:
    pytest.importorskip("alembic")
    from alembic import command
    from alembic.config import Config

    configuration = Config(str(ROOT / "apps" / "api" / "alembic.ini"))
    command.upgrade(configuration, "head")
    return postgres_database
