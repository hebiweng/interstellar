# Interstellar local infrastructure

This directory provides the M0 single-machine development baseline. It runs
PostgreSQL with PostGIS, Redis, MinIO, an idempotent MinIO initializer, and
Mailpit. It intentionally contains no M1 business tables.

## Prerequisites and credentials

- Docker Engine with Docker Compose v2.
- At least 4 GB of free memory and 10 GB of free disk space.
- A local `.env` created from `.env.example`.

Create the environment file and replace every `change-me-*` value with a unique
secret. The Compose file has no credential defaults and refuses to render when
a required credential is missing.

```sh
cp .env.example .env
openssl rand -hex 32
docker compose config --quiet
```

Do not commit `.env`. MinIO root credentials are bootstrap credentials only;
application services use `INTERSTELLAR_MINIO_APP_ACCESS_KEY` and its restricted
bucket policy. Redis disables the default user and exposes a named ACL user.

## Start, inspect, and stop

From the repository root:

```sh
docker compose pull
docker compose up -d
docker compose ps
```

`minio-init` is a one-shot service. An `Exited (0)` status is healthy and means
the private buckets and restricted application identity were created. It is
safe to run again:

```sh
docker compose run --rm minio-init
```

Service endpoints are bound to loopback only:

| Service | Default endpoint | Health check |
|---|---|---|
| PostgreSQL/PostGIS | `127.0.0.1:5432` | `pg_isready` |
| Redis | `127.0.0.1:6379` | authenticated `PING` |
| MinIO S3 API | `http://127.0.0.1:9000` | `/minio/health/live` |
| MinIO console | `http://127.0.0.1:9001` | MinIO service health |
| Mailpit SMTP | `127.0.0.1:1025` | Mailpit `readyz` |
| Mailpit UI | `http://127.0.0.1:8025` | Mailpit `readyz` |

Inspect health and logs with:

```sh
docker compose ps
docker compose logs --tail=100 postgres redis minio mailpit minio-init
docker compose exec postgres psql -U "$INTERSTELLAR_POSTGRES_USER" -d "$INTERSTELLAR_POSTGRES_DB" -c 'SELECT PostGIS_Version();'
docker compose exec redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli --user "$REDIS_USERNAME" ping'
```

Stop containers without deleting data:

```sh
docker compose down
```

## Named volumes and data lifecycle

Compose owns four named volumes, prefixed by the Compose project name:

- `postgres-data`: database cluster and enabled extensions.
- `redis-data`: append-only and snapshot persistence.
- `minio-data`: objects, buckets, identities, and policies.
- `mailpit-data`: captured development messages.

List the resolved names with `docker volume ls --filter label=com.docker.compose.project=interstellar`.
Changing `COMPOSE_PROJECT_NAME` creates an independent stack and independent
volumes. Back up state before upgrades; do not copy a live database volume.

To deliberately destroy all local state, first verify the project and volume
names, then run `docker compose down --volumes`. This cannot be recovered unless
you created a backup.

## Initialization boundaries

PostgreSQL scripts under `infra/postgres/init` run only when `postgres-data` is
first created. They enable PostGIS and pgcrypto and restrict public schema
creation. M1 owns application schemas, roles, tables, RLS, and migrations.

MinIO initialization runs on every explicit `minio-init` execution and is
idempotent for buckets and policy attachment. Changing a persisted MinIO user's
secret may require an explicit credential-rotation operation; recreating the
container alone does not erase object-store identity state.

## Replacement compatibility

Application code must consume only the canonical URLs and S3-compatible fields
from `.env`, not container names or Docker APIs. This keeps replacement paths
open:

- PostgreSQL/PostGIS can be replaced with any compatible managed PostgreSQL.
- Redis can be replaced with a Redis protocol-compatible service supporting ACLs.
- MinIO can be replaced with an S3-compatible store by changing endpoint,
  region, credentials, and path-style setting.
- Mailpit can be replaced with an authenticated SMTP provider.

The project-scoped `backend` bridge network is attachable. Future application
containers join it through Compose; host-run applications use ports that are
published exclusively on `127.0.0.1`. Do not change those bindings to `0.0.0.0`
on a development machine without a separate access-control review.
