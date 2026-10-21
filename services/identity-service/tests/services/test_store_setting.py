"""StoreSetting invariants: true 1:1 with store, decimal-not-float, and
string/currency/payment-duration round-trips."""

from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy.exc import IntegrityError
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession

from app.models.business import Business, BusinessType, LocationType, Store, StoreSetting
from app.models.user import User, UserCategory
from app.schemas.store_setting import StoreSettingUpdate
from app.services.store import generate_store_token


async def _make_store(db_session: AsyncSession, *, name: str = "Store One") -> Store:
    user = User(
        phone=f"+2557{uuid4().hex[:9]}",
        full_name="Settings Test User",
        user_category=UserCategory.BUSINESS_STAFF,
    )
    async with db_session.begin():
        db_session.add(user)
        await db_session.flush()
        business = Business(
            name=f"{name} Biz",
            business_type=BusinessType.RESTAURANT,
            owner_user_id=user.id,
        )
        db_session.add(business)
        await db_session.flush()
        store = Store(
            business_id=business.id,
            name=name,
            token=generate_store_token(),
            location_type=LocationType.HEAD_OFFICE,
        )
        db_session.add(store)
        await db_session.flush()
    return store


class TestStoreSettingOneToOne:
    async def test_second_settings_row_for_same_store_is_rejected(
        self, db_session: AsyncSession
    ) -> None:
        store = await _make_store(db_session)

        async with db_session.begin():
            db_session.add(StoreSetting(store_id=store.id, active=True))

        with pytest.raises(IntegrityError):
            async with db_session.begin():
                db_session.add(StoreSetting(store_id=store.id, active=True))

    async def test_created_with_store_by_default(self) -> None:
        # create_store (sync, auto-commits) must also create the settings row.
        from sqlmodel import Session, SQLModel, create_engine

        engine = create_engine("sqlite:///:memory:")
        SQLModel.metadata.create_all(engine)
        with Session(engine) as session:
            from app.services.store import create_store

            business = Business(
                name="Sync Biz",
                business_type=BusinessType.RESTAURANT,
                owner_user_id=uuid4(),
            )
            session.add(business)
            session.commit()
            session.refresh(business)

            store = create_store(
                session,
                business=business,
                name="Sync Store",
                location_type=LocationType.KITCHEN,
            )

            setting = session.exec(
                select(StoreSetting).where(StoreSetting.store_id == store.id)
            ).one()
            assert setting.active is True


class TestStoreSettingRoundTrip:
    async def test_logo_round_trip(self, db_session: AsyncSession) -> None:
        store = await _make_store(db_session)
        logo_url = "https://cdn.oryonfoods.com/stores/store-1.png"

        async with db_session.begin():
            db_session.add(StoreSetting(store_id=store.id, logo=logo_url))

        setting = (
            await db_session.exec(select(StoreSetting).where(StoreSetting.store_id == store.id))
        ).one()
        assert setting.logo == logo_url

    async def test_amount_is_decimal_not_float_with_precision(
        self, db_session: AsyncSession
    ) -> None:
        store = await _make_store(db_session)

        async with db_session.begin():
            db_session.add(
                StoreSetting(
                    store_id=store.id,
                    preferred_currency="USD",
                    amount=Decimal("1234.56"),
                    max_payment_time_minutes=45,
                    latitude=Decimal("-6.792354"),
                    longitude=Decimal("39.208328"),
                    offer_retail=True,
                    offer_wholesale=True,
                    display_prices_inclusive_of_tax=True,
                )
            )

        setting = (
            await db_session.exec(select(StoreSetting).where(StoreSetting.store_id == store.id))
        ).one()
        assert setting.preferred_currency == "USD"
        assert isinstance(setting.amount, Decimal)
        assert setting.amount == Decimal("1234.56")
        assert setting.max_payment_time_minutes == 45
        assert setting.latitude == Decimal("-6.792354")
        assert setting.longitude == Decimal("39.208328")
        assert setting.offer_retail is True
        assert setting.offer_wholesale is True
        assert setting.display_prices_inclusive_of_tax is True

    async def test_update_schema_normalizes_email_and_phone(self, db_session: AsyncSession) -> None:
        store = await _make_store(db_session)

        body = StoreSettingUpdate(
            email="Store@EXAMPLE.COM",
            phone="0712345678",
            amount=Decimal("10.50"),
        )
        assert body.email == "store@example.com"
        assert body.phone == "+255712345678"

        async with db_session.begin():
            db_session.add(StoreSetting(store_id=store.id, **body.model_dump(exclude_unset=True)))

        setting = (
            await db_session.exec(select(StoreSetting).where(StoreSetting.store_id == store.id))
        ).one()
        assert setting.email == "store@example.com"
        assert setting.phone == "+255712345678"
        assert setting.amount == Decimal("10.50")


class TestBusinessLogo:
    async def test_business_logo_round_trip(self, db_session: AsyncSession) -> None:
        user = User(
            phone=f"+2557{uuid4().hex[:9]}",
            full_name="Logo Test User",
            user_category=UserCategory.BUSINESS_STAFF,
        )
        logo_url = "https://cdn.oryonfoods.com/businesses/biz-1.png"

        async with db_session.begin():
            db_session.add(user)
            await db_session.flush()
            business = Business(
                name="Logo Biz",
                business_type=BusinessType.RESTAURANT,
                owner_user_id=user.id,
                logo=logo_url,
            )
            db_session.add(business)

        saved = (await db_session.exec(select(Business).where(Business.name == "Logo Biz"))).one()
        assert saved.logo == logo_url
