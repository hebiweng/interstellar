# Contract quality gate

This suite protects the M0 source-of-truth contracts without requiring a running API.

Run locally:

```bash
python3 scripts/validate_openapi.py
python3 scripts/generate_contract_types.py --check
python3 -m unittest discover -s tests/contracts -p 'test_*.py'
```

The committed files in `packages/canonical-schema/generated/` are stable index types,
not payload validators. Runtime services must validate payloads against the source JSON
Schemas. Regenerate indexes after any accepted OpenAPI or Schema change:

```bash
python3 scripts/generate_contract_types.py
```

CI fails when a local `$ref` is unresolved, an operation ID is absent or duplicated, a
Schema violates the built-in Draft 2020-12 structural checks, or generated files differ.
If the optional `jsonschema` package is installed, the same validator additionally runs
the full Draft 2020-12 meta-schema check.
