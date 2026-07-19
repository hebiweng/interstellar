"""Essential dignity facts using explicitly versioned classical tables."""

from __future__ import annotations

from interstellar_core.astrology.classical.models import (
    DignityCondition,
    DignityKind,
    EssentialDignityResult,
    EssentialStatusFact,
    EssentialStatusLevel,
    EssentialStatusPolarity,
    Sect,
    TableReference,
    TriplicityRole,
)
from interstellar_core.astrology.classical.rulership import traditional_rulers
from interstellar_core.astrology.classical.sect import require_sect
from interstellar_core.astrology.classical.sources import (
    ALG_DIGNITY_RECEPTION,
    PROFILE_TRADITIONAL_ESSENTIAL_V1,
    RULE_DETRIMENT_V1,
    RULE_EXALTATION_V1,
    RULE_FACES_V1,
    RULE_FALL_V1,
    RULE_PEREGRINE_V1,
    RULE_TERMS_V1,
    RULE_TRADITIONAL_RULERSHIP_V1,
    RULE_TRIPLICITY_V1,
)
from interstellar_core.astrology.classical.tables import (
    CHALDEAN_FACES_TABLE_REF,
    DOROTHEAN_TRIPLICITIES,
    DOROTHEAN_TRIPLICITY_TABLE_REF,
    EGYPTIAN_TERMS_TABLE_REF,
    EXALTATION_RULER_BY_SIGN,
    EXALTATION_TABLE_REF,
    SIGN_ELEMENTS,
    TRADITIONAL_PLANET_IDS,
    TRADITIONAL_RULERSHIP_TABLE_REF,
    face_ruler,
    opposite_sign,
    sign_and_degree,
    term_ruler,
)


def _condition(
    *,
    kind: DignityKind,
    ruler_id: str,
    sign_id: str,
    degree_in_sign: float,
    table_ref: TableReference,
    rule_id: str,
    role: TriplicityRole | None = None,
    is_active_for_sect: bool | None = None,
) -> DignityCondition:
    return DignityCondition(
        kind=kind,
        ruler_id=ruler_id,
        sign_id=sign_id,
        degree_in_sign=degree_in_sign,
        role=role,
        is_active_for_sect=is_active_for_sect,
        table_ref=table_ref,
        rule_id=rule_id,
    )


def _status_fact(
    condition: DignityCondition,
    *,
    polarity: EssentialStatusPolarity,
) -> EssentialStatusFact:
    major = {
        DignityKind.DOMICILE,
        DignityKind.EXALTATION,
        DignityKind.DETRIMENT,
        DignityKind.FALL,
    }
    active = (
        condition.is_active_for_sect
        if condition.kind is DignityKind.TRIPLICITY
        else True
    )
    return EssentialStatusFact(
        status_id=condition.kind,
        polarity=polarity,
        level=(
            EssentialStatusLevel.MAJOR
            if condition.kind in major
            else EssentialStatusLevel.MINOR
        ),
        active=bool(active),
        label_key=f"classical.essential.{condition.kind.value}",
        role=condition.role,
        table_ref=condition.table_ref,
        rule_id=condition.rule_id,
    )


def dignity_rulers_at(
    longitude_deg: float,
    *,
    sect: Sect,
) -> tuple[DignityCondition, ...]:
    """Return every positive essential-dignity lord at one zodiacal degree."""

    sect = require_sect(sect)
    sign_id, degree = sign_and_degree(longitude_deg)
    conditions: list[DignityCondition] = [
        _condition(
            kind=DignityKind.DOMICILE,
            ruler_id=traditional_rulers(sign_id)[0],
            sign_id=sign_id,
            degree_in_sign=degree,
            table_ref=TRADITIONAL_RULERSHIP_TABLE_REF,
            rule_id=RULE_TRADITIONAL_RULERSHIP_V1,
        )
    ]
    exaltation_ruler = EXALTATION_RULER_BY_SIGN.get(sign_id)
    if exaltation_ruler is not None:
        conditions.append(
            _condition(
                kind=DignityKind.EXALTATION,
                ruler_id=exaltation_ruler,
                sign_id=sign_id,
                degree_in_sign=degree,
                table_ref=EXALTATION_TABLE_REF,
                rule_id=RULE_EXALTATION_V1,
            )
        )
    triplicity = DOROTHEAN_TRIPLICITIES[SIGN_ELEMENTS[sign_id]]
    for role in (TriplicityRole.DAY, TriplicityRole.NIGHT, TriplicityRole.PARTICIPATING):
        active = (
            role is TriplicityRole.PARTICIPATING
            or (role is TriplicityRole.DAY and sect is Sect.DAY)
            or (role is TriplicityRole.NIGHT and sect is Sect.NIGHT)
        )
        conditions.append(
            _condition(
                kind=DignityKind.TRIPLICITY,
                ruler_id=triplicity.ruler_for(role),
                sign_id=sign_id,
                degree_in_sign=degree,
                table_ref=DOROTHEAN_TRIPLICITY_TABLE_REF,
                rule_id=RULE_TRIPLICITY_V1,
                role=role,
                is_active_for_sect=active,
            )
        )
    term_id, _ = term_ruler(sign_id, degree)
    conditions.append(
        _condition(
            kind=DignityKind.TERM,
            ruler_id=term_id,
            sign_id=sign_id,
            degree_in_sign=degree,
            table_ref=EGYPTIAN_TERMS_TABLE_REF,
            rule_id=RULE_TERMS_V1,
        )
    )
    face_id, _ = face_ruler(sign_id, degree)
    conditions.append(
        _condition(
            kind=DignityKind.FACE,
            ruler_id=face_id,
            sign_id=sign_id,
            degree_in_sign=degree,
            table_ref=CHALDEAN_FACES_TABLE_REF,
            rule_id=RULE_FACES_V1,
        )
    )
    return tuple(conditions)


