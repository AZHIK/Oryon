/// Application's offline-first Drift database.
///
/// `AppDatabase` is the single source of truth for all local persisted state:
/// auth (staff profiles, PIN hashes, lockout), device config, pending sales
/// awaiting sync, and a cached item catalog.
///
/// ─────────────────────────────────────────────────────────────────────────
/// DESIGN DECISION: No `activeBusinessId` and no `CachedBusinessContext`
/// ─────────────────────────────────────────────────────────────────────────
///
/// The original task described removing these as dead code from a prior
/// schema. This is a greenfield build (v1 is the first version), so they
/// are never created:
///
/// - `LocalUserProfiles.activeBusinessId` would always equal
///   `DeviceConfig.businessId` (the device is locked to one business).
///   A per-request "active business" concept has no use case.
///
/// - `CachedBusinessContext` would duplicate `DeviceConfig` (only ever one
///   row, already there). A business-context cache table has no use case.
///
/// These are documented as a design decision, not removed via migration.
///
/// ─────────────────────────────────────────────────────────────────────────
/// ENCRYPTION
/// ─────────────────────────────────────────────────────────────────────────
///
/// The database connection is opened with at-rest SQLCipher encryption via
/// `NativeDatabase.createInBackground` + a `PRAGMA key` setup, backed by
/// SQLite3MultipleCiphers. The encryption key is generated once on first
/// launch (32 random bytes via `Random.secure()`) and stored in
/// `flutter_secure_storage` (platform keychain/keystore). Subsequent launches
/// retrieve the key and reopen the same encrypted file. See
/// `lib/database/encryption_key_service.dart` for key lifecycle and known
/// edge cases (secure storage cleared but DB file persists, etc.).
///
/// ─────────────────────────────────────────────────────────────────────────
/// SYNC BOOKKEEPING & CONCURRENCY
/// ─────────────────────────────────────────────────────────────────────────
///
/// `PendingSales` tracks sync state across app restarts:
/// - `syncStatus`: pending → syncing → synced|failed
/// - `syncAttemptCount`: incremented on each attempt (tracks retries)
/// - `syncError`: populated if sync failed (not a transport error)
///
/// Synced rows are NEVER deleted; they double as local sale history for
/// offline receipts. The `syncStatus = 'syncing'` value is a row-claim
/// marker for cross-isolate concurrency safety: one DB transaction claims
/// and flips rows to 'syncing' before uploading, so a concurrent background
/// isolate (e.g., workmanager) cannot claim the same rows.
///
/// ─────────────────────────────────────────────────────────────────────────
/// MIGRATION STRATEGY
/// ─────────────────────────────────────────────────────────────────────────
///
/// v1 was the first version, so its `onCreate` handled everything.
///
/// v2 is additive-only: offline RBAC (`CachedPermissions`), an advisory
/// stock-level cache (`CachedStockLevels`), void/refund and expense/income
/// outboxes (`PendingVoidsRefunds`, `ExpenseEntries`, `OtherIncomeEntries`),
/// an audit trail outbox (`LocalAuditLog`), and one new nullable column on
/// `LocalUserProfiles` (`lastRevocationCheckAt`). No existing table is
/// dropped, renamed, or has a column removed.
///
/// v4 adds one nullable column, `CachedItems.unitCost`, mirroring
/// Inventory Service's `Item.unit_cost` (the cost basis behind the
/// inventory-value reporting metric).
///
/// v5 adds the sales read cache (`CachedSales`, `CachedSaleLineItems` — the
/// sales-side analogue of `CachedItems`/`CachedStockLevels`) and renames
/// `PendingSales.businessLocationId` to `storeId`, matching POS Service's
/// own rename of `SaleSyncInput.business_location_id` to `store_id`
/// (migration `c3d4e5f6a7b8`) — the old name would 422 against the real
/// backend.
///
/// v6 connects `ExpenseEntries`/`OtherIncomeEntries` to a real backend
/// (POS Service's `other_expenses`/`other_incomes`, migration
/// `d4e5f6a7b8c9`) for the first time: adds `paymentMethod`, `payee`/
/// `source`, `note`, `receiptAttachmentId`, `localReceiptPath`, and
/// `serverId` columns to both outbox tables, renames their
/// `businessLocationId` to `storeId` (same rename `PendingSales` went
/// through in v5), and adds the pull-side read caches
/// `CachedOtherExpenses`/`CachedOtherIncomes` (the finance-side analogue of
/// `CachedSales`). `paymentMethod` is added with a `'other'` default since
/// SQLite requires one for a non-nullable `addColumn` on existing rows.
///
/// v7 connects the Customers module to a real backend (POS Service's
/// `customers`, migration `e5f6a7b8c9d0`) and wires the POS checkout flow
/// to attribute sales to a customer: adds the outbox `CustomerEntries` and
/// the pull-side cache `CachedCustomers` (business-scoped, not
/// store-scoped — see `customer_entries.dart`'s doc comment on why a
/// customer's id is client-generated and IS its server primary key, unlike
/// every other synced entity), and adds a nullable `customerId` column to
/// both `PendingSales` and `CachedSales` so a sale can carry its
/// attribution end to end. Both new sale columns are nullable, so no
/// SQLite default is needed here (unlike v6's `paymentMethod`).
///
/// v8 connects the Suppliers module to a real backend (Inventory Service's
/// `suppliers`, migration `e4f5a6b7c8d9`): adds the pull-only cache table
/// `CachedSuppliers` (business-scoped). Unlike every prior sync-connected
/// module, it gets no outbox table — Inventory Service writes have always
/// gone direct to the API with no offline queue (see `InventoryNotifier`'s
/// doc comment in `inventory_provider.dart`), and Suppliers follow that
/// same convention rather than Finance/Customers' outbox pattern.
///
/// (A `CachedReorders` table briefly shared this version while the
/// single-line reorders flow existed; it was removed with that flow — the
/// purchases module's multi-line POs are online-only and cache nothing.)
///
/// v9 connects the product-category picker to a real backend (Inventory
/// Service's `category` table, migration
/// `f1a2b3c4d5e6_create_category_and_migrate_item_category`): adds the
/// pull-only cache table `CachedCategories` — global, not business-scoped,
/// mirroring `CachedSuppliers`' shape minus `businessId`/soft-delete.
/// `CachedItems.category` is NOT renamed or altered here — it stays a
/// nullable text column, only its meaning changes (the backend category's
/// UUID, no longer a raw free-text string), since the backend's own
/// `item.category` → `item.category_id` migration renamed the wire field.
///
/// v10 connects the item unit picker to a real backend (Inventory
/// Service's `unit` table, migration
/// `a7b8c9d0e1f2_create_unit_and_migrate_item_unit`): adds the pull-only
/// cache table `CachedUnits` — global, not business-scoped, mirroring
/// `CachedCategories`. Unlike `CachedItems.category` above,
/// `CachedItems.unitOfMeasure` is NOT repurposed: the backend renamed its
/// wire field (`unit_of_measure` → `unit_id`), so the old column is left
/// in place, unused, and a new nullable-in-spirit `unitId` column is added
/// instead (`m.addColumn` can't add a nullable column with no default in
/// SQLite the way this codebase's Drift version emits it, so it carries a
/// `''` "unset" sentinel default rather than being genuinely nullable —
/// see `CachedItems.unitId`'s doc comment).
///
/// v12 adds `LocalUserProfiles.isDeactivated` (default false, so existing
/// rows stay active): logout deactivates the row instead of leaving it
/// offered on the Profile Picker, and the next login reactivates it.
///
/// v13 syncs the item's preferred supplier (`item.supplier_id` on the wire,
/// settable on create/update and nullable server-side): adds
/// `CachedItems.supplierId` (NOT NULL with a `''` "none" default, same
/// SQLite add-column constraint as v10's `unitId`). The order cart
/// pre-assigns this supplier to a new line — still changeable per line or
/// via bulk-assign.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'converters/decimal_converter.dart';
import 'tables/local_user_profiles.dart';
import 'tables/device_config.dart';
import 'tables/pending_sales.dart';
import 'tables/pending_sale_line_items.dart';
import 'tables/cached_items.dart';
import 'tables/cached_permissions.dart';
import 'tables/cached_stock_levels.dart';
import 'tables/cached_business_roles.dart';
import 'tables/cached_sales.dart';
import 'tables/cached_sale_line_items.dart';
import 'tables/pending_voids_refunds.dart';
import 'tables/expense_entries.dart';
import 'tables/other_income_entries.dart';
import 'tables/cached_other_expenses.dart';
import 'tables/cached_other_incomes.dart';
import 'tables/customer_entries.dart';
import 'tables/cached_customers.dart';
import 'tables/cached_suppliers.dart';
import 'tables/cached_categories.dart';
import 'tables/cached_units.dart';
import 'tables/local_audit_log.dart';

