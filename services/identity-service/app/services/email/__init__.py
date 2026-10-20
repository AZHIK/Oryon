from app.core.config import get_settings
from app.services.email.base import EmailProvider, EmailSendResult
from app.services.email.brevo_provider import BrevoEmailProvider
from app.services.email.console_provider import ConsoleEmailProvider
from app.services.email.mailjet_provider import MailjetEmailProvider


def get_email_provider() -> EmailProvider:
    settings = get_settings()
    if settings.email_provider == "brevo":
        return BrevoEmailProvider()
    if settings.email_provider == "mailjet":
        return MailjetEmailProvider()
    return ConsoleEmailProvider()


__all__ = ["EmailProvider", "EmailSendResult", "get_email_provider"]
