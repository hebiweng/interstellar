"""Immutable, versioned classical tables used by the pure calculation modules."""

from __future__ import annotations

import hashlib
import json
import math
from collections.abc import Mapping
from dataclasses import asdict, dataclass
from enum import StrEnum
from types import MappingProxyType
from typing import Any

from interstellar_core.astrology.classical.models import Sect, TableReference, TriplicityRole
from interstellar_core.astrology.classical.sources import (
    SRC_DOROTHEUS_CARMEN,
    SRC_INTERSTELLAR_MODERN_RULERSHIP_PROFILE,
    SRC_LILLY_CHRISTIAN_ASTROLOGY,
    SRC_PTOLEMY_TETRABIBLOS,
)
from interstellar_core.domain import DomainError

SIGN_IDS: tuple[str, ...] = (
    "aries",
    "taurus",
    "gemini",
    "cancer",
    "leo",
    "virgo",
    "libra",
    "scorpio",
    "sagittarius",
    "capricorn",
    "aquarius",
    "pisces",
)
TRADITIONAL_PLANET_IDS: tuple[str, ...] = (
    "sun",
    "moon",
    "mercury",
    "venus",
    "mars",
    "jupiter",
    "saturn",
)


class TermsTable(StrEnum):
    """Released term/bounds table variants accepted by the rule layer."""

    EGYPTIAN = "egyptian"
    PTOLEMAIC = "ptolemaic"


class TriplicityTable(StrEnum):
    """Released triplicity-ruler table variants accepted by the rule layer."""

    DOROTHEAN = "dorothean"
    PTOLEMAIC = "ptolemaic"

SIGN_ELEMENTS: Mapping[str, str] = MappingProxyType(
    {
        "aries": "fire",
        "taurus": "earth",
        "gemini": "air",
        "cancer": "water",
        "leo": "fire",
        "virgo": "earth",
        "libra": "air",
        "scorpio": "water",
        "sagittarius": "fire",
        "capricorn": "earth",
        "aquarius": "air",
        "pisces": "water",
    }
)


@dataclass(frozen=True, slots=True)
class TriplicityRulers:
    element: str
    day_ruler_id: str
    night_ruler_id: str
    participating_ruler_id: str | None

    def ruler_for(self, role: TriplicityRole) -> str | None:
        return {
            TriplicityRole.DAY: self.day_ruler_id,
            TriplicityRole.NIGHT: self.night_ruler_id,
            TriplicityRole.PARTICIPATING: self.participating_ruler_id,
        }[role]

    def active_ruler(self, sect: Sect) -> str:
        return self.day_ruler_id if sect is Sect.DAY else self.night_ruler_id


@dataclass(frozen=True, slots=True)
class TermInterval:
    start_deg: float
    end_deg: float
    ruler_id: str

    def contains(self, degree_in_sign: float) -> bool:
        return self.start_deg <= degree_in_sign < self.end_deg


def _content_hash(value: Any) -> str:
    def normalize(item: Any) -> Any:
        if hasattr(item, "__dataclass_fields__"):
            return normalize(asdict(item))
        if isinstance(item, Mapping):
            return {key: normalize(item[key]) for key in sorted(item)}
        if isinstance(item, tuple):
            return [normalize(child) for child in item]
        return item

    payload = json.dumps(normalize(value), sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode()).hexdigest()


TRADITIONAL_RULERS_BY_SIGN: Mapping[str, tuple[str, ...]] = MappingProxyType(
    {
        "aries": ("mars",),
        "taurus": ("venus",),
        "gemini": ("mercury",),
        "cancer": ("moon",),
        "leo": ("sun",),
        "virgo": ("mercury",),
        "libra": ("venus",),
        "scorpio": ("mars",),
        "sagittarius": ("jupiter",),
        "capricorn": ("saturn",),
        "aquarius": ("saturn",),
        "pisces": ("jupiter",),
    }
)

MODERN_RULERS_BY_SIGN: Mapping[str, tuple[str, ...]] = MappingProxyType(
    {
        **dict(TRADITIONAL_RULERS_BY_SIGN),
        "scorpio": ("mars", "pluto"),
        "aquarius": ("saturn", "uranus"),
        "pisces": ("jupiter", "neptune"),
    }
)

EXALTATION_RULER_BY_SIGN: Mapping[str, str] = MappingProxyType(
    {
        "aries": "sun",
        "taurus": "moon",
        "cancer": "jupiter",
        "virgo": "mercury",
        "libra": "saturn",
        "capricorn": "mars",
        "pisces": "venus",
    }
)

