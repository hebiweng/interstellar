"""Optional, isolated downstream natal AI connector contract.

The connector receives one immutable technical document.  It cannot access the
ephemeris adapter or write calculated facts back to a snapshot.  Standard
deployments intentionally expose only disabled example provider families until
an operator supplies an allow-listed exact model and executor.
"""

from __future__ import annotations

import hashlib
import inspect
import json
from datetime import UTC, datetime
from typing import Any, Literal
from uuid import uuid4

from fastapi import APIRouter, Request, status
from interstellar_core.application.natal_technical_export import (
    natal_technical_document_content_hash,
    render_natal_technical_document,
)
from pydantic import BaseModel, ConfigDict, Field

from interstellar_api.errors import ErrorCode, ProblemException
from interstellar_api.workflow_store import WorkflowRecordNotFound

router = APIRouter(prefix="/api/v1/ai", tags=["Natal AI Connectors"])


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class NatalAiPreviewRequest(StrictModel):
    snapshot_id: str = Field(min_length=1, max_length=160)
    provider_id: Literal["deepseek", "openai", "moonshot"]
    model_id: Literal["deepseek-v4-flash", "deepseek-v4-pro", "gpt", "kimi"]
    document_format: Literal["markdown", "plaintext", "json"] = "markdown"
    analysis_focus: str | None = Field(default=None, max_length=4_000)
    store_response: bool = True


class NatalAiAnalysisRequest(NatalAiPreviewRequest):
    payload_hash: str = Field(pattern=r"^sha256:[A-Fa-f0-9]{64}$")
    consent_to_send_snapshot: bool
    authority_for_subject_data: bool
    consent_policy_version: str = Field(min_length=1, max_length=80)
    consent_accepted_at: datetime | None = None


def _default_provider_catalog() -> list[dict[str, Any]]:
    return [
        {
            "provider_id": "deepseek",
            "label": "DeepSeek",
            "configured": False,
            "availability": "not_configured",
            "blocking_reason": "等待服务端配置 DeepSeek API 密钥",
            "data_destination": "DeepSeek API；仅在用户预览并同意后发送本命盘分析文档",
            "privacy_policy_url": "https://www.deepseek.com/zh/policy/",
            "retention_policy": "以 DeepSeek 当前服务条款与部署者策略为准",
            "models": [
                {
                    "model_id": "deepseek-v4-pro",
                    "label": "DeepSeek V4 Pro",
                    "configured": False,
                    "context_limit": None,
                },
                {
                    "model_id": "deepseek-v4-flash",
                    "label": "DeepSeek V4 Flash",
                    "configured": False,
                    "context_limit": None,
                },
            ],
        },
        {
            "provider_id": "openai",
            "label": "GPT / OpenAI",
            "configured": False,
            "availability": "not_configured",
            "blocking_reason": "等待部署者配置 API、精确模型允许清单与数据保留策略",
            "data_destination": "未配置；当前不会发送任何数据",
            "privacy_policy_url": None,
            "retention_policy": "未配置",
            "models": [
                {
                    "model_id": "gpt",
                    "label": "GPT（示例家族；部署时指定精确版本）",
                    "configured": False,
                    "context_limit": None,
                }
            ],
        },
        {
            "provider_id": "moonshot",
            "label": "Kimi / Moonshot",
            "configured": False,
            "availability": "not_configured",
            "blocking_reason": "等待部署者配置 API、精确模型允许清单与数据保留策略",
            "data_destination": "未配置；当前不会发送任何数据",
            "privacy_policy_url": None,
            "retention_policy": "未配置",
            "models": [
                {
                    "model_id": "kimi",
                    "label": "Kimi（示例家族；部署时指定精确版本）",
                    "configured": False,
                    "context_limit": None,
                }
            ],
        },
    ]


def provider_catalog(request: Request | None = None) -> list[dict[str, Any]]:
    """Return only operator allow-listed provider metadata, never credentials."""

    catalog = _default_provider_catalog()
    overrides = (
        getattr(request.app.state, "natal_ai_provider_overrides", {}) if request is not None else {}
    )
    for provider in catalog:
        key = str(provider["provider_id"])
        override = overrides.get(key)
        if isinstance(override, dict):
            provider.update({item: value for item, value in override.items() if item != "secret"})
    return catalog


