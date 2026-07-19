from __future__ import annotations

import copy
import re
import sys
from collections.abc import Callable, Mapping
from pathlib import Path
from typing import Any

import pytest
import yaml


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "python"))

from interstellar_core.astrology.aspects import (  # noqa: E402
    AspectPoint,
    find_major_aspects,
)
from interstellar_core.astrology.distributions import (  # noqa: E402
    DistributionPoint,
    calculate_distributions,
)
from interstellar_core.astrology.houses import (  # noqa: E402
    assign_longitude_to_house,
    whole_sign_cusps,
)
from interstellar_core.astronomy.derived import (  # noqa: E402
    MotionThreshold,
    classify_motion,
    smallest_angular_separation,
)
from interstellar_core.astrology.distributions import sign_for_longitude  # noqa: E402


FIXTURES = Path(__file__).parent / "fixtures"
TEST_REFERENCE = "tests/gold/natal/test_analytic_gold.py"
FIXTURE_ID = re.compile(r"^GOLD-[A-Z]+-[0-9]{3}$")
REQUIRED_FIELDS = {
    "fixture_id",
    "family",
    "source",
    "reference_family",
    "sut_family",
    "review_status",
    "maturity",
    "availability",
    "expected_origin",
    "expected",
    "referenced_by",
}
SOURCE_FIELDS = {
    "source_id",
    "title",
    "uri",
    "license",
    "independently_captured",
    "stable_eligible",
}


def _load_documents() -> tuple[dict[str, Any], ...]:
    documents = []
    paths = sorted((*FIXTURES.glob("*.yaml"), *FIXTURES.glob("*.yml")))
    assert paths, "natal Gold fixture directory is empty"
    for path in paths:
        document = yaml.safe_load(path.read_text(encoding="utf-8"))
        assert isinstance(document, dict), f"{path.name}: document must be an object"
        document["_fixture_path"] = str(path.relative_to(ROOT))
        documents.append(document)
    return tuple(documents)


def _all_cases() -> tuple[dict[str, Any], ...]:
    cases: list[dict[str, Any]] = []
    for document in _load_documents():
        if "cases" in document:
            raw_cases = document["cases"]
            assert isinstance(raw_cases, list), f"{document['_fixture_path']}: cases must be a list"
            for raw_case in raw_cases:
                assert isinstance(raw_case, dict)
                case = dict(raw_case)
                case["_fixture_path"] = document["_fixture_path"]
                cases.append(case)
        else:
            cases.append(document)
    return tuple(cases)


CASES = _all_cases()


def _validation_errors(case: Mapping[str, Any]) -> tuple[str, ...]:
    fixture_id = str(case.get("fixture_id", "<missing>"))
    errors: list[str] = []
    missing = REQUIRED_FIELDS - set(case)
    if missing:
        errors.append("missing fields: " + ", ".join(sorted(missing)))
    if not FIXTURE_ID.fullmatch(fixture_id):
        errors.append("fixture_id must match GOLD-[A-Z]+-[0-9]{3}")

    source = case.get("source")
    if not isinstance(source, Mapping):
        errors.append("source must be an object")
    else:
        missing_source = SOURCE_FIELDS - set(source)
        if missing_source:
            errors.append("source missing fields: " + ", ".join(sorted(missing_source)))

    if case.get("review_status") not in {"draft", "independently_captured", "approved"}:
        errors.append("review_status is invalid")
    if case.get("maturity") not in {"stable", "beta", "experimental"}:
        errors.append("maturity is invalid")
    if case.get("availability") not in {"available", "unavailable"}:
        errors.append("availability is invalid")
    if case.get("expected") in (None, {}, []):
        errors.append("expected must be non-empty")
    if case.get("expected_origin") == "system_under_test":
        errors.append("expected values cannot originate from the system under test")
    if TEST_REFERENCE not in case.get("referenced_by", []):
        errors.append("fixture is not referenced by the executable natal Gold suite")

    if case.get("maturity") == "stable":
        if case.get("availability") != "available":
            errors.append("an unavailable fixture cannot satisfy stable")
        if case.get("reference_family") == case.get("sut_family"):
            errors.append("the same implementation family cannot satisfy stable")
        if case.get("review_status") not in {"independently_captured", "approved"}:
            errors.append("stable requires independent capture or approval")
        if isinstance(source, Mapping):
            if source.get("independently_captured") is not True:
                errors.append("stable source must be independently captured")
            if source.get("stable_eligible") is not True:
                errors.append("stable source must be stable eligible")
    return tuple(errors)


