from __future__ import annotations

import copy
import re
from collections.abc import Callable
from pathlib import Path

import pytest
import yaml

from interstellar_core.analysis.registries import (
    DEFAULT_ANALYSIS_CATALOG,
    DEFAULT_CAPABILITIES_CATALOG,
    RegistryValidationError,
    load_analysis_registry,
)


def _read(path: Path) -> dict[str, object]:
    document = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert isinstance(document, dict)
    return document


def _mutated_catalogs(
    tmp_path: Path,
    *,
    mutate_analysis: Callable[[dict[str, object]], None] | None = None,
    mutate_capabilities: Callable[[dict[str, object]], None] | None = None,
) -> tuple[Path, Path]:
    analysis = copy.deepcopy(_read(DEFAULT_ANALYSIS_CATALOG))
    capabilities = copy.deepcopy(_read(DEFAULT_CAPABILITIES_CATALOG))
    if mutate_analysis is not None:
        mutate_analysis(analysis)
    if mutate_capabilities is not None:
        mutate_capabilities(capabilities)
    analysis_path = tmp_path / "analysis.yaml"
    capabilities_path = tmp_path / "capabilities.yaml"
    analysis_path.write_text(
        yaml.safe_dump(analysis, allow_unicode=True, sort_keys=False), encoding="utf-8"
    )
    capabilities_path.write_text(
        yaml.safe_dump(capabilities, allow_unicode=True, sort_keys=False), encoding="utf-8"
    )
    return analysis_path, capabilities_path


def test_real_catalog_loads_expected_six_12_24_35_registry() -> None:
    registry = load_analysis_registry()

    assert len(registry.entry_points) == 6
    assert len(registry.base_models) == 12
    assert len(registry.topic_models) == 24
    assert len(registry.intents) == 35
    assert {entry.id for entry in registry.entry_points} == {
        "entry.technique",
        "entry.topic_model",
        "entry.object_context",
        "entry.personal_dashboard",
        "entry.intent",
        "entry.context_shortcut",
    }


def test_registry_versions_hashes_and_intent_pointer_are_explicit_and_deterministic() -> None:
    first = load_analysis_registry()
    second = load_analysis_registry()

    assert first.id == "interstellar.analysis_catalog.v1"
    assert first.version == "1.0.0"
    assert first.content_hash == second.content_hash
    assert re.fullmatch(r"sha256:[0-9a-f]{64}", first.content_hash)
    assert first.intent_source_pointer == "docs/analysis-catalog.yaml#analysis_intents"
    assert [source.kind for source in first.sources] == [
        "analysis_catalog",
        "capabilities_catalog",
        "intent_taxonomy",
    ]
    assert first.sources[2].pointer == "#analysis_intents"
    assert all(re.fullmatch(r"[0-9a-f]{64}", source.sha256) for source in first.sources)


def test_registry_collections_and_records_are_read_only() -> None:
    registry = load_analysis_registry()
    with pytest.raises(TypeError):
        registry.base_models["new.v1"] = registry.get_base_model("natal.modern.v1")  # type: ignore[index]
    with pytest.raises(AttributeError):
        registry.entry_points.append(registry.entry_points[0])  # type: ignore[attr-defined]
    with pytest.raises(AttributeError):
        registry.get_topic_model("personality.modern.v1").phase = "changed"  # type: ignore[misc]


def test_public_lookup_api_is_exact_and_unknown_ids_raise() -> None:
    registry = load_analysis_registry()
    assert len(registry.list_entry_points()) == 6
    assert len(registry.list_base_models()) == 12
    assert len(registry.list_topic_models()) == 24
    assert len(registry.list_intents()) == 35
    assert registry.get_base_model("natal.modern.v1").components == (
        "natal.standard_chart",
        "natal.patterns_distributions",
    )
    assert registry.get_topic_model("timing.short_term.v1").base_models == (
        "forecast.short_transit.v1",
    )
    assert registry.get_intent("intent.annual_cycle").topic_models == (
        "timing.annual_integrated.v1",
    )
    with pytest.raises(KeyError):
        registry.get_intent("intent.unknown")


