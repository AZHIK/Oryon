"""Smoke tests for health-check endpoints."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health_returns_ok(client: AsyncClient) -> None:
    resp = await client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"
    assert data["service"] == "oryonfoods-auth"


@pytest.mark.asyncio
async def test_readiness_endpoint_structure(client: AsyncClient) -> None:
    """Readiness may return unhealthy in tests (no DB/Redis), but must be valid JSON."""
    resp = await client.get("/health/ready")
    assert resp.status_code == 200
    data = resp.json()
    assert "status" in data
    assert "database" in data
    assert "redis" in data
