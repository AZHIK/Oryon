# Oryon Foods Auth Service Database Schema

This document explains the database schema for the Oryon Foods authentication
and authorization service.

The auth service owns identity, sessions, platform roles, business membership,
business-level permissions, and login security. Audit persistence is owned by a
separate Audit Service that consumes `audit.recorded` events. Product data such
as sales, inventory, purchase orders, supplier prices, delivery jobs, forecasts,
and farmer production plans should live in separate domain services.

## Design Summary

Oryon Foods is a multi-sided platform with restaurants, suppliers, farmers,
drivers, consumers, and platform staff. The schema is designed around these
needs:

- One user identity can access multiple businesses.
- Businesses can be restaurants, suppliers, farmers, distributors, or platform
  operators.
- Businesses can belong to an organization and can have multiple locations.
- Access can be granted globally, at business level, or at business-location
  level.
- Permissions can mark AI-sensitive actions and actions requiring human
  approval.
- Login, device, session, and risk data are tracked separately.
- Auditable actions publish `audit.recorded` events for a separate Audit
  Service.

Most core tables include:

- `id`: UUID primary key.
- `created_at`: creation timestamp.
- `updated_at`: last update timestamp.
- `is_deleted` and `deleted_at`: soft-delete fields where applicable.

## Table Groups

## Identity

### `users`

Stores the platform-wide identity record for every person using Oryon Foods.

Used for:

- Restaurant owners and staff.
- Supplier users.
- Farmer users.
- Drivers.
- Consumers.
- Platform staff.

Important columns:

- `phone`: unique phone number. This is the primary mobile-first identifier.
- `email`: optional unique email address.
- `full_name`: user's display name.
- `user_category`: broad category such as `platform_staff`, `business_user`,
  `driver`, or `consumer`.
- `status`: account lifecycle state: `active`, `invited`, `suspended`, or
  `locked`.
- `password_hash`: optional password hash for password-based login.
- `is_active`: quick active/inactive flag.
- `is_phone_verified`: whether the phone number has been verified.
- `is_email_verified`: whether the email address has been verified.

Relationships:

- Owns zero or more `businesses`.
- Can be assigned global roles through `user_roles`.
- Can be assigned platform roles through `user_platform_roles`.
- Can be assigned business roles through `user_business_roles`.
- Can receive direct business permission overrides through
  `user_business_permissions`.

## Tenant And Business Structure

### `organizations`

Groups related businesses under one owner or legal operating structure.

Examples:

- A restaurant group with several branches.
- A supplier company with multiple depots.
- A farmer cooperative with multiple farms.

Important columns:

- `name`: organization name.
- `legal_name`: optional registered legal name.
- `country_code`: default country, currently defaulting to `TZ`.
- `default_timezone`: default timezone, currently `Africa/Dar_es_Salaam`.
- `owner_user_id`: user who owns or administrates the organization.

Relationships:

- Has many `businesses`.

### `businesses`

Represents an operating business on the platform.

Examples:

- Restaurant.
- Supplier.
- Farmer.
- Distributor.
- Platform operator.

Important columns:

- `name`: business name.
- `business_type`: controlled type: `restaurant`, `supplier`, `farmer`,
  `distributor`, or `platform_operator`.
- `owner_user_id`: user who owns the business.
- `organization_id`: optional parent organization.
- `tax_id`: optional tax or registration number.
- `country_code`: country of operation.
- `city`: city of operation.
- `timezone`: business timezone.

Relationships:

- Belongs to an optional `organization`.
- Has many `store`.
- Has many `business_roles`.
- Has many user role assignments through `user_business_roles`.
- Has direct permission overrides through `user_business_permissions`.

### `store`

Represents a branch, kitchen, warehouse, farm, depot, or head office belonging
to a business. A "business location" and a "store" are the same concept —
this table used to be named `business_locations`.

Important columns:

- `business_id`: parent business.
- `name`: store name.
- `location_type`: `head_office`, `restaurant_branch`, `kitchen`, `warehouse`,
  `farm`, or `depot`.
- `country_code`: store country.
- `city`: store city.
- `address`: optional physical address.
- `timezone`: store timezone.
- `is_primary`: marks the main store.

Constraints:

- A business cannot have two stores with the same `name`.

Relationships:

- Belongs to `businesses`.
- Can have store-scoped role assignments through
  `user_store_roles`.

## Permission Catalog And Global RBAC

### `permissions`

Central catalog of permission codes used by the platform.

This table prevents permission strings from becoming undocumented magic values.
It is also where Oryon Foods identifies actions that are sensitive because they
allow AI automation.

Example permission codes:

- `inventory.read`
- `inventory.adjust`
- `procurement.approve`
- `procurement.auto_order.enable`
- `ai.forecast.view`
- `ai.recommendation.approve`
- `supplier.price.manage`
- `farmer.supply_commitment.manage`

Important columns:

- `code`: unique machine-readable permission code.
- `name`: human-readable permission name.
- `description`: optional explanation.
- `domain`: permission area, such as `inventory`, `procurement`, `ai`, or
  `supplier`.
