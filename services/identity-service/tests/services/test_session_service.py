from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import pytest
import pytest_asyncio
from sqlalchemy.exc import IntegrityError
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.exceptions import InvalidRefreshTokenError, TokenReuseDetectedError
from app.models import RefreshToken, UserSession
from app.models.user import User, UserCategory
from app.services.session_service import (
    get_usable_refresh_token,
    issue_login_session,
    list_active_sessions,
    revoke_refresh_token,
    revoke_session,
    rotate_refresh_token,
)


@pytest_asyncio.fixture
async def test_user(db_session: AsyncSession) -> User:
    user = User(
        phone=f"+2557{uuid4().hex[:9]}",
        full_name="Test User",
        user_category=UserCategory.CONSUMER,
    )
    async with db_session.begin():
        db_session.add(user)
    return user


class TestIssueLoginSession:
    async def test_creates_refresh_token_and_linked_session(
        self, db_session: AsyncSession, test_user: User
    ) -> None:
        issued = await issue_login_session(
            db_session,
            user_id=test_user.id,
            device_info="Pixel 9",
            ip_address="127.0.0.1",
            raw_token="login-token",
        )
        refresh_tokens = (await db_session.exec(select(RefreshToken))).all()
        user_sessions = (await db_session.exec(select(UserSession))).all()

        assert len(refresh_tokens) == 1
        assert len(user_sessions) == 1
        assert issued.session.refresh_token_id == issued.refresh_token.id
        assert user_sessions[0].is_active is True

    async def test_rolls_back_on_failure(self, db_session: AsyncSession, test_user: User) -> None:
        await issue_login_session(
            db_session,
            user_id=test_user.id,
            device_info=None,
            ip_address=None,
            raw_token="dup-token",
        )
        with pytest.raises(IntegrityError):
            await issue_login_session(
                db_session,
                user_id=test_user.id,
                device_info=None,
                ip_address=None,
                raw_token="dup-token",
            )

        refresh_tokens = (await db_session.exec(select(RefreshToken))).all()
        user_sessions = (await db_session.exec(select(UserSession))).all()
        assert len(refresh_tokens) == 1
        assert len(user_sessions) == 1


class TestGetUsableRefreshToken:
    async def test_raises_for_nonexistent_token(self, db_session: AsyncSession) -> None:
        with pytest.raises(InvalidRefreshTokenError):
            await get_usable_refresh_token(db_session, "nonexistent")


class TestRotateRefreshToken:
    async def test_updates_existing_session(
        self, db_session: AsyncSession, test_user: User
    ) -> None:
        issued = await issue_login_session(
            db_session,
            user_id=test_user.id,
            device_info="Pixel 9",
            ip_address="127.0.0.1",
            raw_token="old-token",
        )
        original_session_id = issued.session.id
        original_activity = issued.session.last_activity_at

        rotated = await rotate_refresh_token(
            db_session,
            raw_token="old-token",
            ip_address="127.0.0.2",
            new_raw_token="new-token",
        )
        refresh_tokens = (await db_session.exec(select(RefreshToken))).all()
        user_sessions = (await db_session.exec(select(UserSession))).all()

        assert len(refresh_tokens) == 2
        assert len(user_sessions) == 1
        assert rotated.session.id == original_session_id
        assert rotated.session.refresh_token_id == rotated.refresh_token.id
        assert rotated.session.last_activity_at >= original_activity

        old_token = next(rt for rt in refresh_tokens if rt.id != rotated.refresh_token.id)
        assert old_token.revoked_at is not None

    async def test_raises_for_invalid_token(self, db_session: AsyncSession) -> None:
        with pytest.raises(InvalidRefreshTokenError):
            await rotate_refresh_token(db_session, raw_token="nonexistent")

    async def test_raises_for_expired_token(
        self, db_session: AsyncSession, test_user: User
    ) -> None:
        issued = await issue_login_session(
            db_session,
            user_id=test_user.id,
            device_info=None,
            ip_address=None,
            raw_token="fresh-token",
        )
        async with db_session.begin():
            issued.refresh_token.expires_at = datetime.now(UTC) - timedelta(hours=1)

        with pytest.raises(InvalidRefreshTokenError):
            await rotate_refresh_token(db_session, raw_token="fresh-token")


class TestRevokeSession:
    async def test_revokes_linked_refresh_token(
        self, db_session: AsyncSession, test_user: User
    ) -> None:
        issued = await issue_login_session(
            db_session,
            user_id=test_user.id,
            device_info=None,
            ip_address=None,
            raw_token="session-token",
        )
        await revoke_session(db_session, issued.session.id)

        stored_session = await db_session.get(UserSession, issued.session.id)
        stored_token = await db_session.get(RefreshToken, issued.refresh_token.id)
        assert stored_session is not None
        assert stored_token is not None
        assert stored_session.is_active is False
        assert stored_token.revoked_at is not None
        with pytest.raises(InvalidRefreshTokenError):
            await get_usable_refresh_token(db_session, "session-token")


