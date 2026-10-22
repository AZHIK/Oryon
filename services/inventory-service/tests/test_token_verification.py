"""Tests for cross-service JWT token verification.

Uses a copy of the same test RSA key pair from Identity Service's own
tests to prove that Inventory Service can verify tokens issued by
Identity Service without calling back to it at runtime.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt
import pytest
from fastapi import HTTPException

from app.core.exceptions import ExpiredTokenError, InvalidTokenError
from app.core.security import (
    decode_and_verify_access_token,
)
from app.deps.auth import (
    get_current_claims,
    require_business_context,
    require_business_permission,
    require_permission,
    require_platform_staff,
)

# ── Test RSA keypair (copy of Identity Service's test keypair #1) ──────────
# Identity Service issues tokens with this private key at runtime.
# Inventory Service verifies them with the corresponding public key.
TEST_PRIVATE_KEY = """-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAoeArXtZ+XrZt5klLXLayTcGOFZCOUZ9tbexpmrdMcXzwxAzx
h+ByKOHyJEJ1xXB6hdZZMWV/66rHMG+dx3l8w8o3woM1Ae/QEz7Yf8Zx1Eu3eqCR
E05QzX0c1SfSxrzNQ91czCIRW3vyq2CQ/dnD3xqFP7asLrfihqYzw2SzSNyoOJo3
EAYwv2IdkJJeQepco+WX5OjZBrYOB9YFXySmo32cT7uT6eIIo1CJFYqCvfK6OeAw
oQy92wOJxod1VcPYRBbFU86bTnge2+ymbjpnnMDUUyF5pl+05raXwrg3pz8ibXjs
V+9aGx1Qs1pAd0IMB6b9JegMcRy3SCdUgvcz/wIDAQABAoIBADEbusyYsdm16n1U
ewJzgoBIWfx80FA+14njkN4ZAZ3kU36GlresBbYVZcpOR0BQsTrtHj34Fui99JPj
KLCdUJZtQKFIAMrHoA5WoIOTBnFrTwxqrdh3h9fvPtIDtNQJ7xPJkh9zrmRco/AN
6a65Y8zJVOdRWccKjjRfM5Dxedp+axsPkLTXJvh/tioGDTzsFTSshMIdOSElH8e4
VZQPx+nB50yRRu/ek3AjrdELppQ8OziNBvl455g9pg8XOuclEG3JuZoZU/s22sYi
oORswvTGrceuzWSdosh6hwMWW8D07BOkLaIMAWpiL0TpCqWW3ABamj6MmZJRHDKL
Rxr8vkECgYEAzosvjW5A5JGTh9XmxMbi2GifN95cm7Lb8IZAdvI/370eVGIxzIHi
eduiHw0pXNcEnTS5uT0fbt/2AvfN8bvoOrfdAnjLSlbgzLFbx544Mtekert6hyGA
ISiB79J6dgdHxa1hWRiQ+Tn+71t+9Afry5TWA/JmqIcFTBLhIJ/WgzECgYEAyKLm
tnN/DHkfYsuWKF2T8LBfXJ5AsXAznfjDP9NKpuVr9ouy/QhjOgVriXdtvt67B00Z
FNtkS2LrjlFLz5cTvABW0TOdB09EA3s6iWE6bjp+Jg7gSHXzIW29YS1VOzVlYxP9
FfYigxlDVrgjnZ9lefZz0iwT+ACDPErjCVdzfi8CgYB6xAxNulzj/wt7z85M5BJt
ozIQGSFegl9shb/Hc5I3wMdITN1gu0sMN1oTrtUJE9zwPCiwS/5k/sXRWc2Vg6Uz
UZoSIA5lb2JLCJiO/CJXRgnD0a+wpl7sVpF1JNwZT5Z/juCv/oQdPzWiu/WnwxWK
ejsDOY9/WFHzt70MkTUF4QKBgQCK5lQo/b54KSZ0ZBNZcKdp2wC6Awkwjkf91ml9
t06YSn462i4ZBQSE95miOp8so9ABVvvFN7mwgxQmm9uLJMFRxz5TaJMOq26fpmE5
GKm2BCKvQF8/awDeJLYWH6dA7U96jy0IVjVAY23+DE8D4YUEMX2vhDpy2BAC3qld
H0DimwKBgG3GWjH5G4uYQ5x/LKX5mSO5vGANRM0n3CVfXtyEDURuo8hQQFbSUyH/
ac/0/f9oHqk1dBBfGYF9eNr6iSo3qgGYmlnavwSeOoemgHwfF9oCULVUPPwldMVD
Miohh2E1Z9T1bGnvke8mHGpvQ4WurtmexOjz+KzVooCAkKzxIYKf
-----END RSA PRIVATE KEY-----
"""

# A DIFFERENT keypair for cross-key rejection tests (keypair #2 from identity-service tests)
DIFFERENT_PRIVATE_KEY = """-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA26P3FF1Uo3QNnSDYcSoT5c8AX6xhDpLo3VNm+vArEeMqynTh
YAUZpzw8Kf24XnKM2lg6x5OtKMIyc2+/aaUbc1EKx29SON6IMtNRuOkXJiDnNzTm
F3GbxznElvPbmA03JfEEGYBOvGexkD2LqzYDIrTzsAIDlEct9t2TjSFg02TPyQbQ
V81GW8ge9+BLUE0VBioynjCz0fyAeudrnUy3+ZVUw7bSZ4g8dv/tAwq1wsSWLXbR
khhBpeuyuHURV6OEIeweN7fxpz4QETVt/1m6rS3JWAXg3KwAVGBhTOi/a5xBmsvi
fpHfMBL36jEU5g/EryyThUDVi1RgUfmzKykMywIDAQABAoIBAEqh22orEIB+BcY3
i/RgBOTYwtq/mzc1ijTyixKHm0r3sumab56N/RqLaDIoiYZmTCBBTK/WKUepPTVm
alc+iCZWCmCcHgc+7m6+yY0YfwowsgBbVDfxHarDoV5dvGddTjjxPaBgreBtJ7PI
hfYGY2herlNHS+oNibvRrLqO9fS+Mn7jGXZUr8vx7ZkQSstaH7p4FdkB2NmjdLAl
eRHvMATGyW3dLcteGrEZkosMX4PGnrSsJaBI1JZS0jHIuVkSKs0LoRNgDA/gwJJS
i7nzGIsXAa6lDpjtkaZfnQv7SzjhJH9zriAsLn8HIbmJV0wzElM3e9H5ckxQgIM0
K2uWyJkCgYEA8tfrOHzbpuaWNpuVFrIaZpFd1U+L+I2eGPchllASqSKHxaii2p/e
a5sR0Hpw0QG4NPz/Vuh+i6aBJq4/KgYJMHvLRdull0I2/OLAeTih6XVAtgG8spSp
pWbgPnhmw0qe8cx4DNk26srbtg+LbLbRlqZszZ6sFZGh0yA5XugwliUCgYEA54o8
jDGNLr7lz4qK6rofSYE6Nve3Otp3RwsuExwjAmnbSRa/o3yHJ8PX59pKkOnbXhUE
NRLOBK9JKELIRzIzrqWysOT/LE8PsQ1tljezaKClgVsbCKrNXUj4N2OmSUlknsOH
52WqPrmNpqoiUcC9slvpdNaq9Oeg3Iqvu8i4zC8CgYEA8BgQJJI1rObP3v+lwIGo
Xn4ckpiKH90MUUyM9YsHWBeeuwrGsHZdNnBjhYZ44fvcPu9gGHHXI4UkrbSbGJZN
IZVTXScTqd+6c/5QI8mdMy9NImXHRZx7ud9jl//8QdsWGKR6kOF1TV/xKChoRbze
rR6v9f+Jze1lXFLAxhe0ac0CgYEAhplTzWPY4P3UdqvhScbc/UwEXYPvnmT1xfT3
2eAXcgW7lmeFDDMOFs3Aq2W4xzlLbwvkoD3ISezkKGV6K/lBFhv5HuBgfo+PXaui
sxq6Tu5kiChANO+l5r7OnNRvDFeACNM+JARzzXbso6Bvxvq2zAKmWmeYhjpIxyxQ
MGflFb0CgYB/MJnESs1IFZJYhU3qs5+3+VesMW4xBpoXBPB+PEjirWZGDONbbkah
I+wVGR4jCj7LwR7YjPRMjWYnvehZ9vg+iQKHk82U5eVEMJYVfwexHHM416A0doLb
goTTOn4Uvqnmdlo3tu0kUBVuRP24wMC0hF+L1g3WeSfjkSUDG/1Bhw==
-----END RSA PRIVATE KEY-----
"""


def _build_token(
    private_key: str = TEST_PRIVATE_KEY,
    *,
    extra_claims: dict | None = None,
    exp_delta: timedelta | None = None,
) -> str:
    from app.core.config import get_settings

    settings = get_settings()
    now = datetime.now(UTC)
    payload = {
        "sub": "user-test-123",
        "type": "access",
        "user_category": "business_staff",
        "iat": now,
        "exp": now + (exp_delta or timedelta(minutes=15)),
        "permissions": ["inventory.view", "inventory.adjust"],
        "roles": ["manager"],
        "active_business_id": "biz-001",
    }
    if extra_claims:
        payload.update(extra_claims)
    return jwt.encode(payload, private_key, algorithm=settings.jwt_algorithm)


class TestDecodeAndVerifyAccessToken:
    def test_valid_token_from_identity_service_is_accepted(self) -> None:
        token = _build_token()
        claims = decode_and_verify_access_token(token)
        assert claims["sub"] == "user-test-123"
        assert claims["user_category"] == "business_staff"
        assert claims["type"] == "access"

    def test_token_signed_with_different_key_is_rejected(self) -> None:
        token = _build_token(private_key=DIFFERENT_PRIVATE_KEY)
        with pytest.raises(InvalidTokenError):
            decode_and_verify_access_token(token)

    def test_expired_token_is_rejected(self) -> None:
        token = _build_token(exp_delta=timedelta(minutes=-5))
        with pytest.raises(ExpiredTokenError, match="expired"):
            decode_and_verify_access_token(token)

    def test_missing_type_claim_rejected(self) -> None:
        from app.core.config import get_settings

        settings = get_settings()
        payload = {
            "sub": "user",
            "user_category": "business_staff",
            "iat": datetime.now(UTC),
            "exp": datetime.now(UTC) + timedelta(minutes=15),
        }
        bad_token = jwt.encode(payload, TEST_PRIVATE_KEY, algorithm=settings.jwt_algorithm)
        with pytest.raises(InvalidTokenError):
            decode_and_verify_access_token(bad_token)

    def test_refresh_type_token_is_rejected(self) -> None:
        from app.core.config import get_settings

        settings = get_settings()
        payload = {
            "sub": "user",
            "type": "refresh",
            "user_category": "business_staff",
            "iat": datetime.now(UTC),
            "exp": datetime.now(UTC) + timedelta(minutes=15),
        }
        token = jwt.encode(payload, TEST_PRIVATE_KEY, algorithm=settings.jwt_algorithm)
        with pytest.raises(InvalidTokenError, match="not 'access'"):
            decode_and_verify_access_token(token)


class TestGetCurrentClaims:
    async def test_valid_token_returns_claims(self) -> None:
        token = _build_token()
        claims = await get_current_claims(authorization=f"Bearer {token}")
        assert claims["sub"] == "user-test-123"

    async def test_missing_header_raises_401(self) -> None:
        with pytest.raises(HTTPException) as exc:
            await get_current_claims(authorization=None)
        assert exc.value.status_code == 401

    async def test_invalid_header_format_raises_401(self) -> None:
        with pytest.raises(HTTPException) as exc:
            await get_current_claims(authorization="NotBearer xyz")
        assert exc.value.status_code == 401

    async def test_expired_token_raises_401(self) -> None:
        token = _build_token(exp_delta=timedelta(minutes=-5))
        with pytest.raises(HTTPException) as exc:
            await get_current_claims(authorization=f"Bearer {token}")
        assert exc.value.status_code == 401
        assert "expired" in exc.value.detail.lower()


async def _call(dep_factory_result, claims: dict, **kwargs):
    return await dep_factory_result(claims, **kwargs)


class TestRequirePermission:
    async def test_allows_token_with_permission_present(self) -> None:
        checker = require_permission("inventory.view")
        claims = {
            "sub": "user",
            "user_category": "business_staff",
            "permissions": ["inventory.view", "inventory.adjust"],
        }
        result = await _call(checker, claims)
        assert result is claims

    async def test_rejects_token_missing_permission(self) -> None:
        checker = require_permission("inventory.adjust")
        claims = {"sub": "user", "user_category": "business_staff", "permissions": ["pos.write"]}
        with pytest.raises(HTTPException) as exc:
            await _call(checker, claims)
        assert exc.value.status_code == 403

    async def test_allows_wildcard_permission(self) -> None:
        checker = require_permission("inventory.adjust")
        claims = {"sub": "user", "user_category": "platform_staff", "permissions": ["*"]}
        result = await _call(checker, claims)
        assert result is claims


class TestRequireBusinessContext:
    async def test_allows_token_with_active_business_id(self) -> None:
        checker = require_business_context()
        claims = {"sub": "user", "user_category": "business_staff", "active_business_id": "biz-abc"}
        result = await _call(checker, claims)
        assert result == "biz-abc"

    async def test_rejects_token_without_business_context(self) -> None:
        checker = require_business_context()
        claims = {"sub": "user", "user_category": "business_staff"}
        with pytest.raises(HTTPException) as exc:
            await _call(checker, claims)
        assert exc.value.status_code == 403


class TestRequireBusinessPermission:
    async def test_allows_with_context_and_permission(self) -> None:
        checker = require_business_permission("inventory.view")
        biz_id = UUID("550e8400-e29b-41d4-a716-446655440000")
        claims = {
            "sub": "user",
            "user_category": "business_staff",
            "active_business_id": str(biz_id),
            "permissions": ["inventory.view"],
        }
        result = await _call(checker, claims, business_id=biz_id)
        assert result == str(biz_id)

    async def test_rejects_without_context(self) -> None:
        checker = require_business_permission("inventory.view")
        claims = {
            "sub": "user",
            "user_category": "business_staff",
            "permissions": ["inventory.view"],
        }
        with pytest.raises(HTTPException) as exc:
            await _call(checker, claims, business_id=UUID("550e8400-e29b-41d4-a716-446655440000"))
        assert exc.value.status_code == 403

    async def test_rejects_without_permission(self) -> None:
        checker = require_business_permission("inventory.adjust")
        biz_id = UUID("550e8400-e29b-41d4-a716-446655440000")
        claims = {
            "sub": "user",
            "user_category": "business_staff",
            "active_business_id": str(biz_id),
            "permissions": ["inventory.view"],
        }
        with pytest.raises(HTTPException) as exc:
            await _call(checker, claims, business_id=biz_id)
        assert exc.value.status_code == 403


class TestRequirePlatformStaff:
    async def test_allows_platform_staff(self) -> None:
        checker = require_platform_staff()
        claims = {"sub": "staff", "user_category": "platform_staff"}
        result = await _call(checker, claims)
        assert result is claims

    async def test_rejects_business_user(self) -> None:
        checker = require_platform_staff()
        claims = {"sub": "user", "user_category": "business_staff"}
        with pytest.raises(HTTPException) as exc:
            await _call(checker, claims)
        assert exc.value.status_code == 403
