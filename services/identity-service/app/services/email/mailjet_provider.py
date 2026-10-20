from __future__ import annotations

import httpx
import structlog

from app.core.config import get_settings
from app.services.email.base import EmailSendResult

logger = structlog.get_logger(__name__)


class MailjetEmailProvider:
    """Sends email through Mailjet's Send API v3.1.

    Auth is HTTP Basic with the Mailjet API key/secret pair. Each request
    carries a single message; the API can batch more, but an OTP email is
    always one recipient.
    """

    def __init__(self) -> None:
        settings = get_settings()
        self._api_key = settings.mailjet_api_key
        self._secret_key = settings.mailjet_secret_key
        self._from_email = settings.mailjet_from_email
        self._from_name = settings.mailjet_from_name
        self._api_url = settings.mailjet_api_url
        self._timeout = settings.mailjet_timeout_seconds

    async def send_email(
        self,
        *,
        to: str,
        subject: str,
        text_body: str,
        html_body: str | None = None,
    ) -> EmailSendResult:
        if not self._api_key or not self._secret_key:
            logger.error("email_mailjet_missing_credentials", to=to)
            return EmailSendResult(
                success=False,
                error="Mailjet credentials are not configured",
            )

        message: dict[str, object] = {
            "From": {"Email": self._from_email, "Name": self._from_name},
            "To": [{"Email": to}],
            "Subject": subject,
            "TextPart": text_body,
        }
        if html_body is not None:
            message["HTMLPart"] = html_body

        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.post(
                    self._api_url,
                    json={"Messages": [message]},
                    auth=httpx.BasicAuth(self._api_key, self._secret_key),
                )
        except httpx.HTTPError as exc:
            logger.error("email_mailjet_request_failed", to=to, error=str(exc))
            return EmailSendResult(success=False, error=str(exc))

        if response.status_code >= 400:
            logger.error(
                "email_mailjet_http_error",
                to=to,
                status_code=response.status_code,
                response=response.text,
            )
            return EmailSendResult(
                success=False,
                error=f"Mailjet HTTP {response.status_code}: {response.text}",
            )

        try:
            payload = response.json()
            result = payload["Messages"][0]
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            logger.error(
                "email_mailjet_unexpected_response",
                to=to,
                response=response.text,
                error=str(exc),
            )
            return EmailSendResult(
                success=False,
                error=f"Unexpected Mailjet response: {exc}",
            )

        if result.get("Status") != "success":
            errors = result.get("Errors") or []
            detail = "; ".join(
                str(error.get("ErrorMessage") or error) if isinstance(error, dict) else str(error)
                for error in errors
            )
            logger.error("email_mailjet_send_failed", to=to, errors=errors)
            return EmailSendResult(
                success=False,
                error=detail or "Mailjet rejected the message",
            )

        recipients = result.get("To") or []
        message_id = None
        if recipients:
            message_id = recipients[0].get("MessageUUID") or recipients[0].get("MessageID")

        return EmailSendResult(
            success=True,
            provider_message_id=(str(message_id) if message_id is not None else None),
        )
