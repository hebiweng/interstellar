"""Read-only inventory of versioned local dataset artifacts.

The inventory is deliberately built from repository manifests and immutable
lock files.  It never contacts an upstream service while serving a user
request, and it keeps data availability separate from calculation maturity.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from interstellar_core.datasets import DatasetManifest, load_catalog

from interstellar_api.config import REPOSITORY_ROOT

CATALOG_PATH = REPOSITORY_ROOT / "data-manifests" / "catalog.yaml"
LOCK_DIRECTORY = REPOSITORY_ROOT / "data-manifests" / "locks"

_CAPABILITY_STATE: dict[str, str] = {
    "swiss_ephemeris": "primary_calculation_active",
    "iana_tzdb": "time_normalization_active",
    "geonames": "location_search_active",
    "timezone_boundary_builder": "timezone_resolution_active",
    "jpl_spice": "local_validation_source_adapter_pending",
    "iers": "local_precision_source_adapter_pending",
    "natural_earth": "local_map_source_ready_renderer_pending",
}


@dataclass(frozen=True, slots=True)
class LocalDatasetRecord:
    dataset_id: str
    version: str
    status: str
    checksum: str
    source_uri: str
    license_identifier: str
    activated_at: str | None
    metadata: dict[str, Any]


def _canonical_checksum(artifacts: list[dict[str, Any]]) -> str:
    payload = [
        {
            "path": artifact.get("path"),
            "sha256": artifact.get("sha256"),
            "size_bytes": artifact.get("size_bytes"),
        }
        for artifact in artifacts
    ]
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return f"sha256:{hashlib.sha256(encoded).hexdigest()}"


def _artifact_path(dataset_id: str, relative_path: str) -> Path:
    if dataset_id == "swiss_ephemeris" and relative_path.startswith("ephe/"):
        return REPOSITORY_ROOT / "vendor" / "swisseph" / relative_path
    return REPOSITORY_ROOT / relative_path


def _load_locked_versions() -> dict[str, dict[str, Any]]:
    versions: dict[str, dict[str, Any]] = {}
    if not LOCK_DIRECTORY.is_dir():
        return versions
    for lock_path in sorted(LOCK_DIRECTORY.glob("*.json")):
        document = json.loads(lock_path.read_text(encoding="utf-8"))
        if document.get("schema_version") != 1:
            continue
        active = document.get("active")
        if not isinstance(active, dict):
            continue
        for dataset_id, raw in active.items():
            if not isinstance(raw, dict):
                continue
            versions[dataset_id] = {**raw, "lock_file": lock_path.name}
    return versions


def _record_from_lock(
    manifest: DatasetManifest,
    locked: dict[str, Any],
) -> LocalDatasetRecord:
    artifacts = locked.get("artifacts")
    if not isinstance(artifacts, list):
        artifacts = []

    artifact_details: list[dict[str, Any]] = []
    local_ready = bool(artifacts)
    for artifact in artifacts:
        if not isinstance(artifact, dict):
            local_ready = False
            continue
        relative_path = str(artifact.get("path", ""))
        candidate = _artifact_path(manifest.dataset_id, relative_path)
        expected_size = int(artifact.get("size_bytes", -1))
        exists = candidate.is_file()
        size_matches = exists and candidate.stat().st_size == expected_size
        local_ready = local_ready and size_matches
        artifact_details.append(
            {
                "path": relative_path,
                "exists": exists,
                "size_matches": size_matches,
                "size_bytes": expected_size,
                "sha256": artifact.get("sha256"),
            }
        )

    capability_state = _CAPABILITY_STATE.get(
        manifest.dataset_id,
        "local_dataset_active",
    )
    return LocalDatasetRecord(
        dataset_id=manifest.dataset_id,
        version=str(locked.get("version") or manifest.pinned_version or "unknown"),
        status="active" if local_ready else "rejected",
        checksum=_canonical_checksum(artifacts),
        source_uri=manifest.source_url or "",
        license_identifier=manifest.license_identifier,
        activated_at=str(locked.get("verified_at")) if local_ready else None,
        metadata={
            "name": manifest.name,
            "role": manifest.role,
            "required_for_v1": manifest.required_for_v1,
            "runtime_mode": manifest.runtime_mode,
            "acquisition_method": manifest.acquisition_method,
            "crawler": False,
            "local_ready": local_ready,
            "capability_state": capability_state if local_ready else "artifact_invalid",
            "lock_file": locked.get("lock_file"),
            "artifacts": artifact_details,
        },
    )


def _discovered_record(manifest: DatasetManifest) -> LocalDatasetRecord:
    return LocalDatasetRecord(
        dataset_id=manifest.dataset_id,
        version=manifest.pinned_version or "unconfigured",
        status="discovered",
        checksum="unverified",
        source_uri=manifest.source_url or "",
        license_identifier=manifest.license_identifier,
        activated_at=None,
        metadata={
            "name": manifest.name,
            "role": manifest.role,
            "required_for_v1": manifest.required_for_v1,
            "runtime_mode": manifest.runtime_mode,
            "acquisition_method": manifest.acquisition_method,
            "crawler": False,
            "local_ready": False,
            "capability_state": "future_or_optional_dataset_not_local",
            "artifacts": [],
        },
    )


def load_local_dataset_inventory() -> tuple[LocalDatasetRecord, ...]:
    """Return every catalog entry with an honest local activation state."""

    manifests = load_catalog(CATALOG_PATH)
    locked_versions = _load_locked_versions()
    records = [
        (
            _record_from_lock(manifest, locked_versions[manifest.dataset_id])
            if manifest.dataset_id in locked_versions
            else _discovered_record(manifest)
        )
        for manifest in manifests
    ]
    return tuple(sorted(records, key=lambda record: record.dataset_id))
