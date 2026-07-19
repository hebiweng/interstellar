"""Load the versioned, offline location resolver configured for this process."""

from __future__ import annotations

from pathlib import Path

from interstellar_core.location.importers import (
    enrich_admin_names,
    load_geonames,
    load_geonames_admin_names,
    load_timezone_geojson,
)
from interstellar_core.location.resolver import (
    GeoJsonTimezoneIndex,
    LocationResolver,
    PlaceIndex,
)

from interstellar_api.config import ApiSettings


def load_location_resolver(settings: ApiSettings) -> LocationResolver | None:
    """Return a resolver only when both required official datasets are configured.

    A half-configured deployment fails during startup instead of silently falling
    back to an online geocoder or guessing a timezone.
    """

    if settings.geonames_path is None and settings.timezone_boundaries_path is None:
        return None
    if settings.geonames_path is None or settings.timezone_boundaries_path is None:
        raise RuntimeError(
            "INTERSTELLAR_GEONAMES_PATH and "
            "INTERSTELLAR_TIMEZONE_BOUNDARIES_PATH must be configured together"
        )

    geonames_path = Path(settings.geonames_path)
    boundaries_path = Path(settings.timezone_boundaries_path)
    if not geonames_path.is_file():
        raise RuntimeError(f"GeoNames dataset not found: {geonames_path}")
    if not boundaries_path.is_file():
        raise RuntimeError(f"timezone boundary dataset not found: {boundaries_path}")

    places = load_geonames(geonames_path)
    if settings.geonames_admin1_path and settings.geonames_admin2_path:
        admin_names: dict[str, str] = {}
        for admin_path_value in (
            settings.geonames_admin1_path,
            settings.geonames_admin2_path,
        ):
            admin_path = Path(admin_path_value)
            if not admin_path.is_file():
                raise RuntimeError(f"GeoNames admin dataset not found: {admin_path}")
            with admin_path.open(encoding="utf-8") as handle:
                admin_names.update(load_geonames_admin_names(handle))
        places = tuple(enrich_admin_names(places, admin_names))
    features = load_timezone_geojson(boundaries_path)
    return LocationResolver(
        PlaceIndex(places, dataset_version=settings.geonames_dataset_version),
        GeoJsonTimezoneIndex(
            features,
            dataset_version=settings.timezone_boundaries_dataset_version,
        ),
    )
