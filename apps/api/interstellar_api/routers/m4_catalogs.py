"""M4 immutable analysis registry catalog endpoints."""

from __future__ import annotations

import hashlib
import json
from typing import Annotated, Any, Literal, cast

from fastapi import APIRouter, Query, Request, status
from interstellar_core.analysis.registries import (
    AnalysisIntent,
    AnalysisRegistry,
    BaseAnalysisModel,
    EntryPoint,
    TopicModel,
)
from pydantic import BaseModel, ConfigDict

from interstellar_api.errors import ErrorCode, ProblemException

router = APIRouter(prefix="/api/v1", tags=["Catalog"])

Maturity = Literal["stable", "beta", "experimental"]
_MATURITY_ORDER: dict[str, int] = {"experimental": 0, "beta": 1, "stable": 2}


class _StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class CatalogItem(_StrictModel):
    id: str
    version: str
    name: str
    maturity: Maturity
    content_hash: str
    payload: dict[str, Any]


class PageInfo(_StrictModel):
    next_cursor: str | None = None
    has_more: bool


class CatalogPage(_StrictModel):
    items: list[CatalogItem]
    page: PageInfo


def _registry(request: Request) -> AnalysisRegistry:
    registry = getattr(request.app.state, "analysis_registry", None)
    if not isinstance(registry, AnalysisRegistry):
        raise ProblemException(
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            code=ErrorCode.INTERNAL_ERROR,
            title="Analysis registry unavailable",
            detail="The immutable analysis registry is not available to this process.",
            retryable=True,
        )
    return registry


def _canonical_hash(value: dict[str, Any]) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return f"sha256:{hashlib.sha256(encoded).hexdigest()}"


def _catalog_item(
    *,
    identifier: str,
    version: str,
    name: str,
    maturity: Maturity,
    payload: dict[str, Any],
) -> CatalogItem:
    semantic_content = {
        "id": identifier,
        "version": version,
        "name": name,
        "maturity": maturity,
        "payload": payload,
    }
    return CatalogItem(
        id=identifier,
        version=version,
        name=name,
        maturity=maturity,
        content_hash=_canonical_hash(semantic_content),
        payload=payload,
    )


def _entry_point_item(entry: EntryPoint) -> CatalogItem:
    return _catalog_item(
        identifier=entry.id,
        version=entry.catalog_version,
        name=entry.name_zh,
        maturity="stable",
        payload={
            "behavior": entry.behavior,
            "catalog_version": entry.catalog_version,
        },
    )


def _analysis_model_item(model: BaseAnalysisModel) -> CatalogItem:
    return _catalog_item(
        identifier=model.id,
        version=model.version,
        name=model.name_zh,
        maturity=_maturity(model.target_maturity),
        payload={
            "phase": model.phase,
            "components": list(model.components),
            "optional_components": list(model.optional_components),
            "variant_components": list(model.variant_components),
            "default_rule_pack": model.default_rule_pack,
            "primary_outputs": list(model.primary_outputs),
        },
    )


def _topic_model_item(model: TopicModel) -> CatalogItem:
    return _catalog_item(
        identifier=model.id,
        version=model.catalog_version,
        name=model.name_zh,
        maturity=_maturity(model.report_target),
        payload={
            "group": model.group,
            "phase": model.phase,
            "base_models": list(model.base_models),
            "input_profile": model.input_profile,
            "output_profile": model.output_profile,
            "report_target": model.report_target,
            "catalog_version": model.catalog_version,
        },
    )


def _maturity(value: str) -> Maturity:
    if value not in _MATURITY_ORDER:
        raise ProblemException(
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            code=ErrorCode.INTERNAL_ERROR,
            title="Invalid analysis registry",
            detail=f"The immutable analysis registry contains invalid maturity {value!r}.",
        )
    return cast(Maturity, value)


def _intent_maturity(intent: AnalysisIntent, registry: AnalysisRegistry) -> Maturity:
    topic_maturities = [
        registry.get_topic_model(topic_id).report_target for topic_id in intent.topic_models
    ]
    if not topic_maturities:
        return "experimental"
    maturity = min(topic_maturities, key=lambda value: _MATURITY_ORDER[value])
    return _maturity(maturity)


def _analysis_intent_item(intent: AnalysisIntent, registry: AnalysisRegistry) -> CatalogItem:
    return _catalog_item(
        identifier=intent.id,
        version=intent.catalog_version,
        name=intent.name_zh,
        maturity=_intent_maturity(intent, registry),
        payload={
            "group": intent.group,
            "topic_models": list(intent.topic_models),
            "input_profile": intent.input_profile,
            "report_profile": intent.report_profile,
            "catalog_version": intent.catalog_version,
        },
    )


def _decode_cursor(cursor: str | None) -> int:
    if cursor is None:
        return 0
    try:
        offset = int(cursor)
    except ValueError as exc:
        raise ProblemException(
            status=status.HTTP_400_BAD_REQUEST,
            code=ErrorCode.INVALID_REQUEST,
            detail="page[cursor] must be an opaque cursor returned by this endpoint.",
            fields={"page[cursor]": "invalid cursor"},
        ) from exc
    if offset < 0:
        raise ProblemException(
            status=status.HTTP_400_BAD_REQUEST,
            code=ErrorCode.INVALID_REQUEST,
            detail="page[cursor] must be an opaque cursor returned by this endpoint.",
            fields={"page[cursor]": "invalid cursor"},
        )
    return offset


