"""Unit tests for the Brevo email provider.

Requests are intercepted with ``httpx.MockTransport`` so the exact payload,
api-key header, and response handling can be asserted without network access.
"""

import json
from collections.abc import Callable, Iterator
from typing import Any

import httpx
import pytest

from app.core.config import get_settings
from app.services.email import EmailSendResult, get_email_provider
from app.services.email.brevo_provider import BrevoEmailProvider

API_URL = "https://api.brevo.com/v3/smtp/email"


@pytest.fixture(autouse=True)
def _brevo_env(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    monkeypatch.setenv("BREVO_API_KEY", "test-key")
    monkeypatch.setenv("BREVO_FROM_EMAIL", "sender@example.com")
    monkeypatch.setenv("BREVO_FROM_NAME", "Oryon Foods Test")
    monkeypatch.setenv("BREVO_API_URL", API_URL)
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def _install_transport(
    monkeypatch: pytest.MonkeyPatch,
    handler: Callable[[httpx.Request], httpx.Response],
) -> None:
    """Route the provider's AsyncClient through a mock transport."""
    real_client = httpx.AsyncClient
    transport = httpx.MockTransport(handler)

    def client_factory(*args: Any, **kwargs: Any) -> httpx.AsyncClient:
        kwargs["transport"] = transport
        return real_client(*args, **kwargs)

    monkeypatch.setattr(
        "app.services.email.brevo_provider.httpx.AsyncClient",
        client_factory,
    )


async def _send() -> EmailSendResult:
    return await BrevoEmailProvider().send_email(
        to="staff@example.com",
        subject="Your code",
        text_body="Code: 123456",
        html_body="<p>Code: <b>123456</b></p>",
    )


async def test_get_email_provider_selects_brevo(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "email_provider", "brevo")
    assert isinstance(get_email_provider(), BrevoEmailProvider)


async def test_sends_payload_with_api_key(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, Any] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["url"] = str(request.url)
        captured["api_key"] = request.headers["api-key"]
        captured["payload"] = json.loads(request.content)
        return httpx.Response(
            201,
            json={"messageId": "<202410201017.123456@example.com>"},
        )

    _install_transport(monkeypatch, handler)
    result = await _send()

    assert result.success is True
    assert result.provider_message_id == "<202410201017.123456@example.com>"
    assert captured["url"] == API_URL
    assert captured["api_key"] == "test-key"

    payload = captured["payload"]
    assert payload["sender"] == {
        "email": "sender@example.com",
        "name": "Oryon Foods Test",
    }
    assert payload["to"] == [{"email": "staff@example.com"}]
    assert payload["subject"] == "Your code"
    assert payload["textContent"] == "Code: 123456"
    assert payload["htmlContent"] == "<p>Code: <b>123456</b></p>"


async def test_missing_api_key_fails_without_calling_api(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("BREVO_API_KEY", "")
    get_settings.cache_clear()
    called = False

    def handler(_request: httpx.Request) -> httpx.Response:
        nonlocal called
        called = True
        return httpx.Response(201, json={"messageId": "id"})

    _install_transport(monkeypatch, handler)
    result = await _send()

    assert result.success is False
    assert "not configured" in (result.error or "")
    assert called is False


async def test_http_error_includes_brevo_message(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            401,
            json={"code": "unauthorized", "message": "Key not found"},
        )

    _install_transport(monkeypatch, handler)
    result = await _send()

    assert result.success is False
    assert "401" in (result.error or "")
    assert "Key not found" in (result.error or "")


async def test_unexpected_response_shape_is_reported(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(201, json={})

    _install_transport(monkeypatch, handler)
    result = await _send()

    assert result.success is False
    assert "Unexpected Brevo response" in (result.error or "")


async def test_network_error_is_reported(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    _install_transport(monkeypatch, handler)
    result = await _send()

    assert result.success is False
    assert "connection refused" in (result.error or "")
