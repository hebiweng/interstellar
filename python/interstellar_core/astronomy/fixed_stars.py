"""Versioned Swiss fixed-star calculations for the natal product.

Fixed stars are a separate astronomical family, not planets. This module
keeps their catalogue identity, magnitude and coordinate provenance distinct
from the chart-point list while still allowing explicit conjunction contacts
to selected natal points.
"""

from __future__ import annotations

import math
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Literal

import swisseph as swe

from interstellar_core.astronomy.adapters.swiss_ephemeris import (
    AYANAMSA_MODES,
    SIGN_IDS,
    SWISS_BACKEND_LOCK,
    EphemerisCalculationError,
    EphemerisInputError,
)


@dataclass(frozen=True, slots=True)
class FixedStarDefinition:
    star_id: str
    swiss_name: str
    label_zh: str


COMMON_FIXED_STAR_DEFINITIONS: tuple[FixedStarDefinition, ...] = (
    FixedStarDefinition("aldebaran", "Aldebaran", "毕宿五"),
    FixedStarDefinition("antares", "Antares", "心宿二"),
    FixedStarDefinition("regulus", "Regulus", "轩辕十四"),
    FixedStarDefinition("spica", "Spica", "角宿一"),
    FixedStarDefinition("sirius", "Sirius", "天狼星"),
    FixedStarDefinition("algol", "Algol", "大陵五"),
    FixedStarDefinition("alcyone", "Alcyone", "昴宿六"),
    FixedStarDefinition("achernar", "Achernar", "水委一"),
    FixedStarDefinition("capella", "Capella", "五车二"),
    FixedStarDefinition("arcturus", "Arcturus", "大角星"),
    FixedStarDefinition("vega", "Vega", "织女一"),
    FixedStarDefinition("altair", "Altair", "河鼓二"),
    FixedStarDefinition("pollux", "Pollux", "北河三"),
    FixedStarDefinition("castor", "Castor", "北河二"),
    FixedStarDefinition("procyon", "Procyon", "南河三"),
    FixedStarDefinition("fomalhaut", "Fomalhaut", "北落师门"),
    FixedStarDefinition("polaris", "Polaris", "勾陈一"),
    FixedStarDefinition("deneb", "Deneb", "天津四"),
    FixedStarDefinition("rigel", "Rigel", "参宿七"),
    FixedStarDefinition("betelgeuse", "Betelgeuse", "参宿四"),
    FixedStarDefinition("canopus", "Canopus", "老人星"),
    FixedStarDefinition("zuben_elgenubi", "Zuben Elgenubi", "氐宿一"),
    FixedStarDefinition("zuben_eschamali", "Zuben Eschamali", "氐宿四"),
    FixedStarDefinition("unukalhai", "Unukalhai", "蜀增一"),
)
COMMON_FIXED_STAR_IDS: tuple[str, ...] = tuple(
    definition.star_id for definition in COMMON_FIXED_STAR_DEFINITIONS
)
FIXED_STAR_REGISTRY: dict[str, FixedStarDefinition] = {
    definition.star_id: definition for definition in COMMON_FIXED_STAR_DEFINITIONS
}


@dataclass(frozen=True, slots=True)
class FixedStarResult:
    stars: tuple[dict[str, Any], ...]
    provenance: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return {"stars": list(self.stars), "provenance": dict(self.provenance)}


