"""Strict, traceable orb-override resolution.

The astronomical aspect angle and the product rule that decides whether that
angle is close enough are deliberately separate.  This module models the
latter as an immutable rule set with one documented precedence chain::

    point pair > point class > aspect > chart context/global > profile preset

Point pairs are unordered.  Point classes are single labels and match when
either endpoint has that label.  If two different point-class rules match the
same pair, resolution fails instead of silently choosing one; callers can
remove the ambiguity with an exact point-pair override.
"""

from __future__ import annotations

import re
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from enum import StrEnum
from math import isfinite
from typing import Any

from .models import AspectContext

_IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]*$")
_ALLOWED_COMMON_KEYS = frozenset({"id", "scope", "orb_deg", "source"})


def _require_identifier(value: str, *, field: str) -> str:
    if not isinstance(value, str) or not value or len(value) > 160:
        raise ValueError(f"{field} must be a non-empty identifier of at most 160 characters")
    if _IDENTIFIER.fullmatch(value) is None:
        raise ValueError(f"invalid {field}: {value!r}")
    return value


def _require_orb(value: Any) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError("orb_deg must be a number")
    orb = float(value)
    if not isfinite(orb) or not 0 <= orb <= 180:
        raise ValueError("orb_deg must be finite and within [0, 180]")
    return orb


class OrbOverrideScope(StrEnum):
    CHART_CONTEXT = "chart_context"
    ASPECT = "aspect"
    POINT_CLASS = "point_class"
    POINT_PAIR = "point_pair"


@dataclass(frozen=True, slots=True)
class OrbOverrideRule:
    """One validated override rule.

    ``context=None`` on a chart-context rule is the global fallback.  Every
    other scope accepts exactly its own selector and no unrelated selector.
    """

    id: str
    scope: OrbOverrideScope
    orb_deg: float
    source: str
    context: AspectContext | None = None
    aspect_id: str | None = None
    point_class: str | None = None
    point_a: str | None = None
    point_b: str | None = None

    def __post_init__(self) -> None:
        _require_identifier(self.id, field="orb override id")
        if not isinstance(self.scope, OrbOverrideScope):
            raise ValueError("orb override scope must be an OrbOverrideScope")
        _require_orb(self.orb_deg)
        if not isinstance(self.source, str) or not self.source.strip():
            raise ValueError("orb override source is required")

        selectors = {
            "context": self.context is not None,
            "aspect_id": self.aspect_id is not None,
            "point_class": self.point_class is not None,
            "point_pair": self.point_a is not None or self.point_b is not None,
        }
        if self.scope is OrbOverrideScope.CHART_CONTEXT:
            if self.context is not None and not isinstance(self.context, AspectContext):
                raise ValueError("context must be an AspectContext")
            unexpected = (
                selectors["aspect_id"] or selectors["point_class"] or selectors["point_pair"]
            )
            if unexpected:
                raise ValueError("chart_context override cannot include aspect or point selectors")
        elif self.scope is OrbOverrideScope.ASPECT:
            if self.aspect_id is None or any(
                (selectors["context"], selectors["point_class"], selectors["point_pair"])
            ):
                raise ValueError("aspect override requires only aspect_id")
            _require_identifier(self.aspect_id, field="aspect_id")
        elif self.scope is OrbOverrideScope.POINT_CLASS:
            if self.point_class is None or any(
                (selectors["context"], selectors["aspect_id"], selectors["point_pair"])
            ):
                raise ValueError("point_class override requires only point_class")
            _require_identifier(self.point_class, field="point_class")
        elif self.scope is OrbOverrideScope.POINT_PAIR:
            if self.point_a is None or self.point_b is None or any(
                (selectors["context"], selectors["aspect_id"], selectors["point_class"])
            ):
                raise ValueError("point_pair override requires only point_a and point_b")
            _require_identifier(self.point_a, field="point_a")
            _require_identifier(self.point_b, field="point_b")
            if self.point_a == self.point_b:
                raise ValueError("point_pair override requires two distinct point ids")
            if (self.point_a, self.point_b) != canonical_point_pair(self.point_a, self.point_b):
                raise ValueError("point_pair override must use canonical lexical point order")

    @property
    def selector_key(self) -> tuple[str, ...]:
        if self.scope is OrbOverrideScope.CHART_CONTEXT:
            return (self.scope.value, self.context.value if self.context is not None else "*")
        if self.scope is OrbOverrideScope.ASPECT:
            return (self.scope.value, str(self.aspect_id))
        if self.scope is OrbOverrideScope.POINT_CLASS:
            return (self.scope.value, str(self.point_class))
        return (self.scope.value, str(self.point_a), str(self.point_b))


