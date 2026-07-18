from __future__ import annotations

from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
HASH_A = "sha256:" + "a" * 64
HASH_B = "sha256:" + "b" * 64


def _sqlalchemy_url(url: str) -> str:
    if url.startswith("postgresql://"):
        return url.replace("postgresql://", "postgresql+psycopg://", 1)
    return url


def _seed(connection) -> None:  # type: ignore[no-untyped-def]
    connection.execute(
        "INSERT INTO interstellar.workspace (id, owner_id) VALUES "
        "('ws_a', 'owner_a'), ('ws_b', 'owner_b')"
    )
    connection.execute(
        "INSERT INTO interstellar.subject "
        "(id, workspace_id, kind, display_name) VALUES "
        "('subject_a', 'ws_a', 'person', 'A'), "
        "('subject_b', 'ws_b', 'person', 'B')"
    )
    connection.execute(
        "INSERT INTO interstellar.subject_version "
        "(id, workspace_id, subject_id, version, kind, display_name, payload, content_hash) "
        "VALUES ('version_a', 'ws_a', 'subject_a', 1, 'person', 'A', '{}'::jsonb, %s)",
        (HASH_A,),
    )
    connection.execute(
        "UPDATE interstellar.subject SET current_version_id = 'version_a' WHERE id = 'subject_a'"
    )
    connection.execute(
        "INSERT INTO interstellar.calculation_snapshot "
        "(id, workspace_id, subject_version_id, schema_version, status, input_fingerprint, "
        "rule_pack_hash, maturity, payload) VALUES "
        "('snapshot_a', 'ws_a', 'version_a', '1.0.0', 'succeeded', %s, %s, 'beta', '{}'::jsonb)",
        (HASH_A, HASH_B),
    )
    connection.commit()


def test_clean_alembic_upgrade_and_downgrade(postgres_database: str) -> None:
    pytest.importorskip("alembic")
    sqlalchemy = pytest.importorskip("sqlalchemy")
    from alembic import command
    from alembic.config import Config

    configuration = Config(str(ROOT / "apps" / "api" / "alembic.ini"))

    command.upgrade(configuration, "head")
    engine = sqlalchemy.create_engine(_sqlalchemy_url(postgres_database))
    with engine.connect() as connection:
        table_names = set(sqlalchemy.inspect(connection).get_table_names(schema="interstellar"))
        assert table_names == {
            "workspace",
            "subject",
            "subject_version",
            "location",
            "time_spec",
            "dataset_version",
            "calculation_snapshot",
        }
        revision = connection.execute(sqlalchemy.text("SELECT version_num FROM alembic_version"))
        assert revision.scalar_one() == "0001_persistence_baseline"

        created_at_type = connection.execute(
            sqlalchemy.text(
                "SELECT data_type FROM information_schema.columns "
                "WHERE table_schema = 'interstellar' AND table_name = 'workspace' "
                "AND column_name = 'created_at'"
            )
        ).scalar_one()
        assert created_at_type == "timestamp with time zone"
    engine.dispose()

    command.downgrade(configuration, "base")
    engine = sqlalchemy.create_engine(_sqlalchemy_url(postgres_database))
    with engine.connect() as connection:
        exists = connection.execute(
            sqlalchemy.text("SELECT to_regnamespace('interstellar')")
        ).scalar_one()
        assert exists is None
    engine.dispose()


def test_rls_hides_and_rejects_cross_workspace_rows(migrated_database: str) -> None:
    psycopg = pytest.importorskip("psycopg")
    with psycopg.connect(migrated_database) as connection:
        _seed(connection)

        connection.execute("SET ROLE interstellar_app")
        connection.execute("SELECT set_config('app.workspace_id', 'ws_a', true)")
        visible_ids = connection.execute(
            "SELECT id FROM interstellar.subject ORDER BY id"
        ).fetchall()
        assert visible_ids == [("subject_a",)]

        with pytest.raises(psycopg.errors.InsufficientPrivilege, match="row-level security"):
            connection.execute(
                "INSERT INTO interstellar.subject "
                "(id, workspace_id, kind, display_name) "
                "VALUES ('cross_workspace', 'ws_b', 'person', 'denied')"
            )


def test_subject_versions_and_snapshots_reject_update_and_delete(
    migrated_database: str,
) -> None:
    psycopg = pytest.importorskip("psycopg")
    with psycopg.connect(migrated_database) as connection:
        _seed(connection)

        with pytest.raises(psycopg.errors.ObjectNotInPrerequisiteState, match="immutable"):
            connection.execute(
                "UPDATE interstellar.subject_version SET display_name = 'changed' "
                "WHERE id = 'version_a'"
            )
        connection.rollback()

        with pytest.raises(psycopg.errors.ObjectNotInPrerequisiteState, match="immutable"):
            connection.execute(
                "DELETE FROM interstellar.calculation_snapshot WHERE id = 'snapshot_a'"
            )