class TestRevokeRefreshToken:
    async def test_marks_linked_session_inactive(
        self, db_session: AsyncSession, test_user: User
    ) -> None:
        issued = await issue_login_session(
            db_session,
            user_id=test_user.id,
            device_info=None,
            ip_address=None,
            raw_token="direct-token",
        )
        await revoke_refresh_token(db_session, issued.refresh_token.id)

        stored_session = await db_session.get(UserSession, issued.session.id)
        assert stored_session is not None
        assert stored_session.is_active is False
        assert await list_active_sessions(db_session, test_user.id) == []

    async def test_raises_for_nonexistent_token(self, db_session: AsyncSession) -> None:
        fake_id = UUID("00000000-0000-0000-0000-000000000999")
        with pytest.raises(InvalidRefreshTokenError):
            await revoke_refresh_token(db_session, fake_id)


class TestTokenFamily:
    """Token family tracking — family_id propagation, lineage linking, and
    replay / theft detection via replaced_by_token_id."""

    async def test_rotation_propagates_family_id(
        self, db_session: AsyncSession, test_user: User
    ) -> None:
        issued = await issue_login_session(
            db_session,
            user_id=test_user.id,
            device_info=None,
            ip_address=None,
            raw_token="family-token",
        )
        family_id = issued.refresh_token.family_id
        assert family_id is not None

        rotated = await rotate_refresh_token(
            db_session,
            raw_token="family-token",
            new_raw_token="family-token-v2",
        )
        assert rotated.refresh_token.family_id == family_id

    async def test_rotation_links_previous_and_replaced(
        self, db_session: AsyncSession, test_user: User
    ) -> None:
        issued = await issue_login_session(
            db_session,
            user_id=test_user.id,
            device_info=None,
            ip_address=None,
            raw_token="link-token",
        )
        old_id = issued.refresh_token.id

        rotated = await rotate_refresh_token(
            db_session,
            raw_token="link-token",
            new_raw_token="link-token-v2",
        )
        new_id = rotated.refresh_token.id
        assert rotated.refresh_token.previous_token_id == old_id

        old = await db_session.get(RefreshToken, old_id)
        assert old is not None
        assert old.replaced_by_token_id == new_id

    async def test_reuse_of_already_rotated_token_raises(
        self, db_session: AsyncSession, test_user: User
    ) -> None:
        await issue_login_session(
            db_session,
            user_id=test_user.id,
            device_info=None,
            ip_address=None,
            raw_token="replay-token",
        )
        await rotate_refresh_token(
            db_session,
            raw_token="replay-token",
            new_raw_token="replay-v2",
        )
        with pytest.raises(TokenReuseDetectedError):
            await rotate_refresh_token(
                db_session,
                raw_token="replay-token",
                new_raw_token="replay-v3",
            )

        # Replay must revoke the whole family, not just reject this request.
        family_tokens = (
            await db_session.exec(
                select(RefreshToken).where(RefreshToken.user_id == test_user.id)
            )
        ).all()
        assert family_tokens
        assert all(token.revoked_at is not None for token in family_tokens)

        sessions = (
            await db_session.exec(
                select(UserSession).where(UserSession.user_id == test_user.id)
            )
        ).all()
        assert sessions
        assert all(not user_session.is_active for user_session in sessions)

        # Close the read transaction opened by the assertions above; the
        # service owns its own begin() block.
        await db_session.commit()

        # The token minted during the legitimate rotation is now revoked too.
        with pytest.raises(InvalidRefreshTokenError):
            await rotate_refresh_token(
                db_session,
                raw_token="replay-v2",
                new_raw_token="replay-v4",
            )

    async def test_reuse_of_rotated_token_raises_twice(
        self, db_session: AsyncSession, test_user: User
    ) -> None:
        """Replaying a rotated token always raises regardless of prior attempts."""
        await issue_login_session(
            db_session,
            user_id=test_user.id,
            device_info=None,
            ip_address=None,
            raw_token="replay-twice",
        )
        await rotate_refresh_token(
            db_session,
            raw_token="replay-twice",
            new_raw_token="replay-twice-v2",
        )
        with pytest.raises(TokenReuseDetectedError):
            await rotate_refresh_token(
                db_session,
                raw_token="replay-twice",
                new_raw_token="replay-twice-v3",
            )
        with pytest.raises(TokenReuseDetectedError):
            await rotate_refresh_token(
                db_session,
                raw_token="replay-twice",
                new_raw_token="replay-twice-v4",
            )


class TestListActiveSessions:
    async def test_returns_only_active_sessions(
        self, db_session: AsyncSession, test_user: User
    ) -> None:
        s1 = await issue_login_session(
            db_session,
            user_id=test_user.id,
            device_info=None,
            ip_address=None,
            raw_token="t1",
        )
        await issue_login_session(
            db_session,
            user_id=test_user.id,
            device_info=None,
            ip_address=None,
            raw_token="t2",
        )
        await revoke_session(db_session, s1.session.id)

        active = await list_active_sessions(db_session, test_user.id)
        assert len(active) == 1

    async def test_excludes_expired_sessions(
        self, db_session: AsyncSession, test_user: User
    ) -> None:
        negative_ttl = timedelta(days=-1)
        await issue_login_session(
            db_session,
            user_id=test_user.id,
            device_info=None,
            ip_address=None,
            raw_token="expired-token",
            ttl=negative_ttl,
        )
        await issue_login_session(
            db_session,
            user_id=test_user.id,
            device_info=None,
            ip_address=None,
            raw_token="valid-token",
        )
        active = await list_active_sessions(db_session, test_user.id)
        assert len(active) == 1
