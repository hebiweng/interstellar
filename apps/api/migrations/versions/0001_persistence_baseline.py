"""Create M1 persistence, isolation, and immutability baseline.

Revision ID: 0001_persistence_baseline
Revises: None
"""

from __future__ import annotations

from collections.abc import Sequence

from alembic import op
from interstellar_core.persistence.schema import DOWNGRADE_STATEMENTS, UPGRADE_STATEMENTS

revision: str = "0001_persistence_baseline"
down_revision: str | Sequence[str] | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    connection = op.get_bind()
    for statement in UPGRADE_STATEMENTS:
        connection.exec_driver_sql(statement)


def downgrade() -> None:
    connection = op.get_bind()
    for statement in DOWNGRADE_STATEMENTS:
        connection.exec_driver_sql(statement)
