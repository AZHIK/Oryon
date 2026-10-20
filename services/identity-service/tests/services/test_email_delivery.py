from uuid import uuid4

import pytest
import pytest_asyncio
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import OtpDeliveryError
from app.models import VerificationCodePurpose
from app.models.user import User, UserCategory
from app.services.email import EmailSendResult, get_email_provider
from app.services.email.console_provider import ConsoleEmailProvider
from app.services.otp_delivery_service import generate_and_send_otp_email

PURPOSE = VerificationCodePurpose.EMAIL_VERIFICATION


@pytest_asyncio.fixture
async def test_user(db_session: AsyncSession) -> User:
    user = User(
        phone=f"+2557{uuid4().hex[:9]}",
        email=f"email-{uuid4().hex[:8]}@example.com",
        full_name="Email Test User",
        user_category=UserCategory.CONSUMER,
    )
    async with db_session.begin():
        db_session.add(user)
    return user


class FakeFailingProvider:
    async def send_email(
        self,
        *,
        to: str,
        subject: str,
        text_body: str,
        html_body: str | None = None,
    ) -> EmailSendResult:
        _ = to, subject, text_body, html_body
        return EmailSendResult(success=False, error="simulated failure")


class TestGenerateAndSendOtpEmail:
    async def test_returns_raw_code_on_success(
        self,
        monkeypatch: pytest.MonkeyPatch,
        db_session: AsyncSession,
        test_user: User,
    ) -> None:
        # A developer's .env may select a real provider; force the console one
        # so the suite never depends on (or sends through) a live account.
        monkeypatch.setattr(get_settings(), "email_provider", "console")
        raw = await generate_and_send_otp_email(
            db_session, user_id=test_user.id, email=test_user.email or ""
        )
        assert isinstance(raw, str)
        assert len(raw) == 6
        assert raw.isdigit()

    async def test_provider_is_console_by_default(self, monkeypatch: pytest.MonkeyPatch) -> None:
        # The declared default must stay `console`; a local .env may override
        # it (EMAIL_PROVIDER=brevo), so read the model field, not runtime.
        assert Settings.model_fields["email_provider"].default == "console"

        monkeypatch.setattr(get_settings(), "email_provider", "console")
        provider = get_email_provider()
        assert isinstance(provider, ConsoleEmailProvider)

    async def test_raises_otp_delivery_error_on_failure(
        self, monkeypatch: pytest.MonkeyPatch, db_session: AsyncSession, test_user: User
    ) -> None:
        monkeypatch.setattr(
            "app.services.otp_delivery_service.get_email_provider",
            lambda: FakeFailingProvider(),
        )
        with pytest.raises(OtpDeliveryError, match="simulated failure"):
            await generate_and_send_otp_email(
                db_session, user_id=test_user.id, email=test_user.email or ""
            )
