from __future__ import annotations

from math import inf, nan

import pytest

from interstellar_core.astrology.aspects import (
    OFFICIAL_STANDARD_ORBS_V1,
    AspectContext,
    AspectPoint,
    OrbOverrideResolutionError,
    OrbOverrideRule,
    OrbOverrideScope,
    OrbOverrideSet,
    canonical_point_pair,
    find_major_aspects,
    parse_orb_overrides,
)


def _resolve(
    overrides: OrbOverrideSet,
    *,
    context: AspectContext = AspectContext.WITHIN_CHART,
    aspect_id: str = "square",
    point_a: str = "sun",
    point_b: str = "moon",
    point_classes: dict[str, str] | None = None,
):
    return overrides.resolve(
        preset_orb_deg=OFFICIAL_STANDARD_ORBS_V1.effective_orb(aspect_id),
        preset_rule_ref="official.orbs.standard.v1@1.0.0",
        preset_source=OFFICIAL_STANDARD_ORBS_V1.source,
        context=context,
        aspect_id=aspect_id,
        point_a=point_a,
        point_b=point_b,
        point_classes=point_classes,
    )


def test_parser_canonicalizes_unordered_point_pair_and_tracks_source() -> None:
    overrides = parse_orb_overrides(
        [
            {
                "id": "user.sun-moon",
                "scope": "point_pair",
                "point_a": "sun",
                "point_b": "moon",
                "orb_deg": 10,
                "source": "user.profile:alice",
            }
        ],
        known_point_ids={"moon", "sun"},
    )
    rule = overrides.rules[0]
    assert (rule.point_a, rule.point_b) == canonical_point_pair("moon", "sun")
    assert rule.source == "user.profile:alice"
    assert _resolve(overrides).to_dict() == {
        "orb_deg": 10.0,
        "scope": "point_pair",
        "rule_id": "user.sun-moon",
        "source": "user.profile:alice",
    }


def test_override_precedence_is_pair_class_aspect_context_global_preset() -> None:
    overrides = parse_orb_overrides(
        [
            {"id": "global", "scope": "global", "orb_deg": 9},
            {
                "id": "natal",
                "scope": "chart_context",
                "context": "within_chart",
                "orb_deg": 8,
            },
            {"id": "square", "scope": "aspect", "aspect_id": "square", "orb_deg": 7},
            {
                "id": "luminary",
                "scope": "point_class",
                "point_class": "luminary",
                "orb_deg": 6,
            },
            {
                "id": "sun-moon",
                "scope": "point_pair",
                "point_a": "moon",
                "point_b": "sun",
                "orb_deg": 5,
            },
        ],
        known_aspect_ids={"square", "sextile"},
        known_point_ids={"sun", "moon", "mars", "jupiter"},
        known_point_classes={"luminary", "planet"},
    )
    classes = {"sun": "luminary", "moon": "luminary", "mars": "planet", "jupiter": "planet"}

    assert _resolve(overrides, point_classes=classes).rule_id == "sun-moon"
    assert _resolve(
        overrides, point_b="mars", point_classes=classes
    ).rule_id == "luminary"
    assert _resolve(
        overrides, point_a="mars", point_b="jupiter", point_classes=classes
    ).rule_id == "square"
    assert _resolve(
        overrides,
        aspect_id="sextile",
        point_a="mars",
        point_b="jupiter",
        point_classes=classes,
    ).rule_id == "natal"
    assert _resolve(
        overrides,
        context=AspectContext.TRANSIT,
        aspect_id="sextile",
        point_a="mars",
        point_b="jupiter",
        point_classes=classes,
    ).rule_id == "global"

    no_rules = parse_orb_overrides([])
    fallback = _resolve(no_rules, point_classes=classes)
    assert fallback.scope == "preset"
    assert fallback.orb_deg == 6.0
    assert fallback.rule_id == "official.orbs.standard.v1@1.0.0"


