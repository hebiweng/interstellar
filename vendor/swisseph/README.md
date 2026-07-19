# Swiss Ephemeris runtime data

This directory contains the smallest official data subset required by the
current natal-first slice.

| File | Purpose | Upstream | SHA-256 |
|---|---|---|---|
| `ephe/sepl_18.se1` | 主要行星，1800–2399 | `aloistr/swisseph` official repository, release family 2.10.3 / DE441 | `ca1393ceab3a44fbc895887cf789c68819ae6a1cbc9b22225872dbe4ccd99a66` |
| `ephe/semo_18.se1` | 月球，1800–2399 | `aloistr/swisseph` official repository, release family 2.10.3 / DE441 | `1ca07bd67c24374d77226180c20a4f9996cba013697894810518e7eb582ca4f7` |
| `ephe/seas_18.se1` | Chiron, Ceres, Pallas, Juno and Vesta, 1800–2399 | `aloistr/swisseph` official repository, release family 2.10.3 / DE441 | `a2cd8fc33807c78ca9a700c91c2e042258b12fc4796519e00781440b5ad8b2e2` |
| `ephe/seorbel.txt` | Swiss fictitious-body orbital elements, including Hamburg TNP definitions | `aloistr/swisseph` official repository | `97b454ff78f4f4716b5cc987a93ca8f33e44ef4b524a165a155a8a4885fd2e18` |
| `ephe/sefstars.txt` | Swiss fixed-star catalogue (stars brighter than magnitude 5) | `aloistr/swisseph` official repository | `18b0dcafbe5b7240773daba2c038a325f5b3fc4163f61e0a7f4e92abd4f517c6` |

Source URL:
`https://raw.githubusercontent.com/aloistr/swisseph/master/ephe/`

Downloaded and verified on 2026-07-18. This artifact is used under the
project's AGPL-3.0-or-later Swiss Ephemeris license choice. A closed-source
commercial deployment must obtain the Swiss Ephemeris Professional License
before operation.

The 1800–2399 natal slice now has local Swiss files for the main planets, Moon,
the bundled common asteroid set, the configured Hamburg hypothetical points,
and the named fixed-star catalogue. Outside that coverage window the adapter
still follows its explicit fallback policy and records any Moshier use. Missing
asteroid data is never silently replaced.
