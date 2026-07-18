# API database migrations

The migration URL is read only from `INTERSTELLAR_DATABASE_URL`; credentials are never stored in
`alembic.ini`. Run from the repository root:

```text
python -m alembic -c apps/api/alembic.ini upgrade head
python -m alembic -c apps/api/alembic.ini downgrade base
```

The M1 baseline creates the `interstellar` schema and an `interstellar_app` NOLOGIN role. Deployment
must connect through a login role that is granted this role; migrations require schema ownership and
`CREATEROLE` for the first install. Tenant transactions must set `app.workspace_id` with
`set_workspace_context()` before accessing any workspace table. The setting is transaction-local.

`subject_version` and `calculation_snapshot` are append-only: both `UPDATE` and `DELETE` are rejected
by triggers, including for the migration owner. Replacements receive new IDs.
