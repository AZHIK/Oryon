"""Unit tests for app/core/security.py — pure function tests, no DB, no FastAPI TestClient.

Tests are fully deterministic and self-contained.  A test keypair is created
via scripts/generate_keys.py before the test suite is run.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.core.exceptions import ExpiredTokenError, InvalidTokenError
from app.core.security import (
    _load_private_key,
    create_access_token,
    decode_and_verify_access_token,
    generate_refresh_token,
    hash_otp_code,
    hash_password,
    hash_refresh_token,
    verify_otp_code,
    verify_password,
    verify_refresh_token,
)
from tests.core.test_security_dat import PRIVATE_KEY_2

# ═══════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════


def _real_settings() -> dict:
    """Return the real (non-mocked) settings values needed for JWT tests."""
    from app.core.config import get_settings

    s = get_settings()
    return {
        "algorithm": s.jwt_algorithm,
        "private_key_path": s.jwt_private_key_path,
        "public_key_path": s.jwt_public_key_path,
        "access_token_ttl_minutes": s.jwt_access_token_ttl_minutes,
    }


# ═══════════════════════════════════════════════════════════════════════════
# 1. Password hashing
# ═══════════════════════════════════════════════════════════════════════════


class TestPasswordHashing:
    def test_hash_and_verify_round_trip(self) -> None:
        password = "MyStr0ng!Pass"
        hashed = hash_password(password)
        assert verify_password(password, hashed) is True

    def test_wrong_password_fails(self) -> None:
        hashed = hash_password("RealPass123!")
        assert verify_password("WrongPass456!", hashed) is False

    def test_salting_produces_different_hashes(self) -> None:
        password = "SaltedP@ss99"
        hash_a = hash_password(password)
        hash_b = hash_password(password)
        assert hash_a != hash_b

    def test_empty_password(self) -> None:
        hashed = hash_password("")
        assert verify_password("", hashed) is True
        assert verify_password("x", hashed) is False


# ═══════════════════════════════════════════════════════════════════════════
# 2. JWT access token
# ═══════════════════════════════════════════════════════════════════════════


class TestJWTAccessToken:
    def test_create_and_verify_business_user(self) -> None:
        token = create_access_token(
            subject="user-1111",
            user_category="business_staff",
            roles=["manager"],
            permissions=["pos.write", "inventory.view"],
            active_business_id="biz-001",
            other_businesses=[{"id": "biz-002", "name": "Second Branch"}],
        )
        payload = decode_and_verify_access_token(token)
        assert payload["sub"] == "user-1111"
        assert payload["user_category"] == "business_staff"
        assert payload["type"] == "access"
        assert payload["roles"] == ["manager"]
        assert payload["permissions"] == ["pos.write", "inventory.view"]
        assert payload["active_business_id"] == "biz-001"
        assert payload["other_businesses"] == [{"id": "biz-002", "name": "Second Branch"}]
        assert "iat" in payload
        assert "exp" in payload

    def test_create_and_verify_platform_staff(self) -> None:
        token = create_access_token(
            subject="staff-2222",
            user_category="platform_staff",
            group="engineering",
            roles=["admin"],
            permissions=["users.manage", "roles.assign"],
        )
        payload = decode_and_verify_access_token(token)
        assert payload["sub"] == "staff-2222"
        assert payload["user_category"] == "platform_staff"
        assert payload["group"] == "engineering"
        assert payload["roles"] == ["admin"]
        assert payload["permissions"] == ["users.manage", "roles.assign"]

    def test_create_and_verify_driver(self) -> None:
        token = create_access_token(
            subject="driver-3333",
            user_category="driver",
            platform_role="driver",
        )
        payload = decode_and_verify_access_token(token)
        assert payload["sub"] == "driver-3333"
        assert payload["user_category"] == "driver"
        assert payload["platform_role"] == "driver"

    def test_create_and_verify_consumer(self) -> None:
        token = create_access_token(
            subject="consumer-4444",
            user_category="consumer",
            platform_role="consumer",
        )
        payload = decode_and_verify_access_token(token)
        assert payload["sub"] == "consumer-4444"
        assert payload["user_category"] == "consumer"
        assert payload["platform_role"] == "consumer"

    def test_token_signed_with_different_key_fails(self) -> None:
        """A token signed with a foreign private key must be rejected by our verifier.

        We sign a JWT with an unrelated RSA keypair (embedded in this module),
        then pass it to decode_and_verify_access_token which uses the *real*
        public key — signature mismatch should raise InvalidTokenError.
        """
        settings = _real_settings()
        payload = {
            "sub": "user",
            "type": "access",
            "user_category": "business_staff",
            "iat": datetime.now(UTC),
            "exp": datetime.now(UTC) + timedelta(minutes=settings["access_token_ttl_minutes"]),
        }
        bad_token = jwt.encode(payload, PRIVATE_KEY_2, algorithm=settings["algorithm"])

        with pytest.raises(InvalidTokenError):
            decode_and_verify_access_token(bad_token)

    def test_expired_token_raises_expired_error(self) -> None:
        """Manually construct a token with an 'exp' in the past and verify it is rejected."""
        settings = _real_settings()
        private_key = _load_private_key()
        payload = {
            "sub": "user",
            "type": "access",
            "user_category": "business_staff",
            "iat": datetime.now(UTC) - timedelta(hours=1),
            "exp": datetime.now(UTC) - timedelta(minutes=1),  # expired 1 minute ago
        }
        expired_token = jwt.encode(payload, private_key, algorithm=settings["algorithm"])

        with pytest.raises(ExpiredTokenError, match="expired"):
            decode_and_verify_access_token(expired_token)

    def test_missing_type_claim_rejected(self) -> None:
        """A JWT without a 'type' claim must be rejected."""
        settings = _real_settings()
        private_key = _load_private_key()
        payload = {
            "sub": "user",
            "user_category": "business_staff",
            "iat": datetime.now(UTC),
            "exp": datetime.now(UTC) + timedelta(minutes=15),
        }
        token = jwt.encode(payload, private_key, algorithm=settings["algorithm"])

        with pytest.raises(InvalidTokenError):
            decode_and_verify_access_token(token)

    def test_wrong_type_refresh_token_rejected(self) -> None:
        """A token with type='refresh' must be rejected by the access-token verifier."""
        settings = _real_settings()
        private_key = _load_private_key()
        payload = {
            "sub": "user",
            "type": "refresh",
            "user_category": "business_staff",
            "iat": datetime.now(UTC),
            "exp": datetime.now(UTC) + timedelta(minutes=15),
        }
        token = jwt.encode(payload, private_key, algorithm=settings["algorithm"])

        with pytest.raises(InvalidTokenError, match="not 'access'"):
            decode_and_verify_access_token(token)

    def test_iat_and_exp_are_present(self) -> None:
        token = create_access_token(subject="u1", user_category="business_staff")
        payload = decode_and_verify_access_token(token)
        assert isinstance(payload["iat"], (int, float))
        assert isinstance(payload["exp"], (int, float))


class TestJwtEnvironmentBinding:
    """SEC-12: issuer/audience/key-id binding for production tokens."""

    def _hardened_settings(self):
        from app.core.config import get_settings

        return get_settings().model_copy(
            update={
                "jwt_issuer": "https://auth.example.test",
                "jwt_audience": "oryonfoods-api",
                "jwt_key_id": "primary",
            }
        )

    def test_access_token_carries_issuer_audience_jti_and_kid(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        import app.core.security as security

        monkeypatch.setattr(security, "get_settings", self._hardened_settings)
        token = create_access_token(subject="u1", user_category="business_staff")

        header = jwt.get_unverified_header(token)
        payload = jwt.decode(token, options={"verify_signature": False})
        assert header["kid"] == "primary"
        assert payload["iss"] == "https://auth.example.test"
        assert payload["aud"] == "oryonfoods-api"
        assert payload["jti"]
        assert decode_and_verify_access_token(token)["aud"] == "oryonfoods-api"

    def test_unknown_key_id_is_rejected(self, monkeypatch: pytest.MonkeyPatch) -> None:
        import app.core.security as security

        settings = self._hardened_settings()
        monkeypatch.setattr(security, "get_settings", lambda: settings)
        token = create_access_token(subject="u1", user_category="business_staff")
        payload = jwt.decode(token, options={"verify_signature": False})
        wrong_key = jwt.encode(
            payload,
            security._load_private_key(),
            algorithm=settings.jwt_algorithm,
            headers={"kid": "retired-key"},
        )

        with pytest.raises(InvalidTokenError, match="unknown key"):
            decode_and_verify_access_token(wrong_key)

    def test_wrong_issuer_is_rejected(self, monkeypatch: pytest.MonkeyPatch) -> None:
        import app.core.security as security

        settings = self._hardened_settings()
        monkeypatch.setattr(security, "get_settings", lambda: settings)
        token = create_access_token(subject="u1", user_category="business_staff")
        payload = jwt.decode(token, options={"verify_signature": False})
        payload["iss"] = "https://attacker.example.test"
        wrong_issuer = jwt.encode(
            payload,
            security._load_private_key(),
            algorithm=settings.jwt_algorithm,
            headers={"kid": "primary"},
        )

        with pytest.raises(InvalidTokenError):
            decode_and_verify_access_token(wrong_issuer)


# ═══════════════════════════════════════════════════════════════════════════
# 3. Refresh token primitives
# ═══════════════════════════════════════════════════════════════════════════


class TestRefreshToken:
    def test_generate_produces_different_values(self) -> None:
        tok_a = generate_refresh_token()
        tok_b = generate_refresh_token()
        assert tok_a != tok_b
        assert len(tok_a) == 64  # 32 bytes → 64 hex chars

    def test_hash_and_verify_round_trip(self) -> None:
        token = generate_refresh_token()
        hashed = hash_refresh_token(token)
        assert verify_refresh_token(token, hashed) is True

    def test_wrong_token_fails_verification(self) -> None:
        token = generate_refresh_token()
        other = generate_refresh_token()
        hashed = hash_refresh_token(token)
        assert verify_refresh_token(other, hashed) is False

    def test_empty_token(self) -> None:
        hashed = hash_refresh_token("")
        assert verify_refresh_token("", hashed) is True
        assert verify_refresh_token("x", hashed) is False


# ═══════════════════════════════════════════════════════════════════════════
# 4. OTP code hashing
# ═══════════════════════════════════════════════════════════════════════════


class TestOTPCode:
    def test_hash_and_verify_round_trip(self) -> None:
        code = "123456"
        hashed = hash_otp_code(code)
        assert verify_otp_code(code, hashed) is True

    def test_wrong_code_fails_verification(self) -> None:
        hashed = hash_otp_code("654321")
        assert verify_otp_code("123456", hashed) is False

    def test_salting_produces_different_hashes(self) -> None:
        code = "000000"
        hash_a = hash_otp_code(code)
        hash_b = hash_otp_code(code)
        assert hash_a != hash_b
