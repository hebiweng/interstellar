"""Explicit sect facts; horizon inference and Hayz are intentionally out of scope."""

from __future__ import annotations

from interstellar_core.astrology.classical.models import Sect, SectResult
from interstellar_core.astrology.classical.sources import (
    ALG_DIGNITY_RECEPTION,
    RULE_SECT_EXPLICIT_V1,
    SRC_DOROTHEUS_CARMEN,
)
from interstellar_core.domain import DomainError


def require_sect(sect: Sect) -> Sect:
    if not isinstance(sect, Sect):
        raise DomainError("CLASSICAL_SECT_INVALID", "sect must be Sect.DAY or Sect.NIGHT")
    return sect


def sect_facts(sect: Sect) -> SectResult:
    """Return traditional sect memberships from an already resolved day/night input."""

    sect = require_sect(sect)
    return SectResult(
        sect=sect,
        sect_light_id="sun" if sect is Sect.DAY else "moon",
        diurnal_planet_ids=("sun", "jupiter", "saturn"),
        nocturnal_planet_ids=("moon", "venus", "mars"),
        conditional_planet_ids=("mercury",),
        algorithm_card_id=ALG_DIGNITY_RECEPTION,
        rule_ids=(RULE_SECT_EXPLICIT_V1,),
        source_ids=(SRC_DOROTHEUS_CARMEN,),
        excluded_capabilities=("sect_horizon_inference", "hayz", "mercury_sect_assignment"),
    )