def _execute_subject_input_collection(case: Mapping[str, Any]) -> None:
    subjects = case.get("subjects")
    assert isinstance(subjects, list)
    assert len(subjects) == case["expected"]["subject_count"]
    ids = [subject["id"] for subject in subjects]
    assert len(ids) == len(set(ids))
    if case["expected"]["every_subject_has_nonempty_required_behavior"]:
        assert all(subject.get("required_behavior") for subject in subjects)


def _execute_sign_boundaries(case: Mapping[str, Any]) -> None:
    actual = [
        sign_for_longitude(float(value)).sign_id
        for value in case["input"]["longitudes_deg"]
    ]
    assert actual == case["expected"]["sign_ids"]


def _execute_motion_state(case: Mapping[str, Any]) -> None:
    threshold = MotionThreshold(
        id=case["fixture_id"],
        absolute_speed_deg_per_day=float(case["input"]["threshold_deg_per_day"]),
        source=case["source"]["source_id"],
        version="1.0.0",
    )
    actual = [
        classify_motion(float(speed), threshold).state.value
        for speed in case["input"]["samples_deg_per_day"]
    ]
    assert actual == case["expected"]["states"]


def _equal_cusps(ascendant_deg: float) -> tuple[float, ...]:
    return tuple((ascendant_deg + index * 30.0) % 360.0 for index in range(12))


def _porphyry_cusps(ascendant_deg: float, mc_deg: float) -> tuple[float, ...]:
    anchors = {
        1: ascendant_deg % 360.0,
        4: (mc_deg + 180.0) % 360.0,
        7: (ascendant_deg + 180.0) % 360.0,
        10: mc_deg % 360.0,
    }
    cusps: dict[int, float] = {}
    for start_house, end_house in ((1, 4), (4, 7), (7, 10), (10, 13)):
        start = anchors[start_house]
        end = anchors[1] if end_house == 13 else anchors[end_house]
        arc = (end - start) % 360.0
        for offset in range(3):
            house = start_house + offset
            cusps[house] = (start + arc * offset / 3.0) % 360.0
    return tuple(cusps[number] for number in range(1, 13))


def _execute_house_derived_boundaries(case: Mapping[str, Any]) -> None:
    expected_by_system = {
        row["system"]: row for row in case["expected"]["systems"]
    }
    tolerance = float(case["tolerance"]["degree"])
    for requested in case["input"]["systems"]:
        system = requested["system"]
        expected = expected_by_system[system]
        if system == "whole_sign":
            actual_cusps = whole_sign_cusps(float(requested["ascendant_deg"]))
        elif system == "equal":
            actual_cusps = _equal_cusps(float(requested["ascendant_deg"]))
        elif system == "porphyry":
            actual_cusps = _porphyry_cusps(
                float(requested["ascendant_deg"]),
                float(requested["mc_deg"]),
            )
        else:  # pragma: no cover - fixture contract makes new families fail visibly
            raise AssertionError(f"unsupported analytic house fixture system: {system}")
        assert actual_cusps == pytest.approx(expected["cusps_deg"], abs=tolerance)

        placements = [
            assign_longitude_to_house(float(longitude), tuple(expected["cusps_deg"]))
            for longitude in requested["placement_longitudes_deg"]
        ]
        assert [placement.house for placement in placements] == expected["houses"]
        assert [placement.on_cusp for placement in placements] == expected["on_cusp"]


