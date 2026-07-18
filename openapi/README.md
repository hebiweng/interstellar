# Interstellar OpenAPI

`openapi.yaml` is the HTTP source of truth for `/api/v1`. It uses OpenAPI 3.1 and references
the JSON Schema 2020-12 contracts in `../packages/canonical-schema`.

Implementation rules:

- Mount the document at `/api/v1/openapi.json` after resolving file references for deployment.
- Use `Idempotency-Key` on mutating commands and `If-Match` for draft revisions.
- Prefer the recipe flow (`draft → resolve → confirm`) for product clients; the calculation
  endpoint is the low-level declarative equivalent and may not bypass preflight.
- Return `201` only when a synchronous result is complete. Return `202 Job` for long work.
- Serve job events as `text/event-stream` and support `Last-Event-ID`.
- Return all errors as `application/problem+json` with a stable domain `code`.
- Keep sensitive birth data, question text, and anonymous access tokens out of URLs and logs.

Before releasing an SDK, bundle external `$ref` values into a standalone document and run an
OpenAPI 3.1 validator. Generated clients must preserve the immutable calculation, recipe,
subject-version, and report resources rather than exposing update operations for them.
