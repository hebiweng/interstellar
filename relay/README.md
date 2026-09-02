# Interstellar LLM Relay (Go)

Docker-containerized forwarding service: the iOS app sends calculated chart
facts and the relay injects the admin-managed API key + prompt template, calls
the OpenAI-compatible upstream, and validates the structured JSON output. The
Relay never stores generated report text; the client persists the report first
and then acknowledges delivery to consume the reserved Credit.

## Production authority

- Consumer API and the standalone administrator are served from
  `https://aaadmin.xiaoguiwk.top`.
- Open `https://aaadmin.xiaoguiwk.top/xiaoguiwk` (or the site root) to manage
  DeepSeek, prompts, usage and user feedback. The administrator is embedded in the Relay and
  does not depend on the paused Web application.
- DeepSeek is seeded with `https://api.deepseek.com` and
  `deepseek-v4-flash`; after deployment the administrator normally only needs
  to enter the API key and run the connection test.

## Endpoints

- `POST /v1/generate` — consumer generation (chart or period report).
  Body includes `{userID, requestID, reportID, mode, chartKind|periodType, preset, profileHash, params, facts, locale, clientVersion}`.
  Response includes the validated report plus the same request/report IDs. Chart report sections cite only IDs from `facts.evidenceFacts`; no per-card content is generated or retained.
- `POST /v1/account/sync` — last-active, authoritative Premium and Credit balance.
- `POST /v1/reports/ack` — consumes the reservation only after local persistence.
- `POST /v1/store/transactions` — verifies StoreKit 2 signed transactions.
- `POST /v1/store/notifications` — verifies App Store Server Notifications V2.
- `GET /privacy` · `GET /terms` — public four-language legal pages.
- `GET /v1/health`
- `POST /v1/feedback` — accepts only the user-entered category, feedback text
  and optional contact. Content and contact are encrypted at rest; request and
  field sizes are bounded and the endpoint is rate-limited.
- Admin API (revocable secure cookie from `POST /admin/login`):
  - `GET|POST|PUT /admin/providers` · `DELETE /admin/providers/{id}`
  - `GET /admin/providers/{id}/models` — pulls the model list from the upstream with the stored key
  - `POST /admin/providers/{id}/test` — connectivity check
  - `PUT /admin/models` — enable or disable a discovered provider model
  - `GET|PUT /admin/prompts` · `POST /admin/prompts/{scope}/{locale}/restore`
  - `GET /admin/usage`
  - `GET /admin/reports?userID=&chartType=&language=&status=&date=`
  - `GET /admin/users` · `GET /admin/users/{uuid}`
  - `POST /admin/users/{uuid}/credits` · `POST /admin/users/{uuid}/premium`
  - `GET /admin/feedback?status=&type=` · `PATCH /admin/feedback/{id}`

## Environment

| Var | Meaning |
|---|---|
| `RELAY_ADDR` | listen address (default `:8080`) |
| `RELAY_DB_PATH` | SQLite path (default `./relay.db`) |
| `RELAY_SECRET` | **required, at least 32 bytes** — derives secret-field encryption |
| `RELAY_ADMIN_USER` / `RELAY_ADMIN_PASS` | bootstrap admin; password must contain at least 24 bytes |
| `RELAY_PRUNE_OTHER_ADMINS` | `1` verifies the bootstrap account, then removes older admins and sessions |
| `RELAY_SEED_PROMPTS` | `1` to insert default prompt templates for missing scopes |
| `RELAY_SEED_PROVIDERS` | `1` seeds missing built-in DeepSeek/OpenAI connection presets without changing API keys, admin edits, or the current default Provider |
| `RELAY_ALLOWED_ORIGIN` | production origin, `https://aaadmin.xiaoguiwk.top` |
| `RELAY_DAILY_GENERATION_QUOTA` | per-installation daily successful generation limit (default `20`) |
| `RELAY_ALLOW_DEV_BYPASS` | temporary Debug/simulator development bypass while App Attest entitlement is unavailable; must be `0` before release |
| `RELAY_APP_ATTEST_APP_ID` | production App Attest app identifier |
| `RELAY_APP_ATTEST_ENVIRONMENT` | `production` for App Store/TestFlight/device release builds |
| `RELAY_APP_ATTEST_ALLOW_DEVELOPMENT` | `1` accepts Apple-verified development AAGUIDs for direct developer installs; this is not the simulator bypass |
| `RELAY_APP_ATTEST_BUNDLE_VERSION` | asserted client bundle version |
| `RELAY_APP_STORE_ISSUER_ID` | issuer ID shown under App Store Connect → Users and Access → Integrations → In-App Purchase |
| `RELAY_APP_STORE_KEY_ID` | key ID for the downloaded In-App Purchase `.p8` key |
| `RELAY_APP_STORE_PRIVATE_KEY_PATH` | container path to the read-only `.p8` key; never store the key in Git or an environment variable |
| `RELAY_APP_STORE_RECONCILE_INTERVAL_HOURS` | interval for subscription status and failed-notification recovery; defaults to 6 hours |

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
