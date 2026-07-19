# NASA/JPL NAIF SPICE validation kernels

This directory is the local, versioned astronomical **validation** source for
the natal slice. Interstellar continues to use Swiss Ephemeris as its primary
astrology calculation engine; these kernels are an independent reference and
must never be used to silently change astrology rules.

| File | Purpose | Official source | SHA-256 |
|---|---|---|---|
| `kernels/spk/de442.bsp` | Planet, Sun, Moon and Earth state vectors; 1549-12-31 through 2650-01-25 | https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/de442.bsp | `8d5001fab315eeff222cc51f7cf7ffcdb43fb38fb9ac73ff09e09a5b361fd388` |
| `kernels/lsk/naif0012.tls` | Leap-second kernel | https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/naif0012.tls | `678e32bdb5a744117a467cd9601cd6b373f0e9bc9bbde1371d5eee39600a039b` |
| `kernels/pck/pck00011.tpc` | IAU planetary constants and body orientation model | https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00011.tpc | `3dff7b1dbeceaa01f25467767d3fa25816051c85d162d1edf04acb310ee28bb1` |

The upstream NAIF checksum index records MD5
`446656322267e7b819a26cb08a0d8718` for `de442.bsp`; the downloaded file matches
that upstream value in addition to the repository SHA-256 lock.

Acquired 2026-07-19 from the official NAIF HTTPS directories. Preserve NASA,
JPL, Caltech and NAIF notices and credit NAIF/SPICE in validation documentation.
No web request is made during a user calculation.

`de442.bsp` exceeds the ordinary GitHub per-file limit. A fresh clone restores
that exact locked artifact with:

```bash
python3 scripts/fetch_jpl_validation_kernels.py
```

The script downloads only the official immutable NAIF URL, verifies byte size
and SHA-256, and atomically promotes the completed file. `--verify-only` is
available for release checks. This is a deployment/bootstrap step, never an
online runtime fallback.

The files being present does not by itself make the natal engine Stable. A
separately reviewed SPICE adapter, coordinate-frame conversion, tolerance
policy and differential fixture suite must pass before the JPL validation gate
can be promoted.
