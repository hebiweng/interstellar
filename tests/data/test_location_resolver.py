from __future__ import annotations

from pathlib import Path

from interstellar_core.location.importers import iter_geonames, load_timezone_geojson
from interstellar_core.location.models import ResolutionStatus
from interstellar_core.location.resolver import GeoJsonTimezoneIndex, LocationResolver, PlaceIndex

FIXTURES = Path(__file__).parent / "fixtures"


def _resolver() -> LocationResolver:
    with (FIXTURES / "geonames.tsv").open(encoding="utf-8") as handle:
        places = tuple(iter_geonames(handle))
    features = load_timezone_geojson(FIXTURES / "timezone-boundaries.geojson")
    return LocationResolver(
        PlaceIndex(places, dataset_version="fixture-geonames-v1"),
        GeoJsonTimezoneIndex(features, dataset_version="fixture-tz-v1"),
    )


def test_ambiguous_place_names_are_ranked_and_admin_hints_disambiguate() -> None:
    resolver = _resolver()
    unqualified = resolver.search("Springfield", country_code="US")
    assert [candidate.place.admin_path[0] for candidate in unqualified] == ["MA", "IL"]

    qualified = resolver.search("Springfield", country_code="US", admin_hints=["IL"])
    assert qualified[0].place.admin_path[0] == "IL"
    assert "admin_match" in qualified[0].match_reasons


def test_exact_timezone_polygon_produces_canonical_location() -> None:
    candidate = _resolver().search("Beijing", country_code="CN")[0]
    assert candidate.timezone.status is ResolutionStatus.RESOLVED
    assert candidate.timezone.selected_timezone_id == "Asia/Shanghai"

    canonical = candidate.to_canonical()
    assert {"name", "latitude", "longitude", "source"} <= canonical.keys()
    assert -90 <= canonical["latitude"] <= 90
    assert -180 <= canonical["longitude"] < 180
    assert canonical["country_code"] == "CN"
    assert all({"code", "message"} <= warning.keys() for warning in canonical["warnings"])


def test_boundary_overlap_returns_candidates_without_auto_selection() -> None:
    candidate = _resolver().search("Boundaryville")[0]
    assert candidate.timezone.status is ResolutionStatus.AMBIGUOUS
    assert {item.timezone_id for item in candidate.timezone.candidates} == {
        "Etc/GMT+1",
        "Etc/GMT-1",
    }
    assert candidate.to_canonical()["timezone_id"] is None
    assert candidate.timezone.warnings[0]["code"] == "TIMEZONE_BOUNDARY_AMBIGUOUS"


def test_boundary_miss_is_degraded_hint_not_an_automatic_timezone() -> None:
    candidate = _resolver().search("Hint Only")[0]
    assert candidate.timezone.status is ResolutionStatus.DEGRADED
    assert candidate.timezone.candidates[0].timezone_id == "Etc/UTC"
    assert candidate.timezone.selected_timezone_id is None
    assert candidate.to_canonical()["timezone_id"] is None


def test_ocean_location_is_explicitly_unresolved_without_nearest_zone_guess() -> None:
    candidate = _resolver().search("Ocean Station")[0]
    assert candidate.timezone.status is ResolutionStatus.UNRESOLVED
    assert candidate.timezone.candidates == ()
    assert candidate.timezone.warnings[0]["code"] == "TIMEZONE_UNRESOLVED"
    assert candidate.to_canonical()["timezone_id"] is None
