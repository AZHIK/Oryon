"""
╔══════════════════════════════════════════════════════════════════════╗
║ DUPLICATION-DRIFT WARNING                                          ║
║                                                                    ║
║ This file is a COPY of Identity Service's PermissionCode enum.     ║
║ It is NOT a shared import from a common package.  Changes made     ║
║ here MUST also be made in Identity Service's copy, and vice versa. ║
║                                                                    ║
║ The long-term solution is to extract this into a shared Python     ║
║ package that both services import.  This was discussed but left    ║
║ unresolved during the initial service-scaffold build.              ║
║ TODO-FIXME: Extract PermissionCode to a shared package.            ║
╚══════════════════════════════════════════════════════════════════════╝
"""

from enum import StrEnum


class PermissionCode(StrEnum):
    POS_WRITE = "pos.write"
    POS_REFUND = "pos.refund"
    INVENTORY_VIEW = "inventory.view"
    INVENTORY_ADJUST = "inventory.adjust"
    INVENTORY_ITEMS_CREATE = "inventory.items.create"
    INVENTORY_ITEMS_UPDATE = "inventory.items.update"
    INVENTORY_ITEMS_DEACTIVATE = "inventory.items.deactivate"
    INVENTORY_WASTE_RECORD = "inventory.waste.record"
    INVENTORY_TRANSFER = "inventory.transfer"
    # ── Reorders / Suppliers (enforced here — see
    # app/api/v1/endpoints/{reorders,suppliers}.py) ────────────────────────
    REORDERS_VIEW = "reorders.view"
    REORDERS_CREATE = "reorders.create"
    REORDERS_RECEIVE = "reorders.receive"
    REORDERS_CANCEL = "reorders.cancel"
    SUPPLIERS_VIEW = "suppliers.view"
    SUPPLIERS_CREATE = "suppliers.create"
    SUPPLIERS_UPDATE = "suppliers.update"
    SUPPLIERS_DELETE = "suppliers.delete"
    # ── Recipes (enforced here — see app/api/v1/endpoints/recipes.py) ────
    RECIPES_VIEW = "recipes.view"
    RECIPES_CREATE = "recipes.create"
    RECIPES_UPDATE = "recipes.update"
    RECIPES_DELETE = "recipes.delete"
    # ── Production (enforced here — see app/api/v1/endpoints/production.py)
    PRODUCTION_CREATE = "production.create"
    PRODUCTION_VIEW = "production.view"
    # ── Reports (cross-service reference — enforced by POS Service and by
    # this service's reports endpoints) ───────────────────────────────────
    REPORTS_VIEW = "reports.view"
    REPORTS_EXPORT = "reports.export"
    PROCUREMENT_CREATE = "procurement.create"
    PROCUREMENT_APPROVE = "procurement.approve"
    # ── Purchases (enforced here — see
    # app/api/v1/endpoints/purchases.py) ───────────────────────────────────
    PROCUREMENT_VIEW = "procurement.view"
    PROCUREMENT_RECEIVE = "procurement.receive"
    PROCUREMENT_AUTO_ORDER_ENABLE = "procurement.auto_order.enable"
    AI_FORECAST_VIEW = "ai.forecast.view"
    AI_RECOMMENDATION_APPROVE = "ai.recommendation.approve"
    SUPPLIER_PRICE_MANAGE = "supplier.price.manage"
    FARMER_SUPPLY_COMMITMENT_MANAGE = "farmer.supply_commitment.manage"

    USERS_VIEW = "users.view"
    USERS_UPDATE = "users.update"
    USERS_DEACTIVATE = "users.deactivate"
    USERS_REACTIVATE = "users.reactivate"
    USERS_MANAGE = "users.manage"

    GROUPS_VIEW = "groups.view"
    GROUPS_CREATE = "groups.create"
    GROUPS_UPDATE = "groups.update"
    GROUPS_DELETE = "groups.delete"
    GROUPS_ASSIGN_USER = "groups.assign_user"

    ROLES_VIEW = "roles.view"
    ROLES_CREATE = "roles.create"
    ROLES_UPDATE = "roles.update"
    ROLES_DELETE = "roles.delete"
    ROLES_ASSIGN_TO_USER = "roles.assign_to_user"
    ROLES_MANAGE_PERMISSIONS = "roles.manage_permissions"
    ROLES_ASSIGN = "roles.assign"

    PLATFORM_ROLES_VIEW = "platform_roles.view"
    PLATFORM_ROLES_CREATE = "platform_roles.create"
    PLATFORM_ROLES_UPDATE = "platform_roles.update"
    PLATFORM_ROLES_DELETE = "platform_roles.delete"
    PLATFORM_ROLES_ASSIGN_TO_USER = "platform_roles.assign_to_user"
    PLATFORM_ROLES_MANAGE_PERMISSIONS = "platform_roles.manage_permissions"

    ORGANIZATIONS_VIEW = "organizations.view"
    ORGANIZATIONS_CREATE = "organizations.create"
    ORGANIZATIONS_UPDATE = "organizations.update"
    ORGANIZATIONS_DELETE = "organizations.delete"

    BUSINESSES_VIEW = "businesses.view"
    BUSINESSES_CREATE = "businesses.create"
    BUSINESSES_UPDATE = "businesses.update"
    BUSINESSES_DELETE = "businesses.delete"
    BUSINESSES_ASSIGN_TO_ORGANIZATION = "businesses.assign_to_organization"

    STORES_VIEW = "stores.view"
    STORES_CREATE = "stores.create"
    STORES_UPDATE = "stores.update"
    STORES_DELETE = "stores.delete"

    BUSINESS_ROLES_VIEW = "business_roles.view"
    BUSINESS_ROLES_CREATE = "business_roles.create"
    BUSINESS_ROLES_UPDATE = "business_roles.update"
    BUSINESS_ROLES_DELETE = "business_roles.delete"
    BUSINESS_ROLES_MANAGE_PERMISSIONS = "business_roles.manage_permissions"
    BUSINESS_MANAGE_ROLES = "business.manage_roles"

    USER_BUSINESS_ROLES_VIEW = "user_business_roles.view"
    USER_BUSINESS_ROLES_ASSIGN = "user_business_roles.assign"
    USER_BUSINESS_ROLES_REVOKE = "user_business_roles.revoke"

    USER_STORE_ROLES_VIEW = "user_store_roles.view"
    USER_STORE_ROLES_ASSIGN = "user_store_roles.assign"
    USER_STORE_ROLES_REVOKE = "user_store_roles.revoke"

    USER_BUSINESS_PERMISSIONS_VIEW = "user_business_permissions.view"
    USER_BUSINESS_PERMISSIONS_GRANT = "user_business_permissions.grant"
    USER_BUSINESS_PERMISSIONS_DENY = "user_business_permissions.deny"
    USER_BUSINESS_PERMISSIONS_REVOKE = "user_business_permissions.revoke"

    ROLE_TEMPLATES_VIEW = "role_templates.view"
    ROLE_TEMPLATES_CREATE = "role_templates.create"
    ROLE_TEMPLATES_UPDATE = "role_templates.update"
    ROLE_TEMPLATES_DELETE = "role_templates.delete"
    ROLE_TEMPLATES_MANAGE_PERMISSIONS = "role_templates.manage_permissions"

    VERIFICATION_CODES_VIEW = "verification_codes.view"
    REFRESH_TOKENS_VIEW = "refresh_tokens.view"
    USER_SESSIONS_VIEW = "user_sessions.view"
    USER_SESSIONS_REVOKE = "user_sessions.revoke"
    TRUSTED_DEVICES_VIEW = "trusted_devices.view"
    TRUSTED_DEVICES_REVOKE = "trusted_devices.revoke"
    LOGIN_ATTEMPTS_VIEW = "login_attempts.view"
    AUTH_RISK_EVENTS_VIEW = "auth_risk_events.view"

    DELIVERY_VIEW_ASSIGNED = "delivery.view_assigned"
    DELIVERY_UPDATE_STATUS = "delivery.update_status"
    DELIVERY_CONFIRM_DROPOFF = "delivery.confirm_dropoff"
    ORDER_CREATE = "order.create"
    ORDER_VIEW_OWN = "order.view_own"
    ORDER_RATE = "order.rate"


def coerce_permission_code(code: str | PermissionCode) -> PermissionCode:
    if isinstance(code, PermissionCode):
        return code
    return PermissionCode(code)


def validate_permission_code(code: str | PermissionCode) -> None:
    coerce_permission_code(code)
