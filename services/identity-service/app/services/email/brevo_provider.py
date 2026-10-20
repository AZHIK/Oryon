from __future__ import annotations

import httpx
import structlog

from app.core.config import get_settings
from app.services.email.base import EmailSendResult

logger = structlog.get_logger(__name__)


class BrevoEmailProvider:
    """Sends email through Brevo's Transactional Email API v3.

    Auth is the ``api-key`` header (not Basic auth). Each request carries a
    single message; an OTP email is always one recipient, so no batching.
    Docs: https://developers.brevo.com/reference/sendtransacemail
    """

    def __init__(self) -> None:
        settings = get_settings()
        self._api_key = settings.brevo_api_key
        self._from_email = settings.brevo_from_email
        self._from_name = settings.brevo_from_name
        self._api_url = settings.brevo_api_url
        self._timeout = settings.brevo_timeout_seconds

    async def send_email(
        self,
        *,
        to: str,
        subject: str,
        text_body: str,
        html_body: str | None = None,
    ) -> EmailSendResult:
        if not self._api_key:
            logger.error("email_brevo_missing_credentials", to=to)
            return EmailSendResult(
                success=False,
                error="Brevo API key is not configured",
            )

        payload: dict[str, object] = {
            "sender": {"email": self._from_email, "name": self._from_name},
            "to": [{"email": to}],
            "subject": subject,
            "textContent": text_body,
        }
        if html_body is not None:
            payload["htmlContent"] = html_body

        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.post(
                    self._api_url,
                    json=payload,
                    headers={
                        "api-key": self._api_key,
                        "accept": "application/json",
                        "content-type": "application/json",
                    },
                )
        except httpx.HTTPError as exc:
            logger.error("email_brevo_request_failed", to=to, error=str(exc))
            return EmailSendResult(success=False, error=str(exc))

        if response.status_code >= 400:
            detail = self._error_detail(response)
            logger.error(
                "email_brevo_http_error",
                to=to,
                status_code=response.status_code,
                response=response.text,
            )
            return EmailSendResult(
                success=False,
                error=f"Brevo HTTP {response.status_code}: {detail}",
            )

        try:
            result = response.json()
            message_id = result["messageId"]
        except (KeyError, TypeError, ValueError) as exc:
            logger.error(
                "email_brevo_unexpected_response",
                to=to,
                response=response.text,
                error=str(exc),
            )
            return EmailSendResult(
                success=False,
                error=f"Unexpected Brevo response: {exc}",
            )

        return EmailSendResult(
            success=True,
            provider_message_id=str(message_id) if message_id is not None else None,
        )

    @staticmethod
    def _error_detail(response: httpx.Response) -> str:
        """Pull Brevo's human-readable error out of a failed response."""
        try:
            body = response.json()
        except ValueError:
            return response.text or "unknown error"
        if isinstance(body, dict):
            message = body.get("message") or body.get("error")
            if message:
                return str(message)
        return response.text or "unknown error"
