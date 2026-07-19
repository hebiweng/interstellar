"""Deterministic professional table projections over immutable snapshots."""

from __future__ import annotations

import csv
import json
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from io import StringIO
from typing import Any


class SnapshotTableError(ValueError):
    pass


def _nested(document: Mapping[str, Any], *path: str) -> Any:
    value: Any = document
    for key in path:
        if not isinstance(value, Mapping) or key not in value:
            return None
        value = value[key]
    return value


def _joined(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
        return "|".join(str(item) for item in value)
    return str(value)


def _json_cell(value: Any) -> str:
    """Serialize nested snapshot facts deterministically for table and CSV cells."""

    if value is None:
        return ""
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )


def _result_value(snapshot: Mapping[str, Any], key: str) -> Any:
    """Read a materialized result collection, with the first chart as fallback."""

    result = _nested(snapshot, "result")
    if not isinstance(result, Mapping):
        return None
    if key in result:
        return result[key]
    charts = result.get("charts")
    if (
        isinstance(charts, Sequence)
        and not isinstance(charts, (str, bytes, bytearray))
        and charts
        and isinstance(charts[0], Mapping)
    ):
        return charts[0].get(key)
    return None


def _mapping_rows(value: Any) -> tuple[Mapping[str, Any], ...]:
    if not isinstance(value, Sequence) or isinstance(value, (str, bytes, bytearray)):
        return ()
    return tuple(item for item in value if isinstance(item, Mapping))


