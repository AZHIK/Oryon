"""Authentication dependencies for FastAPI endpoints."""

from collections.abc import Awaitable, Callable
from typing import Annotated, Any

from fastapi import Depends, Header, HTTPException, status
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.database import get_async_session
from app.core.exceptions import ExpiredTokenError, InvalidTokenError
from app.core.security import decode_and_verify_access_token
from app.models.user import User, UserStatus


async def get_current_claims(
    authorization: Annotated[str | None, Header(alias="Authorization")] = None,
    session: AsyncSession = Depends(get_async_session),
) -> dict[str, Any]:
    """Extract and verify the JWT access token from the Authorization header.

    Returns the decoded token claims on success.
    Raises 401 with appropriate detail on failure.
    """
    if authorization is None or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = authorization.split(" ")[1]

    try:
        claims = decode_and_verify_access_token(token)
    except ExpiredTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Access token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
    except InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid access token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    return claims


async def get_current_user_id(
    claims: Annotated[dict[str, Any], Depends(get_current_claims)],
) -> str:
    """Extract the user_id (subject) from verified token claims."""
    return str(claims["sub"])


async def get_current_user_id_uuid(
    user_id: Annotated[str, Depends(get_current_user_id)],
) -> str:
    """Return user_id as string (UUID string) for type consistency."""
    return user_id


def require_role(
    required_role: str,
) -> Callable[..., Awaitable[dict[str, Any]]]:
    """Dependency factory that requires a specific role in the token claims.

    Usage:
        @router.get("/admin-only", dependencies=[Depends(require_role("admin"))])
        async def admin_only_endpoint(): ...

    Returns a dependency that raises 403 if the role is not present in claims.
    """

    async def _check_role(
        claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    ) -> dict[str, Any]:
        roles = claims.get("roles", [])
        if required_role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Required role '{required_role}' not found in token",
            )
        return claims

    return _check_role


def require_any_role(
    required_roles: list[str],
) -> Callable[..., Awaitable[dict[str, Any]]]:
    """Dependency factory that requires at least one of the specified roles."""

    async def _check_any_role(
        claims: Annotated[dict[str, Any], Depends(get_current_claims)],
    ) -> dict[str, Any]:
        roles = claims.get("roles", [])
        if not any(role in roles for role in required_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Required one of roles {required_roles}, none found",
            )
        return claims

    return _check_any_role


def ensure_active_account(user: User, *, detail: str = "Invalid credentials") -> None:
    """Reject deactivated or suspended/locked accounts.

    Deactivation must be a real containment action (SEC-31): a token must not
    be issuable for an account an administrator has disabled, even if the
    account still knows a valid password or OTP.
    """
    if not user.is_active or user.status in {UserStatus.SUSPENDED, UserStatus.LOCKED}:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_user(
    session: AsyncSession = Depends(get_async_session),
    user_id: str = Depends(get_current_user_id_uuid),
) -> User:
    """Load the full User model from the database using the authenticated user_id.

    Returns the User model instance on success.
    Raises 401 if user not found or the account has been disabled.
    """
    from uuid import UUID

    from sqlmodel import select

    user_uuid = UUID(user_id)
    result = await session.exec(select(User).where(User.id == user_uuid))
    user = result.one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )

    ensure_active_account(user, detail="User account is not active")
    return user
