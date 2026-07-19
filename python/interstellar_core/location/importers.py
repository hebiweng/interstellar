"""Streaming parsers for official GeoNames and timezone boundary inputs."""

from __future__ import annotations

import json
from collections.abc import Iterable, Iterator, Mapping
from contextlib import contextmanager
from dataclasses import replace
from io import TextIOWrapper
from pathlib import Path
from typing import Any, TextIO
from zipfile import BadZipFile, ZipFile

from interstellar_core.domain.errors import DomainError

from .models import PlaceRecord

GEONAMES_COLUMN_COUNT = 19


def validate_coordinates(latitude: float, longitude: float) -> None:
    if not -90 <= latitude <= 90:
        raise DomainError("LOCATION_LATITUDE_INVALID", "latitude must be between -90 and 90")
    if not -180 <= longitude < 180:
        raise DomainError(
            "LOCATION_LONGITUDE_INVALID", "longitude must be at least -180 and less than 180"
        )


def parse_geonames_line(line: str, *, line_number: int) -> PlaceRecord:
    columns = line.rstrip("\n").split("\t")
    if len(columns) != GEONAMES_COLUMN_COUNT:
        raise DomainError(
            "GEONAMES_ROW_INVALID",
            f"line {line_number} has {len(columns)} columns; expected {GEONAMES_COLUMN_COUNT}",
        )
    try:
        geonames_id = int(columns[0])
        latitude = float(columns[4])
        longitude = float(columns[5])
        population = int(columns[14] or 0)
        elevation = float(columns[15]) if columns[15] else None
    except ValueError as exc:
        raise DomainError(
            "GEONAMES_ROW_INVALID", f"line {line_number} has invalid numbers"
        ) from exc
    validate_coordinates(latitude, longitude)
    if len(columns[8]) != 2 or not columns[8].isalpha():
        raise DomainError("GEONAMES_ROW_INVALID", f"line {line_number} has invalid country code")

    admin_path = tuple(value for value in columns[10:14] if value)
    alternates = tuple(value.strip() for value in columns[3].split(",") if value.strip())
    return PlaceRecord(
        geonames_id=geonames_id,
        name=columns[1],
        ascii_name=columns[2],
        alternate_names=alternates,
        latitude=latitude,
        longitude=longitude,
        country_code=columns[8].upper(),
        admin_path=admin_path,
        feature_class=columns[6],
        feature_code=columns[7],
        population=population,
        timezone_id=columns[17] or None,
        elevation_m=elevation,
    )


def iter_geonames(handle: TextIO) -> Iterator[PlaceRecord]:
    for line_number, line in enumerate(handle, start=1):
        if not line.strip() or line.startswith("#"):
            continue
        yield parse_geonames_line(line, line_number=line_number)


@contextmanager
def open_geonames_text(path: str | Path) -> Iterator[TextIO]:
    """Open a plain GeoNames dump or its official single-file ZIP archive.

    Keeping the official archive compressed avoids checking a roughly 40 MB
    generated text file into the repository while preserving a byte-for-byte
    upstream artifact and checksum.
    """

    resolved = Path(path)
    if resolved.suffix.lower() != ".zip":
        with resolved.open(encoding="utf-8") as handle:
            yield handle
        return

    try:
        with ZipFile(resolved) as archive:
            members = sorted(
                item
                for item in archive.namelist()
                if not item.endswith("/") and item.lower().endswith(".txt")
            )
            if len(members) != 1:
                raise DomainError(
                    "GEONAMES_ARCHIVE_INVALID",
                    "GeoNames archive must contain exactly one text dump",
                )
            with (
                archive.open(members[0]) as raw,
                TextIOWrapper(raw, encoding="utf-8") as handle,
            ):
                yield handle
    except BadZipFile as exc:
        raise DomainError(
            "GEONAMES_ARCHIVE_INVALID", "GeoNames archive is not a valid ZIP file"
        ) from exc


def load_geonames(path: str | Path) -> tuple[PlaceRecord, ...]:
    with open_geonames_text(path) as handle:
        return tuple(iter_geonames(handle))


def load_geonames_admin_names(handle: TextIO) -> dict[str, str]:
    """Load GeoNames admin1/admin2 code files into one display-name map."""

    result: dict[str, str] = {}
    for line_number, line in enumerate(handle, start=1):
        if not line.strip() or line.startswith("#"):
            continue
        columns = line.rstrip("\n").split("\t")
        if len(columns) < 2 or not columns[0].strip() or not columns[1].strip():
            raise DomainError(
                "GEONAMES_ADMIN_ROW_INVALID",
                f"line {line_number} lacks an admin code or display name",
            )
        result[columns[0].strip()] = columns[1].strip()
    return result


def enrich_admin_names(
    places: Iterable[PlaceRecord], admin_names: Mapping[str, str]
) -> Iterator[PlaceRecord]:
    """Replace opaque GeoNames admin codes with official hierarchy labels."""

    for place in places:
        resolved: list[str] = []
        code_path: list[str] = [place.country_code]
        for code in place.admin_path:
            code_path.append(code)
            resolved.append(admin_names.get(".".join(code_path), code))
        yield replace(place, admin_path=tuple(resolved))