@dataclass(frozen=True, slots=True)
class SnapshotTable:
    table_id: str
    snapshot_id: str
    input_fingerprint: str
    engine_version: str
    columns: tuple[str, ...]
    rows: tuple[dict[str, Any], ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "table_id": self.table_id,
            "metadata": {
                "snapshot_id": self.snapshot_id,
                "input_fingerprint": self.input_fingerprint,
                "engine_version": self.engine_version,
            },
            "columns": list(self.columns),
            "rows": [dict(row) for row in self.rows],
        }

    def to_csv(self) -> str:
        output = StringIO(newline="")
        columns = (
            "snapshot_id",
            "input_fingerprint",
            "engine_version",
            *self.columns,
        )
        writer = csv.DictWriter(output, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        for row in self.rows:
            writer.writerow(
                {
                    "snapshot_id": self.snapshot_id,
                    "input_fingerprint": self.input_fingerprint,
                    "engine_version": self.engine_version,
                    **row,
                }
            )
        return output.getvalue()


def _point_rows(snapshot: Mapping[str, Any]) -> tuple[dict[str, Any], ...]:
    points = _nested(snapshot, "result", "points") or []
    return tuple(
        {
            "point_id": point.get("point_id"),
            "kind": point.get("kind"),
            "sign": point.get("sign"),
            "degree_in_sign": point.get("degree_in_sign"),
            "longitude_deg": _nested(point, "position", "ecliptic", "longitude_deg"),
            "latitude_deg": _nested(point, "position", "ecliptic", "latitude_deg"),
            "right_ascension_deg": _nested(
                point,
                "position",
                "equatorial",
                "right_ascension_deg",
            ),
            "declination_deg": _nested(
                point,
                "position",
                "equatorial",
                "declination_deg",
            ),
            "distance_au": _nested(point, "position", "distance_au"),
            "longitude_speed_deg_per_day": _nested(
                point,
                "position",
                "velocity",
                "longitude_deg_per_day",
            ),
            "motion_state": _nested(point, "position", "motion_state"),
            "house": point.get("house"),
        }
        for point in points
    )


def _speed_rows(snapshot: Mapping[str, Any]) -> tuple[dict[str, Any], ...]:
    return tuple(
        {
            "point_id": row["point_id"],
            "longitude_speed_deg_per_day": row["longitude_speed_deg_per_day"],
            "motion_state": row["motion_state"],
        }
        for row in _point_rows(snapshot)
    )


def _house_rows(snapshot: Mapping[str, Any]) -> tuple[dict[str, Any], ...]:
    houses = _nested(snapshot, "result", "houses") or []
    return tuple(
        {
            "number": house.get("number"),
            "cusp_longitude_deg": house.get("cusp_longitude_deg"),
            "sign": house.get("sign"),
            "degree_in_sign": house.get("degree_in_sign"),
            "ruler_ids": _joined(house.get("ruler_ids")),
            "point_ids": _joined(house.get("point_ids")),
            "intercepted_signs": _joined(house.get("intercepted_signs")),
        }
        for house in houses
    )


def _aspect_rows(snapshot: Mapping[str, Any]) -> tuple[dict[str, Any], ...]:
    aspects = _nested(snapshot, "result", "aspects") or []
    return tuple(
        {
            "aspect_id": aspect.get("aspect_id"),
            "point_a": aspect.get("point_a"),
            "point_b": aspect.get("point_b"),
            "type": aspect.get("type"),
            "exact_angle_deg": aspect.get("exact_angle_deg"),
            "actual_angle_deg": aspect.get("actual_angle_deg"),
            "orb_deg": aspect.get("orb_deg"),
            "orb_ratio": aspect.get("orb_ratio"),
            "applying_state": aspect.get("applying_state"),
            "strength": aspect.get("strength"),
        }
        for aspect in aspects
    )


def _distribution_rows(
    snapshot: Mapping[str, Any],
    dimension: str,
) -> tuple[dict[str, Any], ...]:
    distributions = _nested(snapshot, "result", "distributions") or []
    selected = next(
        (
            item
            for item in distributions
            if item.get("dimension") == dimension
            or item.get("distribution_id") in {dimension, f"distribution.{dimension}.v1"}
        ),
        None,
    )
    if selected is None:
        return ()
    entries = selected.get("entries") or selected.get("categories") or []
    if isinstance(entries, Mapping):
        entries = [{"category": key, **dict(value)} for key, value in entries.items()]
    return tuple(
        {
            "category": item.get("category") or item.get("category_id") or item.get("id"),
            "raw_count": item.get("raw_count", item.get("count")),
            "weighted_score": item.get("weighted_score", item.get("weight")),
            "percentage": item.get("percentage"),
            "participant_ids": _joined(item.get("participant_ids", item.get("points", []))),
        }
        for item in entries
    )


def _pattern_rows(snapshot: Mapping[str, Any]) -> tuple[dict[str, Any], ...]:
    patterns = _mapping_rows(_result_value(snapshot, "patterns"))
    if not patterns:
        structure = _result_value(snapshot, "structure")
        if isinstance(structure, Mapping):
            patterns = (
                *_mapping_rows(_nested(structure, "stelliums", "facts")),
                *_mapping_rows(_nested(structure, "geometric_patterns", "facts")),
            )
    rows: list[dict[str, Any]] = []
    for pattern in patterns:
        is_stellium = bool(pattern.get("stellium_id"))
        rows.append(
            {
                "pattern_id": pattern.get("pattern_id") or pattern.get("stellium_id"),
                "pattern_family": "stellium" if is_stellium else "geometric",
                "pattern_type": pattern.get("pattern_type") or pattern.get("kind"),
                "participant_ids": _joined(pattern.get("participant_ids")),
                "sign_index": pattern.get("sign_index"),
                "house": pattern.get("house"),
                "longitude_start_deg": pattern.get("longitude_start_deg"),
                "longitude_span_deg": pattern.get("longitude_span_deg"),
                "roles": _json_cell(pattern.get("roles")),
                "evidence_aspect_ids": _joined(pattern.get("evidence_aspect_ids")),
                "rule_ref": pattern.get("rule_ref"),
            }
        )
    return tuple(rows)


def _dignity_rows(snapshot: Mapping[str, Any]) -> tuple[dict[str, Any], ...]:
    dignities = _mapping_rows(_result_value(snapshot, "dignities"))
    return tuple(
        {
            "point_id": dignity.get("point_id"),
            "longitude_deg": dignity.get("longitude_deg"),
            "sign_id": dignity.get("sign_id"),
            "degree_in_sign": dignity.get("degree_in_sign"),
            "sect": dignity.get("sect"),
            "applicable": dignity.get("applicable"),
            "unavailable_reason": dignity.get("unavailable_reason"),
            "dignities": _json_cell(dignity.get("dignities")),
            "debilities": _json_cell(dignity.get("debilities")),
            "peregrine": dignity.get("peregrine"),
            "algorithm_card_id": dignity.get("algorithm_card_id"),
            "rule_ids": _joined(dignity.get("rule_ids")),
            "source_ids": _joined(dignity.get("source_ids")),
            "excluded_capabilities": _joined(dignity.get("excluded_capabilities")),
        }
        for dignity in dignities
    )


def _reception_rows(snapshot: Mapping[str, Any]) -> tuple[dict[str, Any], ...]:
    documents = _mapping_rows(_result_value(snapshot, "receptions"))
    if not documents:
        classical = _result_value(snapshot, "classical")
        reception_document = (
            classical.get("receptions") if isinstance(classical, Mapping) else None
        )
        if isinstance(reception_document, Mapping):
            documents = (reception_document,)

    rows: list[dict[str, Any]] = []
    for document in documents:
        shared = {
            "aspect_required": document.get("aspect_required"),
            "algorithm_card_id": document.get("algorithm_card_id"),
            "rule_ids": _joined(document.get("rule_ids")),
            "source_ids": _joined(document.get("source_ids")),
            "excluded_capabilities": _joined(document.get("excluded_capabilities")),
        }
        for reception in _mapping_rows(document.get("receptions")):
            rows.append(
                {
                    "reception_type": "directed",
                    "host_point_id": reception.get("host_point_id"),
                    "guest_point_id": reception.get("guest_point_id"),
                    "dignity_kind": reception.get("dignity_kind"),
                    "triplicity_role": reception.get("triplicity_role"),
                    "active_for_sect": reception.get("active_for_sect"),
                    "point_a": None,
                    "point_b": None,
                    "a_receives_b_by": "",
                    "b_receives_a_by": "",
                    "table_ref": _json_cell(reception.get("table_ref")),
                    "rule_id": reception.get("rule_id"),
                    **shared,
                }
            )
        for reception in _mapping_rows(document.get("mutual_receptions")):
            rows.append(
                {
                    "reception_type": "mutual",
                    "host_point_id": None,
                    "guest_point_id": None,
                    "dignity_kind": None,
                    "triplicity_role": None,
                    "active_for_sect": None,
                    "point_a": reception.get("point_a"),
                    "point_b": reception.get("point_b"),
                    "a_receives_b_by": _joined(reception.get("a_receives_b_by")),
                    "b_receives_a_by": _joined(reception.get("b_receives_a_by")),
                    "table_ref": "",
                    "rule_id": reception.get("rule_id"),
                    **shared,
                }
            )
    return tuple(rows)


def _dispositor_rows(snapshot: Mapping[str, Any]) -> tuple[dict[str, Any], ...]:
    classical = _result_value(snapshot, "classical")
    graph = classical.get("dispositors") if isinstance(classical, Mapping) else None
    if not isinstance(graph, Mapping):
        return ()
    shared = {
        "cycles": _json_cell(graph.get("cycles")),
        "final_dispositor_ids": _joined(graph.get("final_dispositor_ids")),
        "unresolved_ruler_ids": _joined(graph.get("unresolved_ruler_ids")),
        "algorithm_card_id": graph.get("algorithm_card_id"),
        "rule_ids": _joined(graph.get("rule_ids")),
        "source_ids": _joined(graph.get("source_ids")),
    }
    edges = _mapping_rows(graph.get("edges"))
    if not edges:
        return (
            {
                "row_type": "summary",
                "subject_point_id": None,
                "subject_sign_id": None,
                "ruler_point_id": None,
                "table_ref": "",
                "rule_id": None,
                **shared,
            },
        )
    return tuple(
        {
            "row_type": "edge",
            "subject_point_id": edge.get("subject_point_id"),
            "subject_sign_id": edge.get("subject_sign_id"),
            "ruler_point_id": edge.get("ruler_point_id"),
            "table_ref": _json_cell(edge.get("table_ref")),
            "rule_id": edge.get("rule_id"),
            **shared,
        }
        for edge in edges
    )


def _sect_rows(snapshot: Mapping[str, Any]) -> tuple[dict[str, Any], ...]:
    classical = _result_value(snapshot, "classical")
    if not isinstance(classical, Mapping):
        return ()
    sect = classical.get("sect")
    sect_document = sect if isinstance(sect, Mapping) else {}
    return (
        {
            "availability": classical.get("availability"),
            "unavailable_reasons": _joined(classical.get("unavailable_reasons")),
            "day_night_status": classical.get("day_night_status"),
            "sun_altitude_deg": classical.get("sun_altitude_deg"),
            "sect": sect_document.get("sect"),
            "sect_light_id": sect_document.get("sect_light_id"),
            "diurnal_planet_ids": _joined(sect_document.get("diurnal_planet_ids")),
            "nocturnal_planet_ids": _joined(sect_document.get("nocturnal_planet_ids")),
            "conditional_planet_ids": _joined(
                sect_document.get("conditional_planet_ids")
            ),
            "missing_traditional_planet_ids": _joined(
                classical.get("missing_traditional_planet_ids")
            ),
            "algorithm_card_id": sect_document.get("algorithm_card_id"),
            "rule_ids": _joined(sect_document.get("rule_ids")),
            "source_ids": _joined(sect_document.get("source_ids")),
            "excluded_capabilities": _joined(
                sect_document.get("excluded_capabilities")
            ),
            "interpretation_boundary": classical.get("interpretation_boundary"),
        },
    )


def _arabic_part_rows(snapshot: Mapping[str, Any]) -> tuple[dict[str, Any], ...]:
    lots = _mapping_rows(_result_value(snapshot, "lots"))
    points = {
        point.get("point_id"): point
        for point in _mapping_rows(_result_value(snapshot, "points"))
        if point.get("point_id")
    }
    return tuple(
        {
            "lot_id": lot.get("lot_id"),
            "longitude_deg": lot.get("longitude_deg"),
            "sign_id": lot.get("sign_id"),
            "degree_in_sign": lot.get("degree_in_sign"),
            "house": (points.get(lot.get("lot_id")) or {}).get("house"),
            "sect": lot.get("sect"),
            "formula_id": lot.get("formula_id"),
            "formula_version": lot.get("formula_version"),
            "formula_expression": lot.get("formula_expression"),
            "operands": _json_cell(lot.get("operands")),
            "algorithm_card_id": lot.get("algorithm_card_id"),
            "rule_ids": _joined(lot.get("rule_ids")),
            "source_ids": _joined(lot.get("source_ids")),
            "excluded_capabilities": _joined(lot.get("excluded_capabilities")),
        }
        for lot in lots
    )


_POINT_COLUMNS = (
    "point_id",
    "kind",
    "sign",
    "degree_in_sign",
    "longitude_deg",
    "latitude_deg",
    "right_ascension_deg",
    "declination_deg",
    "distance_au",
    "longitude_speed_deg_per_day",
    "motion_state",
    "house",
)
TableRows = tuple[dict[str, Any], ...]
TableBuilder = Callable[[Mapping[str, Any]], TableRows]
_TABLE_BUILDERS: dict[str, tuple[tuple[str, ...], TableBuilder]] = {
    "table.planet_positions": (_POINT_COLUMNS, _point_rows),
    "table.planet_speeds": (
        ("point_id", "longitude_speed_deg_per_day", "motion_state"),
        _speed_rows,
    ),
    "table.house_cusps": (
        (
            "number",
            "cusp_longitude_deg",
            "sign",
            "degree_in_sign",
            "ruler_ids",
            "point_ids",
            "intercepted_signs",
        ),
        _house_rows,
    ),
    "table.natal_aspects": (
        (
            "aspect_id",
            "point_a",
            "point_b",
            "type",
            "exact_angle_deg",
            "actual_angle_deg",
            "orb_deg",
            "orb_ratio",
            "applying_state",
            "strength",
        ),
        _aspect_rows,
    ),
    "table.elements": (
        ("category", "raw_count", "weighted_score", "percentage", "participant_ids"),
        lambda snapshot: _distribution_rows(snapshot, "elements"),
    ),
    "table.modalities": (
        ("category", "raw_count", "weighted_score", "percentage", "participant_ids"),
        lambda snapshot: _distribution_rows(snapshot, "modalities"),
    ),
    "table.polarity": (
        ("category", "raw_count", "weighted_score", "percentage", "participant_ids"),
        lambda snapshot: _distribution_rows(snapshot, "polarity"),
    ),
    "table.chart_patterns": (
        (
            "pattern_id",
            "pattern_family",
            "pattern_type",
            "participant_ids",
            "sign_index",
            "house",
            "longitude_start_deg",
            "longitude_span_deg",
            "roles",
            "evidence_aspect_ids",
            "rule_ref",
        ),
        _pattern_rows,
    ),
    "table.essential_dignities": (
        (
            "point_id",
            "longitude_deg",
            "sign_id",
            "degree_in_sign",
            "sect",
            "applicable",
            "unavailable_reason",
            "dignities",
            "debilities",
            "peregrine",
            "algorithm_card_id",
            "rule_ids",
            "source_ids",
            "excluded_capabilities",
        ),
        _dignity_rows,
    ),
    "table.receptions": (
        (
            "reception_type",
            "host_point_id",
            "guest_point_id",
            "dignity_kind",
            "triplicity_role",
            "active_for_sect",
            "point_a",
            "point_b",
            "a_receives_b_by",
            "b_receives_a_by",
            "table_ref",
            "rule_id",
            "aspect_required",
            "algorithm_card_id",
            "rule_ids",
            "source_ids",
            "excluded_capabilities",
        ),
        _reception_rows,
    ),
    "graph.dispositor_chain": (
        (
            "row_type",
            "subject_point_id",
            "subject_sign_id",
            "ruler_point_id",
            "cycles",
            "final_dispositor_ids",
            "unresolved_ruler_ids",
            "table_ref",
            "rule_id",
            "algorithm_card_id",
            "rule_ids",
            "source_ids",
        ),
        _dispositor_rows,
    ),
    "table.sect_condition": (
        (
            "availability",
            "unavailable_reasons",
            "day_night_status",
            "sun_altitude_deg",
            "sect",
            "sect_light_id",
            "diurnal_planet_ids",
            "nocturnal_planet_ids",
            "conditional_planet_ids",
            "missing_traditional_planet_ids",
            "algorithm_card_id",
            "rule_ids",
            "source_ids",
            "excluded_capabilities",
            "interpretation_boundary",
        ),
        _sect_rows,
    ),
    "table.arabic_parts": (
        (
            "lot_id",
            "longitude_deg",
            "sign_id",
            "degree_in_sign",
            "house",
            "sect",
            "formula_id",
            "formula_version",
            "formula_expression",
            "operands",
            "algorithm_card_id",
            "rule_ids",
            "source_ids",
            "excluded_capabilities",
        ),
        _arabic_part_rows,
    ),
}

_EMPTY_ROWS_ARE_VALID = frozenset(
    {
        "table.chart_patterns",
        "table.essential_dignities",
        "table.receptions",
        "graph.dispositor_chain",
        "table.sect_condition",
        "table.arabic_parts",
    }
)


def build_snapshot_table(snapshot: Mapping[str, Any], table_id: str) -> SnapshotTable:
    try:
        columns, builder = _TABLE_BUILDERS[table_id]
    except KeyError as exc:
        raise SnapshotTableError(f"unsupported snapshot table: {table_id}") from exc
    rows = builder(snapshot)
    if not rows and table_id not in _EMPTY_ROWS_ARE_VALID:
        raise SnapshotTableError(f"table has no generated rows: {table_id}")
    return SnapshotTable(
        table_id=table_id,
        snapshot_id=str(snapshot["id"]),
        input_fingerprint=str(snapshot["input_fingerprint"]),
        engine_version=str(_nested(snapshot, "engine", "version")),
        columns=columns,
        rows=rows,
    )


def table_json_bytes(table: SnapshotTable) -> bytes:
    return json.dumps(
        table.to_dict(),
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
