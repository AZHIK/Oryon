from uuid import UUID

import structlog
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import OtpDeliveryError
from app.models import VerificationCodePurpose, VerificationCodeType
from app.services.email import get_email_provider
from app.services.otp_service import generate_and_store_otp
from app.services.sms import get_sms_provider

logger = structlog.get_logger(__name__)


async def generate_and_send_otp_sms(
    session: AsyncSession,
    *,
    user_id: UUID,
    phone: str,
    purpose: VerificationCodePurpose = VerificationCodePurpose.PHONE_VERIFICATION,
) -> str:
    raw_code = await generate_and_store_otp(
        session,
        user_id=user_id,
        purpose=purpose,
        delivery_type=VerificationCodeType.SMS,
    )

    message = f"Your Oryon Foods verification code is: {raw_code}. It expires in 5 minutes."

    provider = get_sms_provider()
    result = await provider.send_sms(phone=phone, message=message)

    if not result.success:
        error_detail = result.error or "unknown"
        logger.error(
            "otp_sms_delivery_failed",
            user_id=str(user_id),
            phone=phone,
            error=error_detail,
        )
        raise OtpDeliveryError(f"Failed to deliver OTP via SMS: {error_detail}")

    logger.info(
        "otp_sms_delivered",
        user_id=str(user_id),
        phone=phone,
        provider_message_id=result.provider_message_id,
    )
    return raw_code


async def generate_and_send_otp_email(
    session: AsyncSession,
    *,
    user_id: UUID,
    email: str,
    purpose: VerificationCodePurpose = VerificationCodePurpose.EMAIL_VERIFICATION,
) -> str:
    """Generate a login/verification code and deliver it by email.

    Same storage and invalidation rules as the SMS path — only the delivery
    channel differs — so ``verify_otp`` stays channel-agnostic.
    """
    settings = get_settings()
    raw_code = await generate_and_store_otp(
        session,
        user_id=user_id,
        purpose=purpose,
        delivery_type=VerificationCodeType.EMAIL,
    )

    expiry_minutes = settings.otp_expire_minutes
    subject = "Your Oryon Foods verification code"
    text_body = (
        f"Your Oryon Foods verification code is: {raw_code}. It expires in {expiry_minutes} minutes."
    )
    html_body = (
        "<p>Your Oryon Foods verification code is:</p>"
        f'<p style="font-size:24px;font-weight:bold;letter-spacing:4px">{raw_code}</p>'
        f"<p>It expires in {expiry_minutes} minutes.</p>"
    )

    provider = get_email_provider()
    result = await provider.send_email(
        to=email,
        subject=subject,
        text_body=text_body,
        html_body=html_body,
    )

    if not result.success:
        error_detail = result.error or "unknown"
        logger.error(
            "otp_email_delivery_failed",
            user_id=str(user_id),
            email=email,
            error=error_detail,
        )
        raise OtpDeliveryError(f"Failed to deliver OTP via email: {error_detail}")

    logger.info(
        "otp_email_delivered",
        user_id=str(user_id),
        email=email,
        provider_message_id=result.provider_message_id,
    )
    return raw_code
