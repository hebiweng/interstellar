#!/usr/bin/env python3
"""Validate Interstellar's normative planning catalogs before build or review."""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

import yaml


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"


def load_yaml(name: str) -> dict[str, Any]:
    with (DOCS / name).open("r", encoding="utf-8") as handle:
        value = yaml.safe_load(handle)
    if not isinstance(value, dict):
        raise AssertionError(f"{name}: expected a mapping at document root")
    return value


def load_yaml_path(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = yaml.safe_load(handle)
    if not isinstance(value, dict):
        raise AssertionError(f"{path}: expected a mapping at document root")
    return value


def load_json_path(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise AssertionError(f"{path}: expected a mapping at document root")
    return value


def parse_front_matter(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n", text, flags=re.DOTALL)
    if not match:
        raise AssertionError(f"{path}: missing YAML front matter")
    value = yaml.safe_load(match.group(1))
    if not isinstance(value, dict):
        raise AssertionError(f"{path}: front matter must be a mapping")
    return value


def iter_refs(value: Any) -> Iterable[str]:
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "$ref" and isinstance(child, str):
                yield child
            else:
                yield from iter_refs(child)
    elif isinstance(value, list):
        for child in value:
            yield from iter_refs(child)


def resolve_pointer(document: Any, pointer: str) -> Any:
    if not pointer:
        return document
    if not pointer.startswith("/"):
        raise KeyError(pointer)
    current = document
    for raw_part in pointer[1:].split("/"):
        part = raw_part.replace("~1", "/").replace("~0", "~")
        if isinstance(current, list):
            current = current[int(part)]
        else:
            current = current[part]
    return current


def validate_refs(path: Path, document: dict[str, Any], errors: list[str]) -> None:
    cache: dict[Path, dict[str, Any]] = {path.resolve(): document}
    for reference in iter_refs(document):
        if reference.startswith(("http://", "https://")):
            continue
        file_part, _, fragment = reference.partition("#")
        target_path = (path.parent / file_part).resolve() if file_part else path.resolve()
        if not target_path.exists():
            errors.append(f"{path}: unresolved $ref file {reference}")
            continue
        try:
            target_document = cache.get(target_path)
            if target_document is None:
                if target_path.suffix == ".json":
                    target_document = load_json_path(target_path)
                else:
                    target_document = load_yaml_path(target_path)
                cache[target_path] = target_document
            resolve_pointer(target_document, fragment)
        except (AssertionError, KeyError, ValueError, IndexError, json.JSONDecodeError, yaml.YAMLError) as exc:
            errors.append(f"{path}: unresolved $ref {reference}: {exc}")


def require_unique(values: Iterable[str], label: str, errors: list[str]) -> set[str]:
    items = list(values)
    duplicates = sorted(value for value, count in Counter(items).items() if count > 1)
    if duplicates:
        errors.append(f"{label}: duplicate IDs: {', '.join(duplicates)}")
    return set(items)


def missing_fields(item: dict[str, Any], fields: Iterable[str]) -> list[str]:
    return [field for field in fields if field not in item]


def validate_required_fields(
    items: Iterable[dict[str, Any]], fields: Iterable[str], label: str, errors: list[str]
) -> None:
    for item in items:
        missing = missing_fields(item, fields)
        if missing:
            errors.append(f"{label} {item.get('id') or item.get('calculation_id')}: missing {missing}")


def main() -> int:
    errors: list[str] = []
    capabilities = load_yaml("capabilities.yaml")
    calculations = load_yaml("calculation-catalog.yaml")
    renders = load_yaml("render-catalog.yaml")
    analysis = load_yaml("analysis-catalog.yaml")

    capability_rows = capabilities.get("capabilities", [])
    capability_ids = require_unique((row["id"] for row in capability_rows), "capability", errors)
    base_model_rows = capabilities.get("analysis_models", [])
    base_model_ids = require_unique((row["id"] for row in base_model_rows), "analysis model", errors)

    calculation_rows = calculations.get("calculations", [])
    calculation_ids = require_unique(
        (row["calculation_id"] for row in calculation_rows), "calculation", errors
    )
    validate_required_fields(
        calculation_rows,
        calculations["entry_contract"]["required_fields"],
        "calculation",
        errors,
    )
    for row in calculation_rows:
        if row["capability_id"] not in capability_ids:
            errors.append(
                f"calculation {row['calculation_id']}: unknown capability {row['capability_id']}"
            )

    view_rows = renders.get("views", [])
    view_ids = require_unique((row["view_id"] for row in view_rows), "view", errors)
    view_numbers = [row["number"] for row in view_rows]
    require_unique((str(number) for number in view_numbers), "view number", errors)
    if view_numbers != list(range(1, len(view_numbers) + 1)):
        errors.append("view numbers must be ordered and contiguous from 1")
    validate_required_fields(
        view_rows, renders["entry_contract"]["required_fields"], "view", errors
    )
    for row in view_rows:
        if row["capability_id"] not in capability_ids:
            errors.append(f"view {row['view_id']}: unknown capability {row['capability_id']}")
        for dependency in row["result_dependencies"]:
            if row["target_release"] == "post_v1_consumer" and dependency.startswith("future."):
                continue
            if dependency not in capability_ids and dependency not in calculation_ids:
                errors.append(f"view {row['view_id']}: unknown result dependency {dependency}")

    topic_rows = analysis.get("topic_models", [])
    topic_ids = require_unique((row["id"] for row in topic_rows), "topic model", errors)
    validate_required_fields(
        topic_rows, analysis["topic_model_contract"]["required_fields"], "topic model", errors
    )
    input_profiles = set(analysis.get("input_profiles", {}))
    output_profiles = analysis.get("output_profiles", {})
    for row in topic_rows:
        for model_id in row["base_models"]:
            if model_id not in base_model_ids:
                errors.append(f"topic model {row['id']}: unknown base model {model_id}")
        if row["input_profile"] not in input_profiles:
            errors.append(f"topic model {row['id']}: unknown input profile {row['input_profile']}")
        if row["output_profile"] not in output_profiles:
            errors.append(f"topic model {row['id']}: unknown output profile {row['output_profile']}")

    for profile_id, profile in output_profiles.items():
        for view_id in profile.get("primary_views", []) + profile.get("secondary_views", []):
            if view_id not in view_ids:
                errors.append(f"output profile {profile_id}: unknown view {view_id}")

    intent_rows = [
        row for group in analysis.get("analysis_intents", {}).values() for row in group
    ]
    require_unique((row["id"] for row in intent_rows), "analysis intent", errors)
    validate_required_fields(
        intent_rows,
        analysis["analysis_intent_contract"]["required_fields"],
        "analysis intent",
        errors,
    )
    report_rows = analysis.get("report_profiles", [])
    report_ids = require_unique((row["id"] for row in report_rows), "report profile", errors)
    validate_required_fields(
        report_rows,
        analysis["report_profile_contract"]["required_fields"],
        "report profile",
        errors,
    )
    for row in intent_rows:
        for topic_id in row["topic_models"]:
            if topic_id not in topic_ids:
                errors.append(f"analysis intent {row['id']}: unknown topic model {topic_id}")
        if row["input_profile"] not in input_profiles:
            errors.append(f"analysis intent {row['id']}: unknown input profile {row['input_profile']}")
        if row["report_profile"] not in report_ids:
            errors.append(f"analysis intent {row['id']}: unknown report profile {row['report_profile']}")

    # Implementation assets are normative, not optional prose examples.
    algorithm_catalog_path = ROOT / "algorithm-cards" / "catalog.yaml"
    if not algorithm_catalog_path.exists():
        errors.append("algorithm-cards/catalog.yaml: missing")
    else:
        algorithm_catalog = load_yaml_path(algorithm_catalog_path)
        card_rows = algorithm_catalog.get("cards", [])
        require_unique((row["card_id"] for row in card_rows), "algorithm card", errors)
        covered_capabilities = require_unique(
            (row["capability_id"] for row in card_rows), "algorithm card capability", errors
        )
        required_card_capabilities = {
            row["id"] for row in capability_rows if row.get("algorithm_card") == "required"
        }
        if covered_capabilities != required_card_capabilities:
            missing = sorted(required_card_capabilities - covered_capabilities)
            extra = sorted(covered_capabilities - required_card_capabilities)
            if missing:
                errors.append(f"algorithm cards: missing capabilities {', '.join(missing)}")
            if extra:
                errors.append(f"algorithm cards: unexpected capabilities {', '.join(extra)}")
        for row in card_rows:
            if row.get("status") not in {"draft", "review", "approved", "superseded"}:
                errors.append(f"algorithm card {row['card_id']}: invalid status {row.get('status')}")
            if row.get("implementation_status") not in {
                "not_started",
                "in_progress",
                "implemented",
                "verified",
            }:
                errors.append(
                    f"algorithm card {row['card_id']}: invalid implementation status "
                    f"{row.get('implementation_status')}"
                )
            card_path = ROOT / row["path"]
            if not card_path.exists():
                errors.append(f"algorithm card {row['card_id']}: missing file {row['path']}")
                continue
            try:
                front_matter = parse_front_matter(card_path)
                if front_matter.get("card_id") != row["card_id"]:
                    errors.append(f"algorithm card {row['card_id']}: front-matter card_id mismatch")
                if front_matter.get("capability_id") != row["capability_id"]:
                    errors.append(
                        f"algorithm card {row['card_id']}: front-matter capability_id mismatch"
                    )
                if front_matter.get("status") != row["status"]:
                    errors.append(f"algorithm card {row['card_id']}: status mismatch")
            except (AssertionError, yaml.YAMLError) as exc:
                errors.append(str(exc))

    dataset_manifest_path = ROOT / "data-manifests" / "catalog.yaml"
    if not dataset_manifest_path.exists():
        errors.append("data-manifests/catalog.yaml: missing")
    else:
        dataset_manifest = load_yaml_path(dataset_manifest_path)
        dataset_rows = dataset_manifest.get("datasets", [])
        dataset_ids = require_unique((row["id"] for row in dataset_rows), "dataset manifest", errors)
        declared_dataset_ids = set(capabilities.get("data_sources", {}))
        if dataset_ids != declared_dataset_ids:
            missing = sorted(declared_dataset_ids - dataset_ids)
            extra = sorted(dataset_ids - declared_dataset_ids)
            if missing:
                errors.append(f"dataset manifests: missing {', '.join(missing)}")
            if extra:
                errors.append(f"dataset manifests: unexpected {', '.join(extra)}")
        for row in dataset_rows:
            acquisition = row.get("acquisition", {})
            if acquisition.get("crawler") is not False:
                errors.append(f"dataset {row['id']}: crawler must be false")
            if "license" not in row or "failure_strategy" not in row:
                errors.append(f"dataset {row['id']}: license and failure_strategy are required")

    preset_path = ROOT / "presets" / "official" / "analysis-model-presets.yaml"
    if not preset_path.exists():
        errors.append("presets/official/analysis-model-presets.yaml: missing")
        preset_rows: list[dict[str, Any]] = []
    else:
        preset_rows = load_yaml_path(preset_path).get("presets", [])
        preset_ids = require_unique((row["id"] for row in preset_rows), "analysis preset", errors)
        if preset_ids != base_model_ids:
            errors.append("analysis presets: IDs must exactly match the 12 analysis models")
        for row in preset_rows:
            for component in row.get("required_components", []) + row.get("optional_components", []):
                if component not in capability_ids:
                    errors.append(f"analysis preset {row['id']}: unknown component {component}")
            for view_id in row.get("primary_outputs", []) + row.get("secondary_outputs", []):
                if view_id not in view_ids:
                    errors.append(f"analysis preset {row['id']}: unknown view {view_id}")

    base_rules_path = ROOT / "rules" / "official" / "base-model-rules.yaml"
    topic_rules_path = ROOT / "rules" / "official" / "topic-model-rules.yaml"
    if not base_rules_path.exists():
        errors.append("rules/official/base-model-rules.yaml: missing")
    else:
        base_rule_rows = load_yaml_path(base_rules_path).get("rule_packs", [])
        base_rule_ids = require_unique((row["id"] for row in base_rule_rows), "base rule pack", errors)
        expected_rule_ids = {row["default_rule_pack"] for row in base_model_rows}
        if base_rule_ids != expected_rule_ids:
            errors.append("base rule packs: IDs must exactly match analysis model default_rule_pack values")
    if not topic_rules_path.exists():
        errors.append("rules/official/topic-model-rules.yaml: missing")
    else:
        topic_binding_rows = load_yaml_path(topic_rules_path).get("topic_rule_bindings", [])
        bound_topic_ids = require_unique(
            (row["topic_model_id"] for row in topic_binding_rows), "topic rule binding", errors
        )
        if bound_topic_ids != topic_ids:
            errors.append("topic rule bindings: IDs must exactly match the 24 topic models")

    report_contract_path = ROOT / "reports" / "report-profiles.yaml"
    if not report_contract_path.exists():
        errors.append("reports/report-profiles.yaml: missing")
    else:
        implementation_report_rows = load_yaml_path(report_contract_path).get("profiles", [])
        implementation_report_ids = require_unique(
            (row["id"] for row in implementation_report_rows), "implemented report profile", errors
        )
        if implementation_report_ids != report_ids:
            errors.append("report profile assets: IDs must exactly match analysis-catalog.yaml")
    for locale in ["zh-CN", "en-US"]:
        template_path = ROOT / "reports" / f"templates.{locale}.yaml"
        if not template_path.exists():
            errors.append(f"reports/templates.{locale}.yaml: missing")
            continue
        template_profile_ids = set(load_yaml_path(template_path).get("profiles", {}))
        if template_profile_ids != report_ids:
            errors.append(f"report templates {locale}: profile coverage mismatch")

    backlog_path = DOCS / "backlog" / "m24-single-owner.yaml"
    if not backlog_path.exists():
        errors.append("docs/backlog/m24-single-owner.yaml: missing")
    else:
        backlog_rows = load_yaml_path(backlog_path).get("months", [])
        month_values = [row.get("month") for row in backlog_rows]
        if month_values != [f"M{index}" for index in range(25)]:
            errors.append("M24 backlog: months must be contiguous M0 through M24")
        require_unique(
            (task["id"] for row in backlog_rows for task in row.get("tasks", [])),
            "M24 task",
            errors,
        )

    phase_controller_path = DOCS / "backlog" / "execution-controller.yaml"
    phase_state_path = DOCS / "backlog" / "execution-state.yaml"
    expected_stage_ids = [
        "foundation",
        "professional_alpha",
        "professional_beta",
        "professional_pro",
        "complete_v1",
    ]
    if not phase_controller_path.exists():
        errors.append("docs/backlog/execution-controller.yaml: missing")
        controller_stage_ids: list[str] = []
    else:
        phase_controller = load_yaml_path(phase_controller_path)
        controller_stage_rows = phase_controller.get("stages", [])
        controller_stage_ids = [row.get("id") for row in controller_stage_rows]
        if controller_stage_ids != expected_stage_ids:
            errors.append("phase controller: stages must follow foundation through complete_v1")
        controlled_months = [month for row in controller_stage_rows for month in row.get("months", [])]
        if controlled_months != [f"M{index}" for index in range(25)]:
            errors.append("phase controller: stage months must cover contiguous M0 through M24")
        for row in controller_stage_rows:
            if not row.get("exit_gate"):
                errors.append(f"phase controller {row.get('id')}: exit_gate required")
    if not phase_state_path.exists():
        errors.append("docs/backlog/execution-state.yaml: missing")
    else:
        phase_state = load_yaml_path(phase_state_path)
        active_stage = phase_state.get("active_stage")
        if active_stage not in controller_stage_ids:
            errors.append(f"phase execution state: unknown active stage {active_stage}")
        state_stage_ids = list(phase_state.get("stage_status", {}))
        if state_stage_ids != [*expected_stage_ids, "released"]:
            errors.append("phase execution state: stage_status keys must include all stages and released")

    seed_fixture_path = ROOT / "tests" / "gold" / "specs" / "seed-cases.yaml"
    if not seed_fixture_path.exists():
        errors.append("tests/gold/specs/seed-cases.yaml: missing")
    else:
        seed_rows = load_yaml_path(seed_fixture_path).get("cases", [])
        require_unique((row["fixture_id"] for row in seed_rows), "gold fixture", errors)
        for row in seed_rows:
            for capability_id in row.get("capability_ids", []):
                if capability_id not in capability_ids:
                    errors.append(f"gold fixture {row['fixture_id']}: unknown capability {capability_id}")
            for calculation_id in row.get("calculation_ids", []):
                if calculation_id not in calculation_ids:
                    errors.append(f"gold fixture {row['fixture_id']}: unknown calculation {calculation_id}")

    schema_files = sorted((ROOT / "packages" / "canonical-schema").glob("**/*.json"))
    if not schema_files:
        errors.append("packages/canonical-schema: no JSON Schema files found")
    for schema_path in schema_files:
        try:
            schema_document = load_json_path(schema_path)
            if schema_document.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
                errors.append(f"{schema_path}: JSON Schema 2020-12 declaration is required")
            validate_refs(schema_path, schema_document, errors)
        except (AssertionError, json.JSONDecodeError) as exc:
            errors.append(str(exc))

    openapi_path = ROOT / "openapi" / "openapi.yaml"
    if not openapi_path.exists():
        errors.append("openapi/openapi.yaml: missing")
    else:
        try:
            openapi_document = load_yaml_path(openapi_path)
            if not str(openapi_document.get("openapi", "")).startswith("3.1"):
                errors.append("openapi/openapi.yaml: OpenAPI 3.1 is required")
            validate_refs(openapi_path, openapi_document, errors)
            operation_ids = []
            for path_value in openapi_document.get("paths", {}).values():
                for method, operation in path_value.items():
                    if method in {"get", "post", "put", "patch", "delete", "options", "head", "trace"}:
                        operation_id = operation.get("operationId")
                        if not operation_id:
                            errors.append("openapi/openapi.yaml: every operation requires operationId")
                        else:
                            operation_ids.append(operation_id)
            require_unique(operation_ids, "OpenAPI operation", errors)
        except (AssertionError, yaml.YAMLError) as exc:
            errors.append(str(exc))

    implementation_test_specs = {
        "contract": ROOT / "tests" / "contracts" / "specs" / "matrix.yaml",
        "differential": ROOT / "tests" / "differential" / "specs" / "matrix.yaml",
        "visual": ROOT / "tests" / "visual" / "specs" / "catalog-coverage.yaml",
        "performance": ROOT / "tests" / "performance" / "specs" / "budgets.yaml",
        "operations": ROOT / "tests" / "operations" / "specs" / "recovery-matrix.yaml",
    }
    for label, spec_path in implementation_test_specs.items():
        if not spec_path.exists():
            errors.append(f"{spec_path.relative_to(ROOT)}: missing {label} test specification")
            continue
        try:
            test_spec = load_yaml_path(spec_path)
            if "schema_version" not in test_spec or not (
                test_spec.get("suite_id") or test_spec.get("matrix_id")
            ):
                errors.append(
                    f"{spec_path.relative_to(ROOT)}: schema_version and suite_id/matrix_id required"
                )
        except (AssertionError, yaml.YAMLError) as exc:
            errors.append(str(exc))

    declared = capabilities["normative_catalogs"]
    expected_counts = {
        "base analysis models": (declared["analysis_registry"]["base_analysis_models"], len(base_model_rows)),
        "topic models": (declared["analysis_registry"]["topic_models"], len(topic_rows)),
        "analysis intents": (declared["analysis_registry"]["analysis_intents"], len(intent_rows)),
        "report profiles": (declared["analysis_registry"]["report_profiles"], len(report_rows)),
        "calculations": (declared["calculation_registry"]["total_calculations"], len(calculation_rows)),
        "render views": (declared["render_views"]["total_views"], len(view_rows)),
    }
    for label, (expected, actual) in expected_counts.items():
        if expected != actual:
            errors.append(f"{label}: declared {expected}, found {actual}")

    spec = (DOCS / "v1-development-spec.md").read_text(encoding="utf-8")
    work_package_ids = require_unique(
        re.findall(r"^\| (V1-[A-Z]+-\d{3}) \|", spec, flags=re.MULTILINE),
        "work package",
        errors,
    )
    for row in capability_rows + base_model_rows:
        work_package = row.get("work_package")
        if work_package and work_package not in work_package_ids:
            errors.append(f"{row['id']}: unknown work package {work_package}")

    for markdown_name in [
        "v1-development-spec.md",
        "project-plan.md",
        "algorithm-card-template.md",
        "calculation-result-catalog.md",
    ]:
        fence_count = (DOCS / markdown_name).read_text(encoding="utf-8").count("```")
        if fence_count % 2:
            errors.append(f"{markdown_name}: unbalanced fenced code blocks")

    if errors:
        print("Catalog validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(
        "Catalog validation passed: "
        f"{len(base_model_rows)} base models, {len(topic_rows)} topic models, "
        f"{len(intent_rows)} intents, {len(report_rows)} report profiles, "
        f"{len(calculation_rows)} calculations, {len(view_rows)} views, "
        f"{len(card_rows)} algorithm cards, {len(dataset_rows)} dataset manifests, "
        f"{len(schema_files)} canonical schemas, {len(backlog_rows)} backlog months."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
