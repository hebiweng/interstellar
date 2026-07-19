# Timezone Boundary Builder local dataset

| Field | Value |
|---|---|
| Artifact | `timezones-2026b.geojson.zip` |
| Upstream member | `combined.json` |
| Source | https://github.com/evansiroky/timezone-boundary-builder/releases/download/2026b/timezones.geojson.zip |
| Release | 2026b |
| Downloaded | 2026-07-19 |
| SHA-256 | `f892b57ce8c7d9633a03ce9e6775d54544c05d9b8d62029bc6543091cac213c4` |
| Output license | ODbL 1.0 |
| Attribution | Timezone Boundary Builder contributors and OpenStreetMap contributors |

The API reads the official full GeoJSON ZIP directly and resolves a selected
coordinate to an individual IANA timezone by exact polygon lookup. The compact
`now` artifact is deliberately not used because it merges zones with equal
current behavior and is unsafe for historical birth-time conversion. Ocean
coordinates, historical border uncertainty and unmatched points are never
guessed: the product exposes the GeoNames hint or requires an explicit IANA
timezone.

Do not use the public Nominatim service as a hidden fallback. Upgrade this
archive only through a versioned checksum and location/timezone regression run.