- `is_ai_sensitive`: marks permissions that allow AI-backed actions.
- `requires_human_approval`: marks permissions that should require explicit
  approval before execution.

### `groups`

Defines global user groups.

Groups are useful for organizing platform-level roles, such as finance,
operations, support, or compliance.

Important columns:

- `name`: unique group name.
- `description`: optional explanation.

Relationships:

- Has many `roles`.
- Linked to users through `user_group`.

### `roles`

Defines global roles inside a group.

Important columns:

- `group_id`: parent group.
- `name`: role name.
- `description`: optional explanation.

Relationships:

- Belongs to `groups`.
- Has permissions through `role_permissions`.
- Assigned to users through `user_roles`.

### `role_permissions`

Join table connecting global roles to permission codes.

Important columns:

- `role_id`: global role.
- `permission_code`: permission code.

Primary key:

- `role_id`, `permission_code`.

### `user_group`

Join table assigning users to global groups.

Important columns:

- `user_id`: user.
- `group_id`: group.

Primary key:

- `user_id`, `group_id`.

### `user_roles`

Join table assigning global roles directly to users.

Important columns:

- `user_id`: user.
- `role_id`: global role.

Primary key:

- `user_id`, `role_id`.

## Platform Roles

### `platform_roles`

Defines platform-wide roles that are not tied to one business.

Examples:

- `super_admin`
- `support_agent`
- `finance_admin`
- `compliance_admin`
- `driver_operations`

Important columns:

- `name`: unique platform role name.

Relationships:

- Assigned to users through `user_platform_roles`.

### `platform_role_permissions`

Join table connecting platform roles to permission codes.

Important columns:

- `platform_role_id`: platform role.
- `permission_code`: permission code.

Primary key:

- `platform_role_id`, `permission_code`.

### `user_platform_roles`

Assigns platform-wide roles to users.

Important columns:

- `user_id`: user.
- `platform_role_id`: platform role.

Constraints:

- A user cannot be assigned the same platform role more than once.

## Business RBAC

### `business_roles`

Defines roles inside a specific business.

Examples:

- Owner.
- Manager.
- Cashier.
- Stock controller.
- Procurement approver.
- Supplier sales admin.
- Farm coordinator.

Important columns:

- `business_id`: business that owns the role.
- `name`: role name.
- `description`: optional explanation.
- `is_protected`: prevents critical built-in roles from being changed or
  deleted casually.

Relationships:

- Belongs to `businesses`.
- Has permission codes through `business_role_permissions`.
- Assigned to users through `user_business_roles`.

### `business_role_permissions`

Join table connecting business roles to permission codes.

Important columns:

- `business_role_id`: business role.
- `permission_code`: permission code.

Primary key:

- `business_role_id`, `permission_code`.

### `user_business_roles`

Assigns a user to a business role across the whole business.

Important columns:

- `user_id`: user.
- `business_id`: business.
- `business_role_id`: business role.

Constraints:

- A user cannot receive the same role in the same business more than once.

### `user_store_roles`

Assigns a user to a business role for one specific store.

This supports cases such as a manager who only manages one restaurant branch,
warehouse, farm, kitchen, or depot.

Important columns:

- `user_id`: user.
- `business_id`: business.
- `store_id`: store.
- `business_role_id`: role.

Constraints:

- A user cannot receive the same role at the same store more than once.

### `user_business_permissions`

Direct business-level permission override for a user.

This allows granting or denying a specific permission outside normal role
membership.

Important columns:

- `user_id`: user receiving the override.
- `business_id`: business where the override applies.
- `permission_code`: permission being overridden.
- `type`: `grant` or `deny`.
- `created_by`: user who created the override.

Constraints:

- A user can only have one override per business and permission code.

## Role Templates

### `role_templates`

Defines reusable role templates.

Role templates can be used when creating a new restaurant, supplier, farmer, or
distributor account so the system can seed standard roles quickly.

Important columns:

- `name`: unique template name.
- `description`: optional explanation.
- `business_type`: optional business type scope, such as `restaurant`, `supplier`,
  `farmer`, `distributor`, or `platform_operator`. When set, this template is used
  when creating a business of that type. `NULL` means the template is generic or
  intended for manual assignment only.
- `is_owner_template`: when `true`, marks this as the Owner-equivalent template.
  During business creation, the cloned role gets `is_protected=true` and is
  auto-assigned to the business creator.

Relationships:

- Has permissions through `role_template_permissions`.

### `role_template_permissions`

Join table connecting role templates to permission codes.

Important columns:

- `role_template_id`: role template.
- `permission_code`: permission code.

Primary key:

- `role_template_id`, `permission_code`.

## Authentication And Sessions

### `verification_codes`

Stores hashed one-time verification codes.

Used for:

- Phone verification.
- Email verification.
- Password reset.
- Login OTP.

Important columns:

- `user_id`: user receiving the code.
- `code_hash`: hashed verification code. Raw OTP codes should not be stored.
- `type`: delivery type, either `sms` or `email`.
- `purpose`: `phone_verification`, `email_verification`, `password_reset`, or
  `login`.
