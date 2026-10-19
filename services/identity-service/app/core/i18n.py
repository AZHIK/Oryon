"""Stateless UI-language support for backend messages.

No database change: the language is never stored. The Flutter app sends
`Accept-Language: en|sw` (see `LocaleInterceptor`), [LocaleMiddleware]
resolves it onto `request.state.lang`, and [L] picks the message.

Catalog keys are stable (`auth.invalid_credentials`) so logs stay greppable
in English while the user-facing `detail` goes out localized.
"""

from __future__ import annotations

from starlette.requests import Request

SUPPORTED = ("en", "sw")
DEFAULT = "en"

_CATALOG: dict[str, dict[str, str]] = {
    # -- OTP ---------------------------------------------------------------
    "otp.sms_body": {
        "en": "Your FoodLink verification code is: {code}. It expires in 5 minutes.",
        "sw": "Nambari yako ya uthibitisho ya FoodLink ni: {code}. Inaisha baada ya dakika 5.",
    },
    "otp.not_found": {
        "en": "No verification code found. Please request a new one.",
        "sw": "Hakuna msimbo wa uthibitisho uliopatikana. Tafadhali omba mpya.",
    },
    "otp.expired": {
        "en": "Verification code has expired. Please request a new one.",
        "sw": "Msimbo wa uthibitisho umeisha muda wake. Tafadhali omba mpya.",
    },
    "otp.max_attempts": {
        "en": "Maximum verification attempts reached. Please request a new code.",
        "sw": "Umefikia kiwango cha juu cha majaribio. Tafadhali omba msimbo mpya.",
    },
    "otp.delivery_failed": {
        "en": "Failed to deliver OTP via SMS: {error}",
        "sw": "Imeshindwa kutuma OTP kwa SMS: {error}",
    },
    # -- auth --------------------------------------------------------------
    "auth.email_registered": {
        "en": "Email already registered",
        "sw": "Barua pepe tayari imesajiliwa",
    },
    "auth.phone_registered": {
        "en": "Phone number already registered",
        "sw": "Nambari ya simu tayari imesajiliwa",
    },
    "auth.invalid_code": {
        "en": "Invalid or expired code",
        "sw": "Msimbo si sahihi au umeisha muda wake",
    },
    "auth.invalid_credentials": {
        "en": "Invalid phone number or password",
        "sw": "Nambari ya simu au nenosiri si sahihi",
    },
    "auth.invalid_refresh": {
        "en": "Invalid, expired, or revoked refresh token",
        "sw": "Token ya kuonyesha upya si sahihi, imeisha muda, au imebatilishwa",
    },
    "auth.missing_header": {
        "en": "Missing or invalid Authorization header",
        "sw": "Kichwa cha Authorization hakipo au si sahihi",
    },
    "auth.token_expired": {
        "en": "Access token has expired",
        "sw": "Token ya ufikiaji imeisha muda wake",
    },
    "auth.token_invalid": {
        "en": "Invalid access token",
        "sw": "Token ya ufikiaji si sahihi",
    },
    "auth.permission_required": {
        "en": "Permission '{permission}' is required",
        "sw": "Ruhusa ya '{permission}' inahitajika",
    },
    "auth.store_required": {
        "en": "A valid store context is required to access this resource",
        "sw": "Muktadha sahihi wa duka unahitajika kufikia rasilimali hii",
    },
    # -- validators --------------------------------------------------------
    "validate.phone": {
        "en": "Phone number is not valid. Use 6XXXXXXXX or 7XXXXXXXX.",
        "sw": "Nambari ya simu si sahihi. Tumia 6XXXXXXXX au 7XXXXXXXX.",
    },
    "validate.otp_length": {
        "en": "OTP code must be a 6-digit number",
        "sw": "Msimbo wa OTP lazima uwe tarakimu 6",
    },
    "validate.password": {
        "en": (
            "Password must be at least 8 characters and contain an uppercase "
            "letter, a digit and a special character."
        ),
        "sw": (
            "Nenosiri lazima liwe na herufi 8 angalau na liwe na herufi kubwa, "
            "tarakimu na alama maalum."
        ),
    },
}


def parse_lang(accept_language: str | None) -> str:
    """Resolve `Accept-Language` to a supported code, defaulting to English."""
    if not accept_language:
        return DEFAULT
    first = accept_language.split(",")[0].strip().lower()
    code = first.split(";")[0].strip().split("-")[0].strip()
    return code if code in SUPPORTED else DEFAULT


def request_lang(request: Request) -> str:
    """Language resolved by [LocaleMiddleware]; safe before middleware too."""
    state_lang = getattr(getattr(request, "state", None), "lang", None)
    if state_lang in SUPPORTED:
        return str(state_lang)
    headers = getattr(request, "headers", {}) or {}
    return parse_lang(headers.get("accept-language"))


def L(key: str, lang: str = DEFAULT, **kwargs: object) -> str:  # noqa: E743, N802
    """Localized message for [key]; English fallback for unknown keys."""
    entry = _CATALOG.get(key)
    if entry is None:
        return key
    template = entry.get(lang, entry[DEFAULT])
    try:
        return template.format(**kwargs)
    except (KeyError, IndexError):
        return template
