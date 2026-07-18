from __future__ import annotations

from copy import deepcopy
from datetime import UTC, datetime, timedelta

import pytest

from interstellar_core.analysis.recipe import (
    AnalysisRecipeResolver,
    ComponentDefinition,
    DegradationDefinition,
    DependencyCycleError,
    EntryPointDefinition,
    InMemoryRecipeRegistry,
    InvalidDraftError,
    LockedNodeOverrideError,
    RecipeConfirmationError,
    RecipeExpiredError,
    RecipeOutputs,
    RecipeResolutionPolicy,
    ResourceBudgetExceeded,
    ReuseCandidate,
    SelectionDefinition,
    UnknownRegistryItemError,
    canonical_json,
    confirm_recipe,
    content_hash,
)

NOW = datetime(2026, 7, 18, 2, 30, tzinfo=UTC)
ENTRY_POINTS = (
    "new_calculation",
    "purpose_guided",
    "topic_library",
    "technique_library",
    "model_library",
    "research_workspace",
)
SELECTOR_TYPES = frozenset(
    {
        "analysis_intent_id",
        "topic_model_id",
        "analysis_model_id",
        "technique_id",
        "custom_model_spec",
    }
)


def inline_subject(
    *,
    precision: str = "minute",
    selected_utc: str | None = "1990-01-01T04:00:00Z",
    with_location: bool = True,
) -> dict:
    time_spec = {
        "calendar": "gregorian",
        "local_value": "1990-01-01T12:00:00",
        "precision": precision,
        "utc_candidates": [selected_utc] if selected_utc else [],
        "selected_utc": selected_utc,
        "confidence": "high",
        "source": {"kind": "user"},
        "warnings": [],
    }
    return {
        "kind": "person",
        "display_name": "测试对象",
        "time_spec": time_spec,
        "location": (
            {
                "name": "Shanghai",
                "latitude": 31.2304,
                "longitude": 121.4737,
                "timezone_id": "Asia/Shanghai",
                "source": "fixture",
            }
            if with_location
            else None
        ),
        "attributes": {},
        "source": {"kind": "user"},
    }


def draft(
    *,
    entry_point_id: str = "new_calculation",
    selection: dict | None = None,
    subject: dict | None = None,
    overrides: dict | None = None,
    optional_extensions: list[str] | None = None,
    requested_outputs: dict | None = None,
) -> dict:
    value = {
        "draft_id": "draft.1",
        "entry_point_id": entry_point_id,
        "selection": selection or {"analysis_model_id": "model.natal"},
        "subject_roles": [
            {"role": "primary", "inline_subject": subject or inline_subject()}
        ],
        "allowed_overrides": overrides or {},
        "optional_extensions": optional_extensions or [],
        "revision": 1,
        "status": "ready",
    }
    if requested_outputs is not None:
        value["requested_outputs"] = requested_outputs
    return value


def base_components() -> tuple[ComponentDefinition, ...]:
    return (
        ComponentDefinition(
            "calc.positions",
            output_ids=("view.positions",),
            duration_ms_p50=120,
        ),
        ComponentDefinition(
            "calc.houses",
            dependencies=("calc.positions",),
            required_time_precision={"primary": "minute"},
            requires_resolved_utc_roles=frozenset({"primary"}),
            requires_location_roles=frozenset({"primary"}),
            degradation=DegradationDefinition(
                code="NO_TIME_HOUSELESS_CHART",
                effective_calculation_id="calc.houseless",
                message="宫位不可用，显式降级为无时间星盘",
                output_ids=("view.wheel.houseless",),
            ),
            output_ids=("view.wheel",),
            duration_ms_p50=80,
        ),
        ComponentDefinition(
            "calc.aspects",
            dependencies=("calc.positions",),
            default_parameters={"orb_profile": "modern.v1"},
            override_keys=frozenset({"orb_profile"}),
            output_ids=("view.aspect_grid",),
            duration_ms_p50=100,
        ),
        ComponentDefinition(
            "calc.distributions",
            dependencies=("calc.positions",),
            output_ids=("view.distributions",),
            duration_ms_p50=40,
        ),
        ComponentDefinition(
            "calc.fixed_stars",
            dependencies=("calc.positions",),
            output_ids=("view.fixed_stars",),
            duration_ms_p50=500,
        ),
    )


