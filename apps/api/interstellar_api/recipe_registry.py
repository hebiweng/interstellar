"""Repository-backed adapter for the deterministic AnalysisRecipe resolver.

This module is the integration boundary between the immutable YAML catalogs,
the process workflow adapter, and the framework-independent recipe domain.
It does not calculate astrology and never treats a cataloged future capability
as an implemented runtime component.
"""

from __future__ import annotations

from collections.abc import Mapping
from copy import deepcopy
from pathlib import Path
from typing import Any

import yaml
from interstellar_core.analysis.recipe import (
    ComponentDefinition,
    DegradationDefinition,
    EntryPointDefinition,
    InMemoryRecipeRegistry,
    RecipeOutputs,
    ReuseCandidate,
    SelectionDefinition,
    SubjectFacts,
    content_hash,
)
from interstellar_core.analysis.registries import AnalysisRegistry

from interstellar_api.workflow_store import WorkflowRecordNotFound, WorkflowStore

IMPLEMENTED_M4_COMPONENTS = frozenset(
    {
        "platform.canonical_schema",
        "platform.time_spec",
        "platform.location",
        "platform.subject_versioning",
        "platform.analysis_model_registry",
        "platform.analysis_recipe_resolver",
        "platform.analysis_catalog",
        "platform.calculation_snapshot",
        "platform.rest_api",
        "platform.async_jobs",
        "platform.workspace_security",
        "astronomy.ephemeris_core",
        "astronomy.houses_angles",
        "astronomy.aspects",
        "natal.standard_chart",
    }
)

_ALL_SELECTORS = frozenset(
    {
        "analysis_intent_id",
        "topic_model_id",
        "analysis_model_id",
        "technique_id",
        "custom_model_spec",
    }
)


