"""Create the first platform administrator.

This is a one-off bootstrap command, not an HTTP endpoint. It expects the
schema to be migrated and the internal RBAC seed to have run.

Environment:
    ADMIN_EMAIL           Required. Login email for the administrator.
    ADMIN_FULL_NAME       Optional display name.
    ADMIN_PASSWORD_FILE   Password file, default /run/secrets/admin_password.
    ADMIN_RESET_PASSWORD  Set to 1 to reset an existing account's password.
"""

from __future__ import annotations

import asyncio
import os
from pathlib import Path

from sqlalchemy.ext.asyncio import create_async_engine
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import get_settings
from app.core.security import hash_password
from app.models import Group, Role, User, UserCategory, UserGroup, UserStatus

GROUP_NAME = "IT / Platform Admin"
ROLE_NAME = "Super Admin"


def _read_password() -> str:
    password_file = Path(os.environ.get("ADMIN_PASSWORD_FILE", "/run/secrets/admin_password"))
    if not password_file.is_file():
        raise SystemExit(f"Admin password file not found: {password_file}")
    password = password_file.read_text().strip()
    if len(password) < 16:
        raise SystemExit("Admin password must be at least 16 characters")
    return password


async def main() -> None:
    email = os.environ.get("ADMIN_EMAIL", "").strip().lower()
    full_name = os.environ.get("ADMIN_FULL_NAME", "Platform Administrator").strip()
    reset_password = os.environ.get("ADMIN_RESET_PASSWORD", "0") == "1"

    if not email or "@" not in email:
        raise SystemExit("ADMIN_EMAIL must be a valid email address")

    password = _read_password()
    engine = create_async_engine(get_settings().db_url)

    try:
        async with AsyncSession(engine) as session:
            group = (
                await session.exec(select(Group).where(Group.name == GROUP_NAME))
            ).one_or_none()
            if group is None:
                raise SystemExit(
                    f"Group '{GROUP_NAME}' not found. Run scripts/seed_internal_rbac.py first."
                )

            role = (
                await session.exec(
                    select(Role).where(
                        Role.group_id == group.id,
                        Role.name == ROLE_NAME,
                    )
                )
            ).one_or_none()
            if role is None:
                raise SystemExit(
                    f"Role '{ROLE_NAME}' not found. Run scripts/seed_internal_rbac.py first."
                )

            existing = (await session.exec(select(User).where(User.email == email))).one_or_none()

            if existing is not None:
                if existing.user_category != UserCategory.PLATFORM_STAFF:
                    raise SystemExit(
                        "A non-platform account already uses this email; choose another address."
                    )
                if reset_password:
                    existing.password_hash = hash_password(password)
                    existing.is_active = True
                    existing.status = UserStatus.ACTIVE
                    existing.is_email_verified = True
                    session.add(existing)
                    print(f"Reset password for platform administrator {email}.")
                else:
                    print(f"Platform administrator already exists: {email}")

                membership = (
                    await session.exec(
                        select(UserGroup).where(
                            UserGroup.user_id == existing.id,
                            UserGroup.group_id == group.id,
                        )
                    )
                ).one_or_none()
                if membership is None:
                    session.add(UserGroup(user_id=existing.id, group_id=group.id))
                    await session.commit()
                    print(f"Added {email} to group '{GROUP_NAME}'.")
                else:
                    await session.commit()
                return

            user = User(
                phone=None,
                email=email,
                full_name=full_name or "Platform Administrator",
                user_category=UserCategory.PLATFORM_STAFF,
                status=UserStatus.ACTIVE,
                password_hash=hash_password(password),
                is_active=True,
                is_email_verified=True,
            )
            session.add(user)
            await session.flush()
            session.add(UserGroup(user_id=user.id, group_id=group.id))
            await session.commit()

        print(f"Created platform administrator {email} in group '{GROUP_NAME}'.")
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