def registry(
    *,
    components: tuple[ComponentDefinition, ...] | None = None,
    reuse: tuple[ReuseCandidate, ...] = (),
    output_requirements: dict | None = None,
) -> InMemoryRecipeRegistry:
    selection = SelectionDefinition(
        selection_id="model.natal",
        selector_type="analysis_model_id",
        required_components=("calc.houses", "calc.aspects"),
        recommended_components=("calc.distributions",),
        optional_components=("calc.fixed_stars",),
        required_roles=("primary",),
        resolved_topic_models=("topic.self",),
        resolved_base_models=("model.natal",),
        rule_packs=(
            {
                "id": "rules.modern",
                "version": "1.0.0",
                "content_hash": "sha256:" + "a" * 64,
            },
        ),
        dataset_requirements=(
            {
                "id": "swiss-ephemeris",
                "version": "2.10.03",
                "checksum": "sha256:fixture",
                "license": "AGPL-3.0",
                "source_uri": "https://example.test/swe",
            },
        ),
        default_outputs=RecipeOutputs(
            view_ids=("view.wheel", "view.aspect_grid"),
            report_profile_ids=("report.professional",),
            exports=("json", "svg"),
        ),
    )
    return InMemoryRecipeRegistry(
        entry_points=tuple(
            EntryPointDefinition(entry, SELECTOR_TYPES) for entry in ENTRY_POINTS
        ),
        selections=(selection,),
        components=components or base_components(),
        reuse_candidates=reuse,
        output_requirements=output_requirements
        or {
            "view.wheel": ("calc.houses",),
            "view.aspect_grid": ("calc.aspects",),
            "report.professional": (
                "calc.houses",
                "calc.aspects",
                "calc.distributions",
            ),
        },
    )


def resolve(value: dict, *, active_registry=None, policy=None, recipe_id="recipe.1"):
    return AnalysisRecipeResolver(active_registry or registry(), policy=policy).resolve(
        value, recipe_id=recipe_id, now=NOW
    )


def node_by_calculation(recipe: dict, calculation_id: str) -> dict:
    return next(
        node for node in recipe["nodes"] if node["calculation_id"] == calculation_id
    )


def test_six_entry_points_resolve_to_the_same_execution_plan() -> None:
    plans = []
    for entry_point_id in ENTRY_POINTS:
        payload = resolve(draft(entry_point_id=entry_point_id)).to_dict()
        plans.append(
            (
                [
                    (
                        node["calculation_id"],
                        node["tier"],
                        node["selected"],
                        node["depends_on"],
                    )
                    for node in payload["nodes"]
                ],
                payload["outputs"],
            )
        )
    assert all(plan == plans[0] for plan in plans)


def test_recipe_shape_only_contains_canonical_contract_properties() -> None:
    payload = resolve(draft()).to_dict()
    allowed = {
        "recipe_id",
        "recipe_version",
        "source_draft_id",
        "source_draft_revision",
        "content_hash",
        "entry_point_id",
        "subject_roles",
        "resolved_topic_models",
        "resolved_base_models",
        "rule_packs",
        "dataset_requirements",
        "nodes",
        "reuse",
        "outputs",
        "warnings",
        "resource_estimate",
        "status",
        "created_at",
        "expires_at",
        "confirmed_at",
    }
    assert set(payload) == allowed


def test_canonical_json_uses_jcs_number_and_unicode_rules() -> None:
    encoded = canonical_json(
        {"b": 1.0, "a": "é", "tiny": 1e-7, "micro": 1e-6, "huge": 1e20}
    )
    assert encoded == (
        b'{"a":"\xc3\xa9","b":1,"huge":100000000000000000000,'
        b'"micro":0.000001,"tiny":1e-7}'
    )
    with pytest.raises(ValueError):
        canonical_json({"invalid": float("nan")})


