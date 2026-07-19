"""FastAPI application factory."""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from interstellar_core.analysis.registries import load_analysis_registry
from interstellar_core.jobs import InMemoryJobStore

from interstellar_api.catalogs import load_official_analysis_models
from interstellar_api.config import ApiSettings
from interstellar_api.errors import install_problem_handlers
from interstellar_api.middleware import install_request_context
from interstellar_api.readiness import ProbeResult, ReadinessRegistry
from interstellar_api.recipe_registry import load_repository_recipe_registry
from interstellar_api.routers.health import router as health_router
from interstellar_api.routers.m1_workflow import router as m1_workflow_router
from interstellar_api.routers.m2_calculations import router as m2_calculations_router
from interstellar_api.routers.m4_catalogs import router as m4_catalogs_router
from interstellar_api.routers.m4_jobs import router as m4_jobs_router
from interstellar_api.routers.natal_ai import router as natal_ai_router
from interstellar_api.routers.natal_interpretations import (
    router as natal_interpretations_router,
)
from interstellar_api.workflow_store import WorkflowStore


def create_app(settings: ApiSettings | None = None) -> FastAPI:
    resolved = settings or ApiSettings.from_env()
    app = FastAPI(
        title="Interstellar Professional Astrology API",
        version=resolved.service_version,
        debug=resolved.debug,
        docs_url="/api/docs" if resolved.environment != "production" else None,
        redoc_url=None,
        openapi_url="/api/openapi.json" if resolved.environment != "production" else None,
    )
    app.state.settings = resolved
    if resolved.cors_allowed_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=list(resolved.cors_allowed_origins),
            allow_credentials=False,
            allow_methods=["GET", "POST", "PATCH", "OPTIONS"],
            allow_headers=[
                "Accept",
                "Content-Type",
                "If-Match",
                "Last-Event-ID",
                "Prefer",
                resolved.request_id_header,
            ],
            expose_headers=["Location", "Retry-After", resolved.request_id_header],
        )
    app.state.analysis_model_catalog = load_official_analysis_models()
    app.state.analysis_registry = load_analysis_registry()
    app.state.workflow_store = WorkflowStore()
    app.state.recipe_registry = load_repository_recipe_registry(
        analysis_registry=app.state.analysis_registry,
        workflow_store=app.state.workflow_store,
    )
    # M4 reference adapter. The JobStore port is intentionally replaceable by
    # the durable PostgreSQL/Redis adapter without changing the HTTP contract.
    app.state.job_store = InMemoryJobStore()
    readiness = ReadinessRegistry()
    readiness.register(
        "process",
        lambda: ProbeResult(
            ready=resolved.ready_on_startup,
            detail="process initialized" if resolved.ready_on_startup else "startup gate disabled",
        ),
    )
    app.state.readiness = readiness

    install_problem_handlers(app)
    install_request_context(app, request_id_header=resolved.request_id_header)
    app.include_router(health_router)
    app.include_router(m1_workflow_router)
    app.include_router(m2_calculations_router)
    app.include_router(m4_catalogs_router)
    app.include_router(m4_jobs_router)
    app.include_router(natal_interpretations_router)
    app.include_router(natal_ai_router)
    return app


app = create_app()
