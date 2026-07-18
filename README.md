# Interstellar

Interstellar is a professional Western-astrology calculation, research, visualization, and evidence-reporting platform. V1 prioritizes deterministic calculation and professional workflows; it does not include AI interpretation or a consumer horoscope experience.

The current repository contains the product/development baseline and an interactive frontend prototype. The normative scope is:

- 12 backend `AnalysisModel` definitions;
- 24 user-facing `TopicModel` definitions;
- 35 `AnalysisIntent` choices;
- 99 registered deterministic calculations;
- 146 registered render views, of which 1–128 are the professional V1 baseline;
- six report profiles, three report densities, and six evidence/report layers.

## Documentation map

| Document | Authority |
|---|---|
| [`docs/v1-development-spec.md`](./docs/v1-development-spec.md) | Architecture, domain contracts, API, workflow, security, testing, and acceptance |
| [`docs/project-plan.md`](./docs/project-plan.md) | 24-month scope, milestones, resources, risks, and post-V1 roadmap |
| [`docs/analysis-catalog.yaml`](./docs/analysis-catalog.yaml) | Entry points, models, intents, recipes, output profiles, and reports |
| [`docs/capabilities.yaml`](./docs/capabilities.yaml) | Capability ownership, phase, dependencies, data sources, and maturity |
| [`docs/calculation-catalog.yaml`](./docs/calculation-catalog.yaml) | Stable calculation IDs, result contracts, release, and maturity targets |
| [`docs/calculation-result-catalog.md`](./docs/calculation-result-catalog.md) | Raw and derived result fields, boundaries, units, and null semantics |
| [`docs/render-catalog.yaml`](./docs/render-catalog.yaml) | All 146 view IDs, dependencies, renderer, and release scope |
| [`docs/algorithm-card-template.md`](./docs/algorithm-card-template.md) | Required algorithm/model/report-rule decision record |
| [`docs/m24-development-assets.md`](./docs/m24-development-assets.md) | Current implementation readiness, authority map, start order, and known blockers |
| [`docs/backlog/m24-single-owner.yaml`](./docs/backlog/m24-single-owner.yaml) | M0—M24 single-accountable-owner ledger with 100 acceptance-based tasks |
| [`docs/backlog/execution-controller.yaml`](./docs/backlog/execution-controller.yaml) | Five stage gates, parallel lanes, failure behavior, and automatic phase advancement |
| [`docs/backlog/execution-state.yaml`](./docs/backlog/execution-state.yaml) | Current active phase, work packages, evidence, and blockers |
| [`packages/canonical-schema/`](./packages/canonical-schema/) | JSON Schema 2020-12 source of truth for domain and persisted contracts |
| [`openapi/openapi.yaml`](./openapi/openapi.yaml) | OpenAPI 3.1 source of truth for `/api/v1` and generated SDKs |
| [`algorithm-cards/catalog.yaml`](./algorithm-cards/catalog.yaml) | Capability-to-algorithm-card coverage and implementation status |
| [`data-manifests/catalog.yaml`](./data-manifests/catalog.yaml) | Official data acquisition, version, license, attribution, and failure strategy |
| [`presets/official/`](./presets/official/) | Versioned default model components and user-overridable parameters |
| [`rules/official/`](./rules/official/) | Deterministic base-model and topic-model rule packs |
| [`reports/`](./reports/) | Report profiles and deterministic Chinese/English template contracts |

When documents disagree, stable IDs and catalog-owned fields follow the relevant YAML catalog; behavioral and engineering constraints follow the development specification.

## Foundation development environment

Python 3.13 and Node.js `>=22.13.0` are required. Install the independently pinned Python runtime and development dependencies, then install the root Web dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r apps/api/requirements.lock -r requirements-dev.lock
npm ci
npm run foundation:check
```

`npm run foundation:check` runs catalog validation, OpenAPI/JSON Schema validation, deterministic generated-contract drift checks, contract tests, Python lint and tests, Web lint, Web build, and rendered-HTML tests. `npm run docs:validate` remains available for the catalog-only gate.

Run the three application processes independently:

```bash
npm run dev
npm run api:dev
npm run worker:once
```

Local PostgreSQL/PostGIS, Redis, MinIO, and Mailpit are defined in `compose.yaml`; copy `.env.example` to `.env`, replace every `change-me-*` credential, and follow [`infra/README.md`](./infra/README.md). Infrastructure health is a separate executable gate from repository tests.

## Web workspace

```bash
npm run dev
```

The current frontend is still a product-flow prototype, not a working astrology engine. Demo values remain labeled as virtual/cached/prototype data, and planned maturity is distinct from actual implementation state. It demonstrates the unified analysis center, “add and analyze” flow, Recipe preflight, on-demand calculation planning, result workspace, chart catalog, evidence drill-down, and report profiles.

## Product invariants

- Never substitute `00:00` for an unknown birth time.
- A page load never calculates every model or chart.
- Every execution resolves to an immutable `AnalysisRecipe` and `CalculationSnapshot`.
- Required dependencies are server-selected and locked; optional extensions are explicit.
- AI never performs ephemeris, house, aspect, or exact timing calculation.
- A formal report requires an approved `ReportRulePack`; otherwise results remain structured facts/evidence or a technical report.
- Proprietary commercial astrology models, texts, and weights are not executable without written permission.
- V1 uses a zero-crawler data strategy and official, versioned sources.

## Current implementation shape

- frontend: Next.js/React through vinext;
- Foundation API: FastAPI/Python health, readiness, status, request context, and RFC 9457-style problem details;
- Foundation Worker: dependency-free heartbeat runner with liveness inspection;
- local infrastructure: PostgreSQL/PostGIS, Redis, MinIO, and Mailpit through Docker Compose;
- `.openai/hosting.json` describes the prototype hosting bindings.

The current `db/` and `worker/` files are prototype scaffolding and do not replace the canonical backend plan in the development specification.

Current readiness is deliberately explicit: planning and implementation contracts are present; production astrology calculation, persistence, API, worker, and render code are still `not_started` unless an individual capability later says otherwise. Start with M0 in the [development asset guide](./docs/m24-development-assets.md), not by extending prototype demo values.