def load_alternate_names(handle: TextIO) -> dict[int, tuple[str, ...]]:
    """Parse alternateNamesV2 rows into a small import-time lookup.

    Full production imports should stage this file in PostgreSQL instead of
    retaining it in memory; this function defines the file contract and is used
    by deterministic fixtures.
    """

    result: dict[int, list[str]] = {}
    for line_number, line in enumerate(handle, start=1):
        if not line.strip() or line.startswith("#"):
            continue
        columns = line.rstrip("\n").split("\t")
        if len(columns) < 4:
            raise DomainError(
                "GEONAMES_ALTERNATE_ROW_INVALID", f"line {line_number} has fewer than 4 columns"
            )
        try:
            geonames_id = int(columns[1])
        except ValueError as exc:
            raise DomainError(
                "GEONAMES_ALTERNATE_ROW_INVALID", f"line {line_number} has invalid id"
            ) from exc
        name = columns[3].strip()
        if name:
            result.setdefault(geonames_id, []).append(name)
    return {key: tuple(dict.fromkeys(values)) for key, values in result.items()}


def merge_alternate_names(
    places: Iterable[PlaceRecord], alternates: Mapping[int, tuple[str, ...]]
) -> Iterator[PlaceRecord]:
    for place in places:
        merged = tuple(
            dict.fromkeys((*place.alternate_names, *alternates.get(place.geonames_id, ())))
        )
        yield PlaceRecord(
            geonames_id=place.geonames_id,
            name=place.name,
            ascii_name=place.ascii_name,
            alternate_names=merged,
            latitude=place.latitude,
            longitude=place.longitude,
            country_code=place.country_code,
            admin_path=place.admin_path,
            feature_class=place.feature_class,
            feature_code=place.feature_code,
            population=place.population,
            timezone_id=place.timezone_id,
            elevation_m=place.elevation_m,
        )


def validate_timezone_feature_collection(document: object) -> tuple[dict[str, Any], ...]:
    if not isinstance(document, Mapping) or document.get("type") != "FeatureCollection":
        raise DomainError("TIMEZONE_BOUNDARY_INVALID", "input must be a GeoJSON FeatureCollection")
    features = document.get("features")
    if not isinstance(features, list):
        raise DomainError("TIMEZONE_BOUNDARY_INVALID", "features must be a list")
    validated: list[dict[str, Any]] = []
    for index, feature_value in enumerate(features):
        if not isinstance(feature_value, Mapping) or feature_value.get("type") != "Feature":
            raise DomainError("TIMEZONE_BOUNDARY_INVALID", f"feature {index} is invalid")
        properties = feature_value.get("properties")
        geometry = feature_value.get("geometry")
        if not isinstance(properties, Mapping) or not isinstance(properties.get("tzid"), str):
            raise DomainError("TIMEZONE_BOUNDARY_INVALID", f"feature {index} lacks tzid")
        if not isinstance(geometry, Mapping) or geometry.get("type") not in {
            "Polygon",
            "MultiPolygon",
        }:
            raise DomainError(
                "TIMEZONE_BOUNDARY_INVALID", f"feature {index} must be Polygon or MultiPolygon"
            )
        coordinates = geometry.get("coordinates")
        _validate_coordinate_tree(coordinates, f"feature {index}.geometry.coordinates")
        validated.append(
            {
                "type": "Feature",
                "properties": {"tzid": properties["tzid"]},
                "geometry": {"type": geometry["type"], "coordinates": coordinates},
            }
        )
    return tuple(validated)


def _validate_coordinate_tree(value: object, path: str) -> None:
    if not isinstance(value, list) or not value:
        raise DomainError("TIMEZONE_BOUNDARY_INVALID", f"{path} must be a non-empty array")
    if len(value) >= 2 and all(isinstance(item, int | float) for item in value[:2]):
        latitude = float(value[1])
        longitude = float(value[0])
        # GeoJSON polygon rings may legally close on +180°. Canonical user
        # point coordinates remain half-open [-180, 180), but rejecting the
        # antimeridian in an official boundary dataset would make the archive
        # impossible to load.
        if not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
            raise DomainError(
                "TIMEZONE_BOUNDARY_INVALID",
                f"{path} contains an out-of-range coordinate",
            )
        return
    for index, child in enumerate(value):
        _validate_coordinate_tree(child, f"{path}[{index}]")


def load_timezone_geojson(path: str | Path) -> tuple[dict[str, Any], ...]:
    resolved = Path(path)
    if resolved.suffix.lower() != ".zip":
        document = json.loads(resolved.read_text(encoding="utf-8"))
        return validate_timezone_feature_collection(document)

    try:
        with ZipFile(resolved) as archive:
            members = sorted(
                item
                for item in archive.namelist()
                if not item.endswith("/")
                and item.lower().endswith((".json", ".geojson"))
            )
            if len(members) != 1:
                raise DomainError(
                    "TIMEZONE_BOUNDARY_ARCHIVE_INVALID",
                    "timezone boundary archive must contain exactly one GeoJSON document",
                )
            document = json.loads(archive.read(members[0]).decode("utf-8"))
    except BadZipFile as exc:
        raise DomainError(
            "TIMEZONE_BOUNDARY_ARCHIVE_INVALID",
            "timezone boundary archive is not a valid ZIP file",
        ) from exc
    return validate_timezone_feature_collection(document)