class RepositoryRecipeRegistry:
    """Strict resolver port backed by the checked-in V1 catalogs."""

    def __init__(
        self,
        *,
        analysis_registry: AnalysisRegistry,
        workflow_store: WorkflowStore,
        analysis_catalog: Mapping[str, Any],
        capability_catalog: Mapping[str, Any],
        preset_catalog: Mapping[str, Any],
        implemented_components: frozenset[str] = IMPLEMENTED_M4_COMPONENTS,
    ) -> None:
        self._analysis_registry = analysis_registry
        self._workflow_store = workflow_store
        self._analysis_catalog = deepcopy(dict(analysis_catalog))
        self._capability_catalog = deepcopy(dict(capability_catalog))
        self._preset_catalog = deepcopy(dict(preset_catalog))
        self._implemented = implemented_components
        self._components = self._build_components()
        self._selections = self._build_selections()
        self._entry_points = self._build_entry_points()
        self._output_requirements = self._build_output_requirements()
        self._delegate = InMemoryRecipeRegistry(
            entry_points=tuple(self._entry_points.values()),
            selections=tuple(self._selections.values()),
            components=tuple(self._components.values()),
            output_requirements=self._output_requirements,
        )

    def get_entry_point(self, entry_point_id: str) -> EntryPointDefinition:
        return self._delegate.get_entry_point(entry_point_id)

    def resolve_selection(
        self,
        selector_type: str,
        selection: str | Mapping[str, Any],
    ) -> SelectionDefinition:
        return self._delegate.resolve_selection(selector_type, selection)

    def get_component(self, calculation_id: str) -> ComponentDefinition:
        return self._delegate.get_component(calculation_id)

    def get_subject_facts(self, subject_version_id: str) -> SubjectFacts:
        try:
            version = self._workflow_store.get_subject_version(subject_version_id)
        except WorkflowRecordNotFound:
            return self._delegate.get_subject_facts(subject_version_id)
        time_spec = version.get("time_spec") or {}
        return SubjectFacts(
            time_precision=str(time_spec.get("precision", "unknown")),
            has_resolved_utc=bool(time_spec.get("selected_utc")),
            has_location=version.get("location") is not None,
        )

    def find_reuse(self, semantic_key: str) -> ReuseCandidate | None:
        # Snapshot semantic-result indexing is introduced with the durable M5
        # calculation repository. M4 must not pretend process dictionaries are a cache.
        del semantic_key
        return None

    def get_output_requirements(self, output_id: str) -> tuple[str, ...] | None:
        return self._output_requirements.get(output_id)

    def _build_entry_points(self) -> dict[str, EntryPointDefinition]:
        allowed_by_entry = {
            "entry.technique": frozenset({"technique_id"}),
            "entry.topic_model": frozenset(
                {"topic_model_id", "analysis_model_id", "custom_model_spec"}
            ),
            "entry.object_context": _ALL_SELECTORS,
            "entry.personal_dashboard": frozenset(
                {"analysis_intent_id", "topic_model_id", "analysis_model_id"}
            ),
            "entry.intent": frozenset({"analysis_intent_id"}),
            "entry.context_shortcut": frozenset(
                {"analysis_intent_id", "topic_model_id", "analysis_model_id", "technique_id"}
            ),
        }
        return {
            entry.id: EntryPointDefinition(
                entry_point_id=entry.id,
                allowed_selector_types=allowed_by_entry[entry.id],
            )
            for entry in self._analysis_registry.list_entry_points()
        }

    def _build_components(self) -> dict[str, ComponentDefinition]:
        result: dict[str, ComponentDefinition] = {}
        for raw in self._capability_catalog["capabilities"]:
            identifier = str(raw["id"])
            requirements = _component_input_requirements(identifier, raw)
            result[identifier] = ComponentDefinition(
                calculation_id=identifier,
                version=str(self._capability_catalog["document_version"]),
                dependencies=tuple(str(item) for item in raw.get("dependencies", [])),
                semantic_key=identifier,
                required_time_precision=requirements[0],
                requires_resolved_utc_roles=requirements[1],
                requires_location_roles=requirements[2],
                degradation=_component_degradation(identifier),
                implementation_available=identifier in self._implemented,
                implementation_reason=(
                    None
                    if identifier in self._implemented
                    else f"{identifier} is cataloged for {raw['phase']} and is not deployed in M4"
                ),
                output_ids=tuple(str(item) for item in raw.get("outputs", [])),
                duration_ms_p50=_duration_for(str(raw.get("category", "platform"))),
                search_points=_search_points_for(identifier),
            )
        return result

    def _build_selections(self) -> dict[tuple[str, str], SelectionDefinition]:
        result: dict[tuple[str, str], SelectionDefinition] = {}
        presets = {str(item["id"]): item for item in self._preset_catalog["presets"]}

        for model in self._analysis_registry.list_base_models():
            preset = presets[model.id]
            selection = self._model_selection(model.id, preset)
            result[(selection.selector_type, selection.selection_id)] = selection

        for topic in self._analysis_registry.list_topic_models():
            selections = [result[("analysis_model_id", model_id)] for model_id in topic.base_models]
            output_profile = self._analysis_catalog["output_profiles"][topic.output_profile]
            selection = SelectionDefinition(
                selection_id=topic.id,
                selector_type="topic_model_id",
                required_components=_ordered_union(item.required_components for item in selections),
                optional_components=_ordered_union(item.optional_components for item in selections),
                required_roles=_required_roles(self._analysis_catalog, topic.input_profile),
                resolved_topic_models=(topic.id,),
                resolved_base_models=topic.base_models,
                rule_packs=_ordered_dict_union(item.rule_packs for item in selections),
                dataset_requirements=self._datasets_for_components(
                    _ordered_union(item.required_components for item in selections)
                ),
                default_outputs=RecipeOutputs(
                    view_ids=tuple(output_profile["primary_views"]),
                    report_profile_ids=("report.topic_model.v1",),
                    exports=("json", "svg"),
                ),
            )
            result[(selection.selector_type, selection.selection_id)] = selection

        for intent in self._analysis_registry.list_intents():
            topics = [result[("topic_model_id", topic_id)] for topic_id in intent.topic_models]
            selection = SelectionDefinition(
                selection_id=intent.id,
                selector_type="analysis_intent_id",
                required_components=_ordered_union(item.required_components for item in topics),
                optional_components=_ordered_union(item.optional_components for item in topics),
                required_roles=_required_roles(self._analysis_catalog, intent.input_profile),
                resolved_topic_models=intent.topic_models,
                resolved_base_models=_ordered_union(item.resolved_base_models for item in topics),
                rule_packs=_ordered_dict_union(item.rule_packs for item in topics),
                dataset_requirements=self._datasets_for_components(
                    _ordered_union(item.required_components for item in topics)
                ),
                default_outputs=RecipeOutputs(
                    view_ids=_ordered_union(item.default_outputs.view_ids for item in topics),
                    report_profile_ids=(intent.report_profile,),
                    exports=("json", "svg"),
                ),
            )
            result[(selection.selector_type, selection.selection_id)] = selection

        for identifier, component in self._components.items():
            selection = SelectionDefinition(
                selection_id=identifier,
                selector_type="technique_id",
                required_components=(identifier,),
                required_roles=("primary",),
                dataset_requirements=self._datasets_for_components((identifier,)),
                default_outputs=RecipeOutputs(view_ids=component.output_ids, exports=("json",)),
            )
            result[(selection.selector_type, selection.selection_id)] = selection
        return result

    def _model_selection(
        self,
        model_id: str,
        preset: Mapping[str, Any],
    ) -> SelectionDefinition:
        required = tuple(str(item) for item in preset.get("required_components", []))
        optional = tuple(str(item) for item in preset.get("optional_components", []))
        rule_pack = {
            "id": str(preset["rule_pack_id"]),
            "version": "1.0.0",
            "content_hash": content_hash(dict(preset)),
        }
        return SelectionDefinition(
            selection_id=model_id,
            selector_type="analysis_model_id",
            required_components=required,
            optional_components=optional,
            required_roles=("primary",),
            resolved_base_models=(model_id,),
            rule_packs=(rule_pack,),
            dataset_requirements=self._datasets_for_components(required),
            default_outputs=RecipeOutputs(
                view_ids=tuple(str(item) for item in preset.get("primary_outputs", [])),
                report_profile_ids=(str(preset["report_profile_id"]),),
                exports=("json", "svg"),
            ),
        )

    def _datasets_for_components(
        self,
        component_ids: tuple[str, ...],
    ) -> tuple[Mapping[str, Any], ...]:
        capabilities = {
            str(item["id"]): item for item in self._capability_catalog["capabilities"]
        }
        source_ids: set[str] = set()
        pending = list(component_ids)
        visited: set[str] = set()
        while pending:
            identifier = pending.pop()
            if identifier in visited or identifier not in capabilities:
                continue
            visited.add(identifier)
            raw = capabilities[identifier]
            source_ids.update(str(item) for item in raw.get("data_sources", []))
            pending.extend(str(item) for item in raw.get("dependencies", []))
        records: list[Mapping[str, Any]] = []
        for source_id in sorted(source_ids):
            raw_source = self._capability_catalog["data_sources"][source_id]
            version = str(
                raw_source.get("baseline_version")
                or self._capability_catalog["document_version"]
            )
            records.append(
                {
                    "id": source_id,
                    "version": version,
                    "checksum": content_hash(dict(raw_source)),
                    "license": str(raw_source["license"]),
                    "source_uri": raw_source.get("url"),
                }
            )
        return tuple(records)

    def _build_output_requirements(self) -> dict[str, tuple[str, ...]]:
        requirements: dict[str, set[str]] = {}
        for selection in self._selections.values():
            for output_id in selection.default_outputs.view_ids:
                requirements.setdefault(output_id, set()).update(selection.required_components)
            for report_id in selection.default_outputs.report_profile_ids:
                requirements.setdefault(report_id, set()).update(selection.required_components)
        return {key: tuple(sorted(value)) for key, value in requirements.items()}


