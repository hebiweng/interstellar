# Natural Earth local world-map subset

| Field | Value |
|---|---|
| Version | Natural Earth 5.1.2 |
| Scale | 1:110m |
| Layers | Admin-0 countries, land, coastline |
| Format | GeoJSON |
| Official repository | https://github.com/nvkelso/natural-earth-vector/tree/v5.1.2 |
| License | Public domain |
| Retrieved | 2026-07-19 |

This minimal subset is sufficient as the deterministic base geometry for the
future global astrocartography, eclipse-path and static map renderers. It does
not enable those calculation/rendering capabilities by itself. The renderer,
projection policy, disputed-boundary presentation and visual regression suite
must still pass before a map view is published.

Files are taken from the official `v5.1.2` tag rather than a moving download
page. Each file is pinned by path, byte size and SHA-256 in
`data-manifests/locks/natural-earth-5.1.2-110m.json`. Higher-detail 50m/10m
layers must be added as separate versioned artifacts only when a concrete view
requires them.
