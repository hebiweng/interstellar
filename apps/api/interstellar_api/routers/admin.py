"""Server-enforced administration endpoints.

The browser never decides whether a caller is an administrator.  Every route
resolves the signed-in account from the server-side session and verifies its
stored role before reading or changing operational data.
"""

from __future__ import annotations

import asyncio
from datetime import UTC, datetime, timedelta
from typing import Any, Literal
from urllib.error import HTTPError, URLError
from urllib.request import Request as UrlRequest
from urllib.request import urlopen

from fastapi import APIRouter, Query, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field

from interstellar_api.account_store import AccountError, AccountStore
from interstellar_api.routers.accounts import account_error, current_user

router = APIRouter(prefix="/api/v1/admin", tags=["administration"])


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class UserCreate(StrictModel):
    email: str = Field(min_length=3, max_length=254)
    display_name: str = Field(default="", max_length=80)
    password: str = Field(min_length=8, max_length=128)


class UserPatch(StrictModel):
    email: str = Field(min_length=3, max_length=254)
    status: Literal["active", "disabled", "suspended", "pending_deletion"]
    reason: str | None = Field(default=None, max_length=500)
    suspended_until: datetime | None = None


class AdminCreate(UserCreate):
    role: Literal["admin", "super_admin"] = "admin"


class AdminPatch(StrictModel):
    email: str = Field(min_length=3, max_length=254)
    role: Literal["user", "admin", "super_admin"]


class ProviderModelPayload(StrictModel):
    model_id: str = Field(min_length=1, max_length=160)
    display_name: str = Field(min_length=1, max_length=160)
    purpose: str = Field(default="natal_analysis", min_length=1, max_length=120)
    enabled: bool = True
    default: bool = False
    options: dict[str, Any] = Field(default_factory=dict)
    prompt_override: str | None = Field(default=None, max_length=20_000)
    prompt_version: str | None = Field(default=None, max_length=80)


class ProviderPayload(StrictModel):
    provider_id: str = Field(min_length=2, max_length=64)
    display_name: str = Field(min_length=1, max_length=160)
    base_url: str = Field(min_length=8, max_length=2_000)
    enabled: bool = False
    default: bool = False
    api_key: str | None = Field(default=None, min_length=1, max_length=8_000)
    timeout: int = Field(default=90, ge=1, le=600)
    models: list[ProviderModelPayload] = Field(default_factory=list, max_length=100)


class PlatformPromptPayload(StrictModel):
    platform_prompt: str = Field(default="", max_length=20_000)
    version: str | None = Field(default=None, min_length=1, max_length=80)


class ProviderKeyPayload(StrictModel):
    api_key: str = Field(min_length=1, max_length=8_000)


def _store(request: Request) -> AccountStore:
    return request.app.state.account_store


def _admin(request: Request, *, super_only: bool = False) -> dict[str, str]:
    user = current_user(request)
    if user is None or user.get("role") not in {"admin", "super_admin"}:
        raise AccountError("FORBIDDEN", "需要管理员权限。")
    if super_only and user.get("role") != "super_admin":
        raise AccountError("FORBIDDEN", "需要超级管理员权限。")
    return user


def _safe_error(error: AccountError) -> JSONResponse:
    return account_error(error, default_status=422)


@router.get("/overview", response_model=None)
def overview(
    request: Request, days: int = Query(default=30, ge=1, le=365)
) -> dict[str, Any] | JSONResponse:
    try:
        _admin(request)
    except AccountError as error:
        return _safe_error(error)
    since = (datetime.now(UTC) - timedelta(days=days)).isoformat().replace("+00:00", "Z")
    return {
        "periodDays": days,
        "accounts": _store(request).account_summary(),
        "analytics": _store(request).analytics_summary(since=since),
        "providers": {
            "configured": len(_store(request).list_providers(admin=True)),
            "enabled": len(_store(request).list_providers(admin=False)),
        },
    }


