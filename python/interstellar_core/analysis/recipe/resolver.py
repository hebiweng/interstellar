"""Deterministic six-entry AnalysisDraft to AnalysisRecipe resolution."""

from __future__ import annotations

from collections import defaultdict, deque
from collections.abc import Mapping, Sequence
from copy import deepcopy
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from types import MappingProxyType
from typing import Any

from .canonical import content_hash
from .errors import (
    DependencyCycleError,
    InvalidDraftError,
    LockedNodeOverrideError,
    RecipeConfirmationError,
    RecipeExpiredError,
    ResourceBudgetExceeded,
)
from .models import (
    ComponentDefinition,
    RecipeOutputs,
    RecipeResolutionPolicy,
    ReuseCandidate,
    SubjectFacts,
)
from .registry import RecipeRegistry

_PRECISION_RANK = {
    "unknown": 0,
    "date": 1,
    "part_of_day": 2,
    "interval": 2,
    "hour": 3,
    "quarter_hour": 4,
    "minute": 5,
    "second": 6,
}
_SELECTOR_TYPES = {
    "analysis_intent_id",
    "topic_model_id",
    "analysis_model_id",
    "technique_id",
    "custom_model_spec",
}
_TIER_RANK = {"optional": 0, "recommended": 1, "required": 2}