EXALTATION_DEGREE_BY_SIGN: Mapping[str, float] = MappingProxyType(
    {
        "aries": 19.0,
        "taurus": 3.0,
        "cancer": 15.0,
        "virgo": 15.0,
        "libra": 21.0,
        "capricorn": 28.0,
        "pisces": 27.0,
    }
)

DOROTHEAN_TRIPLICITIES: Mapping[str, TriplicityRulers] = MappingProxyType(
    {
        "fire": TriplicityRulers("fire", "sun", "jupiter", "saturn"),
        "earth": TriplicityRulers("earth", "venus", "moon", "mars"),
        "air": TriplicityRulers("air", "saturn", "mercury", "jupiter"),
        "water": TriplicityRulers("water", "venus", "mars", "moon"),
    }
)

# Ptolemy assigns only the two sect rulers to fire, earth and air. In water,
# Mars remains a co-ruler while Venus leads by day and the Moon by night.
# ``None`` is intentional: it prevents a Dorothean participating ruler from
# being silently invented when the Ptolemaic table is selected.
PTOLEMAIC_TRIPLICITIES: Mapping[str, TriplicityRulers] = MappingProxyType(
    {
        "fire": TriplicityRulers("fire", "sun", "jupiter", None),
        "earth": TriplicityRulers("earth", "venus", "moon", None),
        "air": TriplicityRulers("air", "saturn", "mercury", None),
        "water": TriplicityRulers("water", "venus", "moon", "mars"),
    }
)


def _term_intervals(*entries: tuple[float, str]) -> tuple[TermInterval, ...]:
    start = 0.0
    result = []
    for end, ruler in entries:
        result.append(TermInterval(start, float(end), ruler))
        start = float(end)
    if not math.isclose(start, 30.0):
        raise AssertionError("term intervals must end at 30 degrees")
    return tuple(result)


EGYPTIAN_TERMS: Mapping[str, tuple[TermInterval, ...]] = MappingProxyType(
    {
        "aries": _term_intervals(
            (6, "jupiter"), (14, "venus"), (21, "mercury"), (26, "mars"), (30, "saturn")
        ),
        "taurus": _term_intervals(
            (8, "venus"), (14, "mercury"), (22, "jupiter"), (27, "saturn"), (30, "mars")
        ),
        "gemini": _term_intervals(
            (6, "mercury"), (12, "jupiter"), (17, "venus"), (24, "mars"), (30, "saturn")
        ),
        "cancer": _term_intervals(
            (7, "mars"), (13, "venus"), (19, "mercury"), (26, "jupiter"), (30, "saturn")
        ),
        "leo": _term_intervals(
            (6, "jupiter"), (11, "venus"), (18, "saturn"), (24, "mercury"), (30, "mars")
        ),
        "virgo": _term_intervals(
            (7, "mercury"), (17, "venus"), (21, "jupiter"), (28, "mars"), (30, "saturn")
        ),
        "libra": _term_intervals(
            (6, "saturn"), (14, "mercury"), (21, "jupiter"), (28, "venus"), (30, "mars")
        ),
        "scorpio": _term_intervals(
            (7, "mars"), (11, "venus"), (19, "mercury"), (24, "jupiter"), (30, "saturn")
        ),
        "sagittarius": _term_intervals(
            (12, "jupiter"), (17, "venus"), (21, "mercury"), (26, "saturn"), (30, "mars")
        ),
        "capricorn": _term_intervals(
            (7, "mercury"), (14, "jupiter"), (22, "venus"), (26, "saturn"), (30, "mars")
        ),
        "aquarius": _term_intervals(
            (7, "mercury"), (13, "venus"), (20, "jupiter"), (25, "mars"), (30, "saturn")
        ),
        "pisces": _term_intervals(
            (12, "venus"), (16, "jupiter"), (19, "mercury"), (28, "mars"), (30, "saturn")
        ),
    }
)

