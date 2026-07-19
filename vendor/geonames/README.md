# GeoNames local place dataset

| Field | Value |
|---|---|
| Artifacts | `cities500-2026-07-19.zip`, `admin1CodesASCII-2026-07-19.txt`, `admin2Codes-2026-07-19.txt` |
| Upstream members | `cities500.txt`, `admin1CodesASCII.txt`, `admin2Codes.txt` |
| Source | https://download.geonames.org/export/dump/ |
| Downloaded | 2026-07-19 |
| SHA-256 | cities: `6cc1dd51bfdd407d626a3d3bc02226c36e44281fceecdc03019cf755c65d664a`; admin1: `34784457b76b988a669dff7c3e4b104e4902c0875643cff019281ac79dfa2992`; admin2: `314a76e0b02610c653947acbf4e9dceab6b20eb39a0e793e09fea55d3d1a96be` |
| License | CC BY 4.0 |
| Attribution | GeoNames, https://www.geonames.org/ |

The API reads the official ZIP and administrative code files directly. They are
used for offline place-name, alias, coordinate, elevation, readable
administrative hierarchy and IANA timezone-hint search. The `cities500`
scope covers populated places with population at least 500 plus administrative
seats. Street addresses, buildings and every historical place name are not in
scope; users can always enter coordinates and an IANA timezone explicitly.

Do not replace this file in place. Add a new versioned artifact, run the
location regression suite, update the checksum, then switch the configured
dataset version.
