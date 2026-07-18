#!/usr/bin/env python3
"""Validate Interstellar's normative planning catalogs before build or review."""

from __future__ import annotations

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
        f"{len(calculation_rows)} calculations, {len(view_rows)} views."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