def load_repository_recipe_registry(
    *,
    analysis_registry: AnalysisRegistry,
    workflow_store: WorkflowStore,
    root: Path | None = None,
    implemented_components: frozenset[str] = IMPLEMENTED_M4_COMPONENTS,
) -> RepositoryRecipeRegistry:
    repository = root or Path(__file__).resolve().parents[3]
    return RepositoryRecipeRegistry(
        analysis_registry=analysis_registry,
        workflow_store=workflow_store,
        analysis_catalog=_yaml(repository / "docs" / "analysis-catalog.yaml"),
        capability_catalog=_yaml(repository / "docs" / "capabilities.yaml"),
        preset_catalog=_yaml(repository / "presets" / "official" / "analysis-model-presets.yaml"),
        implemented_components=implemented_components,
    )


def _yaml(path: Path) -> dict[str, Any]:
    document = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(document, dict):
        raise ValueError(f"catalog must be an object: {path}")
    return document


def _ordered_union(groups: Any) -> tuple[str, ...]:
    seen: set[str] = set()
    result: list[str] = []
    for group in groups:
        for item in group:
            value = str(item)
            if value not in seen:
                seen.add(value)
                result.append(value)
    return tuple(result)


def _ordered_dict_union(groups: Any) -> tuple[Mapping[str, Any], ...]:
    seen: set[tuple[str, str]] = set()
    result: list[Mapping[str, Any]] = []
    for group in groups:
        for item in group:
            key = (str(item.get("id")), str(item.get("version")))
            if key not in seen:
                seen.add(key)
                result.append(dict(item))
    return tuple(result)