@dataclass(frozen=True, slots=True)
class EffectiveOrb:
    """Resolved allowance plus enough provenance for snapshots and exports."""

    orb_deg: float
    scope: str
    rule_id: str
    source: str

    @property
    def rule_ref(self) -> str:
        return f"orb_override:{self.rule_id};scope={self.scope};source={self.source}"

    def to_dict(self) -> dict[str, Any]:
        return {
            "orb_deg": self.orb_deg,
            "scope": self.scope,
            "rule_id": self.rule_id,
            "source": self.source,
        }


class OrbOverrideResolutionError(ValueError):
    """Raised when a valid rule set is ambiguous for a concrete point pair."""


@dataclass(frozen=True, slots=True)
class OrbOverrideSet:
    id: str
    version: str
    source: str
    rules: tuple[OrbOverrideRule, ...] = ()

    def __post_init__(self) -> None:
        _require_identifier(self.id, field="orb override set id")
        if not isinstance(self.version, str) or not self.version.strip():
            raise ValueError("orb override set version is required")
        if not isinstance(self.source, str) or not self.source.strip():
            raise ValueError("orb override set source is required")
        if any(not isinstance(rule, OrbOverrideRule) for rule in self.rules):
            raise ValueError("orb override set rules must be OrbOverrideRule values")
        ids = [rule.id for rule in self.rules]
        if len(ids) != len(set(ids)):
            raise ValueError("orb override set contains duplicate rule ids")
        selectors = [rule.selector_key for rule in self.rules]
        if len(selectors) != len(set(selectors)):
            raise ValueError("orb override set contains duplicate selectors")

    def resolve(
        self,
        *,
        preset_orb_deg: float,
        preset_rule_ref: str,
        preset_source: str,
        context: AspectContext,
        aspect_id: str,
        point_a: str,
        point_b: str,
        point_classes: Mapping[str, str] | None = None,
    ) -> EffectiveOrb:
        """Resolve one allowance using the documented precedence chain."""
        if not isinstance(context, AspectContext):
            raise ValueError("context must be an AspectContext")
        _require_identifier(aspect_id, field="aspect_id")
        if not isinstance(preset_rule_ref, str) or not preset_rule_ref.strip():
            raise ValueError("preset_rule_ref is required")
        if not isinstance(preset_source, str) or not preset_source.strip():
            raise ValueError("preset_source is required")
        preset = _require_orb(preset_orb_deg)
        canonical_a, canonical_b = canonical_point_pair(point_a, point_b)

        pair_rule = self._one(
            rule
            for rule in self.rules
            if rule.scope is OrbOverrideScope.POINT_PAIR
            and (rule.point_a, rule.point_b) == (canonical_a, canonical_b)
        )
        if pair_rule is not None:
            return _effective(pair_rule)

        classes = point_classes or {}
        class_a = classes.get(canonical_a)
        class_b = classes.get(canonical_b)
        for value in (class_a, class_b):
            if value is not None:
                _require_identifier(value, field="point class mapping value")
        class_rules = tuple(
            rule
            for rule in self.rules
            if rule.scope is OrbOverrideScope.POINT_CLASS
            and rule.point_class in {class_a, class_b}
        )
        if class_rules:
            distinct = {(rule.orb_deg, rule.source) for rule in class_rules}
            if len(distinct) > 1:
                labels = ", ".join(rule.id for rule in class_rules)
                raise OrbOverrideResolutionError(
                    "multiple point_class orb overrides match this pair with different "
                    f"values or sources: {labels}; add a point_pair override"
                )
            return _effective(sorted(class_rules, key=lambda rule: rule.id)[0])

        aspect_rule = self._one(
            rule
            for rule in self.rules
            if rule.scope is OrbOverrideScope.ASPECT and rule.aspect_id == aspect_id
        )
        if aspect_rule is not None:
            return _effective(aspect_rule)

        context_rule = self._one(
            rule
            for rule in self.rules
            if rule.scope is OrbOverrideScope.CHART_CONTEXT and rule.context is context
        )
        if context_rule is not None:
            return _effective(context_rule)
        global_rule = self._one(
            rule
            for rule in self.rules
            if rule.scope is OrbOverrideScope.CHART_CONTEXT and rule.context is None
        )
        if global_rule is not None:
            return _effective(global_rule)
        return EffectiveOrb(preset, "preset", preset_rule_ref, preset_source)

    @staticmethod
    def _one(rules: Iterable[OrbOverrideRule]) -> OrbOverrideRule | None:
        matches = tuple(rules)
        if not matches:
            return None
        if len(matches) > 1:
            # Duplicate selectors are rejected during construction; this is a
            # defensive assertion for future selector types.
            raise OrbOverrideResolutionError("multiple orb overrides match one exact selector")
        return matches[0]


def _effective(rule: OrbOverrideRule) -> EffectiveOrb:
    return EffectiveOrb(rule.orb_deg, rule.scope.value, rule.id, rule.source)


