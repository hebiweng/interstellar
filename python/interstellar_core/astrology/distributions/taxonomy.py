"""Equal 30-degree tropical zodiac taxonomy used by distribution v1."""

from __future__ import annotations

import math
from dataclasses import dataclass

from interstellar_core.domain.errors import DomainError


@dataclass(frozen=True, slots=True)
class SignDefinition:
    sign_id: str
    element: str
    modality: str
    polarity: str


SIGNS: tuple[SignDefinition, ...] = (
    SignDefinition("aries", "fire", "cardinal", "positive"),
    SignDefinition("taurus", "earth", "fixed", "negative"),
    SignDefinition("gemini", "air", "mutable", "positive"),
    SignDefinition("cancer", "water", "cardinal", "negative"),
    SignDefinition("leo", "fire", "fixed", "positive"),
    SignDefinition("virgo", "earth", "mutable", "negative"),
    SignDefinition("libra", "air", "cardinal", "positive"),
    SignDefinition("scorpio", "water", "fixed", "negative"),
    SignDefinition("sagittarius", "fire", "mutable", "positive"),
    SignDefinition("capricorn", "earth", "cardinal", "negative"),
    SignDefinition("aquarius", "air", "fixed", "positive"),
    SignDefinition("pisces", "water", "mutable", "negative"),
)


def sign_for_longitude(longitude_deg: float) -> SignDefinition:
    """Map normalized longitude to a sign; invalid input is never wrapped silently."""

    if not math.isfinite(longitude_deg) or not 0 <= longitude_deg < 360:
        raise DomainError(
            "DISTRIBUTION_LONGITUDE_INVALID",
            "longitude must be finite, at least 0 degrees, and less than 360 degrees",
        )
    return SIGNS[int(longitude_deg // 30)]
