# Swiss Ephemeris runtime data

This directory contains the smallest official data subset required by the
current natal-first slice.

| File | Purpose | Upstream | SHA-256 |
|---|---|---|---|
| `ephe/sepl_18.se1` | 主要行星，1800–2399 | `aloistr/swisseph` official repository, release family 2.10.3 / DE441 | `ca1393ceab3a44fbc895887cf789c68819ae6a1cbc9b22225872dbe4ccd99a66` |
| `ephe/semo_18.se1` | 月球，1800–2399 | `aloistr/swisseph` official repository, release family 2.10.3 / DE441 | `1ca07bd67c24374d77226180c20a4f9996cba013697894810518e7eb582ca4f7` |
| `ephe/seas_18.se1` | Chiron, Ceres, Pallas, Juno and Vesta, 1800–2399 | `aloistr/swisseph` official repository, release family 2.10.3 / DE441 | `a2cd8fc33807c78ca9a700c91c2e042258b12fc4796519e00781440b5ad8b2e2` |

Source URL:
`https://raw.githubusercontent.com/aloistr/swisseph/master/ephe/{sepl_18,semo_18,seas_18}.se1`

Downloaded and verified on 2026-07-18. This artifact is used under the
project's AGPL-3.0-or-later Swiss Ephemeris license choice. A closed-source
commercial deployment must obtain the Swiss Ephemeris Professional License
before operation.

The 1800–2399 natal slice now has local Swiss files for the main planets, Moon,
and the bundled common asteroid set. Outside that coverage window the adapter
still follows its explicit fallback policy and records any Moshier use. Missing
asteroid data is never silently replaced.