class SwissFixedStarCalculator:
    """Calculate a declared fixed-star projection from ``sefstars.txt``."""

    def __init__(self, *, ephemeris_path: str | Path | None = None) -> None:
        self.ephemeris_path = (
            str(Path(ephemeris_path).expanduser().resolve()) if ephemeris_path else None
        )

    def calculate(
        self,
        *,
        julian_day_ut: float,
        star_ids: Iterable[str],
        zodiac: Literal["tropical", "sidereal"] = "tropical",
        ayanamsa: str | None = None,
    ) -> FixedStarResult:
        ids = tuple(str(star_id) for star_id in star_ids)
        if not ids:
            return FixedStarResult(
                stars=(),
                provenance={
                    "calculator": "swiss_fixstar_ut",
                    "catalog": "sefstars.txt",
                    "formula_ref": "ephemeris.swiss.fixed_star.v1",
                    "selected_star_ids": [],
                },
            )
        duplicates = sorted(star_id for star_id in set(ids) if ids.count(star_id) > 1)
        if duplicates:
            raise EphemerisInputError(
                "fixed_star_ids contains duplicate ids: " + ", ".join(duplicates)
            )
        unknown = sorted(set(ids) - set(FIXED_STAR_REGISTRY))
        if unknown:
            raise EphemerisInputError(
                "fixed_star_ids contains unsupported ids: " + ", ".join(unknown)
            )
        if zodiac == "tropical":
            if ayanamsa is not None:
                raise EphemerisInputError("tropical zodiac must not declare an ayanamsa")
            ayanamsa_mode = None
        elif zodiac == "sidereal":
            if ayanamsa not in AYANAMSA_MODES:
                raise EphemerisInputError("sidereal fixed stars require a supported ayanamsa")
            ayanamsa_mode = AYANAMSA_MODES[ayanamsa]
        else:
            raise EphemerisInputError(f"unsupported fixed-star zodiac: {zodiac}")

        flags = swe.FLG_SWIEPH | swe.FLG_SPEED
        ecliptic_flags = flags | (swe.FLG_SIDEREAL if zodiac == "sidereal" else 0)
        equatorial_flags = flags | swe.FLG_EQUATORIAL
        stars: list[dict[str, Any]] = []
        with SWISS_BACKEND_LOCK:
            if self.ephemeris_path is not None:
                swe.set_ephe_path(self.ephemeris_path)
            if ayanamsa_mode is not None:
                swe.set_sid_mode(ayanamsa_mode)
            for star_id in ids:
                definition = FIXED_STAR_REGISTRY[star_id]
                stars.append(
                    self._calculate_star(
                        definition,
                        julian_day_ut=float(julian_day_ut),
                        ecliptic_flags=ecliptic_flags,
                        equatorial_flags=equatorial_flags,
                    )
                )
        return FixedStarResult(
            stars=tuple(stars),
            provenance={
                "calculator": "swiss_fixstar_ut",
                "catalog": "sefstars.txt",
                "formula_ref": "ephemeris.swiss.fixed_star.v1",
                "zodiac": zodiac,
                "ayanamsa": ayanamsa,
                "ephemeris_path": self.ephemeris_path,
                "selected_star_ids": list(ids),
            },
        )

    def _calculate_star(
        self,
        definition: FixedStarDefinition,
        *,
        julian_day_ut: float,
        ecliptic_flags: int,
        equatorial_flags: int,
    ) -> dict[str, Any]:
        try:
            ecliptic_values, returned_name, ecliptic_returned_flags = swe.fixstar_ut(
                definition.swiss_name,
                julian_day_ut,
                ecliptic_flags,
            )
            equatorial_values, equatorial_name, equatorial_returned_flags = swe.fixstar_ut(
                definition.swiss_name,
                julian_day_ut,
                equatorial_flags,
            )
            magnitude, magnitude_name = swe.fixstar_mag(definition.swiss_name)
        except Exception as exc:
            raise EphemerisCalculationError(
                f"Swiss Ephemeris fixed-star calculation failed for {definition.star_id}: "
                f"{type(exc).__name__}: {exc}"
            ) from exc
        if returned_name != equatorial_name or returned_name != magnitude_name:
            raise EphemerisCalculationError(
                f"fixed-star catalogue identity mismatch for {definition.star_id}"
            )
        required_ecliptic = swe.FLG_SPEED | (ecliptic_flags & swe.FLG_SIDEREAL)
        if ecliptic_returned_flags & required_ecliptic != required_ecliptic:
            raise EphemerisCalculationError(
                f"fixed-star ecliptic flags incomplete for {definition.star_id}"
            )
        required_equatorial = swe.FLG_SPEED | swe.FLG_EQUATORIAL
        if equatorial_returned_flags & required_equatorial != required_equatorial:
            raise EphemerisCalculationError(
                f"fixed-star equatorial flags incomplete for {definition.star_id}"
            )
        ecliptic = tuple(float(value) for value in ecliptic_values)
        equatorial = tuple(float(value) for value in equatorial_values)
        if len(ecliptic) != 6 or len(equatorial) != 6:
            raise EphemerisCalculationError(
                f"fixed-star coordinate shape invalid for {definition.star_id}"
            )
        if not all(math.isfinite(value) for value in (*ecliptic, *equatorial, magnitude)):
            raise EphemerisCalculationError(
                f"fixed-star coordinate is non-finite for {definition.star_id}"
            )
        longitude = ecliptic[0] % 360
        sign_index = min(int(longitude // 30), 11)
        catalogue_parts = [part.strip() for part in returned_name.split(",", 1)]
        return {
            "star_id": definition.star_id,
            "name": catalogue_parts[0],
            "label_zh": definition.label_zh,
            "catalog_designation": catalogue_parts[1] if len(catalogue_parts) == 2 else None,
            "magnitude_v": float(magnitude),
            "position": {
                "ecliptic": {
                    "longitude_deg": longitude,
                    "latitude_deg": ecliptic[1],
                },
                "equatorial": {
                    "right_ascension_deg": equatorial[0] % 360,
                    "declination_deg": equatorial[1],
                },
                "distance_au": ecliptic[2],
                "velocity": {
                    "longitude_deg_per_day": ecliptic[3],
                    "latitude_deg_per_day": ecliptic[4],
                    "distance_au_per_day": ecliptic[5],
                },
                "frame": "true_ecliptic_of_date",
                "center": "geocentric",
                "epoch": f"JDUT:{julian_day_ut:.9f}",
            },
            "sign": SIGN_IDS[sign_index],
            "degree_in_sign": longitude - sign_index * 30,
            "formula_ref": "ephemeris.swiss.fixed_star.v1",
            "source_ref": "source.swiss_ephemeris.fixed_star_catalog",
        }


def calculate_fixed_star_contacts(
    stars: Sequence[Mapping[str, Any]],
    points: Sequence[Mapping[str, Any]],
    *,
    conjunction_orb_deg: float = 1.0,
) -> list[dict[str, Any]]:
    """Return explicit conjunction contacts; no interpretive score is invented."""

    orb = float(conjunction_orb_deg)
    if not math.isfinite(orb) or orb <= 0 or orb > 10:
        raise EphemerisInputError(
            "fixed-star conjunction orb must be greater than 0 and at most 10"
        )
    contacts: list[dict[str, Any]] = []
    for star in stars:
        star_longitude = float(star["position"]["ecliptic"]["longitude_deg"])
        for point in points:
            point_longitude = float(point["position"]["ecliptic"]["longitude_deg"])
            separation = abs((star_longitude - point_longitude + 180) % 360 - 180)
            if separation > orb:
                continue
            strength = max(0.0, 1.0 - separation / orb)
            contacts.append(
                {
                    "contact_id": (
                        f"fixed_star_contact:{star['star_id']}:{point['point_id']}:conjunction"
                    ),
                    "star_id": str(star["star_id"]),
                    "point_id": str(point["point_id"]),
                    "type": "conjunction",
                    "exact_angle_deg": 0.0,
                    "orb_deg": separation,
                    "orb_allowance_deg": orb,
                    "strength": strength,
                    "applying_state": "not_applicable",
                    "formula_ref": "aspect.fixed_star_conjunction.v1",
                }
            )
    contacts.sort(key=lambda item: (-float(item["strength"]), str(item["contact_id"])))
    return contacts


def fixed_star_registry_document() -> dict[str, Any]:
    return {
        "registry_id": "fixed_stars.common.v1",
        "catalog": "sefstars.txt",
        "stars": [asdict(definition) for definition in COMMON_FIXED_STAR_DEFINITIONS],
    }
