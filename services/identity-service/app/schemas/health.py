"""Health-check response schemas."""

from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str = "ok"
    version: str = "0.1.0"
    service: str = "oryonfoods-auth"


class ReadinessResponse(BaseModel):
    status: str
    database: str
    redis: str
