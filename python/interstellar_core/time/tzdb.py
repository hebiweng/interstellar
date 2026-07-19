"""Pinned local IANA timezone database configuration."""

from __future__ import annotations

from importlib.resources import files
from zoneinfo import reset_tzpath

import tzdata

from .models import DatasetReference

TZDATA_PACKAGE_VERSION = tzdata.__version__
IANA_TZDB_VERSION = tzdata.IANA_VERSION
TZDB_DATASET_REFERENCE = DatasetReference(
    id="iana_tzdb",
    version=IANA_TZDB_VERSION,
    license="IANA-TZDB",
    source_uri="https://data.iana.org/time-zones/releases/",
)


def configure_bundled_tzdb() -> None:
    """Force ``zoneinfo`` to use the pinned wheel instead of host OS data."""

    zoneinfo_root = files("tzdata.zoneinfo")
    reset_tzpath((str(zoneinfo_root),))


configure_bundled_tzdb()
