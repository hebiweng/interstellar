"""Resolver-facing registry protocol and deterministic in-memory fixture.

The protocol deliberately does not import the M4 catalog implementation.  A
catalog adapter can implement this port later without coupling recipe logic to
YAML, SQL, or a particular release manifest.
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any, Protocol

from .canonical import content_hash
from .errors import InvalidDraftError, UnknownRegistryItemError
from .models import (
    ComponentDefinition,
    EntryPointDefinition,
    RecipeOutputs,
    ReuseCandidate,
    SelectionDefinition,
    SubjectFacts,
)


class RecipeRegistry(Protocol):
    def get_entry_point(self, entry_point_id: str) -> EntryPointDefinition: ...

    def resolve_selection(
        self,
        selector_type: str,
        selection: str | Mapping[str, Any],
    ) -> SelectionDefinition: ...

    def get_component(self, calculation_id: str) -> ComponentDefinition: ...

    def get_subject_facts(self, subject_version_id: str) -> SubjectFacts: ...

    def find_reuse(self, semantic_key: str) -> ReuseCandidate | None: ...

    def get_output_requirements(self, output_id: str) -> tuple[str, ...] | None: ...


class InMemoryRecipeRegistry:
    """Small catalog adapter for unit tests, local tools, and integration spikes."""

    def __init__(
        self,
        *,
        entry_points: tuple[EntryPointDefinition, ...] = (),
        selections: tuple[SelectionDefinition, ...] = (),
        components: tuple[ComponentDefinition, ...] = (),
        subject_facts: Mapping[str, SubjectFacts] | None = None,
        reuse_candidates: tuple[ReuseCandidate, ...] = (),
        output_requirements: Mapping[str, tuple[str, ...]] | None = None,
    ) -> None:
        self._entry_points = {item.entry_point_id: item for item in entry_points}
        self._selections = {(item.selector_type, item.selection_id): item for item in selections}
        self._components = {item.calculation_id: item for item in components}
        self._subject_facts = dict(subject_facts or {})
        self._reuse = {item.semantic_key: item for item in reuse_candidates}
        self._output_requirements = dict(output_requirements or {})

    def get_entry_point(self, entry_point_id: str) -> EntryPointDefinition:
        try:
            return self._entry_points[entry_point_id]
        except KeyError as error:
            raise UnknownRegistryItemError(
                f"unknown entry point: {entry_point_id}",
                path="/entry_point_id",
                details={"entry_point_id": entry_point_id},
            ) from error

    def resolve_selection(
        self,
        selector_type: str,
        selection: str | Mapping[str, Any],
    ) -> SelectionDefinition:
        if selector_type == "custom_model_spec":
            if not isinstance(selection, Mapping):
                raise InvalidDraftError(
                    "custom_model_spec must be an object",
                    path="/selection/custom_model_spec",
                )
            custom_id = str(selection.get("id") or f"custom:{content_hash(selection)[7:23]}")
            outputs = selection.get("default_outputs", {})
            return SelectionDefinition(
                selection_id=custom_id,
                selector_type=selector_type,
                required_components=tuple(selection.get("required_components", ())),
                recommended_components=tuple(selection.get("recommended_components", ())),
                optional_components=tuple(selection.get("optional_components", ())),
                required_roles=tuple(selection.get("required_roles", ("primary",))),
                resolved_topic_models=tuple(selection.get("resolved_topic_models", ())),
                resolved_base_models=tuple(selection.get("resolved_base_models", (custom_id,))),
                rule_packs=tuple(selection.get("rule_packs", ())),
                dataset_requirements=tuple(selection.get("dataset_requirements", ())),
                default_outputs=RecipeOutputs(
                    view_ids=tuple(outputs.get("view_ids", ())),
                    report_profile_ids=tuple(outputs.get("report_profile_ids", ())),
                    exports=tuple(outputs.get("exports", ("json",))),
                ),
            )
        if not isinstance(selection, str):
            raise InvalidDraftError(
                f"{selector_type} must be an identifier",
                path=f"/selection/{selector_type}",
            )
        try:
            return self._selections[(selector_type, selection)]
        except KeyError as error:
            raise UnknownRegistryItemError(
                f"unknown {selector_type}: {selection}",
                path=f"/selection/{selector_type}",
                details={"selector_type": selector_type, "selection_id": selection},
            ) from error

    def get_component(self, calculation_id: str) -> ComponentDefinition:
        try:
            return self._components[calculation_id]
        except KeyError as error:
            raise UnknownRegistryItemError(
                f"unknown calculation: {calculation_id}",
                path="/selection",
                details={"calculation_id": calculation_id},
            ) from error

    def get_subject_facts(self, subject_version_id: str) -> SubjectFacts:
        try:
            return self._subject_facts[subject_version_id]
        except KeyError as error:
            raise UnknownRegistryItemError(
                f"unknown subject version: {subject_version_id}",
                path="/subject_roles",
                details={"subject_version_id": subject_version_id},
            ) from error

    def find_reuse(self, semantic_key: str) -> ReuseCandidate | None:
        return self._reuse.get(semantic_key)

    def get_output_requirements(self, output_id: str) -> tuple[str, ...] | None:
        return self._output_requirements.get(output_id)

    def with_reuse(self, *candidates: ReuseCandidate) -> InMemoryRecipeRegistry:
        """Return a new fixture with additional immutable reuse candidates."""

        return InMemoryRecipeRegistry(
            entry_points=tuple(self._entry_points.values()),
            selections=tuple(self._selections.values()),
            components=tuple(self._components.values()),
            subject_facts=self._subject_facts,
            reuse_candidates=(*self._reuse.values(), *candidates),
            output_requirements=self._output_requirements,
        )
