"""Traditional domicile-dispositor graph and cycle calculation."""

from __future__ import annotations

from collections.abc import Mapping

from interstellar_core.astrology.classical.models import DispositorEdge, DispositorGraphResult
from interstellar_core.astrology.classical.rulership import traditional_rulers
from interstellar_core.astrology.classical.sources import (
    ALG_DIGNITY_RECEPTION,
    RULE_DISPOSITOR_V1,
    SRC_LILLY_CHRISTIAN_ASTROLOGY,
)
from interstellar_core.astrology.classical.tables import (
    TRADITIONAL_RULERSHIP_TABLE_REF,
    sign_and_degree,
)


def _canonical_cycle(cycle: tuple[str, ...]) -> tuple[str, ...]:
    rotations = tuple(cycle[index:] + cycle[:index] for index in range(len(cycle)))
    return min(rotations)


def _find_cycles(graph: Mapping[str, str]) -> tuple[tuple[str, ...], ...]:
    found: set[tuple[str, ...]] = set()
    for start in sorted(graph):
        path: list[str] = []
        indexes: dict[str, int] = {}
        current = start
        while current in graph and current not in indexes:
            indexes[current] = len(path)
            path.append(current)
            current = graph[current]
        if current in indexes:
            found.add(_canonical_cycle(tuple(path[indexes[current] :])))
    return tuple(sorted(found))


def calculate_traditional_dispositors(
    point_longitudes_deg: Mapping[str, float],
) -> DispositorGraphResult:
    edges = []
    graph: dict[str, str] = {}
    for point_id in sorted(point_longitudes_deg):
        sign_id, _ = sign_and_degree(point_longitudes_deg[point_id])
        ruler_id = traditional_rulers(sign_id)[0]
        edges.append(
            DispositorEdge(
                subject_point_id=point_id,
                subject_sign_id=sign_id,
                ruler_point_id=ruler_id,
                table_ref=TRADITIONAL_RULERSHIP_TABLE_REF,
                rule_id=RULE_DISPOSITOR_V1,
            )
        )
        graph[point_id] = ruler_id
    cycles = _find_cycles(graph)
    final_dispositors = tuple(cycle[0] for cycle in cycles if len(cycle) == 1)
    unresolved = tuple(sorted(set(graph.values()) - set(graph)))
    return DispositorGraphResult(
        edges=tuple(edges),
        cycles=cycles,
        final_dispositor_ids=final_dispositors,
        unresolved_ruler_ids=unresolved,
        algorithm_card_id=ALG_DIGNITY_RECEPTION,
        rule_ids=(RULE_DISPOSITOR_V1,),
        source_ids=(SRC_LILLY_CHRISTIAN_ASTROLOGY,),
    )
