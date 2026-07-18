"""Request-scoped PostgreSQL workspace context.

The setting is transaction-local. Callers must start a transaction before invoking this
function and must never reuse a connection outside that transaction as an authorization
decision. PostgreSQL RLS remains the enforcement boundary.
"""

from __future__ import annotations

import re
from collections.abc import Mapping
from typing import Any, Protocol

_IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$")
SET_WORKSPACE_SQL = "SELECT set_config('app.workspace_id', %(workspace_id)s, true)"


class WorkspaceContextError(ValueError):
    """Workspace identifier cannot safely enter the database context."""


class WorkspaceConnection(Protocol):
    """Small DB-API-compatible port implemented by psycopg connections/cursors."""

    def execute(self, query: str, params: Mapping[str, Any]) -> Any: ...


def set_workspace_context(connection: WorkspaceConnection, workspace_id: str) -> None:
    """Set the transaction-local workspace used by all tenant RLS policies."""

    if not _IDENTIFIER.fullmatch(workspace_id):
        raise WorkspaceContextError("workspace_id must match the canonical Identifier format")
    connection.execute(SET_WORKSPACE_SQL, {"workspace_id": workspace_id})
