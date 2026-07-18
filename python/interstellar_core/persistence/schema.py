"""Ordered PostgreSQL DDL shared by Alembic and psql integration tests."""

from __future__ import annotations

SCHEMA_NAME = "interstellar"
APPLICATION_ROLE = "interstellar_app"

UPGRADE_STATEMENTS: tuple[str, ...] = (
    "CREATE SCHEMA IF NOT EXISTS interstellar",
    """
    DO $role$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'interstellar_app') THEN
        EXECUTE 'CREATE ROLE interstellar_app NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS';
      END IF;
    END
    $role$
    """,
    """
    CREATE FUNCTION interstellar.current_workspace_id()
    RETURNS text
    LANGUAGE sql
    STABLE
    PARALLEL SAFE
    AS $$
      SELECT NULLIF(current_setting('app.workspace_id', true), '')
    $$
    """,
    """
    CREATE FUNCTION interstellar.reject_immutable_change()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      RAISE EXCEPTION '%% is immutable; create a replacement record', TG_TABLE_NAME
        USING ERRCODE = '55000';
    END
    $$
    """,
    """
    CREATE TABLE interstellar.workspace (
      id text PRIMARY KEY,
      owner_id text NOT NULL,
      locale text NOT NULL DEFAULT 'zh-CN',
      created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
      deleted_at timestamptz,
      CONSTRAINT workspace_id_identifier CHECK (id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$'),
      CONSTRAINT workspace_owner_identifier CHECK (owner_id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$'),
      CONSTRAINT workspace_locale_not_blank CHECK (length(btrim(locale)) > 0)
    )
    """,
    """
    CREATE TABLE interstellar.location (
      id text PRIMARY KEY,
      workspace_id text NOT NULL REFERENCES interstellar.workspace(id) ON DELETE RESTRICT,
      name text NOT NULL,
      country_code text,
      latitude double precision NOT NULL,
      longitude double precision NOT NULL,
      elevation_m double precision,
      timezone_id text,
      geonames_id bigint,
      payload jsonb NOT NULL,
      content_hash text NOT NULL,
      created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT location_latitude_range CHECK (latitude BETWEEN -90 AND 90),
      CONSTRAINT location_longitude_range CHECK (longitude >= -180 AND longitude < 180),
      CONSTRAINT location_elevation_range CHECK (elevation_m IS NULL OR elevation_m BETWEEN -500 AND 10000),
      CONSTRAINT location_country_code CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$'),
      CONSTRAINT location_payload_object CHECK (jsonb_typeof(payload) = 'object'),
      CONSTRAINT location_content_hash CHECK (content_hash ~ '^(sha256|hmac-sha256):[A-Fa-f0-9]{32,128}$'),
      UNIQUE (workspace_id, content_hash)
    )
    """,
    """
    CREATE TABLE interstellar.time_spec (
      id text PRIMARY KEY,
      workspace_id text NOT NULL REFERENCES interstellar.workspace(id) ON DELETE RESTRICT,
      calendar text NOT NULL,
      local_value text NOT NULL,
      precision text NOT NULL,
      timezone_id text,
      selected_utc timestamptz,
      confidence text NOT NULL,
      payload jsonb NOT NULL,
      content_hash text NOT NULL,
      created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT time_spec_calendar CHECK (calendar IN ('gregorian', 'julian', 'proleptic_gregorian', 'custom')),
      CONSTRAINT time_spec_precision CHECK (precision IN ('second', 'minute', 'quarter_hour', 'hour', 'part_of_day', 'date', 'interval', 'unknown')),
      CONSTRAINT time_spec_confidence CHECK (confidence IN ('high', 'medium', 'low', 'disputed', 'unknown')),
      CONSTRAINT time_spec_unknown_has_no_selected_utc CHECK (precision NOT IN ('date', 'unknown') OR selected_utc IS NULL),
      CONSTRAINT time_spec_payload_object CHECK (jsonb_typeof(payload) = 'object'),
      CONSTRAINT time_spec_content_hash CHECK (content_hash ~ '^(sha256|hmac-sha256):[A-Fa-f0-9]{32,128}$'),
      UNIQUE (workspace_id, content_hash)
    )
    """,
    """
    CREATE TABLE interstellar.subject (
      id text PRIMARY KEY,
      workspace_id text NOT NULL REFERENCES interstellar.workspace(id) ON DELETE RESTRICT,
      kind text NOT NULL,
      display_name text NOT NULL,
      current_version_id text,
      created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
      deleted_at timestamptz,
      CONSTRAINT subject_kind CHECK (kind IN ('person', 'event', 'project', 'organization', 'country', 'relationship', 'question', 'location')),
      CONSTRAINT subject_display_name CHECK (length(display_name) BETWEEN 1 AND 240),
      UNIQUE (workspace_id, id)
    )
    """,
    """
    CREATE TABLE interstellar.subject_version (
      id text PRIMARY KEY,
      workspace_id text NOT NULL,
      subject_id text NOT NULL,
      version integer NOT NULL,
      kind text NOT NULL,
      display_name text NOT NULL,
      time_spec_id text REFERENCES interstellar.time_spec(id) ON DELETE RESTRICT,
      location_id text REFERENCES interstellar.location(id) ON DELETE RESTRICT,
      payload jsonb NOT NULL,
      content_hash text NOT NULL,
      created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT subject_version_subject_fk FOREIGN KEY (workspace_id, subject_id)
        REFERENCES interstellar.subject(workspace_id, id) ON DELETE RESTRICT,
      CONSTRAINT subject_version_positive CHECK (version >= 1),
      CONSTRAINT subject_version_kind CHECK (kind IN ('person', 'event', 'project', 'organization', 'country', 'relationship', 'question', 'location')),
      CONSTRAINT subject_version_display_name CHECK (length(display_name) BETWEEN 1 AND 240),
      CONSTRAINT subject_version_payload_object CHECK (jsonb_typeof(payload) = 'object'),
      CONSTRAINT subject_version_content_hash CHECK (content_hash ~ '^(sha256|hmac-sha256):[A-Fa-f0-9]{32,128}$'),
      UNIQUE (subject_id, version),
      UNIQUE (workspace_id, id)
    )
    """,
    """
    ALTER TABLE interstellar.subject
      ADD CONSTRAINT subject_current_version_fk
      FOREIGN KEY (workspace_id, current_version_id)
      REFERENCES interstellar.subject_version(workspace_id, id)
      DEFERRABLE INITIALLY DEFERRED
    """,
    """
    CREATE TABLE interstellar.dataset_version (
      id text PRIMARY KEY,
      dataset_id text NOT NULL,
      version text NOT NULL,
      status text NOT NULL DEFAULT 'available',
      checksum text NOT NULL,
      source_uri text NOT NULL,
      license text NOT NULL,
      manifest jsonb NOT NULL DEFAULT '{}'::jsonb,
      activated_at timestamptz,
      created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT dataset_version_status CHECK (status IN ('available', 'active', 'retired', 'unavailable')),
      CONSTRAINT dataset_manifest_object CHECK (jsonb_typeof(manifest) = 'object'),
      UNIQUE (dataset_id, version)
    )
    """,
    """
    CREATE TABLE interstellar.calculation_snapshot (
      id text PRIMARY KEY,
      workspace_id text NOT NULL REFERENCES interstellar.workspace(id) ON DELETE RESTRICT,
      subject_version_id text,
      schema_version text NOT NULL,
      status text NOT NULL,
      input_fingerprint text NOT NULL,
      rule_pack_hash text NOT NULL,
      maturity text NOT NULL,
      payload jsonb NOT NULL,
      created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
      supersedes_id text REFERENCES interstellar.calculation_snapshot(id) ON DELETE RESTRICT,
      CONSTRAINT calculation_snapshot_subject_fk FOREIGN KEY (workspace_id, subject_version_id)
        REFERENCES interstellar.subject_version(workspace_id, id) ON DELETE RESTRICT,
      CONSTRAINT calculation_snapshot_schema_version CHECK (schema_version ~ '^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\\+[0-9A-Za-z.-]+)?$'),
      CONSTRAINT calculation_snapshot_status CHECK (status IN ('succeeded', 'partial', 'failed', 'cancelled', 'timed_out')),
      CONSTRAINT calculation_snapshot_maturity CHECK (maturity IN ('stable', 'beta', 'experimental')),
      CONSTRAINT calculation_snapshot_input_hash CHECK (input_fingerprint ~ '^(sha256|hmac-sha256):[A-Fa-f0-9]{32,128}$'),
      CONSTRAINT calculation_snapshot_rule_hash CHECK (rule_pack_hash ~ '^(sha256|hmac-sha256):[A-Fa-f0-9]{32,128}$'),
      CONSTRAINT calculation_snapshot_payload_object CHECK (jsonb_typeof(payload) = 'object'),
      UNIQUE (workspace_id, input_fingerprint, rule_pack_hash)
    )
    """,
    "CREATE INDEX location_workspace_name_idx ON interstellar.location (workspace_id, name)",
    "CREATE INDEX time_spec_workspace_created_idx ON interstellar.time_spec (workspace_id, created_at DESC)",
    "CREATE INDEX subject_workspace_kind_idx ON interstellar.subject (workspace_id, kind) WHERE deleted_at IS NULL",
    "CREATE INDEX subject_version_subject_created_idx ON interstellar.subject_version (subject_id, version DESC)",
    "CREATE INDEX calculation_snapshot_workspace_created_idx ON interstellar.calculation_snapshot (workspace_id, created_at DESC)",
    """
    CREATE TRIGGER subject_version_immutable
    BEFORE UPDATE OR DELETE ON interstellar.subject_version
    FOR EACH ROW EXECUTE FUNCTION interstellar.reject_immutable_change()
    """,
    """
    CREATE TRIGGER calculation_snapshot_immutable
    BEFORE UPDATE OR DELETE ON interstellar.calculation_snapshot
    FOR EACH ROW EXECUTE FUNCTION interstellar.reject_immutable_change()
    """,
    "GRANT USAGE ON SCHEMA interstellar TO interstellar_app",
    "GRANT EXECUTE ON FUNCTION interstellar.current_workspace_id() TO interstellar_app",
    "GRANT SELECT, INSERT, UPDATE ON interstellar.workspace, interstellar.location, interstellar.time_spec, interstellar.subject TO interstellar_app",
    "GRANT SELECT, INSERT ON interstellar.subject_version, interstellar.calculation_snapshot TO interstellar_app",
    "GRANT SELECT ON interstellar.dataset_version TO interstellar_app",
    "ALTER TABLE interstellar.workspace ENABLE ROW LEVEL SECURITY",
    "ALTER TABLE interstellar.workspace FORCE ROW LEVEL SECURITY",
    "ALTER TABLE interstellar.location ENABLE ROW LEVEL SECURITY",
    "ALTER TABLE interstellar.location FORCE ROW LEVEL SECURITY",
    "ALTER TABLE interstellar.time_spec ENABLE ROW LEVEL SECURITY",
    "ALTER TABLE interstellar.time_spec FORCE ROW LEVEL SECURITY",
    "ALTER TABLE interstellar.subject ENABLE ROW LEVEL SECURITY",
    "ALTER TABLE interstellar.subject FORCE ROW LEVEL SECURITY",
    "ALTER TABLE interstellar.subject_version ENABLE ROW LEVEL SECURITY",
    "ALTER TABLE interstellar.subject_version FORCE ROW LEVEL SECURITY",
    "ALTER TABLE interstellar.calculation_snapshot ENABLE ROW LEVEL SECURITY",
    "ALTER TABLE interstellar.calculation_snapshot FORCE ROW LEVEL SECURITY",
    """
    CREATE POLICY workspace_isolation ON interstellar.workspace
      USING (id = interstellar.current_workspace_id())
      WITH CHECK (id = interstellar.current_workspace_id())
    """,
    """
    CREATE POLICY location_workspace_isolation ON interstellar.location
      USING (workspace_id = interstellar.current_workspace_id())
      WITH CHECK (workspace_id = interstellar.current_workspace_id())
    """,
    """
    CREATE POLICY time_spec_workspace_isolation ON interstellar.time_spec
      USING (workspace_id = interstellar.current_workspace_id())
      WITH CHECK (workspace_id = interstellar.current_workspace_id())
    """,
    """
    CREATE POLICY subject_workspace_isolation ON interstellar.subject
      USING (workspace_id = interstellar.current_workspace_id())
      WITH CHECK (workspace_id = interstellar.current_workspace_id())
    """,
    """
    CREATE POLICY subject_version_workspace_isolation ON interstellar.subject_version
      USING (workspace_id = interstellar.current_workspace_id())
      WITH CHECK (workspace_id = interstellar.current_workspace_id())
    """,
    """
    CREATE POLICY calculation_snapshot_workspace_isolation ON interstellar.calculation_snapshot
      USING (workspace_id = interstellar.current_workspace_id())
      WITH CHECK (workspace_id = interstellar.current_workspace_id())
    """,
)

DOWNGRADE_STATEMENTS: tuple[str, ...] = (
    "DROP SCHEMA IF EXISTS interstellar CASCADE",
)