# Tetrabiblos I.20-21 (Robbins numbering) / the table headed "Terms according
# to Ptolemy". Values below are cumulative interval endpoints. The transmitted
# Libra row's final ruler is Mars: a repeated Saturn would omit Mars and violate
# the table's five-planet allocation described immediately above the table.
PTOLEMAIC_TERMS: Mapping[str, tuple[TermInterval, ...]] = MappingProxyType(
    {
        "aries": _term_intervals(
            (6, "jupiter"), (14, "venus"), (21, "mercury"), (26, "mars"), (30, "saturn")
        ),
        "taurus": _term_intervals(
            (8, "venus"), (15, "mercury"), (22, "jupiter"), (24, "saturn"), (30, "mars")
        ),
        "gemini": _term_intervals(
            (7, "mercury"), (13, "jupiter"), (20, "venus"), (26, "mars"), (30, "saturn")
        ),
        "cancer": _term_intervals(
            (6, "mars"), (13, "jupiter"), (20, "mercury"), (27, "venus"), (30, "saturn")
        ),
        "leo": _term_intervals(
            (6, "jupiter"), (13, "mercury"), (19, "saturn"), (25, "venus"), (30, "mars")
        ),
        "virgo": _term_intervals(
            (7, "mercury"), (13, "venus"), (18, "jupiter"), (24, "saturn"), (30, "mars")
        ),
        "libra": _term_intervals(
            (6, "saturn"), (11, "venus"), (16, "mercury"), (24, "jupiter"), (30, "mars")
        ),
        "scorpio": _term_intervals(
            (6, "mars"), (13, "venus"), (21, "jupiter"), (27, "mercury"), (30, "saturn")
        ),
        "sagittarius": _term_intervals(
            (8, "jupiter"), (14, "venus"), (19, "mercury"), (25, "saturn"), (30, "mars")
        ),
        "capricorn": _term_intervals(
            (6, "venus"), (12, "mercury"), (19, "jupiter"), (25, "saturn"), (30, "mars")
        ),
        "aquarius": _term_intervals(
            (6, "saturn"), (12, "mercury"), (20, "venus"), (25, "jupiter"), (30, "mars")
        ),
        "pisces": _term_intervals(
            (8, "venus"), (14, "jupiter"), (20, "mercury"), (25, "mars"), (30, "saturn")
        ),
    }
)

CHALDEAN_FACE_RULERS: Mapping[str, tuple[str, str, str]] = MappingProxyType(
    {
        "aries": ("mars", "sun", "venus"),
        "taurus": ("mercury", "moon", "saturn"),
        "gemini": ("jupiter", "mars", "sun"),
        "cancer": ("venus", "mercury", "moon"),
        "leo": ("saturn", "jupiter", "mars"),
        "virgo": ("sun", "venus", "mercury"),
        "libra": ("moon", "saturn", "jupiter"),
        "scorpio": ("mars", "sun", "venus"),
        "sagittarius": ("mercury", "moon", "saturn"),
        "capricorn": ("jupiter", "mars", "sun"),
        "aquarius": ("venus", "mercury", "moon"),
        "pisces": ("saturn", "jupiter", "mars"),
    }
)

TRADITIONAL_RULERSHIP_TABLE_REF = TableReference(
    "table.rulership.traditional_seven",
    "1.0.0",
    (SRC_PTOLEMY_TETRABIBLOS, SRC_LILLY_CHRISTIAN_ASTROLOGY),
    _content_hash(TRADITIONAL_RULERS_BY_SIGN),
)
MODERN_RULERSHIP_TABLE_REF = TableReference(
    "table.rulership.modern_corulers",
    "1.0.0",
    (SRC_INTERSTELLAR_MODERN_RULERSHIP_PROFILE,),
    _content_hash(MODERN_RULERS_BY_SIGN),
)
EXALTATION_TABLE_REF = TableReference(
    "table.exaltation.ptolemaic",
    "1.0.0",
    (SRC_PTOLEMY_TETRABIBLOS, SRC_LILLY_CHRISTIAN_ASTROLOGY),
    _content_hash({"rulers": EXALTATION_RULER_BY_SIGN, "degrees": EXALTATION_DEGREE_BY_SIGN}),
)
DOROTHEAN_TRIPLICITY_TABLE_REF = TableReference(
    "table.triplicity.dorothean",
    "1.0.0",
    (SRC_DOROTHEUS_CARMEN,),
    _content_hash(DOROTHEAN_TRIPLICITIES),
)
PTOLEMAIC_TRIPLICITY_TABLE_REF = TableReference(
    "table.triplicity.ptolemaic",
    "1.0.0",
    (SRC_PTOLEMY_TETRABIBLOS,),
    _content_hash(PTOLEMAIC_TRIPLICITIES),
)
EGYPTIAN_TERMS_TABLE_REF = TableReference(
    "table.terms.egyptian",
    "1.0.0",
    (SRC_PTOLEMY_TETRABIBLOS, SRC_LILLY_CHRISTIAN_ASTROLOGY),
    _content_hash(EGYPTIAN_TERMS),
)
PTOLEMAIC_TERMS_TABLE_REF = TableReference(
    "table.terms.ptolemaic",
    "1.0.0",
    (SRC_PTOLEMY_TETRABIBLOS,),
    _content_hash(PTOLEMAIC_TERMS),
)
CHALDEAN_FACES_TABLE_REF = TableReference(
    "table.faces.chaldean",
    "1.0.0",
    (SRC_PTOLEMY_TETRABIBLOS, SRC_LILLY_CHRISTIAN_ASTROLOGY),
    _content_hash(CHALDEAN_FACE_RULERS),
)


