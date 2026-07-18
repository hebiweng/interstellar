from __future__ import annotations

import pytest

from interstellar_api.catalogs import CatalogError, load_official_analysis_models


def test_official_analysis_models_are_versioned_and_complete() -> None:
    catalog = load_official_analysis_models()

    assert len(catalog.list()) == 12
    assert catalog.content_hash.startswith("sha256:")
    modern = catalog.get("natal.modern.v1")
    assert modern["required_components"] == [
        "natal.standard_chart",
        "natal.patterns_distributions",
    ]


def test_catalog_get_returns_a_copy() -> None:
    catalog = load_official_analysis_models()
    first = catalog.get("natal.modern.v1")
    first["id"] = "mutated"

    assert catalog.get("natal.modern.v1")["id"] == "natal.modern.v1"


def test_unknown_model_is_explicit() -> None:
    catalog = load_official_analysis_models()

    with pytest.raises(CatalogError, match="unknown analysis model"):
        catalog.get("missing.model")
