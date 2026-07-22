from __future__ import annotations

from interstellar_core.astrology.natal.point_registry import (
    BLOCKED_COMPETITOR_POINT_IDS,
    COMPETITOR_REFERENCE_POINT_IDS,
    FORMULA_REGISTRY,
    POINT_REGISTRY,
    SOURCE_REGISTRY,
    point_registry_document,
)
from interstellar_core.astrology.natal.points import PROFESSIONAL_POINT_IDS


def test_competitor_reference_registry_is_exactly_66_and_auditable() -> None:
    assert len(COMPETITOR_REFERENCE_POINT_IDS) == 66
    assert len(set(COMPETITOR_REFERENCE_POINT_IDS)) == 66
    assert set(COMPETITOR_REFERENCE_POINT_IDS) < set(POINT_REGISTRY)

    for point_id, entry in POINT_REGISTRY.items():
        assert len(entry.content_hash) == 64
        if entry.availability == "available":
            assert entry.formula_ref in FORMULA_REGISTRY, point_id
            assert entry.source_refs, point_id
            assert set(entry.source_refs) <= set(SOURCE_REGISTRY), point_id
            assert entry.blocked_reason is None
        else:
            assert entry.formula_ref is None
            assert entry.blocked_reason


def test_eros_lot_and_eros_asteroid_are_distinct_and_no_blocked_formula_is_faked() -> (
    None
):
    assert POINT_REGISTRY["lot_eros"].availability == "available"
    assert POINT_REGISTRY["lot_eros"].formula_ref == "lot.eros.paulus.v1"
    assert POINT_REGISTRY["asteroid_eros"].availability == "available"
    assert POINT_REGISTRY["asteroid_eros"].catalog_object_ref == "mpc:433"
    assert all(
        POINT_REGISTRY[point_id].formula_ref is None
        for point_id in BLOCKED_COMPETITOR_POINT_IDS
    )


def test_registry_document_is_json_safe_and_content_addressed() -> None:
    document = point_registry_document()
    assert document["registry_id"] == "natal.points.competitor_reference.v1"
    assert len(document["competitor_reference_point_ids"]) == 66
    assert len(document["points"]) == len(POINT_REGISTRY)
    assert all(len(point["content_hash"]) == 64 for point in document["points"])
    assert all(len(source["content_hash"]) == 64 for source in document["sources"])
    assert all(
        set(formula.source_refs) <= set(SOURCE_REGISTRY)
        for formula in FORMULA_REGISTRY.values()
    )


def test_professional_default_projection_has_62_released_registered_points() -> None:
    assert len(PROFESSIONAL_POINT_IDS) == 62
    assert len(set(PROFESSIONAL_POINT_IDS)) == 62
    assert all(
        POINT_REGISTRY[point_id].availability == "available"
        for point_id in PROFESSIONAL_POINT_IDS
    )
