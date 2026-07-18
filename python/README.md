# Interstellar Python core

This package owns framework-independent boundaries shared by the API and worker.

- `domain`: immutable business values and domain errors; no web, database, queue or renderer imports.
- `application`: use-case orchestration against `ports` only.
- `ports`: protocols implemented by infrastructure adapters.
- `infrastructure`: adapter namespace; no concrete M0 adapters are claimed as complete.

Later calculation engines must return canonical records through these boundaries. M0 does not
contain an ephemeris adapter or any astrology calculation implementation.
