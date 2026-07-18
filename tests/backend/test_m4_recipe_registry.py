from __future__ import annotations

from datetime import UTC, datetime

from interstellar_api.recipe_registry import load_repository_recipe_registry
from interstellar_api.workflow_store import WorkflowStore
from interstellar_core.analysis.recipe import AnalysisRecipeResolver
from interstellar_core.analysis.registries import load_analysis_registry


def _registry() -> tuple[WorkflowStore, object]:
    store = WorkflowStore()
    return store, load_repository_recipe_registry(
        analysis_registry=load_analysis_registry(),
        workflow_store=store,
    )


def _subject() -> dict:
    return {
        "kind": "person",
        "display_name": "Virtual M4 subject",
        "time_spec": {
            "precision": "minute",
            "selected_utc": "1990-01-01T04:00:00Z",
        },
        "location": {"latitude": 31.2, "longitude": 121.4},
    }


def _draft(entry: str, selection: dict) -> dict:
    return {
        "draft_id": f"draft-{entry}",
        "entry_point_id": entry,
        "selection": selection,
        "subject_roles": [{"role": "primary", "inline_subject": _subject()}],
        "allowed_overrides": {},
        "optional_extensions": [],
        "revision": 1,
        "status": "ready",
    }


def test_repository_registry_resolves_each_of_the_six_product_entries() -> None:
    _store, registry = _registry()
    cases = [
        ("entry.technique", {"technique_id": "natal.standard_chart"}),
        ("entry.topic_model", {"topic_model_id": "personality.modern.v1"}),
        ("entry.object_context", {"analysis_model_id": "natal.modern.v1"}),
        ("entry.personal_dashboard", {"analysis_model_id": "natal.modern.v1"}),
        ("entry.intent", {"analysis_intent_id": "intent.natal_overview"}),
        ("entry.context_shortcut", {"topic_model_id": "timing.short_term.v1"}),
    ]
    resolver = AnalysisRecipeResolver(registry)
    for index, (entry, selection) in enumerate(cases):
        recipe = resolver.resolve(
            _draft(entry, selection),
            recipe_id=f"recipe-{index}",
            now=datetime(2026, 7, 18, tzinfo=UTC),
        ).to_dict()
        assert recipe["entry_point_id"] == entry
        assert recipe["nodes"]
        assert recipe["content_hash"].startswith("sha256:")


def test_future_catalog_capabilities_are_explicitly_blocked_not_claimed_available() -> None:
    _store, registry = _registry()
    recipe = AnalysisRecipeResolver(registry).resolve(
        _draft("entry.technique", {"technique_id": "geography.astrocartography"}),
        recipe_id="recipe-future",
        now=datetime(2026, 7, 18, tzinfo=UTC),
    ).to_dict()

    target = next(
        node for node in recipe["nodes"] if node["calculation_id"] == "geography.astrocartography"
    )
    assert target["availability"] == "blocked"
    assert any(
        warning["code"] == "CAPABILITY_NOT_IMPLEMENTED" for warning in recipe["warnings"]
    )


def test_saved_subject_facts_are_read_without_copying_user_data_into_registry() -> None:
    store, registry = _registry()
    store.put_subject(
        {"id": "subject-1"},
        {
            "id": "version-1",
            "time_spec": {"precision": "date", "selected_utc": None},
            "location": None,
        },
    )
    facts = registry.get_subject_facts("version-1")
    assert facts.time_precision == "date"
    assert facts.has_resolved_utc is False
    assert facts.has_location is False
