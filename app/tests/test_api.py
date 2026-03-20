"""
API tests — these run in CI on every PR.
Fast, no external dependencies, no database needed.
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["version"] == "1.0.0"
    assert "uptime_seconds" in data


def test_readiness_check():
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json()["status"] == "ready"


def test_search_endpoint():
    response = client.post(
        "/api/v1/search",
        json={"query": "kubernetes docker", "top_k": 3},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["query"] == "kubernetes docker"
    assert len(data["results"]) <= 3
    assert data["total"] >= 0
    assert "processing_time_ms" in data


def test_search_returns_scored_results():
    response = client.post(
        "/api/v1/search",
        json={"query": "kubernetes", "top_k": 5},
    )
    assert response.status_code == 200
    results = response.json()["results"]
    # Results should be sorted by score descending
    scores = [r["score"] for r in results]
    assert scores == sorted(scores, reverse=True)


def test_search_validates_input():
    # Empty query should fail validation
    response = client.post(
        "/api/v1/search",
        json={"query": "", "top_k": 3},
    )
    assert response.status_code == 422


def test_list_documents():
    response = client.get("/api/v1/documents")
    assert response.status_code == 200
    data = response.json()
    assert "documents" in data
    assert data["total"] == 5


def test_metrics_endpoint():
    response = client.get("/metrics")
    assert response.status_code == 200
    assert b"http_requests" in response.content or b"python_gc" in response.content
    