def evaluate_essential_dignity(
    point_id: str,
    longitude_deg: float,
    *,
    sect: Sect,
) -> EssentialDignityResult:
    sect = require_sect(sect)
    sign_id, degree = sign_and_degree(longitude_deg)
    rule_ids = (
        RULE_TRADITIONAL_RULERSHIP_V1,
        RULE_EXALTATION_V1,
        RULE_TRIPLICITY_V1,
        RULE_TERMS_V1,
        RULE_FACES_V1,
        RULE_DETRIMENT_V1,
        RULE_FALL_V1,
        RULE_PEREGRINE_V1,
    )
    source_ids = tuple(
        dict.fromkeys(
            source_id
            for table_ref in (
                TRADITIONAL_RULERSHIP_TABLE_REF,
                EXALTATION_TABLE_REF,
                DOROTHEAN_TRIPLICITY_TABLE_REF,
                EGYPTIAN_TERMS_TABLE_REF,
                CHALDEAN_FACES_TABLE_REF,
            )
            for source_id in table_ref.source_ids
        )
    )
    if point_id not in TRADITIONAL_PLANET_IDS:
        return EssentialDignityResult(
            point_id=point_id,
            longitude_deg=longitude_deg,
            sign_id=sign_id,
            degree_in_sign=degree,
            sect=sect,
            applicable=False,
            unavailable_reason="POINT_OUTSIDE_TRADITIONAL_SEVEN",
            profile_id=PROFILE_TRADITIONAL_ESSENTIAL_V1,
            dignities=(),
            debilities=(),
            peregrine=None,
            status_facts=(),
            algorithm_card_id=ALG_DIGNITY_RECEPTION,
            rule_ids=rule_ids,
            source_ids=source_ids,
            excluded_capabilities=("almuten", "dignity_score", "accidental_dignity"),
        )

    dignities = [
        condition
        for condition in dignity_rulers_at(longitude_deg, sect=sect)
        if condition.ruler_id == point_id
    ]
    debilities: list[DignityCondition] = []
    opposite = opposite_sign(sign_id)
    if point_id in traditional_rulers(opposite):
        debilities.append(
            _condition(
                kind=DignityKind.DETRIMENT,
                ruler_id=point_id,
                sign_id=sign_id,
                degree_in_sign=degree,
                table_ref=TRADITIONAL_RULERSHIP_TABLE_REF,
                rule_id=RULE_DETRIMENT_V1,
            )
        )
    if EXALTATION_RULER_BY_SIGN.get(opposite) == point_id:
        debilities.append(
            _condition(
                kind=DignityKind.FALL,
                ruler_id=point_id,
                sign_id=sign_id,
                degree_in_sign=degree,
                table_ref=EXALTATION_TABLE_REF,
                rule_id=RULE_FALL_V1,
            )
        )

    active_dignities = tuple(
        item
        for item in dignities
        if item.kind is not DignityKind.TRIPLICITY or item.is_active_for_sect is True
    )
    peregrine = not active_dignities
    status_facts = [
        *(
            _status_fact(item, polarity=EssentialStatusPolarity.DIGNITY)
            for item in dignities
        ),
        *(
            _status_fact(item, polarity=EssentialStatusPolarity.DEBILITY)
            for item in debilities
        ),
    ]
    if peregrine:
        status_facts.append(
            EssentialStatusFact(
                status_id=DignityKind.PEREGRINE,
                polarity=EssentialStatusPolarity.NEUTRAL,
                level=EssentialStatusLevel.DERIVED,
                active=True,
                label_key="classical.essential.peregrine",
                role=None,
                table_ref=None,
                rule_id=RULE_PEREGRINE_V1,
            )
        )
    return EssentialDignityResult(
        point_id=point_id,
        longitude_deg=longitude_deg,
        sign_id=sign_id,
        degree_in_sign=degree,
        sect=sect,
        applicable=True,
        unavailable_reason=None,
        profile_id=PROFILE_TRADITIONAL_ESSENTIAL_V1,
        dignities=tuple(dignities),
        debilities=tuple(debilities),
        peregrine=peregrine,
        status_facts=tuple(status_facts),
        algorithm_card_id=ALG_DIGNITY_RECEPTION,
        rule_ids=rule_ids,
        source_ids=source_ids,
        excluded_capabilities=("almuten", "dignity_score", "accidental_dignity"),
    )
