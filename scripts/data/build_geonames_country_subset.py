#!/usr/bin/env python3
"""Build a deterministic country subset from a verified GeoNames release.

This command never downloads data. It derives a smaller production artifact
from the repository's locked official GeoNames files while retaining the
source release date and CC BY attribution requirements.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from zipfile import ZIP_DEFLATED, BadZipFile, ZipFile, ZipInfo


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--places", type=Path, required=True)
    parser.add_argument("--admin1", type=Path, required=True)
    parser.add_argument("--admin2", type=Path, required=True)
    parser.add_argument("--country-code", required=True)
    parser.add_argument("--source-version", required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    return parser.parse_args()


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _read_official_dump(path: Path) -> tuple[str, ...]:
    try:
        with ZipFile(path) as archive:
            members = [name for name in archive.namelist() if name.endswith(".txt")]
            if len(members) != 1:
                raise ValueError("GeoNames archive must contain exactly one text dump")
            with archive.open(members[0]) as handle:
                return tuple(line.decode("utf-8") for line in handle)
    except BadZipFile as error:
        raise ValueError(f"GeoNames archive is not a valid ZIP file: {path}") from error


def _filter_places(lines: tuple[str, ...], country_code: str) -> tuple[str, ...]:
    selected: list[str] = []
    for line_number, line in enumerate(lines, start=1):
        columns = line.rstrip("\n").split("\t")
        if len(columns) < 19:
            raise ValueError(f"invalid GeoNames row at line {line_number}")
        if columns[8].upper() == country_code:
            selected.append(line if line.endswith("\n") else f"{line}\n")
    if not selected:
        raise ValueError(f"no GeoNames places found for {country_code}")
    return tuple(selected)


def _filter_admin(path: Path, country_code: str) -> tuple[str, ...]:
    prefix = f"{country_code}."
    with path.open(encoding="utf-8") as handle:
        return tuple(line for line in handle if line.startswith(prefix))


def _write_deterministic_zip(path: Path, member_name: str, lines: tuple[str, ...]) -> None:
    info = ZipInfo(member_name, date_time=(1980, 1, 1, 0, 0, 0))
    info.compress_type = ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    with ZipFile(path, "w") as archive:
        archive.writestr(info, "".join(lines).encode("utf-8"))


def _write_lines(path: Path, lines: tuple[str, ...]) -> None:
    path.write_text("".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    country_code = args.country_code.strip().upper()
    if not re.fullmatch(r"[A-Z]{2}", country_code):
        raise ValueError("country code must contain exactly two ASCII letters")
    if not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", args.source_version):
        raise ValueError("source version must be an ISO release date")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    places = _filter_places(_read_official_dump(args.places), country_code)
    admin1 = _filter_admin(args.admin1, country_code)
    admin2 = _filter_admin(args.admin2, country_code)

    suffix = f"{country_code}-{args.source_version}"
    places_path = args.output_dir / f"cities500-{suffix}.zip"
    admin1_path = args.output_dir / f"admin1CodesASCII-{suffix}.txt"
    admin2_path = args.output_dir / f"admin2Codes-{suffix}.txt"
    _write_deterministic_zip(places_path, f"cities500-{country_code}.txt", places)
    _write_lines(admin1_path, admin1)
    _write_lines(admin2_path, admin2)

    artifacts = [places_path, admin1_path, admin2_path]
    print(
        json.dumps(
            {
                "country_code": country_code,
                "source_version": args.source_version,
                "place_records": len(places),
                "admin1_records": len(admin1),
                "admin2_records": len(admin2),
                "artifacts": [
                    {
                        "path": str(path),
                        "size_bytes": path.stat().st_size,
                        "sha256": _sha256(path),
                    }
                    for path in artifacts
                ],
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
