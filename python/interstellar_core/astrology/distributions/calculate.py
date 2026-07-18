"""Pure element, modality, and polarity calculation."""

from __future__ import annotations

from collections import Counter
from collections.abc import Iterable

from interstellar_core.domain.errors import DomainError

from .models import (
    CategoryStatistic,
    DimensionResult,
    DimensionThreshold,
    DistributionAvailability,
    DistributionParticipant,
    DistributionPoint,
    DistributionProfile,
    DistributionProvenance,
    DistributionResult,
)
from .profiles import MODERN_TEN_PROFILE_V1
from .taxonomy import sign_for_longitude

_DIMENSIONS: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("elements", ("fire", "earth", "air", "water")),
    ("modalities", ("cardinal", "fixed", "mutable")),
    ("polarities", ("positive", "negative")),
)


def calculate_distributions(
    points: Iterable[DistributionPoint],
    *,
    profile: DistributionProfile = MODERN_TEN_PROFILE_V1,
) -> DistributionResult:
    """Calculate descriptive distributions using one explicit versioned profile."""

    supplied = tuple(points)
    supplied_ids = [point.point_id for point in supplied]
    if len(set(supplied_ids)) != len(supplied_ids):
        raise DomainError(
            "DISTRIBUTION_POINT_DUPLICATE", "each distribution point may be supplied once"
        )

    weights = {item.point_id: item.weight for item in profile.point_weights}
    unknown = sorted(set(supplied_ids) - set(weights))
    if unknown:
        raise DomainError(
            "DISTRIBUTION_POINT_UNKNOWN",
            "points are not part of the selected profile: " + ", ".join(unknown),
        )

    participants = tuple(_participant(point, weights[point.point_id]) for point in supplied)
    expected_ids = tuple(item.point_id for item in profile.point_weights)
    missing_ids = tuple(point_id for point_id in expected_ids if point_id not in supplied_ids)
    denominator = sum(participant.weight for participant in participants)
    reasons: list[str] = []
    if missing_ids:
        reasons.append("MISSING_REQUIRED_PARTICIPANTS")
    if denominator == 0:
        reasons.append("ZERO_WEIGHT_DENOMINATOR")
    availability = (
        DistributionAvailability.UNAVAILABLE if reasons else DistributionAvailability.AVAILABLE
    )

    thresholds = {threshold.dimension: threshold for threshold in profile.thresholds}
    dimensions = tuple(
        _dimension(
            name,
            categories,
            participants,
            denominator,
            thresholds[name],
            availability,
        )
        for name, categories in _DIMENSIONS
    )
    provenance = DistributionProvenance(
        algorithm_card_id="ALG-NATAL-003",
        capability_id="natal.patterns_distributions",
        calculation_ids=(
            "distribution.elements.v1",
            "distribution.modalities.v1",
            "distribution.polarity.v1",
        ),
        implementation_version="1.0.0",
        zodiac_mapping="tropical_equal_30_degree_signs.v1",
        profile_id=profile.profile_id,
        profile_version=profile.version,
        profile_content_hash=profile.content_hash,
        expected_participant_ids=expected_ids,
        supplied_participant_ids=tuple(supplied_ids),
        missing_participant_ids=missing_ids,
        excluded_capabilities=(
            "distribution.hemisphere.v1",
            "pattern.jones.v1",
            "pattern.geometry.v1",
        ),
        interpretation_boundary=(
            "Descriptive chart distribution only; not a personality, quality, or outcome score"
        ),
    )
    return DistributionResult(
        availability=availability,
        unavailable_reasons=tuple(reasons),
        participants=participants,
        dimensions=dimensions,
        provenance=provenance,
    )


def _participant(point: DistributionPoint, weight: float) -> DistributionParticipant:
    if not point.point_id:
        raise DomainError("DISTRIBUTION_POINT_INVALID", "point id cannot be empty")
    sign = sign_for_longitude(point.longitude_deg)
    return DistributionParticipant(
        point_id=point.point_id,
        longitude_deg=point.longitude_deg,
        sign_id=sign.sign_id,
        element=sign.element,
        modality=sign.modality,
        polarity=sign.polarity,
        weight=weight,
    )


def _dimension(
    name: str,
    category_ids: tuple[str, ...],
    participants: tuple[DistributionParticipant, ...],
    denominator: float,
    threshold: DimensionThreshold,
    availability: DistributionAvailability,
) -> DimensionResult:
    raw_counts: Counter[str] = Counter()
    weighted_scores: Counter[str] = Counter()
    singular = {"elements": "element", "modalities": "modality", "polarities": "polarity"}[name]
    for participant in participants:
        category = getattr(participant, singular)
        raw_counts[category] += 1
        weighted_scores[category] += participant.weight

    categories = tuple(
        _category(
            category_id,
            raw_counts[category_id],
            weighted_scores[category_id],
            denominator,
            threshold,
            availability,
        )
        for category_id in category_ids
    )
    return DimensionResult(
        dimension=name,
        availability=availability,
        denominator=denominator,
        threshold=threshold,
        categories=categories,
    )


def _category(
    category_id: str,
    raw_count: int,
    weighted_score: float,
    denominator: float,
    threshold: DimensionThreshold,
    availability: DistributionAvailability,
) -> CategoryStatistic:
    if availability is DistributionAvailability.UNAVAILABLE:
        return CategoryStatistic(
            category_id=category_id,
            raw_count=raw_count,
            weighted_score=weighted_score,
            percentage=None,
            is_missing=None,
            is_overrepresented=None,
        )
    percentage = weighted_score / denominator * 100.0
    return CategoryStatistic(
        category_id=category_id,
        raw_count=raw_count,
        weighted_score=weighted_score,
        percentage=percentage,
        is_missing=weighted_score <= threshold.missing_weight_max,
        is_overrepresented=percentage >= threshold.overrepresented_percentage_min,
    )
