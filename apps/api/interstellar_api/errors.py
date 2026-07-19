"""Canonical RFC 9457-style error responses."""

from __future__ import annotations

from enum import StrEnum
from http import HTTPStatus
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field
from starlette.exceptions import HTTPException as StarletteHTTPException


class ErrorCode(StrEnum):
    INVALID_REQUEST = "INVALID_REQUEST"
    UNAUTHENTICATED = "UNAUTHENTICATED"
    FORBIDDEN = "FORBIDDEN"
    NOT_FOUND = "NOT_FOUND"
    INTERNAL_ERROR = "INTERNAL_ERROR"
    AI_PAYLOAD_CHANGED_AFTER_CONSENT = "AI_PAYLOAD_CHANGED_AFTER_CONSENT"
    AI_PROVIDER_NOT_CONFIGURED = "AI_PROVIDER_NOT_CONFIGURED"


class ProblemDetails(BaseModel):
    """M0 subset of the canonical ProblemError schema."""

    model_config = ConfigDict(extra="forbid")

    type: str
    title: str = Field(min_length=1)
    status: int = Field(ge=400, le=599)
    code: ErrorCode
    detail: str = Field(min_length=1)
    instance: str
    fields: dict[str, Any] | None = None
    request_id: str = Field(min_length=1, max_length=160, pattern=r"^[A-Za-z0-9][A-Za-z0-9._:-]*$")
    retryable: bool = False


class ProblemException(Exception):
    def __init__(
        self,
        *,
        status: int,
        code: ErrorCode,
        detail: str,
        title: str | None = None,
        fields: dict[str, Any] | None = None,
        retryable: bool = False,
    ) -> None:
        super().__init__(detail)
        self.status = status
        self.code = code
        self.detail = detail
        self.title = title or HTTPStatus(status).phrase
        self.fields = fields
        self.retryable = retryable


def _request_id(request: Request) -> str:
    return getattr(request.state, "request_id", "request-unknown")


def _problem_response(
    request: Request,
    *,
    status: int,
    code: ErrorCode,
    title: str,
    detail: str,
    fields: dict[str, Any] | None = None,
    retryable: bool = False,
) -> JSONResponse:
    problem = ProblemDetails(
        type=f"https://interstellar.dev/problems/{code.value.lower().replace('_', '-')}",
        title=title,
        status=status,
        code=code,
        detail=detail,
        instance=request.url.path,
        fields=fields,
        request_id=_request_id(request),
        retryable=retryable,
    )
    payload = problem.model_dump(mode="json", exclude_none=True)
    return JSONResponse(status_code=status, content=payload, media_type="application/problem+json")


def install_problem_handlers(app: FastAPI) -> None:
    @app.exception_handler(ProblemException)
    async def handle_problem(request: Request, exc: ProblemException) -> JSONResponse:
        return _problem_response(
            request,
            status=exc.status,
            code=exc.code,
            title=exc.title,
            detail=exc.detail,
            fields=exc.fields,
            retryable=exc.retryable,
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation(request: Request, exc: RequestValidationError) -> JSONResponse:
        fields = {"errors": exc.errors(include_url=False, include_context=False)}
        return _problem_response(
            request,
            status=422,
            code=ErrorCode.INVALID_REQUEST,
            title="Request validation failed",
            detail="One or more request fields are invalid.",
            fields=fields,
        )

    @app.exception_handler(StarletteHTTPException)
    async def handle_http(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        code = {
            401: ErrorCode.UNAUTHENTICATED,
            403: ErrorCode.FORBIDDEN,
            404: ErrorCode.NOT_FOUND,
        }.get(exc.status_code, ErrorCode.INVALID_REQUEST)
        title = (
            HTTPStatus(exc.status_code).phrase
            if exc.status_code in HTTPStatus._value2member_map_
            else "HTTP error"
        )
        return _problem_response(
            request,
            status=exc.status_code,
            code=code,
            title=title,
            detail=str(exc.detail),
        )

    @app.exception_handler(Exception)
    async def handle_unexpected(request: Request, _exc: Exception) -> JSONResponse:
        return _problem_response(
            request,
            status=500,
            code=ErrorCode.INTERNAL_ERROR,
            title="Internal Server Error",
            detail="An unexpected server error occurred.",
            retryable=True,
        )