def _required_roles(catalog: Mapping[str, Any], profile_id: str) -> tuple[str, ...]:
    roles = catalog["input_profiles"][profile_id]["roles"]
    required: list[str] = []
    for role, kind in roles.items():
        if isinstance(kind, str) and kind in {"optional", "location_list"}:
            continue
        required.append(str(role))
    return tuple(required)


def _component_input_requirements(
    identifier: str,
    raw: Mapping[str, Any],
) -> tuple[Mapping[str, str], frozenset[str], frozenset[str]]:
    precision: dict[str, str] = {}
    resolved: set[str] = set()
    locations: set[str] = set()
    if identifier == "astronomy.houses_angles":
        precision["primary"] = "minute"
        resolved.add("primary")
        locations.add("primary")
    if identifier.startswith("geography."):
        precision["primary"] = "minute"
        resolved.add("primary")
        locations.update({"primary", "context"})
    if identifier.startswith("horary.") or identifier.startswith("electional."):
        precision["primary"] = "minute"
        resolved.add("primary")
        locations.add("primary")
    if "time_range" in raw.get("inputs", []) or identifier == "forecast.event_search":
        precision["context"] = "second"
        resolved.add("context")
    return precision, frozenset(resolved), frozenset(locations)


def _component_degradation(identifier: str) -> DegradationDefinition | None:
    if identifier != "astronomy.houses_angles":
        return None
    return DegradationDefinition(
        code="NO_TIME_HOUSELESS_CHART",
        effective_calculation_id="astronomy.houseless_chart",
        message="时间或地点不足，显式降级为无宫位、无轴点星盘。",
        output_ids=("wheel.houseless",),
    )


def _duration_for(category: str) -> int:
    return {
        "platform": 10,
        "astronomy": 80,
        "natal": 120,
        "forecast": 800,
        "relationship": 500,
        "timing": 700,
        "geography": 3_000,
        "mundane": 1_000,
        "horary": 400,
        "electional": 3_000,
        "rendering": 150,
        "reporting": 250,
    }.get(category, 300)


def _search_points_for(identifier: str) -> int:
    if "event_search" in identifier or "electional" in identifier:
        return 20_000
    if identifier.startswith("geography."):
        return 5_000
    if identifier.startswith("forecast.") or identifier.startswith("timing."):
        return 1_000
    return 0
