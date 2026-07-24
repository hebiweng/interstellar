"""Dignity-based receptions with explicit host/guest direction semantics."""

from __future__ import annotations

from collections.abc import Mapping

from interstellar_core.astrology.classical.dignities import dignity_rulers_at
from interstellar_core.astrology.classical.models import (
    DignityKind,
    MutualReception,
    Reception,
    ReceptionResult,
    Sect,
)
from interstellar_core.astrology.classical.sect import require_sect
from interstellar_core.astrology.classical.sources import (
    ALG_DIGNITY_RECEPTION,
    RULE_MUTUAL_RECEPTION_V1,
    RULE_RECEPTION_V1,
    SRC_LILLY_CHRISTIAN_ASTROLOGY,
)
from interstellar_core.astrology.classical.tables import TermsTable, TriplicityTable


def calculate_receptions(
    point_longitudes_deg: Mapping[str, float],
    *,
    sect: Sect,
    terms_table: TermsTable = TermsTable.EGYPTIAN,
    triplicity_table: TriplicityTable = TriplicityTable.DOROTHEAN,
) -> ReceptionResult:
    sect = require_sect(sect)
    receptions: list[Reception] = []
    supplied_ids = set(point_longitudes_deg)
    for guest_id in sorted(point_longitudes_deg):
        for condition in dignity_rulers_at(
            point_longitudes_deg[guest_id],
            sect=sect,
            terms_table=terms_table,
            triplicity_table=triplicity_table,
        ):
            if condition.ruler_id == guest_id or condition.ruler_id not in supplied_ids:
                continue
            if (
                condition.kind is DignityKind.TRIPLICITY
                and condition.is_active_for_sect is not True
            ):
                continue
            receptions.append(
                Reception(
                    host_point_id=condition.ruler_id,
                    guest_point_id=guest_id,
                    dignity_kind=condition.kind,
                    triplicity_role=condition.role,
                    active_for_sect=condition.is_active_for_sect,
                    table_ref=condition.table_ref,
                    rule_id=RULE_RECEPTION_V1,
                )
            )
    receptions.sort(
        key=lambda item: (
            item.host_point_id,
            item.guest_point_id,
            item.dignity_kind.value,
            item.triplicity_role.value if item.triplicity_role else "",
        )
    )
    directed: dict[tuple[str, str], set[DignityKind]] = {}
    for reception in receptions:
        directed.setdefault(
            (reception.host_point_id, reception.guest_point_id),
            set(),
        ).add(reception.dignity_kind)

    mutual = []
    for point_a, point_b in sorted(
        {tuple(sorted(pair)) for pair in directed if pair[0] != pair[1]}
    ):
        if (point_a, point_b) not in directed or (point_b, point_a) not in directed:
            continue
        mutual.append(
            MutualReception(
                point_a=point_a,
                point_b=point_b,
                a_receives_b_by=tuple(
                    sorted(directed[(point_a, point_b)], key=lambda item: item.value)
                ),
                b_receives_a_by=tuple(
                    sorted(directed[(point_b, point_a)], key=lambda item: item.value)
                ),
                rule_id=RULE_MUTUAL_RECEPTION_V1,
            )
        )
    return ReceptionResult(
        receptions=tuple(receptions),
        mutual_receptions=tuple(mutual),
        aspect_required=False,
        algorithm_card_id=ALG_DIGNITY_RECEPTION,
        rule_ids=(RULE_RECEPTION_V1, RULE_MUTUAL_RECEPTION_V1),
        source_ids=(SRC_LILLY_CHRISTIAN_ASTROLOGY,),
        excluded_capabilities=("aspect_perfection", "reception_mitigation_score"),
    )