def _timestamp(value: datetime) -> str:
    return value.astimezone(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _parse_timestamp(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(UTC)


def _warning(
    code: str,
    message: str,
    *,
    severity: str = "warning",
    path: str | None = None,
    details: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "code": code,
        "message": message,
        "severity": severity,
        "path": path,
        "details": dict(details or {}),
    }


def _freeze(value: Any) -> Any:
    if isinstance(value, Mapping):
        return MappingProxyType({str(key): _freeze(item) for key, item in value.items()})
    if isinstance(value, (list, tuple)):
        return tuple(_freeze(item) for item in value)
    return value


def _thaw(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {key: _thaw(item) for key, item in value.items()}
    if isinstance(value, tuple):
        return [_thaw(item) for item in value]
    return deepcopy(value)


@dataclass(frozen=True, slots=True)
class RecipeDocument:
    """Immutable recipe value; transitions return a new document."""

    _payload: Mapping[str, Any]

    def __init__(self, payload: Mapping[str, Any]) -> None:
        object.__setattr__(self, "_payload", _freeze(deepcopy(dict(payload))))

    @property
    def content_hash(self) -> str:
        return str(self._payload["content_hash"])

    @property
    def status(self) -> str:
        return str(self._payload["status"])

    def to_dict(self) -> dict[str, Any]:
        return _thaw(self._payload)

    def confirm(
        self,
        *,
        now: datetime,
        expected_content_hash: str,
    ) -> RecipeDocument:
        """Confirm the exact resolved content without mutating this instance."""

        if expected_content_hash != self.content_hash:
            raise RecipeConfirmationError(
                "recipe content changed before confirmation",
                path="/content_hash",
                details={
                    "expected": expected_content_hash,
                    "actual": self.content_hash,
                },
            )
        if now.astimezone(UTC) >= _parse_timestamp(str(self._payload["expires_at"])):
            raise RecipeExpiredError(
                "recipe confirmation window has expired",
                path="/expires_at",
            )
        if self.status == "confirmed":
            return self
        if self.status != "resolved":
            raise RecipeConfirmationError(
                f"cannot confirm recipe in {self.status} status",
                path="/status",
            )
        confirmed = self.to_dict()
        confirmed["status"] = "confirmed"
        confirmed["confirmed_at"] = _timestamp(now)
        return RecipeDocument(confirmed)


@dataclass(slots=True)
class _NodeState:
    calculation_id: str
    component: ComponentDefinition
    tier: str
    selected: bool
    locked: bool
    parameters: dict[str, Any]


@dataclass(slots=True)
class _SemanticNode:
    semantic_key: str
    aliases: set[str]
    components: list[ComponentDefinition]
    tier: str
    selected: bool
    locked: bool
    parameters: dict[str, Any]
    dependency_keys: set[str]


class AnalysisRecipeResolver:
    """Resolve product entry choices without running any astronomy engine."""

    def __init__(
        self,
        registry: RecipeRegistry,
        *,
        policy: RecipeResolutionPolicy | None = None,
    ) -> None:
        self._registry = registry
        self._policy = policy or RecipeResolutionPolicy()

    def resolve(
        self,
        draft: Mapping[str, Any],
        *,
        recipe_id: str,
        now: datetime,
    ) -> RecipeDocument:
        now = now.astimezone(UTC)
        self._validate_draft(draft, now=now)
        entry = self._registry.get_entry_point(str(draft["entry_point_id"]))
        selector_type, selector_value = next(iter(dict(draft["selection"]).items()))
        if selector_type not in entry.allowed_selector_types:
            raise InvalidDraftError(
                f"{entry.entry_point_id} does not allow {selector_type}",
                path=f"/selection/{selector_type}",
            )
        selection = self._registry.resolve_selection(selector_type, selector_value)
        role_bindings, subject_facts = self._resolve_subjects(draft)
        missing_roles = sorted(set(selection.required_roles) - set(subject_facts))
        if missing_roles:
            raise InvalidDraftError(
                f"missing required subject roles: {', '.join(missing_roles)}",
                path="/subject_roles",
                details={"missing_roles": missing_roles},
            )
        subject_facts["context"] = self._context_facts(draft)

        states = self._seed_nodes(entry=entry, selection=selection)
        self._apply_overrides(states, draft)
        self._apply_optional_extensions(states, draft)
        self._expand_dependency_closure(states)
        semantic_nodes, alias_to_key = self._deduplicate(states)
        ordered_keys = self._topological_order(semantic_nodes, alias_to_key)

        warnings: list[dict[str, Any]] = []
        recipe_nodes, reusable, cost = self._materialize_nodes(
            semantic_nodes,
            ordered_keys=ordered_keys,
            subject_facts=subject_facts,
            warnings=warnings,
        )
        outputs = self._resolve_outputs(draft, entry.default_outputs, selection.default_outputs)
        self._check_output_reachability(recipe_nodes, outputs, warnings)
        resource_estimate = self._resource_estimate(
            duration_ms=cost[0],
            search_points=cost[1],
            selected_node_count=sum(node["selected"] for node in recipe_nodes),
        )

        rule_packs = self._unique_dicts(selection.rule_packs, identity=("id", "version"))
        datasets = self._unique_dicts(
            selection.dataset_requirements,
            identity=("id", "version"),
        )
        expires_at = now + timedelta(seconds=self._policy.ttl_seconds)
        recipe_content = {
            "recipe_version": self._policy.recipe_version,
            "source_draft_id": draft["draft_id"],
            "source_draft_revision": draft["revision"],
            "entry_point_id": entry.entry_point_id,
            "subject_roles": role_bindings,
            "resolved_topic_models": sorted(set(selection.resolved_topic_models)),
            "resolved_base_models": sorted(set(selection.resolved_base_models)),
            "rule_packs": rule_packs,
            "dataset_requirements": datasets,
            "nodes": recipe_nodes,
            "reuse": reusable,
            "outputs": outputs,
            "warnings": warnings,
            "resource_estimate": resource_estimate,
        }
        hash_content = {
            **recipe_content,
            "source_time_context": deepcopy(draft.get("time_context")),
            "source_locations": deepcopy(draft.get("locations", [])),
        }
        payload = {
            "recipe_id": recipe_id,
            **recipe_content,
            "content_hash": content_hash(hash_content),
            "status": "resolved",
            "created_at": _timestamp(now),
            "expires_at": _timestamp(expires_at),
            "confirmed_at": None,
        }
        return RecipeDocument(payload)

    def _validate_draft(self, draft: Mapping[str, Any], *, now: datetime) -> None:
        required = {
            "draft_id",
            "entry_point_id",
            "selection",
            "subject_roles",
            "allowed_overrides",
            "optional_extensions",
            "revision",
            "status",
        }
        missing = sorted(required - set(draft))
        if missing:
            raise InvalidDraftError(
                f"draft is missing: {', '.join(missing)}",
                details={"missing": missing},
            )
        selection = draft["selection"]
        if not isinstance(selection, Mapping) or len(selection) != 1:
            raise InvalidDraftError(
                "selection must contain exactly one selector",
                path="/selection",
            )
        selector_type = next(iter(selection))
        if selector_type not in _SELECTOR_TYPES:
            raise InvalidDraftError(
                f"unsupported selector: {selector_type}",
                path="/selection",
            )
        if int(draft["revision"]) < 1:
            raise InvalidDraftError("revision must be positive", path="/revision")
        if draft["status"] in {"invalid", "expired"}:
            raise InvalidDraftError(
                f"cannot resolve a draft in {draft['status']} status",
                path="/status",
            )
        if draft.get("expires_at") and now >= _parse_timestamp(str(draft["expires_at"])):
            raise InvalidDraftError("draft has expired", path="/expires_at")

    def _resolve_subjects(
        self,
        draft: Mapping[str, Any],
    ) -> tuple[list[dict[str, Any]], dict[str, SubjectFacts]]:
        role_bindings: list[dict[str, Any]] = []
        facts: dict[str, SubjectFacts] = {}
        for index, raw_binding in enumerate(draft["subject_roles"]):
            binding = deepcopy(dict(raw_binding))
            role = str(binding.get("role", ""))
            if not role or role in facts:
                raise InvalidDraftError(
                    "subject role must be present and unique",
                    path=f"/subject_roles/{index}/role",
                )
            has_version = "subject_version_id" in binding
            has_inline = "inline_subject" in binding
            if has_version == has_inline:
                raise InvalidDraftError(
                    "subject role requires exactly one subject source",
                    path=f"/subject_roles/{index}",
                )
            if has_inline:
                inline = binding["inline_subject"]
                time_spec = inline.get("time_spec") or {}
                facts[role] = SubjectFacts(
                    time_precision=str(time_spec.get("precision", "unknown")),
                    has_resolved_utc=bool(time_spec.get("selected_utc")),
                    has_location=inline.get("location") is not None,
                )
            else:
                facts[role] = self._registry.get_subject_facts(str(binding["subject_version_id"]))
            role_bindings.append(binding)
        role_bindings.sort(key=lambda item: str(item["role"]))
        return role_bindings, facts

    @staticmethod
    def _context_facts(draft: Mapping[str, Any]) -> SubjectFacts:
        time_context = draft.get("time_context") or {}
        reference = time_context.get("reference_time") or {}
        if time_context.get("start") and time_context.get("end"):
            precision = "second"
            resolved = True
        else:
            precision = str(reference.get("precision", "unknown"))
            resolved = bool(reference.get("selected_utc"))
        return SubjectFacts(
            time_precision=precision,
            has_resolved_utc=resolved,
            has_location=bool(draft.get("locations")),
        )

    def _seed_nodes(self, *, entry: Any, selection: Any) -> dict[str, _NodeState]:
        states: dict[str, _NodeState] = {}
        sources = (
            ("required", (*entry.required_components, *selection.required_components)),
            (
                "recommended",
                (*entry.recommended_components, *selection.recommended_components),
            ),
            ("optional", (*entry.optional_components, *selection.optional_components)),
        )
        for tier, identifiers in sources:
            for calculation_id in identifiers:
                self._merge_state(
                    states, str(calculation_id), tier=tier, selected=tier != "optional"
                )
        if not states:
            raise InvalidDraftError("selection expands to no calculations", path="/selection")
        return states

    def _merge_state(
        self,
        states: dict[str, _NodeState],
        calculation_id: str,
        *,
        tier: str,
        selected: bool,
        locked: bool | None = None,
    ) -> _NodeState:
        component = self._registry.get_component(calculation_id)
        existing = states.get(calculation_id)
        if existing is None:
            state = _NodeState(
                calculation_id=calculation_id,
                component=component,
                tier=tier,
                selected=selected,
                locked=tier == "required" if locked is None else locked,
                parameters=dict(component.default_parameters),
            )
            states[calculation_id] = state
            return state
        if _TIER_RANK[tier] > _TIER_RANK[existing.tier]:
            existing.tier = tier
        existing.selected = existing.selected or selected
        existing.locked = existing.locked or tier == "required" or bool(locked)
        return existing

    def _apply_overrides(
        self,
        states: dict[str, _NodeState],
        draft: Mapping[str, Any],
    ) -> None:
        raw = draft.get("allowed_overrides") or {}
        overrides = raw.get("nodes", raw)
        if not isinstance(overrides, Mapping):
            raise InvalidDraftError("node overrides must be an object", path="/allowed_overrides")
        ignored_keys = {"allow_degradations", "deny_degradations", "nodes"}
        for calculation_id, raw_override in sorted(overrides.items()):
            if calculation_id in ignored_keys:
                continue
            if not isinstance(raw_override, Mapping):
                raise InvalidDraftError(
                    "node override must be an object",
                    path=f"/allowed_overrides/{calculation_id}",
                )
            if calculation_id not in states:
                raise InvalidDraftError(
                    f"cannot override a node outside the selected model: {calculation_id}",
                    path=f"/allowed_overrides/{calculation_id}",
                )
            state = states[calculation_id]
            if raw_override.get("selected") is False:
                if state.locked:
                    raise LockedNodeOverrideError(
                        f"required node cannot be deselected: {calculation_id}",
                        path=f"/allowed_overrides/{calculation_id}/selected",
                    )
                state.selected = False
            elif raw_override.get("selected") is True:
                state.selected = True
            replacement = raw_override.get("replace_with")
            if replacement:
                if state.locked:
                    raise LockedNodeOverrideError(
                        f"required node cannot be replaced: {calculation_id}",
                        path=f"/allowed_overrides/{calculation_id}/replace_with",
                    )
                state.selected = False
                self._merge_state(
                    states,
                    str(replacement),
                    tier=state.tier,
                    selected=True,
                    locked=False,
                )
            parameter_overrides = raw_override.get("parameters", {})
            unknown = sorted(set(parameter_overrides) - set(state.component.override_keys))
            if unknown:
                raise InvalidDraftError(
                    f"parameters are not overridable: {', '.join(unknown)}",
                    path=f"/allowed_overrides/{calculation_id}/parameters",
                    details={"unknown_parameters": unknown},
                )
            state.parameters.update(deepcopy(dict(parameter_overrides)))

    def _apply_optional_extensions(
        self,
        states: dict[str, _NodeState],
        draft: Mapping[str, Any],
    ) -> None:
        for calculation_id in sorted(set(draft.get("optional_extensions", []))):
            state = self._merge_state(
                states,
                str(calculation_id),
                tier="optional",
                selected=True,
                locked=False,
            )
            state.selected = True

    def _expand_dependency_closure(self, states: dict[str, _NodeState]) -> None:
        queue = deque(sorted(key for key, state in states.items() if state.selected))
        processed: set[str] = set()
        while queue:
            calculation_id = queue.popleft()
            if calculation_id in processed:
                continue
            processed.add(calculation_id)
            state = states[calculation_id]
            for dependency_id in sorted(set(state.component.dependencies)):
                dependency = self._merge_state(
                    states,
                    dependency_id,
                    tier="required",
                    selected=True,
                    locked=True,
                )
                dependency.selected = True
                dependency.locked = True
                queue.append(dependency_id)

    @staticmethod
    def _semantic_key(state: _NodeState) -> str:
        base = state.component.semantic_key or state.calculation_id
        return f"{base}@{state.component.version}:{content_hash(state.parameters)[7:23]}"

    def _deduplicate(
        self,
        states: Mapping[str, _NodeState],
    ) -> tuple[dict[str, _SemanticNode], dict[str, str]]:
        groups: dict[str, _SemanticNode] = {}
        alias_to_key: dict[str, str] = {}
        for calculation_id in sorted(states):
            state = states[calculation_id]
            key = self._semantic_key(state)
            alias_to_key[calculation_id] = key
            group = groups.get(key)
            if group is None:
                groups[key] = _SemanticNode(
                    semantic_key=key,
                    aliases={calculation_id},
                    components=[state.component],
                    tier=state.tier,
                    selected=state.selected,
                    locked=state.locked,
                    parameters=deepcopy(state.parameters),
                    dependency_keys=set(),
                )
                continue
            group.aliases.add(calculation_id)
            group.components.append(state.component)
            if _TIER_RANK[state.tier] > _TIER_RANK[group.tier]:
                group.tier = state.tier
            group.selected = group.selected or state.selected
            group.locked = group.locked or state.locked
            if state.parameters != group.parameters:
                raise InvalidDraftError(
                    "semantic cache key collision has incompatible parameters",
                    details={"semantic_key": key, "aliases": sorted(group.aliases)},
                )
        for key, group in groups.items():
            if not group.selected:
                continue
            for component in group.components:
                for dependency_id in component.dependencies:
                    dependency_key = alias_to_key[dependency_id]
                    if dependency_key != key:
                        group.dependency_keys.add(dependency_key)
        return groups, alias_to_key

    @staticmethod
    def _topological_order(
        groups: Mapping[str, _SemanticNode],
        alias_to_key: Mapping[str, str],
    ) -> list[str]:
        del alias_to_key
        selected = {key for key, group in groups.items() if group.selected}
        indegree = {key: 0 for key in selected}
        dependants: dict[str, set[str]] = defaultdict(set)
        for key in selected:
            for dependency_key in groups[key].dependency_keys:
                if dependency_key not in selected:
                    raise InvalidDraftError(
                        "selected node has an unselected dependency",
                        details={"node": key, "dependency": dependency_key},
                    )
                indegree[key] += 1
                dependants[dependency_key].add(key)
        ready = sorted(key for key, degree in indegree.items() if degree == 0)
        ordered: list[str] = []
        while ready:
            key = ready.pop(0)
            ordered.append(key)
            for dependant in sorted(dependants.get(key, ())):
                indegree[dependant] -= 1
                if indegree[dependant] == 0:
                    ready.append(dependant)
                    ready.sort()
        if len(ordered) != len(selected):
            cycle_keys = sorted(key for key, degree in indegree.items() if degree > 0)
            aliases = sorted(alias for key in cycle_keys for alias in groups[key].aliases)
            raise DependencyCycleError(
                f"calculation dependency cycle: {', '.join(aliases)}",
                details={"calculation_ids": aliases},
            )
        return [*ordered, *sorted(set(groups) - selected)]

    def _materialize_nodes(
        self,
        groups: Mapping[str, _SemanticNode],
        *,
        ordered_keys: Sequence[str],
        subject_facts: Mapping[str, SubjectFacts],
        warnings: list[dict[str, Any]],
    ) -> tuple[list[dict[str, Any]], list[dict[str, Any]], tuple[int, int]]:
        node_ids = {key: f"node.{content_hash(key)[7:23]}" for key in groups}
        nodes: list[dict[str, Any]] = []
        reuse_by_snapshot: dict[str, set[str]] = defaultdict(set)
        duration_ms = 0
        search_points = 0
        availability_by_key: dict[str, str] = {}
        for key in ordered_keys:
            group = groups[key]
            calculation_id = sorted(group.aliases)[0]
            output_ids = sorted(
                {output for component in group.components for output in component.output_ids}
            )
            blocking: list[dict[str, Any]] = []
            degradation: dict[str, Any] | None = None
            for component in group.components:
                if not component.implementation_available:
                    blocking.append(
                        _warning(
                            "CAPABILITY_NOT_IMPLEMENTED",
                            component.implementation_reason
                            or f"{component.calculation_id} is not implemented",
                            severity="error",
                            path=f"/nodes/{calculation_id}",
                            details={"calculation_id": component.calculation_id},
                        )
                    )
                if not component.license_allowed:
                    blocking.append(
                        _warning(
                            "LICENSE_RESTRICTED",
                            component.license_reason
                            or f"license does not permit {component.calculation_id}",
                            severity="error",
                            path=f"/nodes/{calculation_id}",
                            details={"calculation_id": component.calculation_id},
                        )
                    )
                input_failures = self._input_failures(component, subject_facts)
                if input_failures and component.degradation and not blocking:
                    degradation = {
                        "code": component.degradation.code,
                        "effective_calculation_id": (
                            component.degradation.effective_calculation_id
                        ),
                        "message": component.degradation.message,
                        "missing_requirements": input_failures,
                    }
                    if component.degradation.output_ids:
                        output_ids = sorted(set(component.degradation.output_ids))
                elif input_failures:
                    blocking.extend(input_failures)
            blocked_dependencies = sorted(
                dependency_key
                for dependency_key in group.dependency_keys
                if availability_by_key.get(dependency_key) == "blocked"
            )
            if blocked_dependencies:
                blocking.append(
                    _warning(
                        "DEPENDENCY_BLOCKED",
                        f"a dependency of {calculation_id} is blocked",
                        severity="error",
                        path=f"/nodes/{calculation_id}",
                        details={
                            "dependency_node_ids": [node_ids[item] for item in blocked_dependencies]
                        },
                    )
                )
            if blocking:
                tier = "blocked"
                availability = "blocked"
                selected = False
                warnings.extend(blocking)
            elif degradation:
                tier = group.tier
                availability = "degraded"
                selected = group.selected
                degradation_warning = _warning(
                    "CALCULATION_DEGRADED",
                    str(degradation["message"]),
                    path=f"/nodes/{calculation_id}",
                    details=degradation,
                )
                warnings.append(degradation_warning)
            else:
                tier = group.tier
                availability = "available"
                selected = group.selected
            availability_by_key[key] = availability

            candidate: ReuseCandidate | None = None
            if selected and availability != "blocked":
                candidate = self._registry.find_reuse(key)
                if candidate:
                    reuse_by_snapshot[candidate.snapshot_id].update(candidate.result_paths)
                else:
                    duration_ms += max(
                        (component.duration_ms_p50 for component in group.components),
                        default=0,
                    )
                    search_points += max(
                        (component.search_points for component in group.components),
                        default=0,
                    )
            nodes.append(
                {
                    "node_id": node_ids[key],
                    "calculation_id": calculation_id,
                    "tier": tier,
                    "selected": selected,
                    "locked": group.locked,
                    "availability": availability,
                    "depends_on": sorted(node_ids[item] for item in group.dependency_keys),
                    "parameters": deepcopy(group.parameters),
                    "blocking_reasons": blocking,
                    "degradation": degradation,
                    "output_ids": output_ids,
                }
            )
        reuse = [
            {"snapshot_id": snapshot_id, "result_paths": sorted(paths)}
            for snapshot_id, paths in sorted(reuse_by_snapshot.items())
        ]
        return nodes, reuse, (duration_ms, search_points)

    @staticmethod
    def _input_failures(
        component: ComponentDefinition,
        subject_facts: Mapping[str, SubjectFacts],
    ) -> list[dict[str, Any]]:
        failures: list[dict[str, Any]] = []
        for role, required in sorted(component.required_time_precision.items()):
            actual = subject_facts.get(role, SubjectFacts()).time_precision
            if _PRECISION_RANK.get(actual, -1) < _PRECISION_RANK.get(required, 99):
                failures.append(
                    _warning(
                        "TIME_PRECISION_INSUFFICIENT",
                        f"{component.calculation_id} requires {required} time precision for {role}",
                        severity="error",
                        path="/subject_roles" if role != "context" else "/time_context",
                        details={"role": role, "required": required, "actual": actual},
                    )
                )
        for role in sorted(component.requires_resolved_utc_roles):
            if not subject_facts.get(role, SubjectFacts()).has_resolved_utc:
                failures.append(
                    _warning(
                        "RESOLVED_UTC_REQUIRED",
                        f"{component.calculation_id} requires unambiguous UTC for {role}",
                        severity="error",
                        details={"role": role},
                    )
                )
        for role in sorted(component.requires_location_roles):
            if not subject_facts.get(role, SubjectFacts()).has_location:
                failures.append(
                    _warning(
                        "EXACT_LOCATION_REQUIRED",
                        f"{component.calculation_id} requires a location for {role}",
                        severity="error",
                        path="/subject_roles" if role != "context" else "/locations",
                        details={"role": role},
                    )
                )
        return failures

    @staticmethod
    def _resolve_outputs(
        draft: Mapping[str, Any],
        entry_defaults: RecipeOutputs,
        selection_defaults: RecipeOutputs,
    ) -> dict[str, list[str]]:
        requested = draft.get("requested_outputs") or {}
        return {
            "view_ids": sorted(
                set(
                    requested.get("view_ids")
                    or (*entry_defaults.view_ids, *selection_defaults.view_ids)
                )
            ),
            "report_profile_ids": sorted(
                set(
                    requested.get("report_profile_ids")
                    or (
                        *entry_defaults.report_profile_ids,
                        *selection_defaults.report_profile_ids,
                    )
                )
            ),
            "exports": sorted(
                set(
                    requested.get("exports")
                    or (*entry_defaults.exports, *selection_defaults.exports)
                    or ("json",)
                )
            ),
        }

    def _check_output_reachability(
        self,
        nodes: Sequence[Mapping[str, Any]],
        outputs: Mapping[str, Sequence[str]],
        warnings: list[dict[str, Any]],
    ) -> None:
        reachable_outputs = {
            output_id
            for node in nodes
            if node["selected"] and node["availability"] != "blocked"
            for output_id in node.get("output_ids", [])
        }
        calculation_status = {
            str(node["calculation_id"]): bool(
                node["selected"] and node["availability"] != "blocked"
            )
            for node in nodes
        }
        for family in ("view_ids", "report_profile_ids"):
            for output_id in outputs[family]:
                requirements = self._registry.get_output_requirements(output_id)
                if requirements is None:
                    reachable = output_id in reachable_outputs
                    missing = [] if reachable else [output_id]
                else:
                    missing = [
                        calculation_id
                        for calculation_id in requirements
                        if not calculation_status.get(calculation_id, False)
                    ]
                    reachable = not missing
                if not reachable:
                    warnings.append(
                        _warning(
                            "OUTPUT_PARTIALLY_UNAVAILABLE",
                            f"requested output cannot be fully produced: {output_id}",
                            path=f"/outputs/{family}",
                            details={"output_id": output_id, "missing": missing},
                        )
                    )

    def _resource_estimate(
        self,
        *,
        duration_ms: int,
        search_points: int,
        selected_node_count: int,
    ) -> dict[str, Any]:
        if (
            duration_ms > self._policy.hard_duration_ms
            or search_points > self._policy.hard_search_points
        ):
            raise ResourceBudgetExceeded(
                "analysis recipe exceeds the active resource budget",
                details={
                    "duration_ms_p50": duration_ms,
                    "search_points": search_points,
                    "hard_duration_ms": self._policy.hard_duration_ms,
                    "hard_search_points": self._policy.hard_search_points,
                },
            )
        async_required = (
            duration_ms > self._policy.sync_duration_ms
            or search_points > self._policy.sync_search_points
        )
        if selected_node_count >= self._policy.batch_node_count:
            resource_class = "batch"
            async_required = True
        elif duration_ms <= 500 and search_points <= 100:
            resource_class = "small"
        elif duration_ms <= 5_000 and search_points <= 10_000:
            resource_class = "medium"
        else:
            resource_class = "large"
        return {
            "class": resource_class,
            "duration_ms_p50": duration_ms,
            "search_points": search_points,
            "execution_mode": "async" if async_required else "sync",
        }

    @staticmethod
    def _unique_dicts(
        items: Sequence[Mapping[str, Any]],
        *,
        identity: tuple[str, ...],
    ) -> list[dict[str, Any]]:
        unique: dict[tuple[Any, ...], dict[str, Any]] = {}
        for item in items:
            value = deepcopy(dict(item))
            unique[tuple(value.get(key) for key in identity)] = value
        return [unique[key] for key in sorted(unique)]


def confirm_recipe(
    recipe: RecipeDocument,
    *,
    now: datetime,
    expected_content_hash: str,
) -> RecipeDocument:
    """Functional confirmation API used by application and API adapters."""

    return recipe.confirm(now=now, expected_content_hash=expected_content_hash)
