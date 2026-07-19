"""Versioned local dataset inventory endpoints."""

from __future__ import annotations

from typing import Annotated, Any, Literal

from fastapi import APIRouter, Query, Request, status
from pydantic import BaseModel, ConfigDict

from interstellar_api.datasets import LocalDatasetRecord
from interstellar_api.errors import ErrorCode, ProblemException

router = APIRouter(prefix="/api/v1", tags=["Datasets"])


class _StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class DatasetItem(_StrictModel):
    id: str
    version: str
    status: Literal[
        "discovered",
        "downloading",
        "validating",
        "staged",
        "active",
        "rejected",
        "rolled_back",
    ]
    checksum: str
    source_uri: str
    license: str
    activated_at: str | None
    metadata: dict[str, Any]


class PageInfo(_StrictModel):
    next_cursor: str | None = None
    has_more: bool


class DatasetPage(_StrictModel):
    items: list[DatasetItem]
    page: PageInfo


def _records(request: Request) -> tuple[LocalDatasetRecord, ...]:
    records = getattr(request.app.state, "dataset_inventory", None)
    if not isinstance(records, tuple):
        raise ProblemException(
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            code=ErrorCode.INTERNAL_ERROR,
            title="Dataset inventory unavailable",
            detail="The local dataset inventory could not be loaded.",
            retryable=True,
        )
    return records


def _item(record: LocalDatasetRecord) -> DatasetItem:
    return DatasetItem(
        id=record.dataset_id,
        version=record.version,
        status=record.status,  # type: ignore[arg-type]
        checksum=record.checksum,
        source_uri=record.source_uri,
        license=record.license_identifier,
        activated_at=record.activated_at,
        metadata=record.metadata,
    )


def _offset(cursor: str | None) -> int:
    if cursor is None:
        return 0
    try:
        value = int(cursor)
    except ValueError as exc:
        raise ProblemException(
            status=status.HTTP_400_BAD_REQUEST,
            code=ErrorCode.INVALID_REQUEST,
            detail="page[cursor] is invalid.",
            fields={"page[cursor]": "invalid cursor"},
        ) from exc
    if value < 0:
        raise ProblemException(
            status=status.HTTP_400_BAD_REQUEST,
            code=ErrorCode.INVALID_REQUEST,
            detail="page[cursor] is invalid.",
            fields={"page[cursor]": "invalid cursor"},
        )
    return value


@router.get("/datasets", response_model=DatasetPage)
async def list_datasets(
    request: Request,
    cursor: Annotated[str | None, Query(alias="page[cursor]")] = None,
    limit: Annotated[int, Query(ge=1, le=100, alias="page[limit]")] = 20,
) -> DatasetPage:
    records = _records(request)
    offset = _offset(cursor)
    page_records = records[offset : offset + limit]
    next_offset = offset + len(page_records)
    has_more = next_offset < len(records)
    return DatasetPage(
        items=[_item(record) for record in page_records],
        page=PageInfo(next_cursor=str(next_offset) if has_more else None, has_more=has_more),
    )


@router.get("/datasets/{dataset_id}/versions", response_model=DatasetPage)
async def list_dataset_versions(request: Request, dataset_id: str) -> DatasetPage:
    record = next((item for item in _records(request) if item.dataset_id == dataset_id), None)
    if record is None:
        raise ProblemException(
            status=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.NOT_FOUND,
            detail=f"Unknown dataset {dataset_id!r}.",
        )
    return DatasetPage(items=[_item(record)], page=PageInfo(has_more=False))


@router.get("/datasets/{dataset_id}/versions/{version}", response_model=DatasetItem)
async def get_dataset_version(
    request: Request,
    dataset_id: str,
    version: str,
) -> DatasetItem:
    record = next(
        (
            item
            for item in _records(request)
            if item.dataset_id == dataset_id and item.version == version
        ),
        None,
    )
    if record is None:
        raise ProblemException(
            status=status.HTTP_404_NOT_FOUND,
            code=ErrorCode.NOT_FOUND,
            detail=f"Dataset version {dataset_id!r}/{version!r} is not available.",
        )
    return _item(record)
