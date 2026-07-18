from __future__ import annotations

import json
from pathlib import Path

import pytest

from interstellar_core.domain import DomainError
from interstellar_core.location.importers import (
    iter_geonames,
    load_alternate_names,
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


def test_timezone_geojson_contract_keeps_only_required_fields() -> None:
    features = load_timezone_geojson(FIXTURES / "timezone-boundaries.geojson")
    assert len(features) == 5
    assert set(features[0]) == {"type", "properties", "geometry"}
    assert json.dumps(features, ensure_ascii=False)


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
