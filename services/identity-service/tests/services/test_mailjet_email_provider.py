"""Unit tests for the Mailjet email provider.

Requests are intercepted with ``httpx.MockTransport`` so the exact payload,
auth header, and response handling can be asserted without network access.
"""

import base64
import json
from collections.abc import Callable, Iterator
from typing import Any

import httpx
import pytest

from app.core.config import get_settings
from app.services.email import EmailSendResult
from app.services.email.mailjet_provider import MailjetEmailProvider

API_URL = "https://api.mailjet.com/v3.1/send"


@pytest.fixture(autouse=True)
def _mailjet_env(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    monkeypatch.setenv("MAILJET_API_KEY", "test-key")
    monkeypatch.setenv("MAILJET_SECRET_KEY", "test-secret")
    monkeypatch.setenv("MAILJET_FROM_EMAIL", "sender@example.com")
    monkeypatch.setenv("MAILJET_FROM_NAME", "FoodLink Test")
    monkeypatch.setenv("MAILJET_API_URL", API_URL)
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
        "app.services.email.mailjet_provider.httpx.AsyncClient",
        client_factory,
    )


async def _send() -> EmailSendResult:
    return await MailjetEmailProvider().send_email(
        to="staff@example.com",
        subject="Your code",
        text_body="Code: 123456",
        html_body="<p>Code: <b>123456</b></p>",
    )


async def test_sends_payload_with_basic_auth(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, Any] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["url"] = str(request.url)
        captured["authorization"] = request.headers["Authorization"]
        captured["payload"] = json.loads(request.content)
        return httpx.Response(
            200,
            json={
                "Messages": [
                    {
                        "Status": "success",
                        "To": [
                            {
                                "Email": "staff@example.com",
                                "MessageUUID": "uuid-1",
                                "MessageID": 42,
                            }
                        ],
                    }
                ]
            },
        )

    _install_transport(monkeypatch, handler)
    result = await _send()

    assert result.success is True
    assert result.provider_message_id == "uuid-1"
    assert captured["url"] == API_URL

    credentials = base64.b64encode(b"test-key:test-secret").decode()
    assert captured["authorization"] == f"Basic {credentials}"

    message = captured["payload"]["Messages"][0]
    assert message["From"] == {
        "Email": "sender@example.com",
        "Name": "FoodLink Test",
    }
    assert message["To"] == [{"Email": "staff@example.com"}]
    assert message["Subject"] == "Your code"
    assert message["TextPart"] == "Code: 123456"
    assert message["HTMLPart"] == "<p>Code: <b>123456</b></p>"


async def test_missing_credentials_fails_without_calling_api(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("MAILJET_API_KEY", "")
    get_settings.cache_clear()
    called = False

    def handler(_request: httpx.Request) -> httpx.Response:
        nonlocal called
        called = True
        return httpx.Response(200, json={})

    _install_transport(monkeypatch, handler)
    result = await _send()

    assert result.success is False
    assert "credentials" in (result.error or "")
    assert called is False


async def test_http_error_is_reported(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(401, text="unauthorized")

    _install_transport(monkeypatch, handler)
    result = await _send()

    assert result.success is False
    assert "401" in (result.error or "")


async def test_mailjet_rejection_is_reported(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "Messages": [
                    {
                        "Status": "error",
                        "Errors": [
                            {
                                "ErrorIdentifier": "sender",
                                "ErrorCode": "send-0001",
                                "ErrorMessage": "Invalid sender address",
                            }
                        ],
                    }
                ]
            },
        )

    _install_transport(monkeypatch, handler)
    result = await _send()

    assert result.success is False
    assert result.error == "Invalid sender address"


async def test_unexpected_response_shape_is_reported(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"Messages": []})

    _install_transport(monkeypatch, handler)
    result = await _send()

    assert result.success is False
    assert "Unexpected Mailjet response" in (result.error or "")


async def test_network_error_is_reported(monkeypatch: pytest.MonkeyPatch) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    _install_transport(monkeypatch, handler)
    result = await _send()

    assert result.success is False
    assert "connection refused" in (result.error or "")
