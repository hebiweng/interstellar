-- M0 infrastructure bootstrap only. Business schemas and tables belong to M1.
-- The official PostGIS image already installs the extension binaries; this
-- script enables only the extensions required by the canonical platform.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

COMMENT ON EXTENSION postgis IS
  'Spatial support for canonical locations, timezone boundaries, and geographic astrology';
COMMENT ON EXTENSION pgcrypto IS
  'Cryptographic primitives used by later application migrations';