def test_required_recommended_and_optional_tiers_are_explicit() -> None:
    payload = resolve(draft()).to_dict()

    positions = node_by_calculation(payload, "calc.positions")
    distributions = node_by_calculation(payload, "calc.distributions")
    fixed_stars = node_by_calculation(payload, "calc.fixed_stars")

    assert positions["tier"] == "required"
    assert positions["locked"] is True
    assert distributions["tier"] == "recommended"
    assert distributions["selected"] is True
    assert fixed_stars["tier"] == "optional"
    assert fixed_stars["selected"] is False


def test_recommended_override_and_explicit_optional_extension() -> None:
    payload = resolve(
        draft(
            overrides={
                "nodes": {
                    "calc.distributions": {"selected": False},
                    "calc.aspects": {"parameters": {"orb_profile": "strict.v2"}},
                }
            },
            optional_extensions=["calc.fixed_stars"],
        )
    ).to_dict()

    assert node_by_calculation(payload, "calc.distributions")["selected"] is False
    assert node_by_calculation(payload, "calc.fixed_stars")["selected"] is True
    assert node_by_calculation(payload, "calc.aspects")["parameters"] == {
        "orb_profile": "strict.v2"
    }


def test_required_node_cannot_be_removed_or_replaced() -> None:
    with pytest.raises(LockedNodeOverrideError):
        resolve(draft(overrides={"nodes": {"calc.houses": {"selected": False}}}))
    with pytest.raises(LockedNodeOverrideError):
        resolve(
            draft(
                overrides={
                    "nodes": {"calc.houses": {"replace_with": "calc.fixed_stars"}}
                }
            )
        )


def test_dependency_dag_is_topological_and_semantically_deduplicated() -> None:
    components = (
        ComponentDefinition("calc.positions", semantic_key="semantic.positions"),
        ComponentDefinition("calc.positions.alias", semantic_key="semantic.positions"),
        ComponentDefinition(
            "calc.result",
            dependencies=("calc.positions", "calc.positions.alias"),
        ),
    )
    active_registry = InMemoryRecipeRegistry(
        entry_points=(EntryPointDefinition("new_calculation", SELECTOR_TYPES),),
        selections=(
            SelectionDefinition(
                selection_id="model.natal",
                selector_type="analysis_model_id",
                required_components=("calc.result",),
            ),
        ),
        components=components,
    )
    payload = resolve(draft(), active_registry=active_registry).to_dict()

    assert [node["calculation_id"] for node in payload["nodes"]] == [
        "calc.positions",
        "calc.result",
    ]
    assert len(node_by_calculation(payload, "calc.result")["depends_on"]) == 1


def test_kahn_cycle_detection_reports_all_cycle_members() -> None:
    components = (
        ComponentDefinition("calc.a", dependencies=("calc.b",)),
        ComponentDefinition("calc.b", dependencies=("calc.a",)),
    )
    active_registry = InMemoryRecipeRegistry(
        entry_points=(EntryPointDefinition("new_calculation", SELECTOR_TYPES),),
        selections=(
            SelectionDefinition(
                selection_id="model.natal",
                selector_type="analysis_model_id",
                required_components=("calc.a",),
            ),
        ),
        components=components,
    )

    with pytest.raises(DependencyCycleError) as caught:
        resolve(draft(), active_registry=active_registry)
    assert caught.value.details["calculation_ids"] == ["calc.a", "calc.b"]


def test_unknown_entry_selection_component_and_subject_are_typed_errors() -> None:
    with pytest.raises(UnknownRegistryItemError):
        resolve(draft(entry_point_id="missing"))
    with pytest.raises(UnknownRegistryItemError):
        resolve(draft(selection={"analysis_model_id": "missing"}))

    value = draft()
    value["subject_roles"] = [
        {"role": "primary", "subject_version_id": "subject-version.missing"}
    ]
    with pytest.raises(UnknownRegistryItemError):
        resolve(value)


