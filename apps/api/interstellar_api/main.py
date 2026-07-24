"""FastAPI application factory."""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from interstellar_core.analysis.registries import load_analysis_registry
from interstellar_core.jobs import InMemoryJobStore

from interstellar_api.account_store import AccountStore
from interstellar_api.catalogs import load_official_analysis_models
from interstellar_api.config import ApiSettings
from interstellar_api.datasets import load_local_dataset_inventory
from interstellar_api.deepseek import execute_deepseek_analysis
from interstellar_api.errors import install_problem_handlers
from interstellar_api.locations import load_location_resolver
from interstellar_api.middleware import install_request_context
from interstellar_api.readiness import ProbeResult, ReadinessRegistry
from interstellar_api.recipe_registry import load_repository_recipe_registry
from interstellar_api.routers.accounts import router as accounts_router
from interstellar_api.routers.feedback import router as feedback_router
from interstellar_api.routers.admin import router as admin_router
from interstellar_api.routers.analytics import router as analytics_router
from interstellar_api.routers.datasets import router as datasets_router
from interstellar_api.routers.health import router as health_router
from interstellar_api.routers.locations import router as locations_router
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
    app.state.dataset_inventory = load_local_dataset_inventory()
    app.state.account_store = AccountStore(
        resolved.account_database_path,
        master_key=(
            resolved.admin_master_key.get_secret_value()
            if resolved.admin_master_key is not None
            else None
        ),
    )
    if resolved.admin_bootstrap_email:
        app.state.account_store.ensure_super_admin(
            resolved.admin_bootstrap_email,
            (
                resolved.admin_bootstrap_password.get_secret_value()
                if resolved.admin_bootstrap_password is not None
                else None
            ),
        )
    app.state.location_resolver = load_location_resolver(resolved)
    if resolved.cors_allowed_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=list(resolved.cors_allowed_origins),
            allow_credentials=True,
            allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
            allow_headers=[
                "Accept",
                "Content-Type",
                "If-Match",
                "Last-Event-ID",
                "Prefer",
                resolved.request_id_header,
            ],
            expose_headers=[
                "Location",
                "Retry-After",
                "ETag",
                "X-Interstellar-Document-Hash",
                "X-Interstellar-Snapshot-ID",
                "X-Interstellar-Input-Fingerprint",
                resolved.request_id_header,
            ],
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
    if resolved.deepseek_api_key is not None:
        configured_model = resolved.deepseek_model
        app.state.natal_ai_provider_overrides = {
            "deepseek": {
                "configured": True,
                "availability": "configured",
                "blocking_reason": None,
                "models": [
                    {
                        "model_id": model_id,
                        "label": (
                            "DeepSeek V4 Pro"
                            if model_id == "deepseek-v4-pro"
                            else "DeepSeek V4 Flash"
                        ),
                        "configured": model_id == configured_model,
                        "context_limit": None,
                    }
                    for model_id in ("deepseek-v4-pro", "deepseek-v4-flash")
                ],
            }
        }
        secret = resolved.deepseek_api_key.get_secret_value()

        async def deepseek_executor(payload: dict[str, object]) -> dict[str, object]:
            return await execute_deepseek_analysis(
                payload,
                api_key=secret,
                base_url=resolved.deepseek_base_url,
                model=resolved.deepseek_model,
            )

        app.state.natal_ai_executor = deepseek_executor
    else:
        app.state.natal_ai_provider_overrides = {}
        app.state.natal_ai_executor = None
    app.state.optional_ai_artifacts = {}
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
    app.include_router(accounts_router)
    app.include_router(feedback_router)
    app.include_router(admin_router)
    app.include_router(analytics_router)
    app.include_router(datasets_router)
    app.include_router(locations_router)
    app.include_router(m1_workflow_router)
    app.include_router(m2_calculations_router)
    app.include_router(m4_catalogs_router)
    app.include_router(m4_jobs_router)
    app.include_router(natal_interpretations_router)
    app.include_router(natal_ai_router)
    return app


app = create_app()
