from __future__ import annotations

import pytest

from interstellar_core.astrology.distributions import (
    CLASSICAL_SEVEN_PROFILE_V1,
    MODERN_TEN_PROFILE_V1,
    PointWeight,
    profile_by_id,
)
from interstellar_core.domain import DomainError


def test_modern_and_classical_profiles_have_versioned_participant_sets() -> None:
    modern_weights = {
        item.point_id: item.weight for item in MODERN_TEN_PROFILE_V1.point_weights
    }
    classical_ids = {item.point_id for item in CLASSICAL_SEVEN_PROFILE_V1.point_weights}

    assert len(modern_weights) == 10
    assert modern_weights["sun"] == modern_weights["moon"] == 2.0
    assert set(modern_weights.values()) == {1.0, 2.0}
    assert classical_ids == {
        "sun",
        "moon",
        "mercury",
        "venus",
        "mars",
        "jupiter",
        "saturn",
    }
    assert MODERN_TEN_PROFILE_V1.content_hash != CLASSICAL_SEVEN_PROFILE_V1.content_hash
    assert profile_by_id(MODERN_TEN_PROFILE_V1.profile_id) is MODERN_TEN_PROFILE_V1


def test_weights_must_be_positive() -> None:
    with pytest.raises(ValueError, match="greater than zero"):
        PointWeight("sun", 0)


def test_unknown_profile_is_explicit() -> None:
    with pytest.raises(DomainError) as caught:
        profile_by_id("unknown")
    assert caught.value.code == "DISTRIBUTION_PROFILE_UNKNOWN"
