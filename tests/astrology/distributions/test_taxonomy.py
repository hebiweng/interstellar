from __future__ import annotations

import pytest

from interstellar_core.astrology.distributions import sign_for_longitude
from interstellar_core.domain import DomainError


@pytest.mark.parametrize(
    ("longitude", "sign_id"),
    [
        (0.0, "aries"),
        (29.999999, "aries"),
        (30.0, "taurus"),
        (59.999999, "taurus"),
        (60.0, "gemini"),
        (330.0, "pisces"),
        (359.999999, "pisces"),
    ],
)
def test_sign_boundaries_use_half_open_thirty_degree_ranges(
    longitude: float, sign_id: str
) -> None:
    assert sign_for_longitude(longitude).sign_id == sign_id


@pytest.mark.parametrize("longitude", [-0.000001, 360.0, float("inf"), float("nan")])
def test_invalid_longitude_is_not_wrapped_silently(longitude: float) -> None:
    with pytest.raises(DomainError) as caught:
        sign_for_longitude(longitude)
    assert caught.value.code == "DISTRIBUTION_LONGITUDE_INVALID"
