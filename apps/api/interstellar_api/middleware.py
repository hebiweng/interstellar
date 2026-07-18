"""Cross-cutting HTTP middleware."""

from __future__ import annotations

import re
from uuid import uuid4

from fastapi import FastAPI, Request

_REQUEST_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$")


def install_request_context(app: FastAPI, *, request_id_header: str) -> None:
    @app.middleware("http")
    async def request_context(request: Request, call_next):  # type: ignore[no-untyped-def]
        supplied = request.headers.get(request_id_header, "")
        request_id = supplied if _REQUEST_ID.fullmatch(supplied) else f"req-{uuid4().hex}"
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers[request_id_header] = request_id
        return response
