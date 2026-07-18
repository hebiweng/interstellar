"""Pure M1 recipe preflight and non-computing snapshot scaffolding.

This module deliberately does not calculate astrology.  It turns a versioned
analysis-model preset into an auditable execution plan and can materialize a
canonical *partial* snapshot that makes the missing calculation explicit.
Later milestones replace the not-requested manifest entries with real engine
results without changing the provenance envelope.
"""

from __future__ import annotations

import hashlib
import json
from collections.abc import Callable, Mapping, Sequence
from copy import deepcopy
from datetime import UTC, datetime
from typing import Any

_PRECISION_RANK = {
    "unknown": 0,
    "date": 1,
    "part_of_day": 2,
    "hour": 3,
    "quarter_hour": 4,
    "minute": 5,
    "second": 6,
}


def canonical_hash(value: Any) -> str:
    """Return the repository content-hash form for canonical JSON data."""

    encoded = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return f"sha256:{hashlib.sha256(encoded).hexdigest()}"


def _timestamp(now: datetime) -> str:
    normalized = now.astimezone(UTC).replace(microsecond=0)
    return normalized.isoformat().replace("+00:00", "Z")


def _warning(code: str, message: str, *, path: str | None = None) -> dict[str, Any]:
    return {
        "code": code,
        "message": message,
        "severity": "warning",
        "path": path,
        "details": {},
    }


def _precision_satisfies(actual: str, required: str) -> bool:
    return _PRECISION_RANK.get(actual, -1) >= _PRECISION_RANK.get(required, 99)


def resolve_analysis_recipe(
    *,
    recipe_id: str,
    source_draft_id: str,
    source_draft_revision: int,
    entry_point_id: str,
    subject_roles: Sequence[Mapping[str, Any]],
    model_preset: Mapping[str, Any],
    available_components: set[str],
    time_precision: str,
    has_exact_location: bool,
    datasets: Sequence[Mapping[str, Any]],
    requested_view_ids: Sequence[str] | None = None,
    requested_exports: Sequence[str] | None = None,
    now: datetime,
    expires_at: datetime,
) -> dict[str, Any]:
    """Resolve one model preset into a canonical, non-executing recipe.

    Required components remain selected and locked even when blocked. Optional
    components are visible but initially unselected. This is the M1 contract
    for the future resolver; it prevents the UI or API from silently omitting
    unavailable work.
    """

    model_id = str(model_preset["id"])
    defaults = dict(model_preset.get("defaults", {}))
    required_precision = str(defaults.get("minimum_time_precision", "date"))
    exact_location_required = bool(defaults.get("exact_location_required", False))
    precision_ok = _precision_satisfies(time_precision, required_precision)
    location_ok = has_exact_location or not exact_location_required

    nodes: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []

    for tier, components in (
        ("required", model_preset.get("required_components", [])),
        ("optional", model_preset.get("optional_components", [])),
    ):
        for component_id in components:
            component_id = str(component_id)
            reasons: list[dict[str, Any]] = []
            if component_id not in available_components:
                reasons.append(
                    _warning(
                        "COMPONENT_NOT_IMPLEMENTED",
                        f"{component_id} is not implemented in the active release.",
                        path=f"/nodes/{component_id}",
                    )
                )
            if tier == "required" and not precision_ok:
                reasons.append(
                    _warning(
                        "TIME_PRECISION_INSUFFICIENT",
                        f"{model_id} requires {required_precision} time precision.",
                        path="/subject_roles",
                    )
                )
            if tier == "required" and not location_ok:
                reasons.append(
                    _warning(
                        "EXACT_LOCATION_REQUIRED",
                        f"{model_id} requires an exact location.",
                        path="/subject_roles",
                    )
                )

            availability = "blocked" if reasons else "available"
            selected = tier == "required"
            nodes.append(
                {
                    "node_id": f"{recipe_id}:{component_id}",
                    "calculation_id": component_id,
                    "tier": "blocked" if reasons and tier == "required" else tier,
                    "selected": selected,
                    "locked": tier == "required",
                    "availability": availability,
                    "depends_on": [],
                    "parameters": deepcopy(defaults),
                    "blocking_reasons": reasons,
                    "degradation": None,
                    "output_ids": [],
                }
            )
            warnings.extend(reasons)

    default_views = [
        *model_preset.get("primary_outputs", []),
        *model_preset.get("secondary_outputs", []),
    ]
    view_ids = list(dict.fromkeys(requested_view_ids or default_views))
    exports = list(dict.fromkeys(requested_exports or ["json"]))
    dataset_requirements = [deepcopy(dict(item)) for item in datasets]
    semantic_content = {
        "entry_point_id": entry_point_id,
        "source_draft_id": source_draft_id,
        "source_draft_revision": source_draft_revision,
        "subject_roles": [deepcopy(dict(role)) for role in subject_roles],
        "model_id": model_id,
        "rule_pack_id": model_preset.get("rule_pack_id"),
        "nodes": nodes,
        "datasets": dataset_requirements,
        "outputs": {"view_ids": view_ids, "exports": exports},
    }
    content_hash = canonical_hash(semantic_content)

    return {
        "recipe_id": recipe_id,
        "recipe_version": 1,
        "source_draft_id": source_draft_id,
        "source_draft_revision": source_draft_revision,
        "content_hash": content_hash,
        "entry_point_id": entry_point_id,
        "subject_roles": semantic_content["subject_roles"],
        "resolved_topic_models": [],
        "resolved_base_models": [model_id],
        "rule_packs": [
            {
                "id": str(model_preset["rule_pack_id"]),
                "version": "1",
                "content_hash": canonical_hash(model_preset),
            }
        ],
        "dataset_requirements": dataset_requirements,
        "nodes": nodes,
        "reuse": [],
        "outputs": {
            "view_ids": view_ids,
            "report_profile_ids": [str(model_preset["report_profile_id"])],
            "exports": exports,
        },
        "warnings": warnings,
        "resource_estimate": {
            "class": "small",
            "duration_ms_p50": 0,
            "search_points": 0,
            "execution_mode": "sync",
        },
        "status": "resolved",
        "created_at": _timestamp(now),
        "expires_at": _timestamp(expires_at),
        "confirmed_at": None,
    }