@router.get("/users", response_model=None)
def users(
    request: Request,
    q: str = Query(default="", max_length=160),
    role: str | None = None,
    status: str | None = None,
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> dict[str, Any] | JSONResponse:
    try:
        _admin(request)
        return _store(request).list_users(
            query=q, role=role, status=status, limit=limit, offset=offset
        )
    except AccountError as error:
        return _safe_error(error)


@router.get("/users/{email}", response_model=None)
def user_detail(email: str, request: Request) -> dict[str, Any] | JSONResponse:
    try:
        _admin(request)
        return _store(request).get_user(email)
    except AccountError as error:
        return _safe_error(error)


@router.get("/users/{email}/activity", response_model=None)
def user_activity(
    email: str,
    request: Request,
    limit: int = Query(default=100, ge=1, le=500),
) -> dict[str, Any] | JSONResponse:
    try:
        _admin(request)
        return {"items": _store(request).user_activity(email, limit=limit)}
    except AccountError as error:
        return _safe_error(error)


@router.post("/users", response_model=None)
def create_user(payload: UserCreate, request: Request) -> dict[str, Any] | JSONResponse:
    try:
        actor = _admin(request)
        user = _store(request).register(
            payload.email, payload.display_name, payload.password
        )
        _store(request).record_event(
            "account_registered",
            actor_email=user["email"],
            metadata={"route": "admin_create_user"},
        )
        # The temporary password is accepted only in this internal first slice;
        # it is never returned or logged. A mail invitation flow can replace it.
        return {"user": user, "createdBy": actor["email"]}
    except AccountError as error:
        return _safe_error(error)


@router.patch("/users", response_model=None)
def patch_user(payload: UserPatch, request: Request) -> dict[str, Any] | JSONResponse:
    try:
        actor = _admin(request)
        if payload.status == "suspended" and payload.suspended_until is not None:
            if payload.suspended_until.tzinfo is None:
                raise AccountError("INVALID_STATUS", "暂停结束时间必须包含时区。")
            if payload.suspended_until.astimezone(UTC) <= datetime.now(UTC):
                raise AccountError("INVALID_STATUS", "暂停结束时间必须晚于当前时间。")
        suspended_until = (
            payload.suspended_until.astimezone(UTC).isoformat().replace("+00:00", "Z")
            if payload.suspended_until
            else None
        )
        return _store(request).set_account_status(
            payload.email,
            payload.status,
            reason=payload.reason,
            suspended_until=suspended_until,
            actor_email=actor["email"],
        )
    except AccountError as error:
        return _safe_error(error)


@router.delete("/users/{email}", response_model=None)
def soft_delete_user(email: str, request: Request) -> dict[str, Any] | JSONResponse:
    try:
        actor = _admin(request)
        user = _store(request).set_account_status(
            email,
            "pending_deletion",
            reason="管理员发起软删除",
            suspended_until=None,
            actor_email=actor["email"],
        )
        return {"deleted": True, "user": user}
    except AccountError as error:
        return _safe_error(error)


@router.post("/users/{email}/force-logout", response_model=None)
def force_logout(email: str, request: Request) -> dict[str, Any] | JSONResponse:
    try:
        actor = _admin(request)
        revoked = _store(request).force_logout(email, actor_email=actor["email"])
        return {"email": email, "revokedSessions": revoked}
    except AccountError as error:
        return _safe_error(error)


@router.get("/admins", response_model=None)
def admins(request: Request) -> dict[str, Any] | JSONResponse:
    try:
        _admin(request)
        ordinary = _store(request).list_users(role="admin", limit=500)["items"]
        super_admins = _store(request).list_users(role="super_admin", limit=500)["items"]
        return {"items": [*super_admins, *ordinary]}
    except AccountError as error:
        return _safe_error(error)


@router.post("/admins", response_model=None)
def create_admin(payload: AdminCreate, request: Request) -> dict[str, Any] | JSONResponse:
    try:
        actor = _admin(request, super_only=True)
        _store(request).register(
            payload.email,
            payload.display_name,
            payload.password,
        )
        promoted = _store(request).set_account_role(
            payload.email, payload.role, actor_email=actor["email"]
        )
        return promoted | {"createdBy": actor["email"]}
    except AccountError as error:
        return _safe_error(error)


@router.patch("/admins", response_model=None)
def patch_admin(payload: AdminPatch, request: Request) -> dict[str, Any] | JSONResponse:
    try:
        actor = _admin(request, super_only=True)
        return _store(request).set_account_role(
            payload.email, payload.role, actor_email=actor["email"]
        )
    except AccountError as error:
        return _safe_error(error)


def _save_provider(
    payload: ProviderPayload, request: Request, actor: dict[str, str]
) -> dict[str, Any]:
    _store(request).upsert_provider(
        payload.model_dump(exclude={"api_key", "models"}),
        actor_email=actor["email"],
        api_key=payload.api_key,
    )
    for model in payload.models:
        model_data = model.model_dump()
        model_data["pre_analysis_prompt"] = model_data.pop("prompt_override")
        _store(request).upsert_model(
            payload.provider_id, model_data, actor_email=actor["email"]
        )
    return _store(request).get_provider(payload.provider_id, include_models=True)


@router.get("/providers", response_model=None)
def providers(request: Request) -> dict[str, Any] | JSONResponse:
    try:
        _admin(request)
        return {"items": _store(request).list_providers(admin=True)}
    except AccountError as error:
        return _safe_error(error)


@router.post("/providers", response_model=None)
def create_provider(payload: ProviderPayload, request: Request) -> dict[str, Any] | JSONResponse:
    try:
        actor = _admin(request)
        return _save_provider(payload, request, actor)
    except AccountError as error:
        return _safe_error(error)


@router.patch("/providers", response_model=None)
def patch_provider(payload: ProviderPayload, request: Request) -> dict[str, Any] | JSONResponse:
    try:
        actor = _admin(request)
        return _save_provider(payload, request, actor)
    except AccountError as error:
        return _safe_error(error)


def _test_provider_sync(config: dict[str, Any]) -> dict[str, Any]:
    request = UrlRequest(
        f"{str(config['base_url']).rstrip('/')}/models",
        headers={
            "Authorization": f"Bearer {config['api_key']}",
            "Accept": "application/json",
        },
        method="GET",
    )
    started = datetime.now(UTC)
    try:
        with urlopen(request, timeout=config["timeout"]) as response:  # noqa: S310
            response.read(1_000)
            status_code = response.status
    except HTTPError as error:
        return {"ok": False, "statusCode": error.code, "error": "provider_http_error"}
    except (URLError, TimeoutError):
        return {"ok": False, "statusCode": None, "error": "provider_unreachable"}
    duration = round((datetime.now(UTC) - started).total_seconds() * 1_000)
    return {"ok": 200 <= status_code < 300, "statusCode": status_code, "durationMs": duration}


@router.post("/providers/{provider_id}/test", response_model=None)
async def test_provider(provider_id: str, request: Request) -> dict[str, Any] | JSONResponse:
    try:
        actor = _admin(request)
        provider = _store(request).get_provider(provider_id, include_models=True)
        if not provider["models"]:
            raise AccountError("MODEL_NOT_FOUND", "请先为供应商配置至少一个模型。")
        config = _store(request).get_model_config(
            provider_id, provider["models"][0]["model_id"], include_secret=True
        )
        if not config.get("api_key"):
            raise AccountError("PROVIDER_KEY_MISSING", "供应商尚未配置 API 密钥。")
        result = await asyncio.to_thread(_test_provider_sync, config)
        _store(request).record_event(
            "ai_requested",
            actor_email=actor["email"],
            success=bool(result["ok"]),
            duration_ms=result.get("durationMs"),
            metadata={"provider_id": provider_id, "route": "admin_provider_test"},
        )
        return {"providerId": provider_id, **result}
    except AccountError as error:
        return _safe_error(error)


@router.post("/providers/{provider_id}/rotate-key", response_model=None)
def rotate_provider_key(
    provider_id: str, payload: ProviderKeyPayload, request: Request
) -> dict[str, Any] | JSONResponse:
    try:
        actor = _admin(request)
        existing = _store(request).get_provider(provider_id, include_models=True)
        return _store(request).upsert_provider(
            {
                "provider_id": provider_id,
                "display_name": existing["display_name"],
                "base_url": existing["base_url"],
                "enabled": existing["enabled"],
                "default": existing["default"],
                "timeout": existing["timeout"],
            },
            actor_email=actor["email"],
            api_key=payload.api_key,
        )
    except AccountError as error:
        return _safe_error(error)


@router.post("/providers/{provider_id}/models", response_model=None)
def save_model(
    provider_id: str, payload: ProviderModelPayload, request: Request
) -> dict[str, Any] | JSONResponse:
    try:
        actor = _admin(request)
        data = payload.model_dump()
        data["pre_analysis_prompt"] = data.pop("prompt_override")
        return _store(request).upsert_model(provider_id, data, actor_email=actor["email"])
    except AccountError as error:
        return _safe_error(error)


@router.post("/providers/{provider_id}/models/{model_id}/restore-prompt", response_model=None)
def restore_model_prompt(
    provider_id: str, model_id: str, request: Request
) -> dict[str, Any] | JSONResponse:
    try:
        actor = _admin(request)
        return _store(request).restore_model_prompt(
            provider_id, model_id, actor_email=actor["email"]
        )
    except AccountError as error:
        return _safe_error(error)


@router.get("/ai-prompt", response_model=None)
def get_ai_prompt(request: Request) -> dict[str, Any] | JSONResponse:
    try:
        _admin(request)
        return _store(request).get_platform_ai_prompt()
    except AccountError as error:
        return _safe_error(error)


@router.patch("/ai-prompt", response_model=None)
def patch_ai_prompt(
    payload: PlatformPromptPayload, request: Request
) -> dict[str, Any] | JSONResponse:
    try:
        actor = _admin(request)
        return _store(request).set_platform_ai_prompt(
            payload.platform_prompt, payload.version, actor_email=actor["email"]
        )
    except AccountError as error:
        return _safe_error(error)


@router.post("/ai-prompt/restore-default", response_model=None)
def restore_ai_prompt(request: Request) -> dict[str, Any] | JSONResponse:
    try:
        actor = _admin(request)
        return _store(request).restore_platform_ai_prompt(actor_email=actor["email"])
    except AccountError as error:
        return _safe_error(error)


@router.get("/audit-log", response_model=None)
def audit_log(
    request: Request, limit: int = Query(default=100, ge=1, le=500)
) -> dict[str, Any] | JSONResponse:
    try:
        _admin(request)
        return {"items": _store(request).list_audit_logs(limit=limit)}
    except AccountError as error:
        return _safe_error(error)
