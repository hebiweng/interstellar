"""Versioned registry for the professional natal point projection.

The registry separates three concerns which must never be conflated:

* a point name used by a product or historical tradition;
* a locked, reproducible calculation formula;
* whether the datasets required by that formula are shipped in this build.

Entries marked ``blocked`` are intentional capability records, not calculated
facts.  They make missing competitor-parity points auditable without inventing
an unverified formula or silently substituting another object.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import asdict, dataclass
from typing import Literal

Maturity = Literal["stable", "beta", "experimental"]
Availability = Literal["available", "blocked"]
CalculationMode = Literal[
    "swiss_ephemeris",
    "swiss_hypothetical",
    "derived",
    "sect_formula",
    "external_ephemeris",
    "unresolved",
]

SRC_SWISS_PROGRAMMING = "source.swiss_ephemeris.programming_manual"
SRC_SWISS_HYPOTHETICAL = "source.swiss_ephemeris.hypothetical_planets"
SRC_MPC_ORBITS = "source.minor_planet_center.orbits"
SRC_PAULUS_INTRODUCTORY_MATTERS = "source.paulus.introductory_matters"
SRC_ROBERT_HAND_LOT_OF_BASIS = "source.robert_hand.lot_or_part_of_fortune"


def _content_hash(payload: object) -> str:
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


@dataclass(frozen=True, slots=True)
class FormulaRegistryEntry:
    formula_ref: str
    version: str
    expression: str
    operand_ids: tuple[str, ...]
    source_refs: tuple[str, ...]
    maturity: Maturity
    notes: str

    def __post_init__(self) -> None:
        if not self.formula_ref or not self.version or not self.expression:
            raise ValueError("formula reference, version and expression are required")
        if not self.source_refs:
            raise ValueError("a released formula must cite at least one source")

    @property
    def content_hash(self) -> str:
        return _content_hash(asdict(self))


@dataclass(frozen=True, slots=True)
class SourceRegistryEntry:
    source_ref: str
    title: str
    uri: str
    source_kind: Literal["official_documentation", "primary_text", "published_method"]

    @property
    def content_hash(self) -> str:
        return _content_hash(asdict(self))


@dataclass(frozen=True, slots=True)
class PointRegistryEntry:
    point_id: str
    label_zh: str
    category: str
    calculation_mode: CalculationMode
    availability: Availability
    formula_ref: str | None
    catalog_object_ref: str | None
    source_refs: tuple[str, ...]
    maturity: Maturity
    requirements: tuple[str, ...] = ()
    blocked_reason: str | None = None

    def __post_init__(self) -> None:
        if not self.point_id or not self.label_zh or not self.category:
            raise ValueError("point id, label and category are required")
        if self.availability == "available":
            if not self.formula_ref or not self.source_refs:
                raise ValueError(
                    f"available point {self.point_id} requires formula and source refs"
                )
            if self.blocked_reason is not None:
                raise ValueError(f"available point {self.point_id} cannot have a block reason")
        elif not self.blocked_reason:
            raise ValueError(f"blocked point {self.point_id} requires a block reason")

    @property
    def content_hash(self) -> str:
        return _content_hash(asdict(self))


def _formula(
    formula_ref: str,
    expression: str,
    operand_ids: tuple[str, ...],
    *,
    source_refs: tuple[str, ...] = (SRC_PAULUS_INTRODUCTORY_MATTERS,),
    maturity: Maturity = "beta",
    notes: str = "",
) -> FormulaRegistryEntry:
    return FormulaRegistryEntry(
        formula_ref=formula_ref,
        version="1.0.0",
        expression=expression,
        operand_ids=operand_ids,
        source_refs=source_refs,
        maturity=maturity,
        notes=notes,
    )


SOURCE_REGISTRY: dict[str, SourceRegistryEntry] = {
    item.source_ref: item
    for item in (
        SourceRegistryEntry(
            SRC_SWISS_PROGRAMMING,
            "Swiss Ephemeris Programming Interface 2.10",
            "https://www.astro.com/ftp/swisseph/doc/swephprg.2.10.pdf",
            "official_documentation",
        ),
        SourceRegistryEntry(
            SRC_SWISS_HYPOTHETICAL,
            "Swiss Ephemeris hypothetical planets list",
            "https://www.astro.com/swisseph/hyplist.htm",
            "official_documentation",
        ),
        SourceRegistryEntry(
            SRC_MPC_ORBITS,
            "Minor Planet Center data services",
            "https://minorplanetcenter.net/data",
            "official_documentation",
        ),
        SourceRegistryEntry(
            SRC_PAULUS_INTRODUCTORY_MATTERS,
            "Paulus Alexandrinus, Introductory Matters",
            "urn:bibliography:paulus-alexandrinus:introductory-matters",
            "primary_text",
        ),
        SourceRegistryEntry(
            SRC_ROBERT_HAND_LOT_OF_BASIS,
            "Robert Hand, The Lot or Part of Fortune",
            "https://www.astro.com/astrology/in_fortune_g.htm",
            "published_method",
        ),
    )
}


FORMULA_REGISTRY: dict[str, FormulaRegistryEntry] = {
    item.formula_ref: item
    for item in (
        _formula(
            "ephemeris.swiss.geocentric_apparent.v1",
            "Swiss Ephemeris geocentric apparent position of date",
            ("julian_day_ut", "swiss_object_id"),
            source_refs=(SRC_SWISS_PROGRAMMING,),
            maturity="beta",
        ),
        _formula(
            "ephemeris.swiss.hypothetical_orbit.v1",
            "Swiss Ephemeris built-in Hamburg hypothetical orbital elements",
            ("julian_day_ut", "swiss_hypothetical_id"),
            source_refs=(SRC_SWISS_HYPOTHETICAL, SRC_SWISS_PROGRAMMING),
            maturity="experimental",
            notes="Hamburg TNPs are hypothetical points, not observed physical bodies.",
        ),
        _formula(
            "node.true.opposition.v1",
            "true north node + 180 degrees",
            ("true_north_node",),
            source_refs=(SRC_SWISS_PROGRAMMING,),
        ),
        _formula(
            "node.mean.opposition.v1",
            "mean north node + 180 degrees",
            ("mean_north_node",),
            source_refs=(SRC_SWISS_PROGRAMMING,),
        ),
        _formula(
            "angle.ascendant.swiss.v1",
            "Swiss houses_ex ascendant",
            ("julian_day_ut", "latitude", "longitude", "house_system"),
            source_refs=(SRC_SWISS_PROGRAMMING,),
        ),
        _formula(
            "angle.descendant.opposition.v1",
            "ascendant + 180 degrees",
            ("asc",),
            source_refs=(SRC_SWISS_PROGRAMMING,),
        ),
        _formula(
            "angle.midheaven.swiss.v1",
            "Swiss houses_ex midheaven",
            ("julian_day_ut", "latitude", "longitude", "house_system"),
            source_refs=(SRC_SWISS_PROGRAMMING,),
        ),
        _formula(
            "angle.imum_coeli.opposition.v1",
            "midheaven + 180 degrees",
            ("mc",),
            source_refs=(SRC_SWISS_PROGRAMMING,),
        ),
        _formula(
            "angle.vertex.swiss.v1",
            "Swiss houses_ex vertex",
            ("julian_day_ut", "latitude", "longitude"),
            source_refs=(SRC_SWISS_PROGRAMMING,),
        ),
        _formula(
            "angle.anti_vertex.opposition.v1",
            "vertex + 180 degrees",
            ("vertex",),
            source_refs=(SRC_SWISS_PROGRAMMING,),
        ),
        _formula(
            "angle.east_point.swiss.v1",
            "Swiss houses_ex equatorial ascendant",
            ("julian_day_ut", "latitude", "longitude"),
            source_refs=(SRC_SWISS_PROGRAMMING,),
        ),
        _formula(
            "angle.west_point.opposition.v1",
            "east point + 180 degrees",
            ("east_point",),
            source_refs=(SRC_SWISS_PROGRAMMING,),
        ),
        _formula(
            "lot.fortune.paulus.v1", "day ASC + Moon - Sun; night reverse", ("asc", "sun", "moon")
        ),
        _formula(
            "lot.spirit.paulus.v1", "day ASC + Sun - Moon; night reverse", ("asc", "sun", "moon")
        ),
        _formula(
            "lot.eros.paulus.v1",
            "day ASC + Venus - Spirit; night reverse",
            ("asc", "venus", "spirit"),
        ),
        _formula(
            "lot.necessity.paulus.v1",
            "day ASC + Fortune - Mercury; night reverse",
            ("asc", "fortune", "mercury"),
        ),
        _formula(
            "lot.courage.paulus.v1",
            "day ASC + Fortune - Mars; night reverse",
            ("asc", "fortune", "mars"),
        ),
        _formula(
            "lot.victory.paulus.v1",
            "day ASC + Jupiter - Spirit; night reverse",
            ("asc", "jupiter", "spirit"),
        ),
        _formula(
            "lot.nemesis.paulus.v1",
            "day ASC + Fortune - Saturn; night reverse",
            ("asc", "fortune", "saturn"),
        ),
        _formula(
            "lot.exaltation.paulus.v1",
            "day ASC + 19 Aries - Sun; night ASC + 3 Taurus - Moon",
            ("asc", "sun", "moon", "exaltation_reference"),
            maturity="experimental",
            notes="Sect-specific luminary exaltation degree formula; kept experimental.",
        ),
        _formula(
            "lot.basis.hand_shorter_arc.v1",
            "ASC + signed shorter arc from Fortune to Spirit",
            ("asc", "fortune", "spirit"),
            source_refs=(SRC_ROBERT_HAND_LOT_OF_BASIS,),
            maturity="experimental",
            notes=("A locked shorter-arc variant; alternative Basis formulas remain excluded."),
        ),
    )
}


def _point(
    point_id: str,
    label_zh: str,
    category: str,
    mode: CalculationMode,
    formula_ref: str,
    *,
    catalog: str | None = None,
    source_refs: tuple[str, ...] = (SRC_SWISS_PROGRAMMING,),
    maturity: Maturity = "beta",
) -> PointRegistryEntry:
    return PointRegistryEntry(
        point_id=point_id,
        label_zh=label_zh,
        category=category,
        calculation_mode=mode,
        availability="available",
        formula_ref=formula_ref,
        catalog_object_ref=catalog,
        source_refs=source_refs,
        maturity=maturity,
    )


def _blocked(
    point_id: str,
    label_zh: str,
    category: str,
    reason: str,
    *,
    mode: CalculationMode = "unresolved",
    catalog: str | None = None,
    source_refs: tuple[str, ...] = (),
    requirements: tuple[str, ...] = (),
) -> PointRegistryEntry:
    return PointRegistryEntry(
        point_id=point_id,
        label_zh=label_zh,
        category=category,
        calculation_mode=mode,
        availability="blocked",
        formula_ref=None,
        catalog_object_ref=catalog,
        source_refs=source_refs,
        maturity="experimental",
        requirements=requirements,
        blocked_reason=reason,
    )


_DIRECT_LABELS = (
    ("sun", "太阳", "luminary"),
    ("moon", "月亮", "luminary"),
    ("mercury", "水星", "planet"),
    ("venus", "金星", "planet"),
    ("mars", "火星", "planet"),
    ("jupiter", "木星", "planet"),
    ("saturn", "土星", "planet"),
    ("uranus", "天王星", "planet"),
    ("neptune", "海王星", "planet"),
    ("pluto", "冥王星", "dwarf_planet"),
)

_LOT_FORMULAS = {
    "fortune": "lot.fortune.paulus.v1",
    "spirit": "lot.spirit.paulus.v1",
    "lot_eros": "lot.eros.paulus.v1",
    "lot_necessity": "lot.necessity.paulus.v1",
    "lot_courage": "lot.courage.paulus.v1",
    "lot_victory": "lot.victory.paulus.v1",
    "lot_nemesis": "lot.nemesis.paulus.v1",
    "lot_exaltation": "lot.exaltation.paulus.v1",
    "lot_basis": "lot.basis.hand_shorter_arc.v1",
}

_BLOCKED_LOTS = (
    ("lot_commodities", "商品点"),
    ("lot_wealth", "财富点"),
    ("lot_marriage", "婚姻点"),
    ("lot_male_marriage", "男性婚姻点"),
    ("lot_female_marriage", "女性婚姻点"),
    ("lot_divorce", "离婚点"),
    ("lot_sons", "儿子点"),
    ("lot_daughters", "女儿点"),
    ("lot_father", "父亲点"),
    ("lot_mother", "母亲点"),
    ("lot_faith", "信仰点"),
    ("lot_siblings", "兄弟姐妹点"),
    ("lot_love", "爱情点"),
    ("lot_inheritance", "遗产点"),
    ("lot_illness", "疾病点"),
    ("lot_treachery", "背叛点"),
    ("lot_games", "游戏点"),
    ("lot_danger", "危险点"),
    ("lot_death", "死亡点"),
)

_TNP_LABELS = (
    ("cupido", "丘比特", "swiss:h40"),
    ("hades", "哈迪斯", "swiss:h41"),
    ("zeus", "宙斯", "swiss:h42"),
    ("kronos", "克罗诺斯", "swiss:h43"),
    ("apollon", "阿波罗", "swiss:h44"),
    ("admetos", "阿德墨托斯", "swiss:h45"),
    ("vulkanus", "伏尔甘", "swiss:h46"),
    ("poseidon", "波塞冬", "swiss:h47"),
)


_competitor_entries: list[PointRegistryEntry] = [
    *[
        _point(
            point_id, label, category, "swiss_ephemeris", "ephemeris.swiss.geocentric_apparent.v1"
        )
        for point_id, label, category in _DIRECT_LABELS
    ],
    _point("asc", "上升", "angle", "derived", "angle.ascendant.swiss.v1"),
    _point("ic", "天底", "angle", "derived", "angle.imum_coeli.opposition.v1"),
    _point("dsc", "下降", "angle", "derived", "angle.descendant.opposition.v1"),
    _point("mc", "天顶", "angle", "derived", "angle.midheaven.swiss.v1"),
    _point(
        "true_north_node",
        "北交点",
        "node",
        "swiss_ephemeris",
        "ephemeris.swiss.geocentric_apparent.v1",
    ),
    _point("true_south_node", "南交点", "node", "derived", "node.true.opposition.v1"),
    _point("vertex", "宿命点", "angle", "derived", "angle.vertex.swiss.v1"),
    _point("east_point", "东点", "angle", "derived", "angle.east_point.swiss.v1"),
    *[
        _point(
            point_id,
            label,
            "lot",
            "sect_formula",
            _LOT_FORMULAS[point_id],
            source_refs=(
                (SRC_ROBERT_HAND_LOT_OF_BASIS,)
                if point_id == "lot_basis"
                else (SRC_PAULUS_INTRODUCTORY_MATTERS,)
            ),
            maturity=("experimental" if point_id in {"lot_exaltation", "lot_basis"} else "beta"),
        )
        for point_id, label in (
            ("fortune", "福点"),
            ("spirit", "精神点"),
            ("lot_basis", "基础点"),
            ("lot_exaltation", "擢升点"),
            ("lot_eros", "爱欲点"),
            ("lot_necessity", "必然点"),
            ("lot_courage", "勇气点"),
            ("lot_victory", "胜利点"),
            ("lot_nemesis", "报应点"),
        )
    ],
    *[
        _blocked(
            point_id,
            label,
            "lot",
            "published traditions use multiple non-equivalent formulas; "
            "a source-and-variant decision is not locked",
            requirements=("versioned_formula_variant", "primary_source_review"),
        )
        for point_id, label in _BLOCKED_LOTS
    ],
    _point(
        "mean_lilith",
        "莉莉丝",
        "lunar_point",
        "swiss_ephemeris",
        "ephemeris.swiss.geocentric_apparent.v1",
    ),
    _blocked(
        "zi_qi", "紫炁", "traditional_point", "no authoritative Western-astrology formula is locked"
    ),
    _blocked(
        "syzygy",
        "朔望点",
        "event_point",
        "prenatal syzygy requires a separately versioned lunation search "
        "and new/full-moon selection rule",
        requirements=("lunation_event_search", "syzygy_variant"),
    ),
    _point(
        "chiron",
        "凯龙星",
        "centaur",
        "swiss_ephemeris",
        "ephemeris.swiss.geocentric_apparent.v1",
        catalog="mpc:2060",
    ),
    _point(
        "ceres",
        "谷神星",
        "asteroid",
        "swiss_ephemeris",
        "ephemeris.swiss.geocentric_apparent.v1",
        catalog="mpc:1",
    ),
    _point(
        "pallas",
        "智神星",
        "asteroid",
        "swiss_ephemeris",
        "ephemeris.swiss.geocentric_apparent.v1",
        catalog="mpc:2",
    ),
    _point(
        "juno",
        "婚神星",
        "asteroid",
        "swiss_ephemeris",
        "ephemeris.swiss.geocentric_apparent.v1",
        catalog="mpc:3",
    ),
    _point(
        "vesta",
        "灶神星",
        "asteroid",
        "swiss_ephemeris",
        "ephemeris.swiss.geocentric_apparent.v1",
        catalog="mpc:4",
    ),
    *[
        _point(
            point_id,
            label,
            "hypothetical",
            "swiss_hypothetical",
            "ephemeris.swiss.hypothetical_orbit.v1",
            catalog=catalog,
            source_refs=(SRC_SWISS_HYPOTHETICAL, SRC_SWISS_PROGRAMMING),
            maturity="experimental",
        )
        for point_id, label, catalog in _TNP_LABELS
    ],
    *[
        _blocked(
            point_id,
            label,
            category,
            "the object is registered but its Swiss asteroid ephemeris file "
            "is not shipped in the V1 dataset",
            mode="external_ephemeris",
            catalog=f"mpc:{number}",
            source_refs=(SRC_MPC_ORBITS, SRC_SWISS_PROGRAMMING),
            requirements=(
                f"se{number:05d}s.se1",
                f"vendor/swisseph/ephe/ast{number // 1000}/se{number:05d}s.se1",
                "dataset_manifest.source_uri",
                "dataset_manifest.sha256",
                "dataset_manifest.coverage_1500_2099",
                "dataset_manifest.swiss_ephemeris_version",
                "dataset_manifest.license",
            ),
        )
        for point_id, label, category, number in (
            ("nessus", "人龙星", "centaur", 7066),
            ("asteroid_eros", "爱神星", "asteroid", 433),
            ("psyche", "灵神星", "asteroid", 16),
            ("quaoar", "创神星", "dwarf_planet", 50000),
        )
    ],
]

_interstellar_extra_entries: tuple[PointRegistryEntry, ...] = (
    _point(
        "mean_north_node",
        "平均北交点",
        "node",
        "swiss_ephemeris",
        "ephemeris.swiss.geocentric_apparent.v1",
    ),
    _point(
        "mean_south_node",
        "平均南交点",
        "node",
        "derived",
        "node.mean.opposition.v1",
    ),
    _point(
        "true_lilith",
        "真莉莉丝",
        "lunar_point",
        "swiss_ephemeris",
        "ephemeris.swiss.geocentric_apparent.v1",
    ),
    _point(
        "lunar_perigee",
        "月球近地点",
        "lunar_point",
        "swiss_ephemeris",
        "ephemeris.swiss.geocentric_apparent.v1",
    ),
    _point(
        "anti_vertex",
        "反宿命点",
        "angle",
        "derived",
        "angle.anti_vertex.opposition.v1",
    ),
    _point(
        "west_point",
        "西点",
        "angle",
        "derived",
        "angle.west_point.opposition.v1",
    ),
)

_all_entries = (*_competitor_entries, *_interstellar_extra_entries)
POINT_REGISTRY: dict[str, PointRegistryEntry] = {item.point_id: item for item in _all_entries}
if len(POINT_REGISTRY) != len(_all_entries):
    raise ValueError("point registry contains duplicate point ids")

# The exact 66-point competitor reference profile is a comparison fixture, not
# an assertion that every item is a released Interstellar calculation.
COMPETITOR_REFERENCE_POINT_IDS: tuple[str, ...] = tuple(
    item.point_id for item in _competitor_entries
)
if len(COMPETITOR_REFERENCE_POINT_IDS) != 66:
    raise ValueError(
        "competitor reference point profile must remain exactly 66 entries; "
        f"found {len(COMPETITOR_REFERENCE_POINT_IDS)}"
    )

AVAILABLE_COMPETITOR_POINT_IDS: tuple[str, ...] = tuple(
    point_id
    for point_id in COMPETITOR_REFERENCE_POINT_IDS
    if POINT_REGISTRY[point_id].availability == "available"
)
BLOCKED_COMPETITOR_POINT_IDS: tuple[str, ...] = tuple(
    point_id
    for point_id in COMPETITOR_REFERENCE_POINT_IDS
    if POINT_REGISTRY[point_id].availability == "blocked"
)


def point_registry_document() -> dict[str, object]:
    """Return a JSON-safe, content-addressed registry projection."""

    return {
        "registry_id": "natal.points.competitor_reference.v1",
        "version": "1.0.0",
        "points": [
            {
                **asdict(POINT_REGISTRY[point_id]),
                "content_hash": POINT_REGISTRY[point_id].content_hash,
            }
            for point_id in POINT_REGISTRY
        ],
        "competitor_reference_point_ids": list(COMPETITOR_REFERENCE_POINT_IDS),
        "formulas": [
            {**asdict(entry), "content_hash": entry.content_hash}
            for entry in FORMULA_REGISTRY.values()
        ],
        "sources": [
            {**asdict(entry), "content_hash": entry.content_hash}
            for entry in SOURCE_REGISTRY.values()
        ],
    }