def test_all_versioned_models_and_component_references_are_enumerable() -> None:
    registry = load_analysis_registry()
    capability_ids = {item["id"] for item in _read(DEFAULT_CAPABILITIES_CATALOG)["capabilities"]}  # type: ignore[index]
    for model in registry.base_models.values():
        assert re.search(r"\.v[1-9][0-9]*$", model.id)
        assert re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", model.version)
        assert set(model.all_components) <= capability_ids
    for topic in registry.topic_models.values():
        assert re.search(r"\.v[1-9][0-9]*$", topic.id)
        assert set(topic.base_models) <= registry.base_models.keys()
    for intent in registry.intents.values():
        assert set(intent.topic_models) <= registry.topic_models.keys()


def test_allowed_catalog_change_changes_combined_hash(tmp_path: Path) -> None:
    baseline = load_analysis_registry()

    def change_title(document: dict[str, object]) -> None:
        document["title_zh"] = "Changed test title"

    analysis_path, capabilities_path = _mutated_catalogs(
        tmp_path, mutate_analysis=change_title
    )
    changed = load_analysis_registry(analysis_path, capabilities_path)
    assert changed.content_hash != baseline.content_hash


@pytest.mark.parametrize("target", ["root", "topic", "intent"])
def test_unknown_fields_are_never_silently_ignored(tmp_path: Path, target: str) -> None:
    def mutate(document: dict[str, object]) -> None:
        if target == "root":
            document["surprise"] = True
        elif target == "topic":
            document["topic_models"][0]["surprise"] = True  # type: ignore[index]
        else:
            document["analysis_intents"]["self_and_life"][0]["surprise"] = True  # type: ignore[index]

    analysis_path, capabilities_path = _mutated_catalogs(
        tmp_path, mutate_analysis=mutate
    )
    with pytest.raises(RegistryValidationError, match="unknown fields"):
        load_analysis_registry(analysis_path, capabilities_path)


def test_duplicate_topic_id_is_rejected(tmp_path: Path) -> None:
    def duplicate(document: dict[str, object]) -> None:
        document["topic_models"][1]["id"] = document["topic_models"][0]["id"]  # type: ignore[index]

    analysis_path, capabilities_path = _mutated_catalogs(
        tmp_path, mutate_analysis=duplicate
    )
    with pytest.raises(RegistryValidationError, match="duplicate id"):
        load_analysis_registry(analysis_path, capabilities_path)


def test_unknown_topic_base_model_reference_is_rejected(tmp_path: Path) -> None:
    def break_reference(document: dict[str, object]) -> None:
        document["topic_models"][0]["base_models"] = ["missing.model.v1"]  # type: ignore[index]

    analysis_path, capabilities_path = _mutated_catalogs(
        tmp_path, mutate_analysis=break_reference
    )
    with pytest.raises(RegistryValidationError, match="unknown base model"):
        load_analysis_registry(analysis_path, capabilities_path)


def test_unknown_base_model_component_is_rejected(tmp_path: Path) -> None:
    def break_component(document: dict[str, object]) -> None:
        document["analysis_models"][0]["components"] = ["missing.capability"]  # type: ignore[index]

    analysis_path, capabilities_path = _mutated_catalogs(
        tmp_path, mutate_capabilities=break_component
    )
    with pytest.raises(RegistryValidationError, match="unknown component"):
        load_analysis_registry(analysis_path, capabilities_path)


def test_unknown_capability_dependency_is_rejected(tmp_path: Path) -> None:
    def break_dependency(document: dict[str, object]) -> None:
        document["capabilities"][0]["dependencies"] = ["missing.capability"]  # type: ignore[index]

    analysis_path, capabilities_path = _mutated_catalogs(
        tmp_path, mutate_capabilities=break_dependency
    )
    with pytest.raises(RegistryValidationError, match="unknown dependency"):
        load_analysis_registry(analysis_path, capabilities_path)


def test_invalid_catalog_version_is_rejected(tmp_path: Path) -> None:
    def invalidate(document: dict[str, object]) -> None:
        document["schema_version"] = "latest"

    analysis_path, capabilities_path = _mutated_catalogs(
        tmp_path, mutate_analysis=invalidate
    )
    with pytest.raises(RegistryValidationError, match="semantic version"):
        load_analysis_registry(analysis_path, capabilities_path)
