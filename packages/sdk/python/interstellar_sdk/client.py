"""Dependency-free Python client over the generated V1 operation registry."""

from __future__ import annotations

import json
from collections.abc import Iterator, Mapping
from dataclasses import dataclass
from typing import Any
from urllib.error import HTTPError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen

from .operations import OPERATIONS


class InterstellarApiError(RuntimeError):
    def __init__(self, status: int, payload: Any) -> None:
        self.status = status
        self.payload = payload
        detail = payload.get("detail") if isinstance(payload, Mapping) else str(payload)
        super().__init__(f"Interstellar API returned HTTP {status}: {detail}")


@dataclass(frozen=True, slots=True)
class SseEvent:
    event_id: str | None
    event: str
    data: str


class InterstellarClient:
    def __init__(
        self,
        base_url: str,
        *,
        bearer_token: str | None = None,
        timeout_seconds: float = 30.0,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.bearer_token = bearer_token
        self.timeout_seconds = timeout_seconds

    def request(
        self,
        operation_id: str,
        *,
        path: Mapping[str, str | int] | None = None,
        query: Mapping[str, Any] | None = None,
        body: Any = None,
        headers: Mapping[str, str] | None = None,
    ) -> Any:
        definition = self._operation(operation_id)
        url = self._url(definition["path"], path or {}, query or {})
        request_headers = self._headers(headers)
        encoded_body = None
        if body is not None:
            encoded_body = json.dumps(body, ensure_ascii=False).encode("utf-8")
            request_headers.setdefault("Content-Type", "application/json")
        request = Request(
            url,
            data=encoded_body,
            headers=request_headers,
            method=definition["method"],
        )
        try:
            with urlopen(request, timeout=self.timeout_seconds) as response:  # noqa: S310
                return self._decode(
                    response.status,
                    response.headers.get("Content-Type"),
                    response.read(),
                )
        except HTTPError as exc:
            payload = self._decode(
                exc.code, exc.headers.get("Content-Type"), exc.read()
            )
            raise InterstellarApiError(exc.code, payload) from exc

    def stream_sse(
        self,
        operation_id: str,
        *,
        path: Mapping[str, str | int],
        query: Mapping[str, Any] | None = None,
        last_event_id: str | None = None,
    ) -> Iterator[SseEvent]:
        definition = self._operation(operation_id)
        if definition["method"] != "GET":
            raise ValueError("SSE operations must use GET")
        headers = self._headers({"Accept": "text/event-stream"})
        if last_event_id is not None:
            headers["Last-Event-ID"] = last_event_id
        request = Request(
            self._url(definition["path"], path, query or {}),
            headers=headers,
            method="GET",
        )
        try:
            with urlopen(request, timeout=self.timeout_seconds) as response:  # noqa: S310
                yield from _parse_sse_lines(
                    line.decode("utf-8").rstrip("\r\n") for line in response
                )
        except HTTPError as exc:
            payload = self._decode(
                exc.code, exc.headers.get("Content-Type"), exc.read()
            )
            raise InterstellarApiError(exc.code, payload) from exc

    def _operation(self, operation_id: str) -> dict[str, str]:
        try:
            return OPERATIONS[operation_id]
        except KeyError as exc:
            raise ValueError(f"unknown OpenAPI operation: {operation_id}") from exc

    def _url(
        self,
        route: str,
        path: Mapping[str, str | int],
        query: Mapping[str, Any],
    ) -> str:
        rendered = route
        for key, value in path.items():
            rendered = rendered.replace("{" + key + "}", quote(str(value), safe=""))
        if "{" in rendered or "}" in rendered:
            raise ValueError(f"missing path parameter for {route}")
        query_string = urlencode(
            [
                (key, item)
                for key, value in query.items()
                for item in _query_values(value)
            ],
            doseq=True,
        )
        url = self.base_url + rendered
        return f"{url}?{query_string}" if query_string else url

    def _headers(self, extra: Mapping[str, str] | None) -> dict[str, str]:
        headers = {"Accept": "application/json"}
        if self.bearer_token:
            headers["Authorization"] = f"Bearer {self.bearer_token}"
        headers.update(extra or {})
        return headers

    @staticmethod
    def _decode(status: int, content_type: str | None, payload: bytes) -> Any:
        if status == 204 or not payload:
            return None
        text = payload.decode("utf-8")
        if content_type and ("json" in content_type or "+json" in content_type):
            return json.loads(text)
        return text


def _query_values(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, (list, tuple)):
        return list(value)
    if isinstance(value, bool):
        return [str(value).lower()]
    return [value]


def _parse_sse_lines(lines: Iterator[str]) -> Iterator[SseEvent]:
    event_id: str | None = None
    event = "message"
    data: list[str] = []
    for line in lines:
        if not line:
            if data:
                yield SseEvent(event_id=event_id, event=event, data="\n".join(data))
            event_id, event, data = None, "message", []
            continue
        if line.startswith(":"):
            continue
        field, _, value = line.partition(":")
        value = value[1:] if value.startswith(" ") else value
        if field == "id":
            event_id = value
        elif field == "event":
            event = value
        elif field == "data":
            data.append(value)
    if data:
        yield SseEvent(event_id=event_id, event=event, data="\n".join(data))