def create_noncomputing_snapshot(
    *,
    snapshot_id: str,
    recipe: Mapping[str, Any],
    normalized_input: Mapping[str, Any],
    datasets: Sequence[Mapping[str, Any]],
    now: datetime,
    engine_version: str,
) -> dict[str, Any]:
    """Create an honest M1 snapshot envelope without astrology results."""

    engine = {"name": "interstellar-core", "version": engine_version, "content_hash": None}
    input_fingerprint = canonical_hash(normalized_input)
    rule_pack_hash = canonical_hash(recipe.get("rule_packs", []))
    manifest = []
    for node in recipe.get("nodes", []):
        blocked = node.get("availability") == "blocked"
        manifest.append(
            {
                "output_id": f"manifest.{node['calculation_id']}",
                "status": "blocked" if blocked else "not_requested",
                "calculation_id": node["calculation_id"],
                "result_pointer": None,
                "maturity": "experimental",
                "view_ids": [],
                "table_ids": [],
                "export_formats": [],
                "recommended_primary_view_id": None,
                "missing_inputs": [
                    reason["code"] for reason in node.get("blocking_reasons", [])
                ],
                "warnings": deepcopy(node.get("blocking_reasons", [])),
                "algorithm_cards": [],
                "reproducibility": {
                    "engine": engine,
                    "datasets": [deepcopy(dict(item)) for item in datasets],
                    "rule_pack_hash": rule_pack_hash,
                    "input_fingerprint": input_fingerprint,
                },
            }
        )

    warning = _warning(
        "M1_CALCULATION_NOT_EXECUTED",
        "This snapshot records normalized input and preflight only; no astrology calculation ran.",
    )
    request = {
        "recipe_id": recipe["recipe_id"],
        "recipe_content_hash": recipe["content_hash"],
        "outputs": ["snapshot"],
        "report_requests": [],
    }
    return {
        "id": snapshot_id,
        "schema_version": "1.0.0",
        "status": "partial",
        "request": request,
        "normalized_input": deepcopy(dict(normalized_input)),
        "input_fingerprint": input_fingerprint,
        "engine": engine,
        "adapters": [],
        "datasets": [deepcopy(dict(item)) for item in datasets],
        "analysis_model": {
            "id": recipe["resolved_base_models"][0],
            "version": "1",
            "content_hash": recipe["rule_packs"][0]["content_hash"],
            "expanded_components": [node["calculation_id"] for node in recipe["nodes"]],
            "overrides": {},
            "degradations": deepcopy(recipe["warnings"]),
        },
        "recipe": deepcopy(dict(recipe)),
        "rule_pack_hash": rule_pack_hash,
        "maturity": "experimental",
        "result": {
            "astronomical_context": {},
            "charts": [],
            "points": [],
            "houses": [],
            "aspects": [],
            "distributions": [],
            "patterns": [],
            "dignities": [],
            "receptions": [],
            "lots": [],
            "midpoints": [],
            "directions": [],
            "returns": [],
            "periods": [],
            "events": [],
            "relationships": [],
            "geography": [],
            "mundane": [],
            "topic_results": [],
            "evidence": [],
            "output_manifest": manifest,
        },
        "warnings": [warning, *deepcopy(recipe["warnings"])],
        "supersedes_id": None,
        "created_at": _timestamp(now),
    }


IdFactory = Callable[[], str]
