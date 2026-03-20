"""
API route definitions.
Each router is responsible for one domain — easy to test, easy to extend.
"""
import time
import uuid
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Header
from typing import Optional

from app.core.config import get_settings, Settings
from app.models.schemas import (
    DocumentRequest,
    SearchResponse,
    DocumentResult,
    HealthResponse,
    ErrorResponse,
)

router = APIRouter()

# Module-level start time to calculate uptime
_start_time = time.time()

# Simulated document store — in a real system this would be FAISS / pgvector

MOCK_DOCUMENTS = [
    {"id": "doc-1", "title": "Kubernetes Best Practices", "content": "Use namespaces to isolate workloads. Always set resource requests and limits.", "source": "internal-wiki"},
    {"id": "doc-2", "title": "FastAPI Performance Guide", "content": "Use async endpoints for I/O-bound operations. Enable gzip compression for large responses.", "source": "engineering-blog"},
    {"id": "doc-3", "title": "PostgreSQL Indexing Strategy", "content": "Partial indexes reduce index size. Use EXPLAIN ANALYZE to verify index usage.", "source": "dba-runbook"},
    {"id": "doc-4", "title": "Docker Security Hardening", "content": "Never run containers as root. Use read-only filesystems where possible.", "source": "security-docs"},
    {"id": "doc-5", "title": "Redis Caching Patterns", "content": "Cache-aside pattern gives fine-grained control. Always set TTL to prevent stale data.", "source": "architecture-docs"},
]


def _verify_api_key(
    x_api_key: Optional[str] = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> None:
    """Simple API key auth — demonstrates security awareness without over-engineering."""
    if settings.app_env != "development" and x_api_key != settings.api_key:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")


def _score_document(doc: dict, query: str) -> float:
    """
    Naive keyword scoring — intentionally simple.
    A real system uses vector embeddings (FAISS, pgvector).
    This keeps the demo self-contained with zero ML dependencies.
    """
    query_words = set(query.lower().split())
    doc_words = set((doc["title"] + " " + doc["content"]).lower().split())
    overlap = query_words & doc_words
    return round(len(overlap) / max(len(query_words), 1), 2)


# Routes

@router.get("/health", response_model=HealthResponse, tags=["ops"])
async def health_check(settings: Settings = Depends(get_settings)):
    """
    Liveness probe endpoint.
    Kubernetes calls this to decide if the pod needs to be restarted.
    """
    return HealthResponse(
        status="healthy",
        version=settings.app_version,
        environment=settings.app_env,
        uptime_seconds=round(time.time() - _start_time, 2),
    )


@router.get("/ready", tags=["ops"])
async def readiness_check():
    """
    Readiness probe endpoint.
    Kubernetes calls this to decide if the pod should receive traffic.
    In a real system: check DB connection, cache connection, etc.
    """
    return {"status": "ready"}


@router.post(
    "/api/v1/search",
    response_model=SearchResponse,
    tags=["search"],
    dependencies=[Depends(_verify_api_key)],
)
async def search_documents(request: DocumentRequest):
    """
    Document search endpoint.
    Accepts a query, scores all documents, returns top-k results.
    """
    start = time.time()

    scored = [
        {**doc, "score": _score_document(doc, request.query)}
        for doc in MOCK_DOCUMENTS
    ]
    scored.sort(key=lambda x: x["score"], reverse=True)
    top = scored[: request.top_k]

    processing_ms = round((time.time() - start) * 1000, 2)

    return SearchResponse(
        query=request.query,
        results=[DocumentResult(**doc) for doc in top],
        total=len(top),
        processing_time_ms=processing_ms,
        timestamp=datetime.utcnow(),
    )


@router.get("/api/v1/documents", tags=["documents"])
async def list_documents(dependencies=[Depends(_verify_api_key)]):
    """Returns all documents in the store."""
    return {"documents": MOCK_DOCUMENTS, "total": len(MOCK_DOCUMENTS)}