def test_time_and_location_failure_uses_declared_degradation() -> None:
    payload = resolve(
        draft(
            subject=inline_subject(
                precision="date", selected_utc=None, with_location=False
            )
        )
    ).to_dict()
    houses = node_by_calculation(payload, "calc.houses")

    assert houses["availability"] == "degraded"
    assert houses["selected"] is True
    assert houses["degradation"]["effective_calculation_id"] == "calc.houseless"
    assert houses["output_ids"] == ["view.wheel.houseless"]
    assert any(
        warning["code"] == "CALCULATION_DEGRADED" for warning in payload["warnings"]
    )


def test_missing_input_without_fallback_blocks_node_and_dependants() -> None:
    components = (
        ComponentDefinition(
            "calc.location",
            requires_location_roles=frozenset({"primary"}),
        ),
        ComponentDefinition("calc.downstream", dependencies=("calc.location",)),
    )
    active_registry = InMemoryRecipeRegistry(
        entry_points=(EntryPointDefinition("new_calculation", SELECTOR_TYPES),),
        selections=(
            SelectionDefinition(
                selection_id="model.natal",
                selector_type="analysis_model_id",
                required_components=("calc.downstream",),
            ),
        ),
        components=components,
    )
    payload = resolve(
        draft(subject=inline_subject(with_location=False)),
        active_registry=active_registry,
    ).to_dict()

    assert node_by_calculation(payload, "calc.location")["tier"] == "blocked"
    downstream = node_by_calculation(payload, "calc.downstream")
    assert downstream["availability"] == "blocked"
    assert downstream["selected"] is False
    assert downstream["blocking_reasons"][0]["code"] == "DEPENDENCY_BLOCKED"


def test_license_restriction_is_visible_and_never_executes() -> None:
    components = (
        *base_components(),
        ComponentDefinition(
            "calc.commercial",
            license_allowed=False,
            license_reason="commercial dataset is not enabled",
        ),
    )
    active_registry = registry(components=components)
    payload = resolve(
        draft(optional_extensions=["calc.commercial"]),
        active_registry=active_registry,
    ).to_dict()
    node = node_by_calculation(payload, "calc.commercial")

    assert node["tier"] == "blocked"
    assert node["availability"] == "blocked"
    assert node["selected"] is False
    assert node["blocking_reasons"][0]["code"] == "LICENSE_RESTRICTED"


def test_unimplemented_capability_is_not_misreported_as_a_license_failure() -> None:
    components = (
        *base_components(),
        ComponentDefinition(
            "calc.future",
            implementation_available=False,
            implementation_reason="scheduled for M8",
            license_allowed=True,
        ),
    )
    payload = resolve(
        draft(optional_extensions=["calc.future"]),
        active_registry=registry(components=components),
    ).to_dict()
    node = node_by_calculation(payload, "calc.future")

    assert node["tier"] == "blocked"
    assert node["selected"] is False
    assert [reason["code"] for reason in node["blocking_reasons"]] == [
        "CAPABILITY_NOT_IMPLEMENTED"
    ]
    assert not any(
        warning["code"] == "LICENSE_RESTRICTED" for warning in payload["warnings"]
    )


def test_partial_requested_output_is_retained_with_a_warning() -> None:
    components = (
        *base_components(),
        ComponentDefinition(
            "calc.restricted",
            license_allowed=False,
        ),
    )
    active_registry = registry(
        components=components,
        output_requirements={"view.restricted": ("calc.restricted",)},
    )
    payload = resolve(
        draft(
            optional_extensions=["calc.restricted"],
            requested_outputs={
                "view_ids": ["view.restricted"],
                "report_profile_ids": [],
                "exports": ["json"],
            },
        ),
        active_registry=active_registry,
    ).to_dict()

    assert payload["outputs"]["view_ids"] == ["view.restricted"]
    warning = next(
        item
        for item in payload["warnings"]
        if item["code"] == "OUTPUT_PARTIALLY_UNAVAILABLE"
    )
    assert warning["details"]["missing"] == ["calc.restricted"]


