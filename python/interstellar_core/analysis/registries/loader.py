"""Strict loader for Interstellar's normative analysis registries."""

from __future__ import annotations

import hashlib
import re
from collections.abc import Iterable
from pathlib import Path
from typing import Any

import yaml

from .models import (
    AnalysisIntent,
    AnalysisRegistry,
    BaseAnalysisModel,
    EntryPoint,
    RegistrySource,
    TopicModel,
)

REPO_ROOT = Path(__file__).resolve().parents[4]
DEFAULT_ANALYSIS_CATALOG = REPO_ROOT / "docs" / "analysis-catalog.yaml"
DEFAULT_CAPABILITIES_CATALOG = REPO_ROOT / "docs" / "capabilities.yaml"
INTENT_SOURCE_POINTER = "docs/analysis-catalog.yaml#analysis_intents"

_SEMVER = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"
)
_VERSIONED_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]*\.v[1-9][0-9]*$")

_ANALYSIS_ROOT_FIELDS = frozenset(
    {
        "schema_version",
        "catalog_id",
        "title_zh",
        "authoritative_for",
        "product_rules",
        "contextual_interpretation_policy",
        "entry_points",
        "unified_analysis_center",
        "recipe_resolution_policy",
        "object_action_matrix",
        "personal_dashboard",
        "base_analysis_models",
        "topic_model_policy",
        "topic_model_contract",
        "input_profiles",
        "output_profiles",
        "topic_models",
        "analysis_intent_contract",
        "analysis_intents",
        "report_generation",
        "report_layers",
        "report_profile_contract",
        "report_profiles",
        "report_densities",
        "proprietary_models_not_executable_without_license",
    }
)
_CAPABILITIES_ROOT_FIELDS = frozenset(
    {
        "schema_version",
        "document_version",
        "product",
        "baseline_date",
        "license_strategy",
        "normative_catalogs",
        "catalog_coverage_policy",
        "policy",
        "phases",
        "data_sources",
        "validation_profiles",
        "analysis_model_policy",
        "analysis_recipe_policy",
        "topic_and_report_policy",
        "analysis_models",
        "capabilities",
    }
)
_ENTRY_FIELDS = frozenset(
    {
        "id",
        "name_zh",
        "behavior",
        "default_interpretation_model",
        "resolver_adds",
        "model_policy",
        "core_change_behavior",
        "startup_compute",
    }
)
_BASE_MODEL_FIELDS = frozenset(
    {
        "id",
        "version",
        "name_zh",
        "phase",
        "work_package",
        "target_maturity",
        "compatible_topics",
        "subject_roles",
        "optional_subject_roles",
        "minimum_time_precision",
        "components",
        "optional_components",
        "variants",
        "default_rule_pack",
        "primary_outputs",
    }
)
_TOPIC_FIELDS = frozenset(
    {
        "id",
        "name_zh",
        "group",
        "phase",
        "base_models",
        "input_profile",
        "output_profile",
        "report_target",
    }
)
_INTENT_FIELDS = frozenset(
    {"id", "name_zh", "topic_models", "input_profile", "report_profile"}
)
_CAPABILITY_FIELDS = frozenset(
    {
        "id",
        "name_zh",
        "catalog_sections",
        "category",
        "phase",
        "v1_required",
        "target_maturity",
        "work_package",
        "dependencies",
        "algorithm_card",
        "data_sources",
        "optional_data_sources",
        "inputs",
        "outputs",
        "validation_profile",
        "blocker",
        "constraint",
        "constraints",
        "forbidden_outputs",
        "export_presets",
        "view_number_ranges",
        "current_natal_views",
        "professional_natal_layers",
        "known_limits",
        "implemented_house_systems",
        "product_projection",
        "user_analysis_document",
    }
)
_INPUT_PROFILE_FIELDS = frozenset(
    {"roles", "minimum_time_precision", "time_range", "location"}
)
_OUTPUT_PROFILE_FIELDS = frozenset({"primary_views", "secondary_views"})
_REPORT_PROFILE_FIELDS = frozenset(
    {
        "id",
        "name_zh",
        "source",
        "interpretation",
        "default_sections",
        "default_density",
        "missing_dependency_behavior",
    }
)


