"""Standalone account and saved-workspace API for the Interstellar deployment."""

from __future__ import annotations

from typing import Any, Literal

from fastapi import APIRouter, Request, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field

from interstellar_api.account_store import AccountError, AccountStore

router = APIRouter(prefix="/api/v1/account", tags=["account"])


class AccountCredentials(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(default="", max_length=80)


class WorkspaceAction(BaseModel):
    model_config = ConfigDict(extra="allow")

    action: Literal[
        "save_person",
        "save_latest_natal",
        "save_ai_analysis",
        "delete_person",
        "set_default_person",
        "set_sample_visibility",
    ]
    personId: str | None = None
    person: dict[str, Any] | None = None
    snapshot: dict[str, Any] | None = None
    settings: dict[str, Any] | None = None
    groups: dict[str, Any] | None = None
    analysisDocument: str | None = None
    analysisDocumentHash: str | None = None
    aiAnalysisText: str | None = None
    aiModelId: str | None = None
    sampleVisible: bool | None = None


class AccountPreferencesUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    default_person_id: str | None = None
    sample_visible: bool | None = None


def store(request: Request) -> AccountStore:
    return request.app.state.account_store


def account_error(error: AccountError, *, default_status: int = 422) -> JSONResponse:
    status = {
        "EMAIL_EXISTS": 409,
        "AUTHENTICATION_FAILED": 401,
        "LOGIN_REQUIRED": 401,
        "FORBIDDEN": 403,
        "ACCOUNT_DISABLED": 403,
        "ACCOUNT_SUSPENDED": 403,
        "LAST_SUPER_ADMIN": 409,
        "ACCOUNT_NOT_FOUND": 404,
        "PROVIDER_NOT_FOUND": 404,
        "MODEL_NOT_FOUND": 404,
        "MASTER_KEY_REQUIRED": 409,
        "PROVIDER_KEY_MISSING": 409,
        "PERSON_NOT_FOUND": 404,
        "NATAL_RESULT_NOT_FOUND": 404,
    }.get(error.code, default_status)
    return JSONResponse(
        status_code=status,
        content={"error": error.code, "message": str(error)},
    )


def current_user(request: Request) -> dict[str, str] | None:
    settings = request.app.state.settings
    token = request.cookies.get(settings.auth_cookie_name)
    return store(request).resolve_session(token)


def set_session_cookie(
    response: Response,
    request: Request,
    token: str,
) -> None:
    settings = request.app.state.settings
    response.set_cookie(
        key=settings.auth_cookie_name,
        value=token,
        max_age=settings.auth_session_days * 24 * 60 * 60,
        httponly=True,
        secure=settings.auth_cookie_secure,
        samesite="lax",
        path="/",
    )


@router.post("/register", response_model=None)
def register(
    credentials: AccountCredentials,
    request: Request,
    response: Response,
) -> dict[str, Any] | JSONResponse:
    try:
        user = store(request).register(
            credentials.email,
            credentials.display_name,
            credentials.password,
        )
        token, _ = store(request).create_session(
            user["email"],
            lifetime_days=request.app.state.settings.auth_session_days,
        )
    except AccountError as error:
        return account_error(error)
    set_session_cookie(response, request, token)
    store(request).record_event(
        "account_registered", actor_email=user["email"], metadata={"route": "register"}
    )
    return {"authenticated": True, "user": user}


@router.post("/login", response_model=None)
def login(
    credentials: AccountCredentials,
    request: Request,
    response: Response,
) -> dict[str, Any] | JSONResponse:
    try:
        user = store(request).authenticate(credentials.email, credentials.password)
    except AccountError as error:
        return account_error(error)
    if user is None:
        return account_error(
            AccountError("AUTHENTICATION_FAILED", "邮箱或密码不正确。"),
            default_status=401,
        )
    token, _ = store(request).create_session(
        user["email"],
        lifetime_days=request.app.state.settings.auth_session_days,
    )
    set_session_cookie(response, request, token)
    store(request).record_event(
        "account_login", actor_email=user["email"], metadata={"route": "login"}
    )
    return {"authenticated": True, "user": user}


@router.post("/logout")
def logout(request: Request, response: Response) -> dict[str, bool]:
    settings = request.app.state.settings
    store(request).delete_session(request.cookies.get(settings.auth_cookie_name))
    response.delete_cookie(settings.auth_cookie_name, path="/")
    return {"authenticated": False}


@router.get("/workspace")
def get_workspace(request: Request) -> dict[str, Any]:
    user = current_user(request)
    if user is None:
        return {"authenticated": False, "user": None, "people": []}
    return {
        "authenticated": True,
        "user": user,
        "people": store(request).workspace(user["email"]),
        "preferences": store(request).preferences(user["email"]),
    }


@router.post("/workspace", response_model=None)
def update_workspace(action: WorkspaceAction, request: Request) -> dict[str, Any] | JSONResponse:
    user = current_user(request)
    if user is None:
        return account_error(
            AccountError("LOGIN_REQUIRED", "登录后才能保存；游客计算不会持久化。"),
            default_status=401,
        )
    payload = action.model_dump()
    try:
        if action.action == "set_default_person":
            return {
                "preferences": store(request).set_default_person(
                    user["email"], action.personId
                )
            }
        if action.action == "set_sample_visibility":
            if action.sampleVisible is None:
                raise AccountError("INVALID_PREFERENCES", "缺少示例显示设置。")
            return {
                "preferences": store(request).set_sample_visibility(
                    user["email"], action.sampleVisible
                )
            }
        if action.action == "save_person":
            identifier, saved_at = store(request).save_person(
                user["email"],
                action.person or {},
                action.personId,
            )
            store(request).record_event(
                "object_updated" if action.personId else "object_created",
                actor_email=user["email"],
                success=True,
                metadata={"object_type": "person"},
            )
            return {"id": identifier, "savedAt": saved_at}
        person_id = action.personId or ""
        if action.action == "save_latest_natal":
            return store(request).save_latest_natal(user["email"], person_id, payload)
        if action.action == "save_ai_analysis":
            store(request).save_ai_analysis(
                user["email"],
                person_id,
                action.aiAnalysisText or "",
                action.aiModelId,
            )
            store(request).record_event(
                "report_generated",
                actor_email=user["email"],
                success=True,
                metadata={"analysis_type": "natal", "model_id": action.aiModelId or ""},
            )
            return {"personId": person_id, "saved": True}
        store(request).delete_person(user["email"], person_id)
        store(request).record_event(
            "object_deleted",
            actor_email=user["email"],
            success=True,
            metadata={"object_type": "person"},
        )
        return {"personId": person_id, "deleted": True}
    except AccountError as error:
        return account_error(error)


@router.get("/preferences", response_model=None)
def get_preferences(request: Request) -> dict[str, Any] | JSONResponse:
    user = current_user(request)
    if user is None:
        return account_error(
            AccountError("LOGIN_REQUIRED", "登录后才能保存偏好设置。"),
            default_status=401,
        )
    return {"preferences": store(request).preferences(user["email"])}


@router.patch("/preferences", response_model=None)
def patch_preferences(
    payload: AccountPreferencesUpdate, request: Request
) -> dict[str, Any] | JSONResponse:
    user = current_user(request)
    if user is None:
        return account_error(
            AccountError("LOGIN_REQUIRED", "登录后才能保存偏好设置。"),
            default_status=401,
        )
    if not payload.model_fields_set:
        return account_error(AccountError("INVALID_PREFERENCES", "没有需要更新的设置。"))
    try:
        preferences = store(request).preferences(user["email"])
        if "default_person_id" in payload.model_fields_set:
            preferences = store(request).set_default_person(
                user["email"], payload.default_person_id
            )
        if "sample_visible" in payload.model_fields_set:
            if payload.sample_visible is None:
                raise AccountError("INVALID_PREFERENCES", "示例显示设置不能为空。")
            preferences = store(request).set_sample_visibility(
                user["email"], payload.sample_visible
            )
        return {"preferences": preferences}
    except AccountError as error:
        return account_error(error)