def test_reusable_snapshot_is_merged_and_removed_from_cost() -> None:
    key = f"calc.positions@1:{content_hash({})[7:23]}"
    active_registry = registry(
        reuse=(ReuseCandidate(key, "snapshot.1", ("/result/positions",)),)
    )
    without_reuse = resolve(draft()).to_dict()
    with_reuse = resolve(draft(), active_registry=active_registry).to_dict()

    assert with_reuse["reuse"] == [
        {"snapshot_id": "snapshot.1", "result_paths": ["/result/positions"]}
    ]
    assert (
        with_reuse["resource_estimate"]["duration_ms_p50"]
        == without_reuse["resource_estimate"]["duration_ms_p50"] - 120
    )


def test_resource_policy_selects_async_and_rejects_hard_overflow() -> None:
    expensive = ComponentDefinition(
        "calc.expensive", duration_ms_p50=2_500, search_points=2_000
    )
    active_registry = InMemoryRecipeRegistry(
        entry_points=(EntryPointDefinition("new_calculation", SELECTOR_TYPES),),
        selections=(
            SelectionDefinition(
                selection_id="model.natal",
                selector_type="analysis_model_id",
                required_components=("calc.expensive",),
            ),
        ),
        components=(expensive,),
    )
    payload = resolve(draft(), active_registry=active_registry).to_dict()
    assert payload["resource_estimate"]["execution_mode"] == "async"

    strict = RecipeResolutionPolicy(hard_duration_ms=2_000, sync_duration_ms=500)
    with pytest.raises(ResourceBudgetExceeded):
        resolve(draft(), active_registry=active_registry, policy=strict)


def test_content_identity_ignores_recipe_id_and_resolution_time() -> None:
    resolver = AnalysisRecipeResolver(registry())
    first = resolver.resolve(draft(), recipe_id="recipe.1", now=NOW)
    second = resolver.resolve(
        draft(), recipe_id="recipe.2", now=NOW + timedelta(seconds=20)
    )

    assert first.content_hash == second.content_hash
    changed = deepcopy(draft())
    changed["revision"] = 2
    third = resolver.resolve(changed, recipe_id="recipe.3", now=NOW)
    assert third.content_hash != first.content_hash


def test_confirmation_is_hash_guarded_immutable_and_expiring() -> None:
    recipe = resolve(draft())
    original = recipe.to_dict()
    confirmed = confirm_recipe(
        recipe,
        now=NOW + timedelta(minutes=1),
        expected_content_hash=recipe.content_hash,
    )

    assert recipe.status == "resolved"
    assert recipe.to_dict() == original
    assert confirmed.status == "confirmed"
    assert confirmed.content_hash == recipe.content_hash
    assert confirmed.to_dict()["confirmed_at"] == "2026-07-18T02:31:00Z"
    assert (
        confirmed.confirm(
            now=NOW + timedelta(minutes=2), expected_content_hash=recipe.content_hash
        )
        is confirmed
    )

    with pytest.raises(RecipeConfirmationError):
        recipe.confirm(now=NOW, expected_content_hash="sha256:" + "f" * 64)
    with pytest.raises(RecipeExpiredError):
        recipe.confirm(
            now=NOW + timedelta(minutes=15),
            expected_content_hash=recipe.content_hash,
        )


def test_custom_model_spec_uses_the_same_pipeline() -> None:
    custom = {
        "id": "custom.focus",
        "required_components": ["calc.aspects"],
        "optional_components": ["calc.fixed_stars"],
        "required_roles": ["primary"],
        "default_outputs": {"view_ids": ["view.aspect_grid"], "exports": ["json"]},
    }
    payload = resolve(draft(selection={"custom_model_spec": custom})).to_dict()

    assert payload["resolved_base_models"] == ["custom.focus"]
    assert node_by_calculation(payload, "calc.positions")["locked"] is True
    assert node_by_calculation(payload, "calc.fixed_stars")["selected"] is False


def test_role_validation_happens_before_node_resolution() -> None:
    value = draft()
    value["subject_roles"][0]["role"] = "partner"
    with pytest.raises(InvalidDraftError) as caught:
        resolve(value)
    assert caught.value.details["missing_roles"] == ["primary"]