class RegistryValidationError(ValueError):
    def __init__(self, errors: Iterable[str]):
        self.errors = tuple(errors)
        super().__init__("\n".join(self.errors))


def _load_yaml(path: Path) -> tuple[dict[str, Any], bytes]:
    raw = path.read_bytes()
    document = yaml.safe_load(raw)
    if not isinstance(document, dict):
        raise RegistryValidationError([f"{path}: root must be a mapping"])
    return document, raw


def _unknown_fields(
    record: dict[str, Any],
    allowed: frozenset[str],
    label: str,
    errors: list[str],
) -> None:
    unknown = sorted(set(record) - allowed)
    if unknown:
        errors.append(f"{label}: unknown fields {unknown}")


def _require_fields(
    record: dict[str, Any],
    required: Iterable[str],
    label: str,
    errors: list[str],
) -> None:
    missing = sorted(set(required) - set(record))
    if missing:
        errors.append(f"{label}: missing required fields {missing}")


def _string_list(value: Any, label: str, errors: list[str]) -> tuple[str, ...]:
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        errors.append(f"{label}: expected a list of strings")
        return ()
    return tuple(value)


def _record_list(value: Any, label: str, errors: list[str]) -> list[dict[str, Any]]:
    if not isinstance(value, list) or not all(isinstance(item, dict) for item in value):
        errors.append(f"{label}: expected a list of mappings")
        return []
    return value


def _version(value: Any, label: str, errors: list[str]) -> str:
    if not isinstance(value, str) or not _SEMVER.fullmatch(value):
        errors.append(f"{label}: expected semantic version, got {value!r}")
        return "invalid"
    return value


def _versioned_id(value: Any, label: str, errors: list[str]) -> str:
    if not isinstance(value, str) or not _VERSIONED_ID.fullmatch(value):
        errors.append(f"{label}: expected a versioned id ending in .vN, got {value!r}")
        return "invalid.v1"
    return value


def _prefixed_id(value: Any, prefix: str, label: str, errors: list[str]) -> str:
    if (
        not isinstance(value, str)
        or not value.startswith(prefix)
        or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:-]*", value)
    ):
        errors.append(f"{label}: expected stable {prefix}* id, got {value!r}")
        return f"{prefix}invalid"
    return value


def _unique(records: Iterable[Any], label: str, errors: list[str]) -> None:
    seen: set[str] = set()
    for record in records:
        identifier = record.id
        if identifier in seen:
            errors.append(f"{label}: duplicate id {identifier!r}")
        seen.add(identifier)


def _flatten_variant_components(value: Any, label: str, errors: list[str]) -> tuple[str, ...]:
    if value is None:
        return ()
    if not isinstance(value, dict):
        errors.append(f"{label}: variants must be a mapping of string lists")
        return ()
    components: list[str] = []
    for variant_id, variant_components in value.items():
        if not isinstance(variant_id, str):
            errors.append(f"{label}: variant keys must be strings")
            continue
        components.extend(
            _string_list(variant_components, f"{label}.{variant_id}", errors)
        )
    return tuple(components)


def _parse_entry_points(
    catalog: dict[str, Any], version: str, errors: list[str]
) -> tuple[EntryPoint, ...]:
    result: list[EntryPoint] = []
    for index, record in enumerate(
        _record_list(catalog.get("entry_points"), "analysis.entry_points", errors)
    ):
        label = f"analysis.entry_points[{index}]"
        _unknown_fields(record, _ENTRY_FIELDS, label, errors)
        _require_fields(record, ("id", "name_zh", "behavior"), label, errors)
        identifier = _prefixed_id(record.get("id"), "entry.", f"{label}.id", errors)
        result.append(
            EntryPoint(
                id=identifier,
                name_zh=str(record.get("name_zh", "")),
                behavior=str(record.get("behavior", "")),
                catalog_version=version,
            )
        )
    _unique(result, "analysis.entry_points", errors)
    return tuple(result)


