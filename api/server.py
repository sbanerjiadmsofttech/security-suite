"""FastAPI REST API server for Security Suite."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routers import scans, results, modules, health


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    app = FastAPI(
        title="Security Suite API",
        description="REST API for Security Suite scanning and analysis",
        version="0.1.0",
    )

    # Add CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Include routers
    app.include_router(health.router, tags=["Health"])
    app.include_router(scans.router, prefix="/api/v1/scans", tags=["Scans"])
    app.include_router(results.router, prefix="/api/v1/results", tags=["Results"])
    app.include_router(modules.router, prefix="/api/v1/modules", tags=["Modules"])

    return app
