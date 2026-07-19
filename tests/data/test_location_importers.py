from __future__ import annotations

import json
from dataclasses import replace
from io import StringIO
from pathlib import Path
from zipfile import ZipFile

import pytest

from interstellar_core.domain import DomainError
from interstellar_core.location.importers import (
    enrich_admin_names,
    iter_geonames,
    load_alternate_names,
    load_geonames,
    load_geonames_admin_names,
    load_timezone_geojson,
    merge_alternate_names,
    validate_coordinates,
)

FIXTURES = Path(__file__).parent / "fixtures"


def test_geonames_and_alternate_name_contracts_are_streamable() -> None:
    with (FIXTURES / "geonames.tsv").open(encoding="utf-8") as places_handle:
        places = tuple(iter_geonames(places_handle))
    with (FIXTURES / "alternateNamesV2.tsv").open(encoding="utf-8") as aliases_handle:
        aliases = load_alternate_names(aliases_handle)
    merged = tuple(merge_alternate_names(places, aliases))

    beijing = next(place for place in merged if place.geonames_id == 1816670)
    assert "北京市" in beijing.alternate_names
    assert beijing.timezone_id == "Asia/Shanghai"


def test_geonames_admin_hierarchy_replaces_opaque_codes() -> None:
    with (FIXTURES / "geonames.tsv").open(encoding="utf-8") as places_handle:
        places = tuple(iter_geonames(places_handle))
    places = tuple(
        replace(place, admin_path=("22", "11876380"))
        if place.geonames_id == 1816670
        else place
        for place in places
    )
    admin_names = load_geonames_admin_names(
        StringIO(
            "CN.22\tBeijing Municipality\tBeijing Municipality\t2038349\n"
            "CN.22.11876380\tBeijing\tBeijing\t11876380\n"
        )
    )

    enriched = tuple(enrich_admin_names(places, admin_names))
    beijing = next(place for place in enriched if place.geonames_id == 1816670)

    assert beijing.admin_path == ("Beijing Municipality", "Beijing")


def test_geonames_admin_parser_rejects_incomplete_rows() -> None:
    with pytest.raises(DomainError) as caught:
        load_geonames_admin_names(StringIO("CN.22\n"))
    assert caught.value.code == "GEONAMES_ADMIN_ROW_INVALID"


def test_timezone_geojson_contract_keeps_only_required_fields() -> None:
    features = load_timezone_geojson(FIXTURES / "timezone-boundaries.geojson")
    assert len(features) == 5
    assert set(features[0]) == {"type", "properties", "geometry"}
    assert json.dumps(features, ensure_ascii=False)


def test_official_archives_can_be_loaded_without_extraction(tmp_path: Path) -> None:
    geonames_archive = tmp_path / "cities500.zip"
    with ZipFile(geonames_archive, "w") as archive:
        archive.write(FIXTURES / "geonames.tsv", arcname="cities500.txt")
    boundaries_archive = tmp_path / "timezones-now.geojson.zip"
    with ZipFile(boundaries_archive, "w") as archive:
        archive.write(
            FIXTURES / "timezone-boundaries.geojson",
            arcname="combined-now.json",
        )

    assert load_geonames(geonames_archive)[0].name == "Beijing"
    assert load_timezone_geojson(boundaries_archive)[0]["properties"]["tzid"] == (
        "Asia/Shanghai"
    )


@pytest.mark.parametrize(
    ("latitude", "longitude", "code"),
    [(91, 0, "LOCATION_LATITUDE_INVALID"), (0, 180, "LOCATION_LONGITUDE_INVALID")],
)
def test_coordinate_validation_matches_canonical_schema(
    latitude: float, longitude: float, code: str
) -> None:
    with pytest.raises(DomainError) as caught:
        validate_coordinates(latitude, longitude)
    assert caught.value.code == code