def _parse_base_models(
    capabilities: dict[str, Any], errors: list[str]
) -> dict[str, BaseAnalysisModel]:
    result: list[BaseAnalysisModel] = []
    for index, record in enumerate(
        _record_list(capabilities.get("analysis_models"), "capabilities.analysis_models", errors)
    ):
        label = f"capabilities.analysis_models[{index}]"
        _unknown_fields(record, _BASE_MODEL_FIELDS, label, errors)
        _require_fields(
            record,
            (
                "id",
                "version",
                "name_zh",
                "phase",
                "target_maturity",
                "default_rule_pack",
                "primary_outputs",
            ),
            label,
            errors,
        )
        components = _string_list(record.get("components", []), f"{label}.components", errors)
        optional = _string_list(
            record.get("optional_components", []),
            f"{label}.optional_components",
            errors,
        )
        variants = _flatten_variant_components(record.get("variants"), f"{label}.variants", errors)
        result.append(
            BaseAnalysisModel(
                id=_versioned_id(record.get("id"), f"{label}.id", errors),
                version=_version(record.get("version"), f"{label}.version", errors),
                name_zh=str(record.get("name_zh", "")),
                phase=str(record.get("phase", "")),
                target_maturity=str(record.get("target_maturity", "")),
                components=components,
                optional_components=optional,
                variant_components=variants,
                default_rule_pack=str(record.get("default_rule_pack", "")),
                primary_outputs=_string_list(
                    record.get("primary_outputs"), f"{label}.primary_outputs", errors
                ),
            )
        )
    _unique(result, "capabilities.analysis_models", errors)
    return {model.id: model for model in result}


def _parse_topics(
    catalog: dict[str, Any], version: str, errors: list[str]
) -> dict[str, TopicModel]:
    result: list[TopicModel] = []
    for index, record in enumerate(
        _record_list(catalog.get("topic_models"), "analysis.topic_models", errors)
    ):
        label = f"analysis.topic_models[{index}]"
        _unknown_fields(record, _TOPIC_FIELDS, label, errors)
        _require_fields(record, _TOPIC_FIELDS, label, errors)
        result.append(
            TopicModel(
                id=_versioned_id(record.get("id"), f"{label}.id", errors),
                name_zh=str(record.get("name_zh", "")),
                group=str(record.get("group", "")),
                phase=str(record.get("phase", "")),
                base_models=_string_list(
                    record.get("base_models"), f"{label}.base_models", errors
                ),
                input_profile=str(record.get("input_profile", "")),
                output_profile=str(record.get("output_profile", "")),
                report_target=str(record.get("report_target", "")),
                catalog_version=version,
            )
        )
    _unique(result, "analysis.topic_models", errors)
    return {model.id: model for model in result}


def _parse_intents(
    catalog: dict[str, Any], version: str, errors: list[str]
) -> dict[str, AnalysisIntent]:
    groups = catalog.get("analysis_intents")
    if not isinstance(groups, dict):
        errors.append("analysis.analysis_intents: expected a mapping of groups")
        return {}
    result: list[AnalysisIntent] = []
    for group, values in groups.items():
        if not isinstance(group, str):
            errors.append("analysis.analysis_intents: group ids must be strings")
            continue
        for index, record in enumerate(
            _record_list(values, f"analysis.analysis_intents.{group}", errors)
        ):
            label = f"analysis.analysis_intents.{group}[{index}]"
            _unknown_fields(record, _INTENT_FIELDS, label, errors)
            _require_fields(record, _INTENT_FIELDS, label, errors)
            result.append(
                AnalysisIntent(
                    id=_prefixed_id(record.get("id"), "intent.", f"{label}.id", errors),
                    name_zh=str(record.get("name_zh", "")),
                    group=group,
                    topic_models=_string_list(
                        record.get("topic_models"), f"{label}.topic_models", errors
                    ),
                    input_profile=str(record.get("input_profile", "")),
                    report_profile=str(record.get("report_profile", "")),
                    catalog_version=version,
                )
            )
    _unique(result, "analysis.analysis_intents", errors)
    return {intent.id: intent for intent in result}


