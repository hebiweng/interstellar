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

When documents disagree, stable IDs and catalog-owned fields follow the relevant YAML catalog; behavioral and engineering constraints follow the development specification.

## Validate the baseline

Python 3 with PyYAML is required for catalog validation. Node.js `>=22.13.0` is required for the prototype.

```bash
npm install
npm run docs:validate
npm run build
npm test
```

`npm run docs:validate` checks catalog counts, unique IDs, calculation/capability ownership, model and intent references, output-view references, render dependencies, work-package references, and Markdown code fences.

## Prototype

```bash
npm run dev
```

The frontend is a product-flow prototype, not a working astrology engine. Demo values must remain labeled as virtual/cached/prototype data. It demonstrates the unified analysis center, “add and analyze” flow, Recipe preflight, on-demand calculation planning, result workspace, chart catalog, evidence drill-down, and report profiles.

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
- planned API: FastAPI/Python;
- planned storage: PostgreSQL/PostGIS, Redis, and S3-compatible object storage;
- planned local deployment: Docker Compose;
- `.openai/hosting.json` describes the prototype hosting bindings.

The current `db/` and `worker/` files are prototype scaffolding and do not replace the canonical backend plan in the development specification.