part 'app_database.g.dart';

/// Application's Drift database.
@DriftDatabase(tables: [
  LocalUserProfiles,
  DeviceConfig,
  PendingSales,
  PendingSaleLineItems,
  CachedItems,
  CachedPermissions,
  CachedStockLevels,
  CachedBusinessRoles,
  CachedSales,
  CachedSaleLineItems,
  PendingVoidsRefunds,
  ExpenseEntries,
  OtherIncomeEntries,
  CachedOtherExpenses,
  CachedOtherIncomes,
  CustomerEntries,
  CachedCustomers,
  CachedSuppliers,
  CachedCategories,
  CachedUnits,
  LocalAuditLog,
])
class AppDatabase extends _$AppDatabase {
  /// Creates an instance using the provided connection.
  AppDatabase(super.connection);

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(
          localUserProfiles,
          localUserProfiles.lastRevocationCheckAt,
        );
        await m.createTable(cachedBusinessRoles);
        await m.createTable(cachedPermissions);
        await m.createTable(cachedStockLevels);
        await m.createTable(pendingVoidsRefunds);
        await m.createTable(expenseEntries);
        await m.createTable(otherIncomeEntries);
        await m.createTable(localAuditLog);
      }
      if (from < 3) {
        // v2→v3: Create CachedBusinessRoles if it wasn't created in v1→v2 upgrade
        // (safety net for installations that upgraded v1→v2 before this fix)
        try {
          await m.createTable(cachedBusinessRoles);
        } catch (e) {
          // Table may already exist; ignore error
        }
      }
      if (from < 4) {
        await m.addColumn(cachedItems, cachedItems.unitCost);
      }
      if (from < 5) {
        await m.createTable(cachedSales);
        await m.createTable(cachedSaleLineItems);
        await m.renameColumn(
          pendingSales,
          'business_location_id',
          pendingSales.storeId,
        );
      }
      if (from < 6) {
        await m.createTable(cachedOtherExpenses);
        await m.createTable(cachedOtherIncomes);

        await m.renameColumn(
          expenseEntries,
          'business_location_id',
          expenseEntries.storeId,
        );
        await m.addColumn(expenseEntries, expenseEntries.payee);
        await m.addColumn(expenseEntries, expenseEntries.note);
        await m.addColumn(expenseEntries, expenseEntries.paymentMethod);
        await m.addColumn(
          expenseEntries,
          expenseEntries.receiptAttachmentId,
        );
        await m.addColumn(expenseEntries, expenseEntries.localReceiptPath);
        await m.addColumn(expenseEntries, expenseEntries.serverId);

        await m.renameColumn(
          otherIncomeEntries,
          'business_location_id',
          otherIncomeEntries.storeId,
        );
        await m.addColumn(otherIncomeEntries, otherIncomeEntries.source);
        await m.addColumn(otherIncomeEntries, otherIncomeEntries.note);
        await m.addColumn(
          otherIncomeEntries,
          otherIncomeEntries.paymentMethod,
        );
        await m.addColumn(
          otherIncomeEntries,
          otherIncomeEntries.receiptAttachmentId,
        );
        await m.addColumn(
          otherIncomeEntries,
          otherIncomeEntries.localReceiptPath,
        );
        await m.addColumn(otherIncomeEntries, otherIncomeEntries.serverId);
      }
      if (from < 7) {
        await m.createTable(customerEntries);
        await m.createTable(cachedCustomers);
        await m.addColumn(pendingSales, pendingSales.customerId);
        await m.addColumn(cachedSales, cachedSales.customerId);
      }
      if (from < 8) {
        await m.createTable(cachedSuppliers);
      }
      if (from < 9) {
        await m.createTable(cachedCategories);
      }
      if (from < 10) {
        await m.createTable(cachedUnits);
        await m.addColumn(cachedItems, cachedItems.unitId);
      }
      if (from < 11) {
        await m.addColumn(cachedItems, cachedItems.imageUrl);
      }
      if (from < 12) {
        await m.addColumn(
          localUserProfiles,
          localUserProfiles.isDeactivated,
        );
      }
      if (from < 13) {
        await m.addColumn(cachedItems, cachedItems.supplierId);
      }
      if (from < 14) {
        // v13→v14: sale-time production-cost snapshots. Nullable, so
        // existing rows (and sales synced by older clients) read as
        // unknown rather than zero — profit figures fall back to live
        // recipe costs for those.
        await m.addColumn(
          pendingSaleLineItems,
          pendingSaleLineItems.unitCost,
        );
        await m.addColumn(
          cachedSaleLineItems,
          cachedSaleLineItems.unitCost,
        );
      }
    },
    beforeOpen: (details) async {
      // Enforce foreign key constraints.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
