"""M1 process-local workflow adapter.

The durable PostgreSQL adapter is developed in parallel.  This adapter keeps
the HTTP vertical slice testable while preserving the same immutable record
shape; it is never advertised as cloud persistence.
"""

from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass, field
from typing import Any


class WorkflowRecordNotFound(KeyError):
    pass


@dataclass(slots=True)
class WorkflowStore:
    subjects: dict[str, dict[str, Any]] = field(default_factory=dict)
    subject_versions: dict[str, list[dict[str, Any]]] = field(default_factory=dict)
    drafts: dict[str, dict[str, Any]] = field(default_factory=dict)
    recipes: dict[str, dict[str, Any]] = field(default_factory=dict)
    snapshots: dict[str, dict[str, Any]] = field(default_factory=dict)

    def put_subject(self, subject: dict[str, Any], version: dict[str, Any]) -> None:
        subject_id = subject["id"]
        self.subjects[subject_id] = deepcopy(subject)
        self.subject_versions[subject_id] = [deepcopy(version)]

    def get_subject(self, subject_id: str) -> dict[str, Any]:
        try:
            return deepcopy(self.subjects[subject_id])
        except KeyError as exc:
            raise WorkflowRecordNotFound(subject_id) from exc

    def get_subject_version(self, version_id: str) -> dict[str, Any]:
        for versions in self.subject_versions.values():
            for version in versions:
                if version["id"] == version_id:
                    return deepcopy(version)
        raise WorkflowRecordNotFound(version_id)

    def put_draft(self, draft: dict[str, Any]) -> None:
        self.drafts[draft["draft_id"]] = deepcopy(draft)

    def get_draft(self, draft_id: str) -> dict[str, Any]:
        try:
            return deepcopy(self.drafts[draft_id])
        except KeyError as exc:
            raise WorkflowRecordNotFound(draft_id) from exc

    def put_recipe(self, recipe: dict[str, Any]) -> None:
        self.recipes[recipe["recipe_id"]] = deepcopy(recipe)

    def get_recipe(self, recipe_id: str) -> dict[str, Any]:
        try:
            return deepcopy(self.recipes[recipe_id])
        except KeyError as exc:
            raise WorkflowRecordNotFound(recipe_id) from exc

    def put_snapshot(self, snapshot: dict[str, Any]) -> None:
        self.snapshots[snapshot["id"]] = deepcopy(snapshot)

    def get_snapshot(self, snapshot_id: str) -> dict[str, Any]:
        try:
            return deepcopy(self.snapshots[snapshot_id])
        except KeyError as exc:
            raise WorkflowRecordNotFound(snapshot_id) from exc
