from __future__ import annotations

import json
from pathlib import Path

import pytest

from interstellar_core.datasets import DatasetArtifact, DatasetRegistry, DatasetVersionPin
from interstellar_core.datasets.registry import load_catalog, sha256_file
from interstellar_core.domain import DomainError

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).parent / "fixtures"


def _pin(dataset_id: str, filename: str, license_identifier: str) -> DatasetVersionPin:
    path = FIXTURES / filename
    return DatasetVersionPin(
        dataset_id=dataset_id,
        version="fixture-v1",
        license_identifier=license_identifier,
        license_accepted=True,
        artifacts=(
            DatasetArtifact(
                path=filename,
                sha256=sha256_file(path),
                size_bytes=path.stat().st_size,
            ),
        ),
        verified_at="2026-07-18T00:00:00Z",
    )


def test_official_catalog_loads_and_forbids_crawlers() -> None:
    manifests = load_catalog(ROOT / "data-manifests" / "catalog.yaml")
    assert len(manifests) == 14
    assert {manifest.dataset_id for manifest in manifests} >= {
        "geonames",
        "timezone_boundary_builder",
        "iana_tzdb",
    }
    assert all(not manifest.crawler for manifest in manifests)


def test_active_versions_require_license_and_exact_checksums(tmp_path: Path) -> None:
    registry = DatasetRegistry.from_catalog(FIXTURES / "catalog.yaml")
    geonames = _pin("geonames", "geonames.tsv", "CC-BY-4.0")
    timezone = _pin(
        "timezone_boundary_builder",
        "timezone-boundaries.geojson",
        "ODbL-1.0_output_AND_MIT_code",
    )
    registry.activate(geonames, FIXTURES)
    registry.activate(timezone, FIXTURES)
    registry.assert_required_active()

    lock = tmp_path / "active-datasets.json"
    registry.write_active_lock(lock)
    restored = DatasetRegistry.from_catalog(FIXTURES / "catalog.yaml")
    restored.load_active_lock(lock, FIXTURES)
    assert restored.active_version("geonames").artifacts[0].sha256 == sha256_file(
        FIXTURES / "geonames.tsv"
    )
    assert json.loads(lock.read_text())["schema_version"] == 1


def test_checksum_mismatch_does_not_replace_active_version() -> None:
    registry = DatasetRegistry.from_catalog(FIXTURES / "catalog.yaml")
    valid = _pin("geonames", "geonames.tsv", "CC-BY-4.0")
    registry.activate(valid, FIXTURES)
    invalid = DatasetVersionPin(
        dataset_id="geonames",
        version="corrupt",
        license_identifier="CC-BY-4.0",
        license_accepted=True,
        artifacts=(
            DatasetArtifact(
                path="geonames.tsv",
                sha256="0" * 64,
                size_bytes=(FIXTURES / "geonames.tsv").stat().st_size,
            ),
        ),
        verified_at="2026-07-18T00:00:00Z",
    )
    with pytest.raises(DomainError, match="checksum mismatch") as caught:
        registry.activate(invalid, FIXTURES)
    assert caught.value.code == "DATASET_CHECKSUM_MISMATCH"
    assert registry.active_version("geonames").version == valid.version


def test_license_must_be_accepted_and_match_manifest() -> None:
    registry = DatasetRegistry.from_catalog(FIXTURES / "catalog.yaml")
    source = _pin("geonames", "geonames.tsv", "CC-BY-4.0")
    rejected = DatasetVersionPin(
        dataset_id=source.dataset_id,
        version=source.version,
        license_identifier=source.license_identifier,
        license_accepted=False,
        artifacts=source.artifacts,
        verified_at=source.verified_at,
    )
    with pytest.raises(DomainError) as caught:
        registry.activate(rejected, FIXTURES)
    assert caught.value.code == "DATASET_LICENSE_NOT_ACCEPTED"