def _validate_references(
    analysis: dict[str, Any],
    capabilities: dict[str, Any],
    base_models: dict[str, BaseAnalysisModel],
    topics: dict[str, TopicModel],
    intents: dict[str, AnalysisIntent],
    entry_points: tuple[EntryPoint, ...],
    errors: list[str],
) -> None:
    capability_records = _record_list(
        capabilities.get("capabilities"), "capabilities.capabilities", errors
    )
    capability_ids: set[str] = set()
    data_source_ids = set(capabilities.get("data_sources", {}))
    for index, record in enumerate(capability_records):
        label = f"capabilities.capabilities[{index}]"
        _unknown_fields(record, _CAPABILITY_FIELDS, label, errors)
        _require_fields(record, ("id", "dependencies", "data_sources"), label, errors)
        identifier = record.get("id")
        if not isinstance(identifier, str):
            errors.append(f"{label}.id: expected string")
        elif identifier in capability_ids:
            errors.append(f"capabilities.capabilities: duplicate id {identifier!r}")
        else:
            capability_ids.add(identifier)

    for index, record in enumerate(capability_records):
        identifier = str(record.get("id", f"index-{index}"))
        for dependency in _string_list(
            record.get("dependencies"), f"capability {identifier}.dependencies", errors
        ):
            if dependency not in capability_ids:
                errors.append(f"capability {identifier}: unknown dependency {dependency!r}")
        for source in _string_list(
            record.get("data_sources"), f"capability {identifier}.data_sources", errors
        ):
            if source not in data_source_ids:
                errors.append(f"capability {identifier}: unknown data source {source!r}")
        if "optional_data_sources" in record:
            for source in _string_list(
                record.get("optional_data_sources"),
                f"capability {identifier}.optional_data_sources",
                errors,
            ):
                if source not in data_source_ids:
                    errors.append(
                        f"capability {identifier}: unknown optional data source {source!r}"
                    )
        if "known_limits" in record:
            _string_list(
                record.get("known_limits"),
                f"capability {identifier}.known_limits",
                errors,
            )

    declared_base = analysis.get("base_analysis_models")
    if not isinstance(declared_base, dict):
        errors.append("analysis.base_analysis_models: expected mapping")
    else:
        declared_ids = _string_list(
            declared_base.get("ids"), "analysis.base_analysis_models.ids", errors
        )
        if set(declared_ids) != set(base_models):
            errors.append("analysis.base_analysis_models.ids does not match capabilities models")

    for model in base_models.values():
        for component in model.all_components:
            if component not in capability_ids:
                errors.append(f"base model {model.id}: unknown component {component!r}")

    input_profiles = analysis.get("input_profiles")
    output_profiles = analysis.get("output_profiles")
    if not isinstance(input_profiles, dict) or not isinstance(output_profiles, dict):
        errors.append("analysis input_profiles/output_profiles must be mappings")
        input_profiles = {}
        output_profiles = {}
    for profile_id, profile in input_profiles.items():
        if not isinstance(profile, dict):
            errors.append(f"input profile {profile_id}: expected mapping")
        else:
            _unknown_fields(profile, _INPUT_PROFILE_FIELDS, f"input profile {profile_id}", errors)
    for profile_id, profile in output_profiles.items():
        if not isinstance(profile, dict):
            errors.append(f"output profile {profile_id}: expected mapping")
        else:
            _unknown_fields(profile, _OUTPUT_PROFILE_FIELDS, f"output profile {profile_id}", errors)

    for topic in topics.values():
        for base_model in topic.base_models:
            if base_model not in base_models:
                errors.append(f"topic model {topic.id}: unknown base model {base_model!r}")
        if topic.input_profile not in input_profiles:
            errors.append(f"topic model {topic.id}: unknown input profile {topic.input_profile!r}")
        if topic.output_profile not in output_profiles:
            errors.append(
                f"topic model {topic.id}: unknown output profile {topic.output_profile!r}"
            )

    report_records = _record_list(
        analysis.get("report_profiles"), "analysis.report_profiles", errors
    )
    report_ids: set[str] = set()
    for index, record in enumerate(report_records):
        label = f"analysis.report_profiles[{index}]"
        _unknown_fields(record, _REPORT_PROFILE_FIELDS, label, errors)
        _require_fields(record, _REPORT_PROFILE_FIELDS, label, errors)
        identifier = record.get("id")
        if not isinstance(identifier, str):
            errors.append(f"{label}.id: expected string")
        elif identifier in report_ids:
            errors.append(f"analysis.report_profiles: duplicate id {identifier!r}")
        else:
            report_ids.add(identifier)

    for intent in intents.values():
        for topic_model in intent.topic_models:
            if topic_model not in topics:
                errors.append(f"intent {intent.id}: unknown topic model {topic_model!r}")
        if intent.input_profile not in input_profiles:
            errors.append(f"intent {intent.id}: unknown input profile {intent.input_profile!r}")
        if intent.report_profile not in report_ids:
            errors.append(f"intent {intent.id}: unknown report profile {intent.report_profile!r}")

    expected_entries = capabilities.get("analysis_recipe_policy", {}).get("entry_points")
    if expected_entries != len(entry_points):
        errors.append(
            f"entry point count {len(entry_points)} does not match capabilities policy "
            f"{expected_entries!r}"
        )

    counts = capabilities.get("normative_catalogs", {}).get("analysis_registry", {})
    for key, actual in (
        ("base_analysis_models", len(base_models)),
        ("topic_models", len(topics)),
        ("analysis_intents", len(intents)),
    ):
        expected = counts.get(key)
        if expected != actual:
            errors.append(f"{key} count {actual} does not match declared {expected!r}")


