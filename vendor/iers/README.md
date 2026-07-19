# IERS Earth-orientation data

| Field | Value |
|---|---|
| Artifact | `finals2000A-2026-07-19.all` |
| Official source | https://datacenter.iers.org/data/9/finals2000A.all |
| Retrieved | 2026-07-19 |
| Size | 3,755,676 bytes |
| SHA-256 | `d4bb5af084caf3e82621bc75aad902dc7ad9e38e785a97d3fcac0a23d89644fb` |
| Role | Earth orientation, UT1-UTC, polar motion and nutation validation input |

This is a dated local snapshot. Runtime calculations must not fetch the live
IERS endpoint. A new snapshot is added as a new file, checksum-verified and
regression-tested before promotion; the previous verified snapshot remains
available for reproducibility.

Bundling the source does not activate high-precision IERS corrections by
itself. The coordinate adapter and tolerance tests must be implemented before
results may claim to use this dataset.