def test_engine_applies_pair_override_symmetrically_and_adds_rule_provenance() -> None:
    overrides = parse_orb_overrides(
        [
            {
                "id": "user.alpha-beta",
                "scope": "point_pair",
                "point_a": "beta",
                "point_b": "alpha",
                "orb_deg": 8,
                "source": "saved-orb-profile:v2",
            }
        ]
    )
    alpha = AspectPoint("alpha", 0, 0)
    beta = AspectPoint("beta", 97, 1)
    assert find_major_aspects(alpha, beta) == ()  # preset square allowance is 6 degrees

    forward = find_major_aspects(alpha, beta, orb_overrides=overrides)
    reverse = find_major_aspects(beta, alpha, orb_overrides=overrides)
    assert forward == reverse
    assert len(forward) == 1
    assert forward[0].type == "square"
    assert forward[0].orb_ratio == pytest.approx(0.125)
    assert forward[0].rule_refs[-1] == (
        "orb_override:user.alpha-beta;scope=point_pair;source=saved-orb-profile:v2"
    )


def test_point_class_ambiguity_is_rejected_until_pair_override_resolves_it() -> None:
    ambiguous = parse_orb_overrides(
        [
            {"id": "luminary", "scope": "point_class", "point_class": "luminary", "orb_deg": 8},
            {"id": "social", "scope": "point_class", "point_class": "social", "orb_deg": 5},
        ]
    )
    with pytest.raises(OrbOverrideResolutionError, match="add a point_pair override"):
        _resolve(ambiguous, point_classes={"sun": "luminary", "moon": "social"})

    resolved = parse_orb_overrides(
        [
            {"id": "luminary", "scope": "point_class", "point_class": "luminary", "orb_deg": 8},
            {"id": "social", "scope": "point_class", "point_class": "social", "orb_deg": 5},
            {
                "id": "exact-pair",
                "scope": "point_pair",
                "point_a": "sun",
                "point_b": "moon",
                "orb_deg": 7,
            },
        ]
    )
    assert _resolve(
        resolved, point_classes={"sun": "luminary", "moon": "social"}
    ).rule_id == "exact-pair"


@pytest.mark.parametrize("invalid_orb", [True, -0.1, 180.1, nan, inf, "6"])
def test_orb_values_are_strictly_validated(invalid_orb: object) -> None:
    with pytest.raises(ValueError, match="orb_deg"):
        parse_orb_overrides([{"scope": "global", "orb_deg": invalid_orb}])


@pytest.mark.parametrize(
    "raw, message",
    [
        ({"scope": "aspect", "orb_deg": 5}, "missing fields: aspect_id"),
        (
            {"scope": "aspect", "aspect_id": "square", "orb_deg": 5, "point_a": "sun"},
            "unsupported fields: point_a",
        ),
        ({"scope": "unknown", "orb_deg": 5}, "unsupported orb override scope"),
        (
            {"scope": "chart_context", "context": "natalish", "orb_deg": 5},
            "invalid chart context",
        ),
    ],
)
def test_parser_rejects_malformed_or_cross_scope_fields(
    raw: dict[str, object], message: str
) -> None:
    with pytest.raises(ValueError, match=message):
        parse_orb_overrides([raw])


def test_parser_rejects_unknown_references_and_duplicate_selectors() -> None:
    with pytest.raises(ValueError, match="unknown aspect_id"):
        parse_orb_overrides(
            [{"scope": "aspect", "aspect_id": "septile", "orb_deg": 1}],
            known_aspect_ids={"square"},
        )
    with pytest.raises(ValueError, match="unknown point_class"):
        parse_orb_overrides(
            [{"scope": "point_class", "point_class": "asteroid", "orb_deg": 1}],
            known_point_classes={"planet"},
        )
    with pytest.raises(ValueError, match="unknown point id"):
        parse_orb_overrides(
            [
                {
                    "scope": "point_pair",
                    "point_a": "sun",
                    "point_b": "unknown",
                    "orb_deg": 1,
                }
            ],
            known_point_ids={"sun", "moon"},
        )
    with pytest.raises(ValueError, match="duplicate selectors"):
        parse_orb_overrides(
            [
                {"id": "first", "scope": "aspect", "aspect_id": "square", "orb_deg": 5},
                {"id": "second", "scope": "aspect", "aspect_id": "square", "orb_deg": 6},
            ]
        )


def test_direct_point_pair_rules_require_canonical_order() -> None:
    with pytest.raises(ValueError, match="canonical lexical point order"):
        OrbOverrideRule(
            id="bad-pair",
            scope=OrbOverrideScope.POINT_PAIR,
            orb_deg=5,
            source="test",
            point_a="sun",
            point_b="moon",
        )
