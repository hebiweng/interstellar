"""FastAPI application factory."""

from __future__ import annotations

from fastapi import FastAPI

from interstellar_api.config import ApiSettings
from interstellar_api.errors import install_problem_handlers
from interstellar_api.middleware import install_request_context
from interstellar_api.readiness import ProbeResult, ReadinessRegistry
from interstellar_api.routers.health import router as health_router


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
    return app


app = create_app()
