"""Persistence boundaries and PostgreSQL baseline declarations."""

from interstellar_core.persistence.workspace import (
    WorkspaceConnection,
    WorkspaceContextError,
    set_workspace_context,
)

__all__ = ["WorkspaceConnection", "WorkspaceContextError", "set_workspace_context"]