def sign_and_degree(longitude_deg: float) -> tuple[str, float]:
    if not math.isfinite(longitude_deg) or not 0 <= longitude_deg < 360:
        raise DomainError(
            "CLASSICAL_LONGITUDE_INVALID",
            "longitude must be finite, at least 0 degrees, and less than 360 degrees",
        )
    index = int(longitude_deg // 30)
    return SIGN_IDS[index], longitude_deg - index * 30


def opposite_sign(sign_id: str) -> str:
    try:
        return SIGN_IDS[(SIGN_IDS.index(sign_id) + 6) % 12]
    except ValueError as exc:
        raise DomainError("CLASSICAL_SIGN_UNKNOWN", f"unknown sign id: {sign_id}") from exc


def terms_table_data(
    terms_table: TermsTable,
) -> tuple[Mapping[str, tuple[TermInterval, ...]], TableReference]:
    if not isinstance(terms_table, TermsTable):
        raise DomainError(
            "CLASSICAL_TERMS_TABLE_INVALID",
            "terms_table must be a released TermsTable value",
        )
    return {
        TermsTable.EGYPTIAN: (EGYPTIAN_TERMS, EGYPTIAN_TERMS_TABLE_REF),
        TermsTable.PTOLEMAIC: (PTOLEMAIC_TERMS, PTOLEMAIC_TERMS_TABLE_REF),
    }[terms_table]


def triplicity_table_data(
    triplicity_table: TriplicityTable,
) -> tuple[Mapping[str, TriplicityRulers], TableReference]:
    if not isinstance(triplicity_table, TriplicityTable):
        raise DomainError(
            "CLASSICAL_TRIPLICITY_TABLE_INVALID",
            "triplicity_table must be a released TriplicityTable value",
        )
    return {
        TriplicityTable.DOROTHEAN: (
            DOROTHEAN_TRIPLICITIES,
            DOROTHEAN_TRIPLICITY_TABLE_REF,
        ),
        TriplicityTable.PTOLEMAIC: (
            PTOLEMAIC_TRIPLICITIES,
            PTOLEMAIC_TRIPLICITY_TABLE_REF,
        ),
    }[triplicity_table]


def term_ruler(
    sign_id: str,
    degree_in_sign: float,
    *,
    terms_table: TermsTable = TermsTable.EGYPTIAN,
) -> tuple[str, TermInterval]:
    terms, _ = terms_table_data(terms_table)
    if sign_id not in terms:
        raise DomainError("CLASSICAL_SIGN_UNKNOWN", f"unknown sign id: {sign_id}")
    if not math.isfinite(degree_in_sign) or not 0 <= degree_in_sign < 30:
        raise DomainError(
            "CLASSICAL_SIGN_DEGREE_INVALID",
            "degree in sign must be finite, at least 0 degrees, and less than 30 degrees",
        )
    interval = next(item for item in terms[sign_id] if item.contains(degree_in_sign))
    return interval.ruler_id, interval


def face_ruler(sign_id: str, degree_in_sign: float) -> tuple[str, int]:
    if sign_id not in CHALDEAN_FACE_RULERS:
        raise DomainError("CLASSICAL_SIGN_UNKNOWN", f"unknown sign id: {sign_id}")
    if not math.isfinite(degree_in_sign) or not 0 <= degree_in_sign < 30:
        raise DomainError(
            "CLASSICAL_SIGN_DEGREE_INVALID",
            "degree in sign must be finite, at least 0 degrees, and less than 30 degrees",
        )
    index = min(int(degree_in_sign // 10), 2)
    return CHALDEAN_FACE_RULERS[sign_id][index], index + 1
