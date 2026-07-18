"""Immutable public models for the versioned analysis registry."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from types import MappingProxyType


@dataclass(frozen=True, slots=True)
class RegistrySource:
    kind: str
    path: str
    schema_version: str
    sha256: str
    pointer: str | None = None


@dataclass(frozen=True, slots=True)
class EntryPoint:
    id: str
    name_zh: str
    behavior: str
    catalog_version: str


@dataclass(frozen=True, slots=True)
class BaseAnalysisModel:
    id: str
    version: str
    name_zh: str
    phase: str
    target_maturity: str
    components: tuple[str, ...]
    optional_components: tuple[str, ...]
    variant_components: tuple[str, ...]
    default_rule_pack: str
    primary_outputs: tuple[str, ...]

    @property
    def all_components(self) -> tuple[str, ...]:
        return self.components + self.optional_components + self.variant_components


@dataclass(frozen=True, slots=True)
class TopicModel:
    id: str
    name_zh: str
    group: str
    phase: str
    base_models: tuple[str, ...]
    input_profile: str
    output_profile: str
    report_target: str
    catalog_version: str


@dataclass(frozen=True, slots=True)
class AnalysisIntent:
    id: str
    name_zh: str
    group: str
    topic_models: tuple[str, ...]
    input_profile: str
    report_profile: str
    catalog_version: str


@dataclass(frozen=True, slots=True)
class AnalysisRegistry:
    id: str
    version: str
    content_hash: str
    sources: tuple[RegistrySource, ...]
    intent_source_pointer: str
    entry_points: tuple[EntryPoint, ...]
    base_models: Mapping[str, BaseAnalysisModel]
    topic_models: Mapping[str, TopicModel]
    intents: Mapping[str, AnalysisIntent]

    @classmethod
    def create(
        cls,
        *,
        id: str,
        version: str,
        content_hash: str,
        sources: tuple[RegistrySource, ...],
        intent_source_pointer: str,
        entry_points: tuple[EntryPoint, ...],
        base_models: dict[str, BaseAnalysisModel],
        topic_models: dict[str, TopicModel],
        intents: dict[str, AnalysisIntent],
    ) -> AnalysisRegistry:
        return cls(
            id=id,
            version=version,
            content_hash=content_hash,
            sources=sources,
            intent_source_pointer=intent_source_pointer,
            entry_points=entry_points,
            base_models=MappingProxyType(dict(base_models)),
            topic_models=MappingProxyType(dict(topic_models)),
            intents=MappingProxyType(dict(intents)),
        )

    def get_base_model(self, model_id: str) -> BaseAnalysisModel:
        return self.base_models[model_id]

    def get_topic_model(self, model_id: str) -> TopicModel:
        return self.topic_models[model_id]

    def get_intent(self, intent_id: str) -> AnalysisIntent:
        return self.intents[intent_id]

    def list_entry_points(self) -> tuple[EntryPoint, ...]:
        return self.entry_points

    def list_base_models(self) -> tuple[BaseAnalysisModel, ...]:
        return tuple(self.base_models.values())

    def list_topic_models(self) -> tuple[TopicModel, ...]:
        return tuple(self.topic_models.values())

    def list_intents(self) -> tuple[AnalysisIntent, ...]:
        return tuple(self.intents.values())
