from __future__ import annotations

from typing import Any

import pytest

from interstellar_core.persistence.schema import APPLICATION_ROLE, UPGRADE_STATEMENTS
from interstellar_core.persistence.workspace import (
    SET_WORKSPACE_SQL,
    WorkspaceContextError,
    set_workspace_context,
)


class RecordingConnection:
    def __init__(self) -> None:
        self.calls: list[tuple[str, dict[str, Any]]] = []

    def execute(self, query: str, params: dict[str, Any]) -> None:
        self.calls.append((query, params))


def test_workspace_context_is_parameterized_and_transaction_local() -> None:
    connection = RecordingConnection()

    set_workspace_context(connection, "ws_test:01")

    assert connection.calls == [(SET_WORKSPACE_SQL, {"workspace_id": "ws_test:01"})]
    assert SET_WORKSPACE_SQL.endswith(", true)")


def test_workspace_context_rejects_noncanonical_identifier() -> None:
    with pytest.raises(WorkspaceContextError):
        set_workspace_context(RecordingConnection(), "unsafe workspace'; --")


def test_baseline_ddl_declares_all_required_tables_and_guards() -> None:
    ddl = "\n".join(UPGRADE_STATEMENTS).lower()
    for table in (
        "workspace",
        "subject",
        "subject_version",
        "location",
        "time_spec",
        "dataset_version",
        "calculation_snapshot",
    ):
        assert f"create table interstellar.{table}" in ddl

    assert APPLICATION_ROLE in ddl
    assert "force row level security" in ddl
    assert "subject_version_immutable" in ddl
    assert "calculation_snapshot_immutable" in ddl
    assert "timestamptz not null default current_timestamp" in ddl