def _provider(
    request: Request, provider_id: str, model_id: str
) -> tuple[dict[str, Any], dict[str, Any]]:
    provider = next(
        item for item in provider_catalog(request) if item["provider_id"] == provider_id
    )
    model = next(
        (item for item in provider.get("models", []) if item.get("model_id") == model_id),
        None,
    )
    if model is None:
        raise ProblemException(
            status=status.HTTP_422_UNPROCESSABLE_CONTENT,
            code=ErrorCode.INVALID_REQUEST,
            detail="The requested model is not on the operator allow list.",
            fields={"provider_id": provider_id, "model_id": model_id},
        )
    return provider, model


def _snapshot(request: Request, snapshot_id: str) -> dict[str, Any]:
    try:
        return request.app.state.workflow_store.get_snapshot(snapshot_id)
    except WorkflowRecordNotFound as exc:
        raise ProblemException(
            status=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.NOT_FOUND,
            detail="Calculation snapshot was not found.",
        ) from exc


def _document(snapshot: dict[str, Any], output_format: str) -> str:
    if output_format == "json":
        return json.dumps(snapshot, ensure_ascii=False, sort_keys=True, indent=2)
    return render_natal_technical_document(snapshot, output_format=output_format)


def _payload_hash(payload: NatalAiPreviewRequest, document_hash: str) -> str:
    semantic_payload = {
        "snapshot_id": payload.snapshot_id,
        "document_content_hash": document_hash,
        "provider_id": payload.provider_id,
        "model_id": payload.model_id,
        "document_format": payload.document_format,
        "analysis_focus": payload.analysis_focus or None,
        "store_response": payload.store_response,
    }
    encoded = json.dumps(
        semantic_payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    return f"sha256:{hashlib.sha256(encoded).hexdigest()}"


def _preview(payload: NatalAiPreviewRequest, request: Request) -> dict[str, Any]:
    snapshot = _snapshot(request, payload.snapshot_id)
    provider, model = _provider(request, payload.provider_id, payload.model_id)
    document_hash = natal_technical_document_content_hash(snapshot)
    document = _document(snapshot, payload.document_format)
    payload_hash = _payload_hash(payload, document_hash)
    configured = bool(provider.get("configured") and model.get("configured"))
    return {
        "preview_id": f"ai-preview-{payload_hash.removeprefix('sha256:')[:24]}",
        "snapshot_id": payload.snapshot_id,
        "provider_id": payload.provider_id,
        "model_id": payload.model_id,
        "provider_label": provider.get("label"),
        "model_label": model.get("label"),
        "provider_configured": configured,
        "availability": provider.get("availability", "not_configured"),
        "blocking_reason": None if configured else provider.get("blocking_reason"),
        "document_format": payload.document_format,
        "document_content_hash": document_hash,
        "payload_hash": payload_hash,
        "character_count": len(document),
        "estimated_tokens": max(1, round(len(document) / 2.2)),
        "sections": [
            "对象、时间与地点",
            "计算设置",
            "天文计算上下文",
            "完整点位",
            "十二宫",
            "完整相位",
            "分布与盘面结构",
            "古典与希腊化事实",
            "输入质量与分析提醒",
        ],
        "preview_excerpt": document[:1_200],
        "analysis_focus": payload.analysis_focus,
        "data_destination": provider.get("data_destination", "未配置；当前不会发送任何数据"),
        "privacy_policy_url": provider.get("privacy_policy_url"),
        "retention_policy": provider.get("retention_policy", "未配置"),
        "store_response": payload.store_response,
        "requires_subject_data_authority": True,
        "calculation_boundary": (
            "AI receives this immutable document only. It cannot calculate or overwrite "
            "ephemeris, signs, houses, aspects, structure, or classical facts."
        ),
    }


@router.get("/providers")
async def list_ai_providers(request: Request) -> dict[str, object]:
    return {
        "providers": provider_catalog(request),
        "calculation_boundary": (
            "AI receives an immutable calculated snapshot or technical export and never "
            "calculates ephemeris, houses, signs, or aspects."
        ),
    }


@router.post("/analyses/preview")
async def preview_natal_ai_analysis(
    payload: NatalAiPreviewRequest,
    request: Request,
) -> dict[str, Any]:
    """Describe the exact payload and destination without calling a provider."""

    return _preview(payload, request)


@router.post("/analyses", status_code=status.HTTP_202_ACCEPTED)
async def create_natal_ai_analysis(
    payload: NatalAiAnalysisRequest,
    request: Request,
) -> dict[str, Any]:
    if not payload.consent_to_send_snapshot:
        raise ProblemException(
            status=status.HTTP_422_UNPROCESSABLE_CONTENT,
            code=ErrorCode.INVALID_REQUEST,
            detail="Explicit consent is required before sending natal data to an AI provider.",
            fields={"consent_to_send_snapshot": "must be true"},
        )
    if not payload.authority_for_subject_data:
        raise ProblemException(
            status=status.HTTP_422_UNPROCESSABLE_CONTENT,
            code=ErrorCode.INVALID_REQUEST,
            detail="The user must confirm authority to send this subject's data.",
            fields={"authority_for_subject_data": "must be true"},
        )
    preview_payload = NatalAiPreviewRequest(
        snapshot_id=payload.snapshot_id,
        provider_id=payload.provider_id,
        model_id=payload.model_id,
        document_format=payload.document_format,
        analysis_focus=payload.analysis_focus,
        store_response=payload.store_response,
    )
    preview = _preview(preview_payload, request)
    if payload.payload_hash != preview["payload_hash"]:
        raise ProblemException(
            status=status.HTTP_409_CONFLICT,
            code=ErrorCode.AI_PAYLOAD_CHANGED_AFTER_CONSENT,
            detail="The AI payload changed after preview. Review and consent again.",
            fields={
                "expected_payload_hash": preview["payload_hash"],
                "submitted_payload_hash": payload.payload_hash,
            },
        )
    if not preview["provider_configured"]:
        raise ProblemException(
            status=status.HTTP_409_CONFLICT,
            code=ErrorCode.AI_PROVIDER_NOT_CONFIGURED,
            detail=(
                "The selected AI provider is not configured. The deterministic natal result "
                "can still be copied or exported for manual external analysis."
            ),
            fields={
                "provider_id": payload.provider_id,
                "model_id": payload.model_id,
                "availability": preview["availability"],
                "payload_hash": preview["payload_hash"],
            },
        )
    executor = getattr(request.app.state, "natal_ai_executor", None)
    if executor is None:
        raise ProblemException(
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
            code=ErrorCode.AI_PROVIDER_NOT_CONFIGURED,
            detail="The allow-listed provider has no isolated server-side executor.",
        )
    snapshot = _snapshot(request, payload.snapshot_id)
    document = _document(snapshot, payload.document_format)
    execution_result = executor(
        {
            "provider_id": payload.provider_id,
            "model_id": payload.model_id,
            "technical_document": document,
            "technical_document_hash": preview["document_content_hash"],
            "payload_hash": preview["payload_hash"],
            "analysis_focus": payload.analysis_focus,
        }
    )
    if inspect.isawaitable(execution_result):
        execution_result = await execution_result
    artifact = {
        "id": f"optional-ai-artifact-{uuid4()}",
        "snapshot_id": payload.snapshot_id,
        "provider_id": payload.provider_id,
        "model_id": payload.model_id,
        "document_content_hash": preview["document_content_hash"],
        "payload_hash": preview["payload_hash"],
        "created_at": datetime.now(UTC).isoformat(),
        "ai_generated": True,
        "persisted": payload.store_response,
        "response": execution_result,
        "calculation_writeback": False,
    }
    if payload.store_response:
        request.app.state.optional_ai_artifacts[artifact["id"]] = artifact
    return artifact
