"""Deterministic item-level interpretations for immutable natal snapshots."""

from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Request, status
from interstellar_core.reporting import (
    ContextualInterpretationInputError,
    ContextualItemKind,
    InterpretationLocale,
    InterpretationRequest,
    interpret_snapshot_item,
)
from pydantic import BaseModel, ConfigDict, Field

from interstellar_api.errors import ErrorCode, ProblemException
from interstellar_api.workflow_store import WorkflowRecordNotFound

router = APIRouter(prefix="/api/v1", tags=["Natal Contextual Interpretations"])


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ContextualItemPayload(StrictModel):
    item_kind: Literal[
        "point_intrinsic",
        "point_in_sign",
        "point_in_house",
        "motion",
        "natal_aspect",
        "house_cusp_ruler",
        "structure_indicator",
        "classical_condition",
    ]
    result_path: str = Field(
        min_length=9,
        max_length=1_000,
        pattern=r"^/result/",
    )
    locale: Literal["zh-CN", "en-US"] = "zh-CN"


class ContextualInterpretationBatchPayload(StrictModel):
    items: list[ContextualItemPayload] = Field(min_length=1, max_length=200)


@router.post(
    "/calculations/{snapshot_id}/interpretations/contextual",
    status_code=status.HTTP_200_OK,
)
async def create_contextual_interpretations(
    snapshot_id: str,
    payload: ContextualInterpretationBatchPayload,
    request: Request,
) -> dict[str, object]:
    """Resolve requested facts only; missing rules remain explicit per item."""

    try:
        snapshot = request.app.state.workflow_store.get_snapshot(snapshot_id)
    except WorkflowRecordNotFound as exc:
        raise ProblemException(
            status=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.NOT_FOUND,
            detail="Calculation snapshot was not found.",
        ) from exc

    interpretations = []
    for index, item in enumerate(payload.items):
        try:
            interpretation = interpret_snapshot_item(
                snapshot,
                InterpretationRequest(
                    item_kind=ContextualItemKind(item.item_kind),
                    result_path=item.result_path,
                    locale=InterpretationLocale(item.locale),
                ),
            )
        except ContextualInterpretationInputError as exc:
            raise ProblemException(
                status=status.HTTP_422_UNPROCESSABLE_CONTENT,
                code=ErrorCode.INVALID_REQUEST,
                detail="A contextual interpretation item references an invalid fact.",
                fields={f"items.{index}.result_path": str(exc)},
            ) from exc
        interpretations.append(interpretation.to_dict())

    return {
        "schema_version": "1.0.0",
        "snapshot_id": snapshot_id,
        "interpretations": interpretations,
        "generation_mode": "deterministic_rule_template",
        "ai_used": False,
    }
