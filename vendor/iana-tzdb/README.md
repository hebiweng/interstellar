# Pinned IANA timezone rules

| Field | Value |
|---|---|
| Artifact | `tzdata-2026.3-py2.py3-none-any.whl` |
| Python package | `tzdata==2026.3` |
| IANA release | `2026c` |
| Source | https://pypi.org/project/tzdata/2026.3/ |
| Upstream rules | https://data.iana.org/time-zones/releases/ |
| SHA-256 | `dc096730c87af6cab1b171c9d532be840741ff5d459015e7f6947bd7d7e54931` |
| License | Apache-2.0 package; embedded IANA tzdb notices preserved |

The core calls `zoneinfo.reset_tzpath` so calculations use this pinned wheel's
zoneinfo tree instead of an unknown host operating-system database. The wheel is
kept locally for reproducible/offline installation; runtime dependencies also
pin the exact package version.
