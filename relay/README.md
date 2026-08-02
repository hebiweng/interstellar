# Interstellar LLM Relay (Go)

Docker-containerized forwarding service: the iOS app sends calculated chart
facts and the relay injects the admin-managed API key + prompt template, calls
the OpenAI-compatible upstream, validates the structured JSON output and caches
the result so identical parameters never call the LLM twice.

## Production authority

- Consumer API and the standalone administrator are served from
  `https://aaadmin.xiaoguiwk.top`.
- Open `https://aaadmin.xiaoguiwk.top/xiaoguiwk` (or the site root) to manage
  DeepSeek, prompts and usage. The administrator is embedded in the Relay and
  does not depend on the paused Web application.
- DeepSeek is seeded with `https://api.deepseek.com` and
  `deepseek-v4-flash`; after deployment the administrator normally only needs
  to enter the API key and run the connection test.

## Endpoints

- `POST /v1/generate` — consumer generation (chart or period report).
  Body: `{mode, chartKind|periodType, preset, profileHash, params, facts, cardIDs, locale, clientVersion}`.
  Response: `{report: {title, subtitle, sections[]}, cards: {cardID: {detail}}, model, cached}`.
- `GET /v1/health`
- Admin API (revocable secure cookie from `POST /admin/login`):
  - `GET|POST|PUT /admin/providers` · `DELETE /admin/providers/{id}`
  - `GET /admin/providers/{id}/models` — pulls the model list from the upstream with the stored key
  - `POST /admin/providers/{id}/test` — connectivity check
  - `PUT /admin/models` — enable or disable a discovered provider model
  - `GET|PUT /admin/prompts` · `POST /admin/prompts/{scope}/{locale}/restore`
  - `GET /admin/usage`

## Environment

| Var | Meaning |
|---|---|
| `RELAY_ADDR` | listen address (default `:8080`) |
| `RELAY_DB_PATH` | SQLite path (default `./relay.db`) |
| `RELAY_SECRET` | **required, at least 32 bytes** — derives key encryption + cache encryption |
| `RELAY_ADMIN_USER` / `RELAY_ADMIN_PASS` | bootstrap admin; password must contain at least 24 bytes |
| `RELAY_PRUNE_OTHER_ADMINS` | `1` verifies the bootstrap account, then removes older admins and sessions |
| `RELAY_SEED_PROMPTS` | `1` to insert default prompt templates for missing scopes |
| `RELAY_SEED_DEEPSEEK` | defaults to `1`; ensures the DeepSeek V4 Flash provider exists |
| `RELAY_ALLOWED_ORIGIN` | production origin, `https://aaadmin.xiaoguiwk.top` |
| `RELAY_DAILY_GENERATION_QUOTA` | per-installation daily successful generation limit (default `20`) |
| `RELAY_ALLOW_DEV_BYPASS` | simulator-only development bypass; must be `0` in production |
| `RELAY_APP_ATTEST_APP_ID` | production App Attest app identifier |
| `RELAY_APP_ATTEST_ENVIRONMENT` | `production` for App Store/TestFlight/device release builds |
| `RELAY_APP_ATTEST_ALLOW_DEVELOPMENT` | `1` accepts Apple-verified development AAGUIDs for direct developer installs; this is not the simulator bypass |
| `RELAY_APP_ATTEST_BUNDLE_VERSION` | asserted client bundle version |

## Build & test

```sh
cd relay
go mod tidy
go test ./...
go vet ./...
# Build with Buildx (multi-platform / linux/amd64 for the aliyun host):
docker buildx build --platform linux/amd64 -t interstellar-relay:latest .
```
The compose service uses `interstellar-relay:${INTERSTELLAR_IMAGE_TAG:-latest}`.
Build the `linux/amd64` image locally or in CI, export and transfer it, then only
load and switch Compose on the small production host. Do not compile on the
server.

## Deploy

For the current iOS-only deployment use
`infra/deploy/compose.relay-only.yaml`; it starts only Caddy and Relay while the
legacy Web/API containers remain stopped. Back up `relay-data` before every
switch. `infra/deploy/compose.production.yaml` remains the future full-stack
definition, and the old `fate.xiaoguiwk.top` paths are compatibility routes only.
