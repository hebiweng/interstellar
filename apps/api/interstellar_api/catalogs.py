"""Versioned repository catalog adapters used by the API preflight layer."""

from __future__ import annotations

from collections.abc import Mapping
from copy import deepcopy
from pathlib import Path
from typing import Any

import yaml
from interstellar_core.application.recipe_preflight import canonical_hash


class CatalogError(ValueError):
    """Raised when a repository catalog is unavailable or internally inconsistent."""


class AnalysisModelCatalog:
    """Immutable view over official analysis-model presets."""

    def __init__(self, document: Mapping[str, Any]) -> None:
        presets = document.get("presets")
        if not isinstance(presets, list) or not presets:
            raise CatalogError("analysis model catalog must contain a non-empty presets list")
        items: dict[str, dict[str, Any]] = {}
        for raw in presets:
            if not isinstance(raw, Mapping) or not raw.get("id"):
                raise CatalogError("every analysis model preset must have an id")
            item = deepcopy(dict(raw))
            identifier = str(item["id"])
            if identifier in items:
                raise CatalogError(f"duplicate analysis model preset: {identifier}")
            items[identifier] = item
        self._document = deepcopy(dict(document))
        self._items = items
        self.content_hash = canonical_hash(self._document)

    @classmethod
    def from_file(cls, path: Path) -> AnalysisModelCatalog:
        if not path.is_file():
            raise CatalogError(f"analysis model catalog not found: {path}")
        loaded = yaml.safe_load(path.read_text(encoding="utf-8"))
        if not isinstance(loaded, Mapping):
            raise CatalogError("analysis model catalog root must be an object")
        return cls(loaded)

    def get(self, identifier: str) -> dict[str, Any]:
        try:
            return deepcopy(self._items[identifier])
        except KeyError as exc:
            raise CatalogError(f"unknown analysis model preset: {identifier}") from exc

    def list(self) -> list[dict[str, Any]]:
        return [deepcopy(item) for item in self._items.values()]


def repository_root() -> Path:
    return Path(__file__).resolve().parents[3]


def load_official_analysis_models(root: Path | None = None) -> AnalysisModelCatalog:
    base = root or repository_root()
    path = base / "presets" / "official" / "analysis-model-presets.yaml"
    return AnalysisModelCatalog.from_file(path)
