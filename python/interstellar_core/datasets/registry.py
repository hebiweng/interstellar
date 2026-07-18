"""Strict manifest loading, checksum verification, and active-version pinning."""

from __future__ import annotations

import hashlib
import json
import os
from collections.abc import Mapping
from dataclasses import asdict
from pathlib import Path
from typing import Any

from interstellar_core.domain.errors import DomainError

from .models import DatasetArtifact, DatasetManifest, DatasetVersionPin


def _mapping(value: object, path: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise DomainError("DATASET_MANIFEST_INVALID", f"{path} must be an object")
    return value


def _required_text(mapping: Mapping[str, Any], key: str, path: str) -> str:
    value = mapping.get(key)
    if not isinstance(value, str) or not value.strip():
        raise DomainError("DATASET_MANIFEST_INVALID", f"{path}.{key} must be non-empty text")
    return value.strip()


def _load_document(path: Path) -> Mapping[str, Any]:
    text = path.read_text(encoding="utf-8")
    if path.suffix.lower() == ".json":
        return _mapping(json.loads(text), str(path))

    # YAML is a build/control-plane input, not a calculation runtime dependency.
    # The project toolchain already provides PyYAML; deployed services may instead
    # consume a compiled JSON catalog produced during a release build.
    try:
        import yaml
    except ModuleNotFoundError as exc:  # pragma: no cover - environment-specific gate
        raise DomainError(
            "DATASET_MANIFEST_PARSER_UNAVAILABLE",
            "YAML loading requires the release toolchain; provide a compiled JSON catalog",
        ) from exc
    return _mapping(yaml.safe_load(text), str(path))


def load_catalog(path: str | Path) -> tuple[DatasetManifest, ...]:
    """Load and validate an official catalog without contacting the network."""

    document = _load_document(Path(path))
    policy = _mapping(document.get("policy"), "policy")
    if policy.get("crawler_usage") != "forbidden":
        raise DomainError("DATASET_POLICY_INVALID", "catalog policy must forbid crawler use")
    if policy.get("online_runtime_dependency") != "forbidden_for_required_datasets":
        raise DomainError(
            "DATASET_POLICY_INVALID",
            "required datasets must forbid online runtime dependencies",
        )

    raw_datasets = document.get("datasets")
    if not isinstance(raw_datasets, list) or not raw_datasets:
        raise DomainError("DATASET_MANIFEST_INVALID", "datasets must be a non-empty array")

    manifests: list[DatasetManifest] = []
    seen: set[str] = set()
    for index, raw_value in enumerate(raw_datasets):
        path_prefix = f"datasets[{index}]"
        raw = dict(_mapping(raw_value, path_prefix))
        dataset_id = _required_text(raw, "id", path_prefix)
        if dataset_id in seen:
            raise DomainError("DATASET_ID_DUPLICATE", f"duplicate dataset id: {dataset_id}")
        seen.add(dataset_id)

        acquisition = _mapping(raw.get("acquisition"), f"{path_prefix}.acquisition")
        if acquisition.get("crawler") is not False:
            raise DomainError(
                "DATASET_CRAWLER_FORBIDDEN",
                f"{dataset_id} must explicitly set acquisition.crawler=false",
            )
        version = _mapping(raw.get("version"), f"{path_prefix}.version")
        integrity = _mapping(raw.get("integrity"), f"{path_prefix}.integrity")
        license_data = _mapping(raw.get("license"), f"{path_prefix}.license")
        attribution = _mapping(raw.get("attribution"), f"{path_prefix}.attribution")

        pinned = version.get("pinned")
        manifests.append(
            DatasetManifest(
                dataset_id=dataset_id,
                name=_required_text(raw, "name", path_prefix),
                required_for_v1=bool(raw.get("required_for_v1")),
                role=_required_text(raw, "role", path_prefix),
                source_url=(
                    raw.get("source_url") if isinstance(raw.get("source_url"), str) else None
                ),
                acquisition_method=_required_text(
                    acquisition, "method", f"{path_prefix}.acquisition"
                ),
                crawler=False,
                runtime_mode=_required_text(
                    acquisition, "runtime_mode", f"{path_prefix}.acquisition"
                ),
                version_strategy=_required_text(version, "strategy", f"{path_prefix}.version"),
                pinned_version=str(pinned) if pinned is not None else None,
                integrity_state=_required_text(
                    integrity, "state", f"{path_prefix}.integrity"
                ),
                license_identifier=_required_text(
                    license_data, "identifier", f"{path_prefix}.license"
                ),
                attribution_required=attribution.get("required", False),
                failure_strategy=_required_text(raw, "failure_strategy", path_prefix),
                raw=raw,
            )
        )
    return tuple(manifests)


def sha256_file(path: Path, *, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(chunk_size):
            digest.update(chunk)
    return digest.hexdigest()


class DatasetRegistry:
    """Holds manifest policy and an explicit set of active, verified releases."""

    def __init__(self, manifests: tuple[DatasetManifest, ...]) -> None:
        if not manifests:
            raise ValueError("at least one dataset manifest is required")
        self._manifests = {manifest.dataset_id: manifest for manifest in manifests}
        if len(self._manifests) != len(manifests):
            raise ValueError("dataset manifests must have unique ids")
        self._active: dict[str, DatasetVersionPin] = {}

    @classmethod
    def from_catalog(cls, path: str | Path) -> DatasetRegistry:
        return cls(load_catalog(path))

    def manifest(self, dataset_id: str) -> DatasetManifest:
        try:
            return self._manifests[dataset_id]
        except KeyError as exc:
            raise DomainError("DATASET_UNKNOWN", f"unknown dataset: {dataset_id}") from exc

    def verify_version(self, pin: DatasetVersionPin, artifact_root: str | Path) -> None:
        manifest = self.manifest(pin.dataset_id)
        if manifest.integrity_state == "unavailable":
            raise DomainError(
                "DATASET_UNAVAILABLE",
                f"{pin.dataset_id} is declared unavailable and cannot be activated",
            )
        if not pin.license_accepted:
            raise DomainError(
                "DATASET_LICENSE_NOT_ACCEPTED",
                f"license acceptance is required for {pin.dataset_id}",
            )
        if pin.license_identifier != manifest.license_identifier:
            raise DomainError(
                "DATASET_LICENSE_MISMATCH",
                f"pin license does not match manifest for {pin.dataset_id}",
            )

        root = Path(artifact_root).resolve()
        for artifact in pin.artifacts:
            candidate = (root / artifact.path).resolve()
            if not candidate.is_relative_to(root):
                raise DomainError("DATASET_PATH_ESCAPE", f"artifact escapes root: {artifact.path}")
            if not candidate.is_file():
                raise DomainError("DATASET_ARTIFACT_MISSING", f"artifact missing: {artifact.path}")
            stat = candidate.stat()
            if stat.st_size != artifact.size_bytes:
                raise DomainError(
                    "DATASET_SIZE_MISMATCH",
                    f"artifact size mismatch: {artifact.path}",
                )
            actual = sha256_file(candidate)
            if actual != artifact.sha256:
                raise DomainError(
                    "DATASET_CHECKSUM_MISMATCH",
                    f"artifact checksum mismatch: {artifact.path}",
                )

    def activate(self, pin: DatasetVersionPin, artifact_root: str | Path) -> None:
        """Atomically replace the active in-memory pin after full verification."""

        self.verify_version(pin, artifact_root)
        self._active[pin.dataset_id] = pin

    def active_version(self, dataset_id: str) -> DatasetVersionPin:
        self.manifest(dataset_id)
        try:
            return self._active[dataset_id]
        except KeyError as exc:
            raise DomainError(
                "DATASET_VERSION_NOT_ACTIVE", f"no active version for {dataset_id}"
            ) from exc

    def assert_required_active(self) -> None:
        missing = sorted(
            manifest.dataset_id
            for manifest in self._manifests.values()
            if manifest.required_for_v1 and manifest.dataset_id not in self._active
        )
        if missing:
            raise DomainError(
                "REQUIRED_DATASETS_NOT_ACTIVE",
                f"required datasets lack active verified versions: {', '.join(missing)}",
            )

    def write_active_lock(self, path: str | Path) -> None:
        """Persist active pins using atomic replace; never write partial lock state."""

        destination = Path(path)
        destination.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "schema_version": 1,
            "active": {
                dataset_id: {
                    **asdict(pin),
                    "artifacts": [asdict(artifact) for artifact in pin.artifacts],
                }
                for dataset_id, pin in sorted(self._active.items())
            },
        }
        temporary = destination.with_name(f".{destination.name}.{os.getpid()}.tmp")
        temporary.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        temporary.replace(destination)

    def load_active_lock(self, path: str | Path, artifact_root: str | Path) -> None:
        """Verify every lock entry before replacing the current active set."""

        payload = json.loads(Path(path).read_text(encoding="utf-8"))
        if payload.get("schema_version") != 1 or not isinstance(payload.get("active"), dict):
            raise DomainError("DATASET_LOCK_INVALID", "active dataset lock has invalid shape")
        candidate_active: dict[str, DatasetVersionPin] = {}
        for dataset_id, raw_value in payload["active"].items():
            raw = _mapping(raw_value, f"active.{dataset_id}")
            artifacts_raw = raw.get("artifacts")
            if not isinstance(artifacts_raw, list):
                raise DomainError("DATASET_LOCK_INVALID", f"{dataset_id} artifacts must be a list")
            pin = DatasetVersionPin(
                dataset_id=dataset_id,
                version=_required_text(raw, "version", f"active.{dataset_id}"),
                license_identifier=_required_text(
                    raw, "license_identifier", f"active.{dataset_id}"
                ),
                license_accepted=raw.get("license_accepted") is True,
                artifacts=tuple(
                    DatasetArtifact(
                        path=_required_text(
                            _mapping(item, "artifact"), "path", "artifact"
                        ),
                        sha256=_required_text(
                            _mapping(item, "artifact"), "sha256", "artifact"
                        ),
                        size_bytes=int(_mapping(item, "artifact").get("size_bytes", -1)),
                    )
                    for item in artifacts_raw
                ),
                verified_at=_required_text(raw, "verified_at", f"active.{dataset_id}"),
            )
            self.verify_version(pin, artifact_root)
            candidate_active[dataset_id] = pin
        self._active = candidate_active
