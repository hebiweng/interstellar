from __future__ import annotations

import pytest

from interstellar_core.astrology.houses import (
    assign_longitude_to_house,
    assign_points_to_houses,
    derived_house,
)

EQUAL_CUSPS = tuple(float(degree) for degree in range(0, 360, 30))


def test_house_intervals_are_start_inclusive_and_end_exclusive() -> None:
    assert assign_longitude_to_house(1, EQUAL_CUSPS).house == 1
    assert assign_longitude_to_house(29.999999, EQUAL_CUSPS).house == 1
    assert assign_longitude_to_house(30.000001, EQUAL_CUSPS).house == 2
    assert assign_longitude_to_house(359, EQUAL_CUSPS).house == 12


def test_exact_and_tolerance_cusps_belong_to_the_new_house() -> None:
    exact = assign_longitude_to_house(30, EQUAL_CUSPS)
    within_tolerance = assign_longitude_to_house(30 - 0.5e-9, EQUAL_CUSPS)
    outside_tolerance = assign_longitude_to_house(30 - 2e-9, EQUAL_CUSPS)
    zodiac_wrap = assign_longitude_to_house(360 - 0.5e-9, EQUAL_CUSPS)

    assert (exact.house, exact.on_cusp, exact.cusp_number) == (2, True, 2)
    assert (within_tolerance.house, within_tolerance.on_cusp) == (2, True)
    assert (outside_tolerance.house, outside_tolerance.on_cusp) == (1, False)
    assert (zodiac_wrap.house, zodiac_wrap.on_cusp, zodiac_wrap.cusp_number) == (
        1,
        True,
        1,
    )


def test_circular_unequal_cusps_assign_across_zero_degrees() -> None:
    cusps = (
        350.0,
        20.0,
        50.0,
        80.0,
        110.0,
        140.0,
        170.0,
        200.0,
        230.0,
        260.0,
        290.0,
        320.0,
    )

    assert assign_longitude_to_house(0, cusps).house == 1
    assert assign_longitude_to_house(340, cusps).house == 12
    placements = assign_points_to_houses({"sun": 0, "moon": 340}, cusps)
    assert placements["sun"].house == 1
    assert placements["moon"].house == 12


@pytest.mark.parametrize(
    ("starting", "relative", "absolute"),
    [(1, 1, 1), (7, 2, 8), (7, 8, 2), (12, 12, 11)],
)
def test_derived_house_uses_inclusive_modulo_twelve(
    starting: int,
    relative: int,
    absolute: int,
) -> None:
    result = derived_house(starting, relative)
    assert result.starting_house == starting
    assert result.relative_house == relative
    assert result.absolute_house == absolute


@pytest.mark.parametrize("starting,relative", [(0, 1), (13, 1), (1, 0), (1, 13)])
def test_derived_house_rejects_out_of_range_values(
    starting: int, relative: int
) -> None:
    with pytest.raises(ValueError):
        derived_house(starting, relative)
