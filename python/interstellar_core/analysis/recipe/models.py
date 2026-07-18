"""Registry and policy value objects used by the analysis recipe resolver."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from types import MappingProxyType
from typing import Any


def _mapping(value: Mapping[str, Any] | None = None) -> Mapping[str, Any]:
    return MappingProxyType(dict(value or {}))


@dataclass(frozen=True, slots=True)
class RecipeOutputs:
    view_ids: tuple[str, ...] = ()
    report_profile_ids: tuple[str, ...] = ()
    exports: tuple[str, ...] = ("json",)


@dataclass(frozen=True, slots=True)
class DegradationDefinition:
    """Declared, reviewable fallback for insufficient input quality."""

    code: str
    effective_calculation_id: str
    message: str
    output_ids: tuple[str, ...] = ()


@dataclass(frozen=True, slots=True)
class ComponentDefinition:
    """One calculation node independently supplied by a capability catalog."""

    calculation_id: str
    version: str = "1"
    dependencies: tuple[str, ...] = ()
    semantic_key: str | None = None
    default_parameters: Mapping[str, Any] = field(default_factory=_mapping)
    override_keys: frozenset[str] = frozenset()
    required_time_precision: Mapping[str, str] = field(default_factory=_mapping)
    requires_resolved_utc_roles: frozenset[str] = frozenset()
    requires_location_roles: frozenset[str] = frozenset()
    degradation: DegradationDefinition | None = None
    implementation_available: bool = True
    implementation_reason: str | None = None
    license_allowed: bool = True
    license_reason: str | None = None
    output_ids: tuple[str, ...] = ()
    duration_ms_p50: int = 0
    search_points: int = 0

    def __post_init__(self) -> None:
        object.__setattr__(self, "default_parameters", _mapping(self.default_parameters))
        object.__setattr__(self, "required_time_precision", _mapping(self.required_time_precision))
        if self.duration_ms_p50 < 0 or self.search_points < 0:
            raise ValueError("component resource estimates cannot be negative")


@dataclass(frozen=True, slots=True)
class SelectionDefinition:
    """Expanded intent, topic, model, technique, or custom-model preset."""

    selection_id: str
    selector_type: str
    required_components: tuple[str, ...] = ()
    recommended_components: tuple[str, ...] = ()
    optional_components: tuple[str, ...] = ()
    required_roles: tuple[str, ...] = ("primary",)
    resolved_topic_models: tuple[str, ...] = ()
    resolved_base_models: tuple[str, ...] = ()
    rule_packs: tuple[Mapping[str, Any], ...] = ()
    dataset_requirements: tuple[Mapping[str, Any], ...] = ()
    default_outputs: RecipeOutputs = RecipeOutputs()

    def __post_init__(self) -> None:
        object.__setattr__(
            self,
            "rule_packs",
            tuple(_mapping(item) for item in self.rule_packs),
        )
        object.__setattr__(
            self,
            "dataset_requirements",
            tuple(_mapping(item) for item in self.dataset_requirements),
        )


@dataclass(frozen=True, slots=True)
class EntryPointDefinition:
    """One of the product's six entrances into the same resolver."""

    entry_point_id: str
    allowed_selector_types: frozenset[str]
    required_components: tuple[str, ...] = ()
    recommended_components: tuple[str, ...] = ()
    optional_components: tuple[str, ...] = ()
    default_outputs: RecipeOutputs = RecipeOutputs()


@dataclass(frozen=True, slots=True)
class SubjectFacts:
    """Only preflight facts needed by the resolver; never astronomical data."""

    time_precision: str = "unknown"
    has_resolved_utc: bool = False
    has_location: bool = False


@dataclass(frozen=True, slots=True)
class ReuseCandidate:
    semantic_key: str
    snapshot_id: str
    result_paths: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class RecipeResolutionPolicy:
    """Deterministic product limits used for execution-mode selection."""

    recipe_version: int = 1
    ttl_seconds: int = 15 * 60
    sync_duration_ms: int = 2_000
    sync_search_points: int = 1_000
    hard_duration_ms: int = 120_000
    hard_search_points: int = 1_000_000
    batch_node_count: int = 50

    def __post_init__(self) -> None:
        if self.recipe_version < 1 or self.ttl_seconds <= 0:
            raise ValueError("recipe version and TTL must be positive")
        if self.sync_duration_ms > self.hard_duration_ms:
            raise ValueError("sync duration threshold exceeds the hard budget")
        if self.sync_search_points > self.hard_search_points:
            raise ValueError("sync search threshold exceeds the hard budget")
