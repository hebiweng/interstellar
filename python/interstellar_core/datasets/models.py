"""Immutable dataset control-plane values."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import PurePosixPath
from typing import Any


@dataclass(frozen=True, slots=True)
class DatasetManifest:
    """Validated policy for one upstream dataset."""

    dataset_id: str
    name: str
    required_for_v1: bool
    role: str
    source_url: str | None
    acquisition_method: str
    crawler: bool
    runtime_mode: str
    version_strategy: str
    pinned_version: str | None
    integrity_state: str
    license_identifier: str
    attribution_required: bool | str
    failure_strategy: str
    raw: dict[str, Any]


@dataclass(frozen=True, slots=True)
class DatasetArtifact:
    """One immutable file included in a dataset release."""

    path: str
    sha256: str
    size_bytes: int

    def __post_init__(self) -> None:
        candidate = PurePosixPath(self.path)
        if candidate.is_absolute() or ".." in candidate.parts or not candidate.parts:
            raise ValueError("artifact path must be a safe relative POSIX path")
        if len(self.sha256) != 64 or any(char not in "0123456789abcdef" for char in self.sha256):
            raise ValueError("artifact sha256 must be 64 lowercase hexadecimal characters")
        if self.size_bytes < 0:
            raise ValueError("artifact size_bytes cannot be negative")


@dataclass(frozen=True, slots=True)
class DatasetVersionPin:
    """A verified release that is eligible to become active."""

    dataset_id: str
    version: str
    license_identifier: str
    license_accepted: bool
    artifacts: tuple[DatasetArtifact, ...]
    verified_at: str

    def __post_init__(self) -> None:
        if not self.dataset_id or not self.version:
            raise ValueError("dataset_id and version are required")
        if not self.artifacts:
            raise ValueError("a dataset version must pin at least one artifact")