def _page(
    items: list[CatalogItem],
    *,
    cursor: str | None,
    limit: int,
    q: str | None,
    maturity: Maturity | None,
) -> CatalogPage:
    if q is not None and (needle := q.strip().casefold()):
        items = [
            item
            for item in items
            if needle
            in json.dumps(
                item.model_dump(mode="json"),
                ensure_ascii=False,
                sort_keys=True,
            ).casefold()
        ]
    if maturity is not None:
        items = [item for item in items if item.maturity == maturity]

    offset = _decode_cursor(cursor)
    page_items = items[offset : offset + limit]
    next_offset = offset + len(page_items)
    has_more = next_offset < len(items)
    return CatalogPage(
        items=page_items,
        page=PageInfo(next_cursor=str(next_offset) if has_more else None, has_more=has_more),
    )


def _not_found(resource: str, identifier: str, version: str | None = None) -> ProblemException:
    version_suffix = f" at version {version!r}" if version is not None else ""
    return ProblemException(
        status=status.HTTP_404_NOT_FOUND,
        code=ErrorCode.NOT_FOUND,
        detail=f"{resource} {identifier!r}{version_suffix} was not found.",
    )


@router.get("/entry-points", response_model=CatalogPage)
async def list_entry_points(
    request: Request,
    cursor: Annotated[str | None, Query(alias="page[cursor]")] = None,
    limit: Annotated[int, Query(ge=1, le=100, alias="page[limit]")] = 20,
    q: Annotated[str | None, Query(max_length=200)] = None,
    maturity: Annotated[Maturity | None, Query()] = None,
) -> CatalogPage:
    registry = _registry(request)
    return _page(
        [_entry_point_item(item) for item in registry.list_entry_points()],
        cursor=cursor,
        limit=limit,
        q=q,
        maturity=maturity,
    )


@router.get("/analysis-models", response_model=CatalogPage)
async def list_analysis_models(
    request: Request,
    cursor: Annotated[str | None, Query(alias="page[cursor]")] = None,
    limit: Annotated[int, Query(ge=1, le=100, alias="page[limit]")] = 20,
    q: Annotated[str | None, Query(max_length=200)] = None,
    maturity: Annotated[Maturity | None, Query()] = None,
) -> CatalogPage:
    registry = _registry(request)
    return _page(
        [_analysis_model_item(item) for item in registry.list_base_models()],
        cursor=cursor,
        limit=limit,
        q=q,
        maturity=maturity,
    )


@router.get("/analysis-models/{id}", response_model=CatalogItem)
async def get_analysis_model(id: str, request: Request) -> CatalogItem:
    registry = _registry(request)
    try:
        model = registry.get_base_model(id)
    except KeyError as exc:
        raise _not_found("Analysis model", id) from exc
    return _analysis_model_item(model)


@router.get("/analysis-models/{id}/versions/{version}", response_model=CatalogItem)
async def get_analysis_model_version(id: str, version: str, request: Request) -> CatalogItem:
    registry = _registry(request)
    try:
        model = registry.get_base_model(id)
    except KeyError as exc:
        raise _not_found("Analysis model", id, version) from exc
    if model.version != version:
        raise _not_found("Analysis model", id, version)
    return _analysis_model_item(model)


@router.get("/topic-models", response_model=CatalogPage)
async def list_topic_models(
    request: Request,
    cursor: Annotated[str | None, Query(alias="page[cursor]")] = None,
    limit: Annotated[int, Query(ge=1, le=100, alias="page[limit]")] = 20,
    q: Annotated[str | None, Query(max_length=200)] = None,
    maturity: Annotated[Maturity | None, Query()] = None,
) -> CatalogPage:
    registry = _registry(request)
    return _page(
        [_topic_model_item(item) for item in registry.list_topic_models()],
        cursor=cursor,
        limit=limit,
        q=q,
        maturity=maturity,
    )


@router.get("/topic-models/{id}/versions/{version}", response_model=CatalogItem)
async def get_topic_model_version(id: str, version: str, request: Request) -> CatalogItem:
    registry = _registry(request)
    try:
        model = registry.get_topic_model(id)
    except KeyError as exc:
        raise _not_found("Topic model", id, version) from exc
    if model.catalog_version != version:
        raise _not_found("Topic model", id, version)
    return _topic_model_item(model)


@router.get("/analysis-intents", response_model=CatalogPage)
async def list_analysis_intents(
    request: Request,
    cursor: Annotated[str | None, Query(alias="page[cursor]")] = None,
    limit: Annotated[int, Query(ge=1, le=100, alias="page[limit]")] = 20,
    q: Annotated[str | None, Query(max_length=200)] = None,
    maturity: Annotated[Maturity | None, Query()] = None,
) -> CatalogPage:
    registry = _registry(request)
    return _page(
        [_analysis_intent_item(item, registry) for item in registry.list_intents()],
        cursor=cursor,
        limit=limit,
        q=q,
        maturity=maturity,
    )


@router.get("/analysis-intents/{id}/versions/{version}", response_model=CatalogItem)
async def get_analysis_intent_version(id: str, version: str, request: Request) -> CatalogItem:
    registry = _registry(request)
    try:
        intent = registry.get_intent(id)
    except KeyError as exc:
        raise _not_found("Analysis intent", id, version) from exc
    if intent.catalog_version != version:
        raise _not_found("Analysis intent", id, version)
    return _analysis_intent_item(intent, registry)
