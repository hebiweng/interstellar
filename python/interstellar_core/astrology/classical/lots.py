"""Locked sect-aware Lots from the Paulus/Hermetic formula family.

The module intentionally implements only formulas whose variant is explicit in
the registry. Other named Lots remain blocked rather than being inferred from a
competitor result or from a different historical tradition.
"""

from __future__ import annotations

from interstellar_core.astrology.classical.models import LotId, LotOperand, LotResult, Sect
from interstellar_core.astrology.classical.sect import require_sect
from interstellar_core.astrology.classical.sources import (
    ALG_ARABIC_PARTS,
    RULE_BASIS_V1,
    RULE_COURAGE_V1,
    RULE_EROS_V1,
    RULE_EXALTATION_V1,
    RULE_FORTUNE_V1,
    RULE_NECESSITY_V1,
    RULE_NEMESIS_V1,
    RULE_SPIRIT_V1,
    RULE_VICTORY_V1,
    SRC_PAULUS_INTRODUCTORY_MATTERS,
    SRC_ROBERT_HAND_LOT_OF_BASIS,
)
from interstellar_core.astrology.classical.tables import sign_and_degree


def _lot(
    *,
    lot_id: LotId,
    formula_id: str,
    formula_expression: str,
    operands: tuple[LotOperand, ...],
    sect: Sect,
    rule_id: str,
) -> LotResult:
    longitude = sum(item.longitude_deg * item.coefficient for item in operands) % 360.0
    sign_id, degree = sign_and_degree(longitude)
    return LotResult(
        lot_id=lot_id,
        longitude_deg=longitude,
        sign_id=sign_id,
        degree_in_sign=degree,
        sect=sect,
        formula_id=formula_id,
        formula_version="1.0.0",
        formula_expression=formula_expression,
        operands=operands,
        algorithm_card_id=ALG_ARABIC_PARTS,
        rule_ids=(rule_id,),
        source_ids=(SRC_PAULUS_INTRODUCTORY_MATTERS,),
        excluded_capabilities=(
            "lot_house_assignment",
            "lot_rulership",
            "lot_aspects",
            "additional_lots",
        ),
    )


def calculate_fortune_and_spirit(
    *,
    asc_longitude_deg: float,
    sun_longitude_deg: float,
    moon_longitude_deg: float,
    sect: Sect,
) -> tuple[LotResult, LotResult]:
    sect = require_sect(sect)
    for longitude in (asc_longitude_deg, sun_longitude_deg, moon_longitude_deg):
        sign_and_degree(longitude)
    if sect is Sect.DAY:
        fortune_expression = "ASC + Moon - Sun"
        fortune_operands = (
            LotOperand("asc", asc_longitude_deg, 1),
            LotOperand("moon", moon_longitude_deg, 1),
            LotOperand("sun", sun_longitude_deg, -1),
        )
        spirit_expression = "ASC + Sun - Moon"
        spirit_operands = (
            LotOperand("asc", asc_longitude_deg, 1),
            LotOperand("sun", sun_longitude_deg, 1),
            LotOperand("moon", moon_longitude_deg, -1),
        )
    else:
        fortune_expression = "ASC + Sun - Moon"
        fortune_operands = (
            LotOperand("asc", asc_longitude_deg, 1),
            LotOperand("sun", sun_longitude_deg, 1),
            LotOperand("moon", moon_longitude_deg, -1),
        )
        spirit_expression = "ASC + Moon - Sun"
        spirit_operands = (
            LotOperand("asc", asc_longitude_deg, 1),
            LotOperand("moon", moon_longitude_deg, 1),
            LotOperand("sun", sun_longitude_deg, -1),
        )
    return (
        _lot(
            lot_id=LotId.FORTUNE,
            formula_id="lot.fortune.paulus.v1",
            formula_expression=fortune_expression,
            operands=fortune_operands,
            sect=sect,
            rule_id=RULE_FORTUNE_V1,
        ),
        _lot(
            lot_id=LotId.SPIRIT,
            formula_id="lot.spirit.paulus.v1",
            formula_expression=spirit_expression,
            operands=spirit_operands,
            sect=sect,
            rule_id=RULE_SPIRIT_V1,
        ),
    )


def _reversible_lot(
    *,
    lot_id: LotId,
    formula_id: str,
    rule_id: str,
    asc_longitude_deg: float,
    positive_point_id: str,
    positive_longitude_deg: float,
    negative_point_id: str,
    negative_longitude_deg: float,
    sect: Sect,
) -> LotResult:
    """Calculate ``ASC + positive - negative`` by day and reverse by night."""

    if sect is Sect.DAY:
        expression = f"ASC + {positive_point_id.title()} - {negative_point_id.title()}"
        operands = (
            LotOperand("asc", asc_longitude_deg, 1),
            LotOperand(positive_point_id, positive_longitude_deg, 1),
            LotOperand(negative_point_id, negative_longitude_deg, -1),
        )
    else:
        expression = f"ASC + {negative_point_id.title()} - {positive_point_id.title()}"
        operands = (
            LotOperand("asc", asc_longitude_deg, 1),
            LotOperand(negative_point_id, negative_longitude_deg, 1),
            LotOperand(positive_point_id, positive_longitude_deg, -1),
        )
    return _lot(
        lot_id=lot_id,
        formula_id=formula_id,
        formula_expression=expression,
        operands=operands,
        sect=sect,
        rule_id=rule_id,
    )