def _execute_major_aspect_boundaries(case: Mapping[str, Any]) -> None:
    expected_by_id = {
        sample["id"]: sample for sample in case["expected"]["samples"]
    }
    tolerance = float(case["tolerance"]["degree"])
    for sample in case["input"]["samples"]:
        expected = expected_by_id[sample["id"]]
        aspects = find_major_aspects(
            AspectPoint("alpha", float(sample["a_deg"]), 1.0),
            AspectPoint("beta", float(sample["b_deg"]), 0.0),
        )
        assert bool(aspects) is expected["matched"]
        if not expected["matched"]:
            assert aspects == ()
            continue
        assert len(aspects) == 1
        actual = aspects[0]
        assert actual.type == expected["type"]
        assert actual.actual_angle_deg == pytest.approx(
            expected["actual_angle_deg"], abs=tolerance
        )
        assert actual.orb_deg == pytest.approx(expected["orb_deg"], abs=tolerance)
        assert actual.orb_ratio == pytest.approx(expected["orb_ratio"], abs=tolerance)


def _execute_distribution_structure(case: Mapping[str, Any]) -> None:
    result = calculate_distributions(
        DistributionPoint(row["point_id"], float(row["longitude_deg"]))
        for row in case["input"]["points"]
    )
    tolerance = float(case["tolerance"]["percentage"])
    dimensions = {dimension.dimension: dimension for dimension in result.dimensions}
    for dimension_id, expected_categories in case["expected"]["dimensions"].items():
        categories = {
            category.category_id: category
            for category in dimensions[dimension_id].categories
        }
        for category_id, expected in expected_categories.items():
            actual = categories[category_id]
            assert actual.raw_count == expected["raw_count"]
            assert actual.weighted_score == expected["weighted_score"]
            assert actual.percentage == pytest.approx(
                expected["percentage"], abs=tolerance
            )


def _execute_geometry_pattern_reference(case: Mapping[str, Any]) -> None:
    points = {
        row["point_id"]: float(row["longitude_deg"])
        for row in case["input"]["points"]
    }
    tolerance = float(case["tolerance"]["degree"])
    assert case["expected"]["implementation_status"].startswith("reference_only")
    for edge in case["expected"]["required_edges"]:
        actual = smallest_angular_separation(
            points[edge["point_a"]], points[edge["point_b"]]
        )
        assert actual == pytest.approx(edge["angle_deg"], abs=tolerance)


EXECUTORS: dict[str, Callable[[Mapping[str, Any]], None]] = {
    "subject_input_collection": _execute_subject_input_collection,
    "sign_boundaries": _execute_sign_boundaries,
    "motion_state": _execute_motion_state,
    "house_derived_boundaries": _execute_house_derived_boundaries,
    "major_aspect_boundaries": _execute_major_aspect_boundaries,
    "distribution_structure": _execute_distribution_structure,
    "geometry_pattern_reference": _execute_geometry_pattern_reference,
}


def test_fixture_ids_are_unique_and_every_fixture_has_an_executor() -> None:
    ids = [case["fixture_id"] for case in CASES]
    assert len(ids) == len(set(ids))
    assert {case["family"] for case in CASES} <= set(EXECUTORS)


@pytest.mark.parametrize("case", CASES, ids=lambda case: case["fixture_id"])
def test_every_natal_gold_fixture_satisfies_contract(case: Mapping[str, Any]) -> None:
    assert _validation_errors(case) == (), (
        f"{case.get('fixture_id')} ({case.get('_fixture_path')}): "
        + "; ".join(_validation_errors(case))
    )


@pytest.mark.parametrize("case", CASES, ids=lambda case: case["fixture_id"])
def test_every_natal_gold_fixture_is_executed(case: Mapping[str, Any]) -> None:
    EXECUTORS[case["family"]](case)


def test_stable_fixture_cannot_use_same_implementation_family() -> None:
    mutated = copy.deepcopy(next(case for case in CASES if case["maturity"] == "stable"))
    mutated["reference_family"] = mutated["sut_family"]
    assert "the same implementation family cannot satisfy stable" in _validation_errors(
        mutated
    )


def test_unavailable_fixture_cannot_satisfy_stable() -> None:
    mutated = copy.deepcopy(next(case for case in CASES if case["maturity"] == "stable"))
    mutated["availability"] = "unavailable"
    assert "an unavailable fixture cannot satisfy stable" in _validation_errors(mutated)


def test_fixture_not_referenced_by_executable_suite_is_rejected() -> None:
    mutated = copy.deepcopy(CASES[0])
    mutated["referenced_by"] = []
    assert (
        "fixture is not referenced by the executable natal Gold suite"
        in _validation_errors(mutated)
    )
