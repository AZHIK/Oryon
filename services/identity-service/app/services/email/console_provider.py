from uuid import uuid4

import structlog

from app.services.email.base import EmailSendResult

logger = structlog.get_logger(__name__)


class ConsoleEmailProvider:
    """Logs the full email instead of sending it.

    The default provider, mirroring ``ConsoleProvider`` for SMS — local
    development and tests can read the OTP straight from the API logs.
    """

    async def send_email(
        self,
        *,
        to: str,
        subject: str,
        text_body: str,
        html_body: str | None = None,
    ) -> EmailSendResult:
        fake_id = uuid4().hex[:16]
        logger.info(
            "email_console_send",
            to=to,
            subject=subject,
            text_body=text_body,
            html_body=html_body,
            fake_id=fake_id,
        )
        return EmailSendResult(success=True, provider_message_id=fake_id)
