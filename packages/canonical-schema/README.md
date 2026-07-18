# Interstellar Canonical Schema

These files are the source of truth for persisted domain records, public API payloads,
generated SDK types, fixtures, and archive validation. They use JSON Schema 2020-12 and
stable English enum values. Third-party adapter payloads must be normalized into these
contracts before they cross the calculation-engine boundary.

## Contract map

| File | Root contract |
|---|---|
| `time-spec.schema.json` | Historical/local time, precision, UTC candidates and provenance |
| `location.schema.json` | WGS84 normalized location |
| `subject.schema.json` | `Subject`, immutable `SubjectVersion`, and version input |
| `analysis-draft.schema.json` | Mutable analysis selection and optimistic revision |
| `analysis-recipe.schema.json` | Immutable preflight DAG and output plan |
| `chart-request.schema.json` | Low-level deterministic calculation request |
| `chart-result.schema.json` | `Chart`, `Point`, `House`, `Aspect`, astronomical context |
| `output-manifest.schema.json` | Generated/degraded/blocked output coverage |
| `evidence.schema.json` | Snapshot-backed atomic evidence |
| `calculation-snapshot.schema.json` | Immutable reproducible result envelope |
| `report-document.schema.json` | Raw fact references through findings, conclusions, sections and document |
| `render-spec.schema.json` | Safe deterministic view configuration |
| `job.schema.json` | Async execution state and links |
| `problem-error.schema.json` | `application/problem+json` domain error |

## Code generation

OpenAPI clients should be generated from `../../openapi/openapi.yaml`; it references these
schemas directly. Backend domain types may be generated independently, but generated files
must not become the source of truth.

Recommended tooling:

```text
TypeScript: json-schema-to-typescript or openapi-typescript
Python:     datamodel-code-generator (Pydantic v2 target)
OpenAPI:    openapi-generator for external SDKs
```

Generation must fail on unresolved `$ref`, duplicate operation IDs, or schemas that cannot
be meta-validated. Commit generated types only if the repository adopts a deterministic
generator version and a CI diff check.

## Compatibility rules

- Additive optional fields are allowed within V1.
- Enum additions require consumers to preserve unknown values or a minor API notice.
- Required-field, meaning, unit, or nullability changes require `/api/v2`.
- Snapshot and recipe objects are immutable; replacement creates a new resource.
- Unknown birth time is represented explicitly and is never normalized to midnight.
- Units are encoded in field names (`*_deg`, `*_m`, `*_seconds`, `*_au`) where ambiguity is possible.