- `expires_at`: expiration timestamp.
- `used_at`: timestamp when the code was consumed.
- `attempts`: number of verification attempts.

### `refresh_tokens`

Stores hashed refresh tokens.

Used for long-lived login sessions across Flutter apps and the web dashboard.

Important columns:

- `user_id`: token owner.
- `token_hash`: unique hash of the refresh token.
- `device_info`: optional device description.
- `ip_address`: IP address used when token was issued.
- `expires_at`: token expiration.
- `revoked_at`: timestamp when the token was revoked.
- `family_id`: UUID grouping all tokens in the same refresh family (original +
  all rotations). Used for replay detection and full-family revocation.
- `previous_token_id`: self-referencing FK to the token that was rotated to
  produce this one.
- `replaced_by_token_id`: self-referencing FK to the token that replaced this
  one (set on the old token when rotation occurs).

### `user_sessions`

Tracks active authenticated sessions.

Important columns:

- `user_id`: session owner.
- `refresh_token_id`: optional linked refresh token.
- `device_info`: optional device description.
- `ip_address`: last known IP address.
- `last_activity_at`: last activity timestamp.
- `expires_at`: session expiration.
- `is_active`: whether the session is currently active.

### `trusted_devices`

Stores trusted device fingerprints for users.

Used for:

- Reducing friction on known devices.
- Detecting suspicious login attempts.
- Revoking trusted devices.

Important columns:

- `user_id`: device owner.
- `device_fingerprint_hash`: hashed fingerprint. Raw fingerprints should not be
  stored.
- `device_name`: optional user-facing device name.
- `platform`: mobile/web/platform description.
- `last_ip_address`: last seen IP.
- `last_seen_at`: most recent activity timestamp.
- `revoked_at`: timestamp when trust was revoked.

Constraints:

- A user cannot have the same trusted device fingerprint more than once.

### `login_attempts`

Records login attempts whether or not a user was identified.

Used for:

- Brute-force detection.
- Lockout rules.
- Suspicious login monitoring.
- Support investigations.

Important columns:

- `user_id`: optional matched user.
- `identifier`: phone, email, or username entered during login.
- `success`: whether login succeeded.
- `failure_reason`: reason for failure.
- `ip_address`: login IP address.
- `device_fingerprint_hash`: optional hashed device fingerprint.
- `user_agent`: optional browser or client user agent.

### `auth_risk_events`

Records security-relevant authentication events.

Used for:

- Account lockouts.
- Suspicious login behavior.
- Device trust changes.
- High-risk OTP failures.

Important columns:

- `user_id`: optional affected user.
- `session_id`: optional affected session.
- `event_type`: `login_success`, `login_failure`, `otp_failure`,
  `password_reset_request`, `device_trusted`, or `account_locked`.
- `risk_level`: `low`, `medium`, `high`, or `critical`.
- `reason`: explanation for the event.
- `ip_address`: related IP address.
- `device_fingerprint_hash`: related hashed device fingerprint.

## Audit Events

The Identity Service does not own an `audit_logs` table. Auditable actions
publish an `audit.recorded` event to the shared event bus. A separate Audit
Service is responsible for subscribing to those events and storing the durable
audit trail.

Event payload shape:

```json
{
  "actor_id": "<user id or null>",
  "actor_type": "user | system | ai_agent | service",
  "business_id": "<business id or null>",
  "action": "<string>",
  "resource_type": "<string>",
  "resource_id": "<string or null>",
  "details": {}
}
```

Identity Service actions that currently publish this event:

- Business created.
- Business role assigned.
- Business permission override created.
- Protected role edit rejected.

## Relationship Overview

The main relationship chain is:

```text
users
  -> organizations
  -> businesses
  -> store
```

Access control is layered:

```text
permissions
  -> role_permissions
  -> roles
  -> user_roles

permissions
  -> platform_role_permissions
  -> platform_roles
  -> user_platform_roles

permissions
  -> role_template_permissions
  -> role_templates
  -> business_role_permissions (cloned at business creation)
  -> business_roles
  -> user_business_roles
  -> user_store_roles

permissions
  -> business_role_permissions
  -> business_roles
  -> user_business_roles
  -> user_store_roles

permissions
  -> user_business_permissions
```

Authentication state is tracked through:

```text
users
  -> verification_codes
  -> refresh_tokens
  -> user_sessions
  -> trusted_devices
  -> login_attempts
  -> auth_risk_events
```

Auditability is emitted through:

```text
audit.recorded events
```

## Table Count

The current schema registers 26 database tables:

1. `users`
2. `organizations`
3. `businesses`
4. `store`
5. `permissions`
6. `groups`
7. `roles`
8. `role_permissions`
9. `user_group`
10. `user_roles`
11. `platform_roles`
12. `platform_role_permissions`
13. `user_platform_roles`
14. `business_roles`
15. `business_role_permissions`
16. `user_business_roles`
17. `user_store_roles`
18. `user_business_permissions`
19. `role_templates`
20. `role_template_permissions`
21. `verification_codes`
22. `refresh_tokens`
23. `user_sessions`
24. `trusted_devices`
25. `login_attempts`
26. `auth_risk_events`
