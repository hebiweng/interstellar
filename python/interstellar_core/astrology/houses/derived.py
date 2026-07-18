"""Pure derived-house arithmetic."""

from __future__ import annotations

from interstellar_core.astrology.houses.models import DerivedHouseResult


def derived_house(starting_house: int, relative_house: int) -> DerivedHouseResult:
    """Return house `relative_house` counted inclusively from `starting_house`."""

    if not 1 <= starting_house <= 12:
        raise ValueError("starting_house must be in 1..12")
    if not 1 <= relative_house <= 12:
        raise ValueError("relative_house must be in 1..12")
    absolute_house = ((starting_house - 1) + (relative_house - 1)) % 12 + 1
    return DerivedHouseResult(
        starting_house=starting_house,
        relative_house=relative_house,
        absolute_house=absolute_house,
    )