def calculate_supported_lots(
    *,
    asc_longitude_deg: float,
    sun_longitude_deg: float,
    moon_longitude_deg: float,
    mercury_longitude_deg: float,
    venus_longitude_deg: float,
    mars_longitude_deg: float,
    jupiter_longitude_deg: float,
    saturn_longitude_deg: float,
    sect: Sect,
) -> tuple[LotResult, ...]:
    """Calculate the nine released, versioned sect-aware Lots.

    Fortune and Spirit are calculated first because the five planetary Lots
    and Basis use them as formula operands. Basis uses the signed shorter arc
    from Fortune to Spirit, a version which must not be silently exchanged for
    a simple sect reversal. Exaltation uses the sect light's traditional degree
    of exaltation: 19 Aries by day and 3 Taurus by night.
    """

    sect = require_sect(sect)
    supplied = (
        asc_longitude_deg,
        sun_longitude_deg,
        moon_longitude_deg,
        mercury_longitude_deg,
        venus_longitude_deg,
        mars_longitude_deg,
        jupiter_longitude_deg,
        saturn_longitude_deg,
    )
    for longitude in supplied:
        sign_and_degree(longitude)

    fortune, spirit = calculate_fortune_and_spirit(
        asc_longitude_deg=asc_longitude_deg,
        sun_longitude_deg=sun_longitude_deg,
        moon_longitude_deg=moon_longitude_deg,
        sect=sect,
    )
    fortune_to_spirit_arc = (spirit.longitude_deg - fortune.longitude_deg) % 360
    if fortune_to_spirit_arc > 180:
        fortune_to_spirit_arc -= 360
    basis_operands = (
        LotOperand("asc", asc_longitude_deg, 1),
        LotOperand("fortune_to_spirit_shorter_arc", fortune_to_spirit_arc, 1),
    )
    basis_longitude = sum(item.longitude_deg * item.coefficient for item in basis_operands) % 360
    basis_sign, basis_degree = sign_and_degree(basis_longitude)
    basis = LotResult(
        lot_id=LotId.BASIS,
        longitude_deg=basis_longitude,
        sign_id=basis_sign,
        degree_in_sign=basis_degree,
        sect=sect,
        formula_id="lot.basis.hand_shorter_arc.v1",
        formula_version="1.0.0",
        formula_expression="ASC + signed shorter arc Fortune to Spirit",
        operands=basis_operands,
        algorithm_card_id=ALG_ARABIC_PARTS,
        rule_ids=(RULE_BASIS_V1,),
        source_ids=(SRC_ROBERT_HAND_LOT_OF_BASIS,),
        excluded_capabilities=(
            "alternative_basis_formulas",
            "lot_house_assignment",
            "lot_rulership",
            "lot_aspects",
        ),
    )
    eros = _reversible_lot(
        lot_id=LotId.EROS,
        formula_id="lot.eros.paulus.v1",
        rule_id=RULE_EROS_V1,
        asc_longitude_deg=asc_longitude_deg,
        positive_point_id="venus",
        positive_longitude_deg=venus_longitude_deg,
        negative_point_id="spirit",
        negative_longitude_deg=spirit.longitude_deg,
        sect=sect,
    )
    necessity = _reversible_lot(
        lot_id=LotId.NECESSITY,
        formula_id="lot.necessity.paulus.v1",
        rule_id=RULE_NECESSITY_V1,
        asc_longitude_deg=asc_longitude_deg,
        positive_point_id="fortune",
        positive_longitude_deg=fortune.longitude_deg,
        negative_point_id="mercury",
        negative_longitude_deg=mercury_longitude_deg,
        sect=sect,
    )
    courage = _reversible_lot(
        lot_id=LotId.COURAGE,
        formula_id="lot.courage.paulus.v1",
        rule_id=RULE_COURAGE_V1,
        asc_longitude_deg=asc_longitude_deg,
        positive_point_id="fortune",
        positive_longitude_deg=fortune.longitude_deg,
        negative_point_id="mars",
        negative_longitude_deg=mars_longitude_deg,
        sect=sect,
    )
    victory = _reversible_lot(
        lot_id=LotId.VICTORY,
        formula_id="lot.victory.paulus.v1",
        rule_id=RULE_VICTORY_V1,
        asc_longitude_deg=asc_longitude_deg,
        positive_point_id="jupiter",
        positive_longitude_deg=jupiter_longitude_deg,
        negative_point_id="spirit",
        negative_longitude_deg=spirit.longitude_deg,
        sect=sect,
    )
    nemesis = _reversible_lot(
        lot_id=LotId.NEMESIS,
        formula_id="lot.nemesis.paulus.v1",
        rule_id=RULE_NEMESIS_V1,
        asc_longitude_deg=asc_longitude_deg,
        positive_point_id="fortune",
        positive_longitude_deg=fortune.longitude_deg,
        negative_point_id="saturn",
        negative_longitude_deg=saturn_longitude_deg,
        sect=sect,
    )

    if sect is Sect.DAY:
        exaltation_expression = "ASC + 19 Aries - Sun"
        exaltation_operands = (
            LotOperand("asc", asc_longitude_deg, 1),
            LotOperand("aries_19_deg", 19.0, 1),
            LotOperand("sun", sun_longitude_deg, -1),
        )
    else:
        exaltation_expression = "ASC + 3 Taurus - Moon"
        exaltation_operands = (
            LotOperand("asc", asc_longitude_deg, 1),
            LotOperand("taurus_3_deg", 33.0, 1),
            LotOperand("moon", moon_longitude_deg, -1),
        )
    exaltation = _lot(
        lot_id=LotId.EXALTATION,
        formula_id="lot.exaltation.paulus.v1",
        formula_expression=exaltation_expression,
        operands=exaltation_operands,
        sect=sect,
        rule_id=RULE_EXALTATION_V1,
    )
    return (
        fortune,
        spirit,
        basis,
        exaltation,
        eros,
        necessity,
        courage,
        victory,
        nemesis,
    )
