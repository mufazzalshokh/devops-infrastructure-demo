"""
Application entry point.
Wires together config, middleware, routes, and instrumentation.
"""
import time
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from prometheus_fastapi_instrumentator import Instrumentator

from app.core.config import get_settings
from app.api.routes import router

# Logging — structured format for log aggregation (Loki, CloudWatch, etc.)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)


# Lifespan — replaces deprecated @app.on_event("startup")
@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    logger.info(f"Starting {settings.app_name} v{settings.app_version} [{settings.app_env}]")
    yield
    logger.info("Shutting down gracefully")


# App factory
settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="Production-grade FastAPI service demonstrating K8s, Terraform, and CI/CD deployment patterns.",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# CORS — tightened in production via environment variable
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.app_env == "development" else [],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


# Request logging middleware — every request gets logged with timing
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration_ms = round((time.time() - start) * 1000, 2)
    logger.info(
        f"{request.method} {request.url.path} "
        f"→ {response.status_code} [{duration_ms}ms]"
    )
    return response


# Prometheus metrics — exposes /metrics endpoint for scraping
Instrumentator().instrument(app).expose(app)

# Register routes
app.include_router(router)


# Global exception handler — never expose raw tracebacks to clients

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"error": "Internal server error", "detail": str(exc) if settings.debug else None},
    )
