"""
Pydantic schemas for request/response validation.
Separating schemas from routes keeps each file focused on one responsibility.
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class DocumentRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=500, description="Search query")
    top_k: int = Field(default=3, ge=1, le=10, description="Number of results to return")


class DocumentResult(BaseModel):
    id: str
    title: str
    content: str
    score: float = Field(..., ge=0.0, le=1.0)
    source: str


class SearchResponse(BaseModel):
    query: str
    results: list[DocumentResult]
    total: int
    processing_time_ms: float
    timestamp: datetime


class HealthResponse(BaseModel):
    status: str
    version: str
    environment: str
    uptime_seconds: float


class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None
    timestamp: datetime