def canonical_point_pair(point_a: str, point_b: str) -> tuple[str, str]:
    """Return the stable unordered representation of a point pair."""
    _require_identifier(point_a, field="point_a")
    _require_identifier(point_b, field="point_b")
    if point_a == point_b:
        raise ValueError("point pair requires two distinct point ids")
    return tuple(sorted((point_a, point_b)))


def parse_orb_overrides(
    raw_rules: Iterable[Mapping[str, Any]] | None,
    *,
    set_id: str = "request.orb_overrides",
    version: str = "1",
    source: str = "calculation_request.settings.orb_overrides",
    known_aspect_ids: Iterable[str] | None = None,
    known_point_ids: Iterable[str] | None = None,
    known_point_classes: Iterable[str] | None = None,
) -> OrbOverrideSet:
    """Parse the JSON/API shape into an immutable validated rule set.

    ``scope='global'`` is accepted as a request-level shorthand and normalized
    to a chart-context rule with no context.  Unknown keys are rejected.
    """
    aspect_ids = set(known_aspect_ids) if known_aspect_ids is not None else None
    point_ids = set(known_point_ids) if known_point_ids is not None else None
    point_classes = set(known_point_classes) if known_point_classes is not None else None
    rules: list[OrbOverrideRule] = []
    for index, raw in enumerate(raw_rules or ()):
        if not isinstance(raw, Mapping):
            raise ValueError(f"orb override at index {index} must be an object")
        scope_raw = raw.get("scope")
        normalized_scope = "chart_context" if scope_raw == "global" else scope_raw
        try:
            scope = OrbOverrideScope(str(normalized_scope))
        except ValueError as exc:
            raise ValueError(
                f"unsupported orb override scope at index {index}: {scope_raw!r}"
            ) from exc

        required: set[str]
        optional: set[str] = set()
        if scope is OrbOverrideScope.CHART_CONTEXT:
            required = set()
            optional = {"context", "chart_context"}
        elif scope is OrbOverrideScope.ASPECT:
            required = {"aspect_id"}
        elif scope is OrbOverrideScope.POINT_CLASS:
            required = {"point_class"}
        else:
            required = {"point_a", "point_b"}
        allowed = _ALLOWED_COMMON_KEYS | required | optional
        unknown = sorted(set(raw) - allowed)
        if unknown:
            raise ValueError(
                f"orb override at index {index} contains unsupported fields: {', '.join(unknown)}"
            )
        missing = sorted(field for field in required | {"orb_deg"} if field not in raw)
        if missing:
            raise ValueError(
                f"orb override at index {index} is missing fields: {', '.join(missing)}"
            )

        rule_source = str(raw.get("source") or source)
        rule_id = str(raw.get("id") or f"{set_id}.rule.{index + 1}")
        context: AspectContext | None = None
        aspect_id = point_class = point_a = point_b = None
        if (
            scope is OrbOverrideScope.CHART_CONTEXT
            and raw.get("context") is not None
            and raw.get("chart_context") is not None
        ):
            raise ValueError(
                f"chart-context orb override at index {index} cannot include both "
                "context and chart_context"
            )
        raw_context = raw.get("context", raw.get("chart_context"))
        if scope is OrbOverrideScope.CHART_CONTEXT and raw_context is not None:
            try:
                context = AspectContext(str(raw_context))
            except ValueError as exc:
                raise ValueError(
                    f"invalid chart context in orb override at index {index}: {raw_context!r}"
                ) from exc
        elif scope is OrbOverrideScope.ASPECT:
            aspect_id = str(raw["aspect_id"])
            if aspect_ids is not None and aspect_id not in aspect_ids:
                raise ValueError(f"unknown aspect_id in orb override: {aspect_id}")
        elif scope is OrbOverrideScope.POINT_CLASS:
            point_class = str(raw["point_class"])
            if point_classes is not None and point_class not in point_classes:
                raise ValueError(f"unknown point_class in orb override: {point_class}")
        elif scope is OrbOverrideScope.POINT_PAIR:
            raw_a, raw_b = str(raw["point_a"]), str(raw["point_b"])
            if point_ids is not None:
                unknown_points = sorted({raw_a, raw_b} - point_ids)
                if unknown_points:
                    raise ValueError(
                        "unknown point id in orb override: " + ", ".join(unknown_points)
                    )
            point_a, point_b = canonical_point_pair(raw_a, raw_b)

        rules.append(
            OrbOverrideRule(
                id=rule_id,
                scope=scope,
                orb_deg=_require_orb(raw["orb_deg"]),
                source=rule_source,
                context=context,
                aspect_id=aspect_id,
                point_class=point_class,
                point_a=point_a,
                point_b=point_b,
            )
        )
    return OrbOverrideSet(set_id, version, source, tuple(rules))
