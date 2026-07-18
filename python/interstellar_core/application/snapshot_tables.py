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
}


def build_snapshot_table(snapshot: Mapping[str, Any], table_id: str) -> SnapshotTable:
    try:
        columns, builder = _TABLE_BUILDERS[table_id]
    except KeyError as exc:
        raise SnapshotTableError(f"unsupported snapshot table: {table_id}") from exc
    rows = builder(snapshot)
    if not rows:
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
