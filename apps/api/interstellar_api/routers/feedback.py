"""Public feedback submission and admin feedback management."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field

from interstellar_api.account_store import AccountError, AccountStore
from interstellar_api.routers.accounts import account_error, current_user

router = APIRouter(prefix="/api/v1", tags=["feedback"])


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class FeedbackSubmit(StrictModel):
    type: str = Field(default="other", max_length=40)
    content: str = Field(min_length=1, max_length=5000)
    contact: str = Field(default="", max_length=160)


def _store(request: Request) -> AccountStore:
    return request.app.state.account_store


def _admin(request: Request) -> dict[str, str]:
    user = current_user(request)
    if user is None or user.get("role") not in {"admin", "super_admin"}:
        raise AccountError("FORBIDDEN", "需要管理员权限。")
    return user


def _safe_error(error: AccountError) -> JSONResponse:
    return account_error(error, default_status=422)


@router.post("/feedback", response_model=None)
def submit_feedback(payload: FeedbackSubmit, request: Request) -> dict[str, Any] | JSONResponse:
    try:
        user = current_user(request)
        user_email = user.get("email") if user else None
        feedback = _store(request).save_feedback(
            payload.type,
            payload.content,
            contact_value=payload.contact or None,
            user_email_value=user_email,
        )
        return {"ok": True, "feedback": feedback}
    except AccountError as error:
        return _safe_error(error)


@router.get("/admin/feedback", response_model=None)
def list_feedback(
    request: Request,
    status: str | None = None,
    limit: int = 100,
    offset: int = 0,
) -> dict[str, Any] | JSONResponse:
    try:
        _admin(request)
        return _store(request).list_feedback(
            status=status,
            limit=limit,
            offset=offset,
        )
    except AccountError as error:
        return _safe_error(error)


@router.patch("/admin/feedback/{feedback_id}", response_model=None)
def update_feedback(
    feedback_id: int,
    payload: dict[str, Any],
    request: Request,
) -> dict[str, Any] | JSONResponse:
    try:
        _admin(request)
        status = payload.get("status")
        if not isinstance(status, str):
            raise AccountError("INVALID_FEEDBACK_STATUS", "缺少反馈状态。")
        feedback = _store(request).update_feedback_status(feedback_id, status)
        return {"ok": True, "feedback": feedback}
    except AccountError as error:
        return _safe_error(error)