def load_analysis_registry(
    analysis_catalog_path: Path | str = DEFAULT_ANALYSIS_CATALOG,
    capabilities_catalog_path: Path | str = DEFAULT_CAPABILITIES_CATALOG,
) -> AnalysisRegistry:
    analysis_path = Path(analysis_catalog_path).resolve()
    capabilities_path = Path(capabilities_catalog_path).resolve()
    analysis, analysis_raw = _load_yaml(analysis_path)
    capabilities, capabilities_raw = _load_yaml(capabilities_path)
    errors: list[str] = []

    _unknown_fields(analysis, _ANALYSIS_ROOT_FIELDS, "analysis catalog root", errors)
    _unknown_fields(capabilities, _CAPABILITIES_ROOT_FIELDS, "capabilities root", errors)
    _require_fields(
        analysis,
        ("schema_version", "catalog_id", "entry_points", "topic_models", "analysis_intents"),
        "analysis catalog root",
        errors,
    )
    _require_fields(
        capabilities,
        ("schema_version", "document_version", "analysis_models", "capabilities"),
        "capabilities root",
        errors,
    )
    analysis_version = _version(
        analysis.get("schema_version"), "analysis.schema_version", errors
    )
    capabilities_version = _version(
        capabilities.get("schema_version"), "capabilities.schema_version", errors
    )
    _version(capabilities.get("document_version"), "capabilities.document_version", errors)

    entry_points = _parse_entry_points(analysis, analysis_version, errors)
    base_models = _parse_base_models(capabilities, errors)
    topics = _parse_topics(analysis, analysis_version, errors)
    intents = _parse_intents(analysis, analysis_version, errors)
    _validate_references(
        analysis,
        capabilities,
        base_models,
        topics,
        intents,
        entry_points,
        errors,
    )
    if errors:
        raise RegistryValidationError(errors)

    analysis_hash = hashlib.sha256(analysis_raw).hexdigest()
    capabilities_hash = hashlib.sha256(capabilities_raw).hexdigest()
    combined_hash = hashlib.sha256(
        f"{analysis_hash}:{capabilities_hash}".encode()
    ).hexdigest()
    catalog_id = analysis.get("catalog_id")
    if not isinstance(catalog_id, str):
        raise RegistryValidationError(["analysis.catalog_id must be a string"])
    return AnalysisRegistry.create(
        id=catalog_id,
        version=analysis_version,
        content_hash=f"sha256:{combined_hash}",
        sources=(
            RegistrySource(
                kind="analysis_catalog",
                path=str(analysis_path),
                schema_version=analysis_version,
                sha256=analysis_hash,
            ),
            RegistrySource(
                kind="capabilities_catalog",
                path=str(capabilities_path),
                schema_version=capabilities_version,
                sha256=capabilities_hash,
            ),
            RegistrySource(
                kind="intent_taxonomy",
                path=str(analysis_path),
                schema_version=analysis_version,
                sha256=analysis_hash,
                pointer="#analysis_intents",
            ),
        ),
        intent_source_pointer=INTENT_SOURCE_POINTER,
        entry_points=entry_points,
        base_models=base_models,
        topic_models=topics,
        intents=intents,
    )
