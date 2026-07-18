"""FastAPI application factory."""

from __future__ import annotations

from fastapi import FastAPI

from interstellar_api.catalogs import load_official_analysis_models
from interstellar_api.config import ApiSettings
from interstellar_api.errors import install_problem_handlers
from interstellar_api.middleware import install_request_context
from interstellar_api.readiness import ProbeResult, ReadinessRegistry
from interstellar_api.routers.health import router as health_router
from interstellar_api.routers.m1_workflow import router as m1_workflow_router
from interstellar_api.routers.m2_calculations import router as m2_calculations_router
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
    app.state.analysis_model_catalog = load_official_analysis_models()
    app.state.workflow_store = WorkflowStore()
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
    return app


app = create_app()
