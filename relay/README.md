# Interstellar LLM Relay (Go)

Docker-containerized forwarding service: the iOS app sends calculated chart
facts and the relay injects the admin-managed API key + prompt template, calls
the OpenAI-compatible upstream, validates the structured JSON output and caches
the result so identical parameters never call the LLM twice.

## Endpoints

- `POST /v1/generate` — consumer generation (chart or period report).
  Body: `{mode, chartKind|periodType, preset, profileHash, params, facts, cardIDs, locale, clientVersion}`.
  Response: `{report: {title, subtitle, sections[]}, cards: {cardID: {detail}}, model, cached}`.
- `GET /v1/health`
- Admin API (Bearer token from `POST /admin/login`):
  - `GET|POST|PUT /admin/providers` · `DELETE /admin/providers/{id}`
  - `GET /admin/providers/{id}/models` — pulls the model list from the upstream with the stored key
  - `POST /admin/providers/{id}/test` — connectivity check
  - `GET|PUT /admin/prompts` · `POST /admin/prompts/{scope}/{locale}/restore`
  - `GET /admin/usage`

## Environment

| Var | Meaning |
|---|---|
| `RELAY_ADDR` | listen address (default `:8080`) |
| `RELAY_DB_PATH` | SQLite path (default `./relay.db`) |
| `RELAY_SECRET` | **required** — derives key encryption + admin session signing |
| `RELAY_ADMIN_USER` / `RELAY_ADMIN_PASS` | bootstrap admin on first run |
| `RELAY_SEED_PROMPTS` | `1` to insert default prompt templates for missing scopes |

## Build & test

```sh
cd relay
go mod tidy
go test ./...
go vet ./...
# Build with Buildx (multi-platform / linux/amd64 for the aliyun host):
docker buildx build --platform linux/amd64 -t interstellar-relay:latest .
```
The compose service uses `interstellar-relay:${INTERSTELLAR_IMAGE_TAG:-latest}`; either push to a registry or
`docker buildx build --load` on the host before `docker compose -f infra/deploy/compose.production.yaml up -d`.

## Deploy

Add the service to `infra/deploy/compose.production.yaml` with a named volume at
`/data` and the env above; route `/relay/*` and `/xiaoguiwk-api/*` in
`infra/deploy/Caddyfile.fate` to the container.
