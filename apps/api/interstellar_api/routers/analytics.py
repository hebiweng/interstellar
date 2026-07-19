"""Allow-listed, privacy-minimizing product analytics ingestion."""

from __future__ import annotations

import secrets
from typing import Any

from fastapi import APIRouter, Request, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field

from interstellar_api.account_store import AccountError
from interstellar_api.routers.accounts import account_error, current_user

router = APIRouter(prefix="/api/v1/analytics", tags=["analytics"])
VISITOR_COOKIE = "interstellar_visitor"


class AnalyticsEventPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    event_name: str = Field(min_length=1, max_length=80)
    success: bool | None = None
    duration_ms: int | None = Field(default=None, ge=0, le=3_600_000)
    metadata: dict[str, Any] = Field(default_factory=dict)


@router.post("/events", response_model=None)
def create_event(
    payload: AnalyticsEventPayload, request: Request, response: Response
) -> dict[str, bool] | JSONResponse:
    visitor = request.cookies.get(VISITOR_COOKIE) or secrets.token_urlsafe(24)
    if not request.cookies.get(VISITOR_COOKIE):
        response.set_cookie(
            VISITOR_COOKIE,
            visitor,
            max_age=365 * 24 * 60 * 60,
            httponly=True,
            secure=request.app.state.settings.auth_cookie_secure,
            samesite="lax",
            path="/",
        )
    user = current_user(request)
    try:
        request.app.state.account_store.record_event(
            payload.event_name,
            actor_email=user["email"] if user else None,
            visitor_id=visitor,
            success=payload.success,
            duration_ms=payload.duration_ms,
            metadata=payload.metadata,
        )
    except AccountError as error:
        return account_error(error)
    return {"accepted": True}
