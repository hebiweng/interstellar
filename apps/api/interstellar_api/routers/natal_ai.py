"""Optional downstream natal AI connector contract.

The connector is deliberately separate from deterministic chart calculation.
V1 exposes model discovery and validates a submission request, while providers
remain disabled until an operator configures credentials and an executor.
"""

from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Request, status
from pydantic import BaseModel, ConfigDict, Field

from interstellar_api.errors import ErrorCode, ProblemException
from interstellar_api.workflow_store import WorkflowRecordNotFound

router = APIRouter(prefix="/api/v1/ai", tags=["Natal AI Connectors"])


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class NatalAiAnalysisRequest(StrictModel):
    snapshot_id: str = Field(min_length=1, max_length=160)
    provider_id: Literal["openai", "moonshot"]
    model_id: Literal["gpt", "kimi"]
    document_format: Literal["markdown", "plaintext", "json"] = "markdown"
    analysis_focus: str | None = Field(default=None, max_length=4_000)
    consent_to_send_snapshot: bool
    store_response: bool = True


def provider_catalog() -> list[dict[str, object]]:
    return [
        {
            "provider_id": "openai",
            "label": "GPT / OpenAI",
            "configured": False,
            "availability": "blocked",
            "blocking_reason": "等待部署者配置 API、允许模型清单与数据保留策略",
            "models": [
                {
                    "model_id": "gpt",
                    "label": "GPT（部署时指定具体版本）",
                    "configured": False,
                }
            ],
        },
        {
            "provider_id": "moonshot",
            "label": "Kimi / Moonshot",
            "configured": False,
            "availability": "blocked",
            "blocking_reason": "等待部署者配置 API、允许模型清单与数据保留策略",
            "models": [
                {
                    "model_id": "kimi",
                    "label": "Kimi（部署时指定具体版本）",
                    "configured": False,
                }
            ],
        },
    ]


@router.get("/providers")
async def list_ai_providers() -> dict[str, object]:
    return {
        "providers": provider_catalog(),
        "calculation_boundary": (
            "AI receives an immutable calculated snapshot or technical export and never "
            "calculates ephemeris, houses, signs, or aspects."
        ),
    }


@router.post("/analyses", status_code=status.HTTP_202_ACCEPTED)
async def create_natal_ai_analysis(
    payload: NatalAiAnalysisRequest,
    request: Request,
) -> dict[str, object]:
    if not payload.consent_to_send_snapshot:
        raise ProblemException(
            status=status.HTTP_422_UNPROCESSABLE_CONTENT,
            code=ErrorCode.INVALID_REQUEST,
            detail="Explicit consent is required before sending natal data to an AI provider.",
            fields={"consent_to_send_snapshot": "must be true"},
        )
    try:
        request.app.state.workflow_store.get_snapshot(payload.snapshot_id)
    except WorkflowRecordNotFound as exc:
        raise ProblemException(
            status=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.NOT_FOUND,
            detail="Calculation snapshot was not found.",
        ) from exc
    raise ProblemException(
        status=status.HTTP_409_CONFLICT,
        code=ErrorCode.INVALID_REQUEST,
        detail=(
            "The selected AI provider is not configured. The deterministic natal result "
            "can still be copied or exported for manual external analysis."
        ),
        fields={
            "provider_id": payload.provider_id,
            "model_id": payload.model_id,
            "availability": "blocked",
        },
    )

