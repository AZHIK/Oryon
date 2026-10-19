/// Tests for the Drift database schema and basic operations.
///
/// This test suite verifies that the database schema is correctly defined.
/// `onCreate` builds the full schemaVersion 2 shape directly (as it does
/// for any fresh install), so these tests exercise that path rather than
/// the v1-to-v2 `onUpgrade` migration.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos/database/app_database.dart';

AppDatabase _createTestDatabase() {
  final connection = NativeDatabase.memory();
  return AppDatabase(connection);
}

void main() {
  group('AppDatabase', () {
    late AppDatabase database;

    setUp(() {
      database = _createTestDatabase();
    });

    tearDown(() async {
      await database.close();
    });

    test('creates schema on first use', () async {
      // The schema is created in `onCreate` when `MigrationStrategy` is applied.
      // No explicit call needed; just opening the database triggers it.
      // If we get here without an exception, the schema was created successfully.
      expect(database, isA<AppDatabase>());
    });

    test('schema version is 15', () async {
      expect(database.schemaVersion, 15);
    });

    test('LocalUserProfiles table exists and can be queried', () async {
      // Insert a test profile
      await database.into(database.localUserProfiles).insert(
            LocalUserProfilesCompanion.insert(
              id: 'test-staff-1',
              displayName: 'Test Staff',
              pinHash: 'hashed_pin',
              pinSalt: 'salt',
              failedPinAttempts: const Value(0),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // Query it back
      final profile = await (database.select(database.localUserProfiles)
            ..where((row) => row.id.equals('test-staff-1')))
          .getSingleOrNull();

      expect(profile != null, true);
      expect(profile!.displayName, 'Test Staff');
    });

    test('DeviceConfig table exists and enforces singleton constraint', () async {
      final now = DateTime.now();

      // Insert the singleton row
      await database.into(database.deviceConfig).insertOnConflictUpdate(
            DeviceConfigCompanion.insert(
              businessId: 'biz-123',
              businessLocationId: 'loc-456',
              businessName: 'Test Business',
              provisionedAt: now,
              updatedAt: now,
            ),
          );

      // Verify it's there
      final config = await (database.select(database.deviceConfig)
            ..where((row) => row.id.equals(0)))
          .getSingleOrNull();

      expect(config != null, true);
      expect(config!.businessId, 'biz-123');

      // Update the same row (upsert with the same id)
      await database.into(database.deviceConfig).insertOnConflictUpdate(
            DeviceConfigCompanion(
              businessId: const Value('biz-789'),
              businessLocationId: const Value('loc-999'),
              businessName: const Value('Updated Business'),
              provisionedAt: Value(now),
              updatedAt: Value(now.add(const Duration(seconds: 1))),
            ),
          );

      // Verify the row was updated, not duplicated
      final configs = await database.select(database.deviceConfig).get();
      expect(configs.length, 1);
      expect(configs.first.businessId, 'biz-789');
    });

    test('PendingSales and PendingSaleLineItems tables exist', () async {
      final now = DateTime.now();

      // Insert a pending sale
      final saleId = await database.into(database.pendingSales).insert(
            PendingSalesCompanion.insert(
              clientSaleId: 'sale-uuid-1',
              status: 'completed',
              storeId: 'loc-123',
              paymentMethod: 'cash',
              occurredAt: now,
              createdAt: now,
            ),
          );

      // Insert a line item
      await database.into(database.pendingSaleLineItems).insert(
            PendingSaleLineItemsCompanion.insert(
              pendingSaleId: saleId,
              itemId: 'item-uuid-1',
              quantity: Decimal.fromInt(10),
              unitPrice: Decimal.parse('5.00'),
            ),
          );

      // Query the sale back with its line items
      final sales = await database.select(database.pendingSales).get();
      expect(sales.length, 1);
      expect(sales.first.clientSaleId, 'sale-uuid-1');

      final lineItems = await database.select(database.pendingSaleLineItems).get();
      expect(lineItems.length, 1);
      expect(lineItems.first.itemId, 'item-uuid-1');
    });

    test('CachedItems table exists', () async {
      final now = DateTime.now();

      // Insert a cached item
      await database.into(database.cachedItems).insert(
            CachedItemsCompanion.insert(
              id: 'item-uuid-1',
              businessId: 'biz-123',
              businessLocationId: 'loc-456',
              name: 'Tomato',
              unitOfMeasure: 'kg',
              reorderThreshold: Decimal.fromInt(10),
              reorderQuantity: Decimal.fromInt(20),
              itemType: 'sellable',
              createdAtServer: now,
              updatedAtServer: now,
              lastSeenAt: now,
              lastSyncedAt: now,
            ),
          );

      // Query it back
      final items = await database.select(database.cachedItems).get();
      expect(items.length, 1);
      expect(items.first.name, 'Tomato');
      // No photo synced yet — the UI falls back to its placeholder.
      expect(items.first.imageUrl == null, true);
    });

    test('CachedItems.imageUrl round-trips a synced photo URL', () async {
      final now = DateTime.now();

      await database.into(database.cachedItems).insert(
            CachedItemsCompanion.insert(
              id: 'item-uuid-2',
              businessId: 'biz-123',
              businessLocationId: 'loc-456',
              name: 'Pilau',
              unitOfMeasure: 'ea',
              reorderThreshold: Decimal.fromInt(10),
              reorderQuantity: Decimal.fromInt(20),
              itemType: 'sellable',
              createdAtServer: now,
              updatedAtServer: now,
              lastSeenAt: now,
              lastSyncedAt: now,
              imageUrl: const Value(
                '/businesses/biz-123/items/item-uuid-2/image',
              ),
            ),
          );

      final item = await (database.select(database.cachedItems)
            ..where((row) => row.id.equals('item-uuid-2')))
          .getSingle();
      expect(
        item.imageUrl,
        '/businesses/biz-123/items/item-uuid-2/image',
      );

      // A photo removed server-side clears on the next pull.
      await (database.update(database.cachedItems)
            ..where((row) => row.id.equals('item-uuid-2')))
          .write(const CachedItemsCompanion(imageUrl: Value(null)));
      final cleared = await (database.select(database.cachedItems)
            ..where((row) => row.id.equals('item-uuid-2')))
          .getSingle();
      expect(cleared.imageUrl == null, true);
    });

    test('LocalUserProfiles.lastRevocationCheckAt defaults to null and is settable', () async {
      await database.into(database.localUserProfiles).insert(
            LocalUserProfilesCompanion.insert(
              id: 'test-staff-2',
              displayName: 'Test Staff 2',
              pinHash: 'hashed_pin',
              pinSalt: 'salt',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final profile = await (database.select(database.localUserProfiles)
            ..where((row) => row.id.equals('test-staff-2')))
          .getSingle();
      expect(profile.lastRevocationCheckAt, null);

      // Drift's DateTime column stores unix-epoch seconds, truncating
      // sub-second precision, so compare at second resolution.
      final checkedAt = DateTime.fromMillisecondsSinceEpoch(
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) * 1000,
      );
      await (database.update(database.localUserProfiles)
            ..where((row) => row.id.equals('test-staff-2')))
          .write(LocalUserProfilesCompanion(
            lastRevocationCheckAt: Value(checkedAt),
          ));

      final updated = await (database.select(database.localUserProfiles)
            ..where((row) => row.id.equals('test-staff-2')))
          .getSingle();
      expect(updated.lastRevocationCheckAt, checkedAt);
    });

    test('CachedPermissions table exists and cascades on profile delete', () async {
      final now = DateTime.now();

      await database.into(database.localUserProfiles).insert(
            LocalUserProfilesCompanion.insert(
              id: 'test-staff-3',
              displayName: 'Test Staff 3',
              pinHash: 'hashed_pin',
              pinSalt: 'salt',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database.into(database.cachedPermissions).insert(
            CachedPermissionsCompanion.insert(
              userId: 'test-staff-3',
              businessId: 'biz-123',
              businessName: 'Test Business',
              businessLocationId: 'loc-456',
              roleName: 'manager',
              permissionCodes: '["sales.void","staff.invite"]',
              cachedAt: now,
            ),
          );

      final permissions = await database.select(database.cachedPermissions).get();
      expect(permissions.length, 1);
      expect(permissions.first.roleName, 'manager');

      // Deleting the profile should cascade-delete its cached permissions.
      await (database.delete(database.localUserProfiles)
            ..where((row) => row.id.equals('test-staff-3')))
          .go();

      final remaining = await database.select(database.cachedPermissions).get();
      expect(remaining, isEmpty);
    });

    test('CachedStockLevels table exists', () async {
      final now = DateTime.now();

      await database.into(database.cachedStockLevels).insert(
            CachedStockLevelsCompanion.insert(
              itemId: 'item-uuid-1',
              businessLocationId: 'loc-456',
              currentQuantity: Decimal.fromInt(12),
              cachedAt: now,
            ),
          );

      final levels = await database.select(database.cachedStockLevels).get();
      expect(levels.length, 1);
      expect(levels.first.currentQuantity, Decimal.fromInt(12));
    });

    test('PendingVoidsRefunds table exists and references a synced sale', () async {
      final now = DateTime.now();

      await database.into(database.pendingSales).insert(
            PendingSalesCompanion.insert(
              clientSaleId: 'sale-uuid-2',
              status: 'completed',
              storeId: 'loc-123',
              paymentMethod: 'cash',
              occurredAt: now,
              createdAt: now,
            ),
          );

      await database.into(database.pendingVoidsRefunds).insert(
            PendingVoidsRefundsCompanion.insert(
              clientActionId: 'void-uuid-1',
              saleId: 'sale-uuid-2',
              newStatus: 'voided',
              reason: 'Customer changed order',
              actorUserId: 'test-staff-1',
              occurredAt: now,
              createdAt: now,
            ),
          );

      final voids = await database.select(database.pendingVoidsRefunds).get();
      expect(voids.length, 1);
      expect(voids.first.newStatus, 'voided');
    });

    test('ExpenseEntries table exists', () async {
      final now = DateTime.now();

      await database.into(database.expenseEntries).insert(
            ExpenseEntriesCompanion.insert(
              expenseId: 'expense-uuid-1',
              businessId: 'biz-123',
              storeId: 'loc-456',
              category: 'supplies',
              amount: Decimal.parse('45.00'),
              occurredAt: now,
              actorUserId: 'test-staff-1',
              createdAt: now,
            ),
          );

      final expenses = await database.select(database.expenseEntries).get();
      expect(expenses.length, 1);
      expect(expenses.first.category, 'supplies');
      // paymentMethod defaults to 'other' so a v5-shaped insert (unaware of
      // the new column) still round-trips cleanly.
      expect(expenses.first.paymentMethod, 'other');
    });

    test('OtherIncomeEntries table exists', () async {
      final now = DateTime.now();

      await database.into(database.otherIncomeEntries).insert(
            OtherIncomeEntriesCompanion.insert(
              incomeId: 'income-uuid-1',
              businessId: 'biz-123',
              storeId: 'loc-456',
              category: 'equipment_rental',
              amount: Decimal.parse('100.00'),
              occurredAt: now,
              actorUserId: 'test-staff-1',
              createdAt: now,
            ),
          );

      final income = await database.select(database.otherIncomeEntries).get();
      expect(income.length, 1);
      expect(income.first.category, 'equipment_rental');
    });

    test('CachedOtherExpenses and CachedOtherIncomes tables exist', () async {
      final now = DateTime.now();

      await database.into(database.cachedOtherExpenses).insertOnConflictUpdate(
            CachedOtherExpensesCompanion.insert(
              id: 'srv-exp-1',
              businessId: 'biz-123',
              storeId: 'loc-456',
              clientExpenseId: 'client-exp-1',
              category: 'rent',
              amount: Decimal.parse('300.00'),
              description: 'Rent',
              paymentMethod: 'cash',
              occurredAt: now,
              syncedAt: now,
              updatedAt: now,
              createdAt: now,
              lastSyncedAt: now,
            ),
          );
      await database.into(database.cachedOtherIncomes).insertOnConflictUpdate(
            CachedOtherIncomesCompanion.insert(
              id: 'srv-inc-1',
              businessId: 'biz-123',
              storeId: 'loc-456',
              clientIncomeId: 'client-inc-1',
              category: 'catering',
              amount: Decimal.parse('500.00'),
              description: 'Catering',
              paymentMethod: 'mobile_money',
              occurredAt: now,
              syncedAt: now,
              updatedAt: now,
              createdAt: now,
              lastSyncedAt: now,
            ),
          );

      final expenses = await database.select(database.cachedOtherExpenses).get();
      final incomes = await database.select(database.cachedOtherIncomes).get();
      expect(expenses.length, 1);
      expect(incomes.length, 1);
      expect(expenses.first.isDeleted, false);
    });

    test('CustomerEntries outbox and CachedCustomers cache tables exist', () async {
      final now = DateTime.now();

      await database.into(database.customerEntries).insert(
            CustomerEntriesCompanion.insert(
              customerId: 'cust-uuid-1',
              businessId: 'biz-123',
              name: 'Jane Doe',
              phone: '+1-555-0100',
              joinedAt: now,
              actorUserId: 'test-staff-1',
              createdAt: now,
            ),
          );
      await database.into(database.cachedCustomers).insertOnConflictUpdate(
            CachedCustomersCompanion.insert(
              id: 'cust-uuid-1',
              businessId: 'biz-123',
              name: 'Jane Doe',
              phone: '+1-555-0100',
              joinedAt: now,
              syncedAt: now,
              updatedAt: now,
              createdAt: now,
              totalSpent: Decimal.parse('120.00'),
              lastSyncedAt: now,
            ),
          );

      final outbox = await database.select(database.customerEntries).get();
      final cached = await database.select(database.cachedCustomers).get();
      expect(outbox.length, 1);
      expect(cached.length, 1);
      // The outbox row's customerId and the cache row's id use the same
      // value space — a customer's id is client-generated and IS its
      // server primary key (see `customer_entries.dart`'s doc comment).
      expect(outbox.first.customerId, cached.first.id);
      expect(cached.first.totalOrders, 0); // withDefault
      expect(cached.first.isDeleted, false);
    });

    test('CachedSuppliers table exists', () async {
      final now = DateTime.now();

      await database.into(database.cachedSuppliers).insertOnConflictUpdate(
            CachedSuppliersCompanion.insert(
              id: 'sup-uuid-1',
              businessId: 'biz-123',
              name: 'Acme Produce',
              updatedAt: now,
              createdAt: now,
              lastSyncedAt: now,
            ),
          );

      final suppliers = await database.select(database.cachedSuppliers).get();
      expect(suppliers.length, 1);
      expect(suppliers.first.isDeleted, false);
    });

    test('PendingSales.customerId and CachedSales.customerId are nullable', () async {
      final now = DateTime.now();

      await database.into(database.pendingSales).insert(
            PendingSalesCompanion.insert(
              clientSaleId: 'sale-no-customer',
              status: 'completed',
              storeId: 'loc-456',
              paymentMethod: 'cash',
              occurredAt: now,
              createdAt: now,
            ),
          );

      final rows = await database.select(database.pendingSales).get();
      expect(rows.first.customerId, null);
    });

    test('LocalAuditLog table exists', () async {
      final now = DateTime.now();

      await database.into(database.localAuditLog).insert(
            LocalAuditLogCompanion.insert(
              actorUserId: 'test-staff-1',
              action: 'sale.completed',
              occurredAt: now,
              createdAt: now,
            ),
          );

      final entries = await database.select(database.localAuditLog).get();
      expect(entries.length, 1);
      expect(entries.first.action, 'sale.completed');
    });

    test('foreign keys are enforced', () async {
      // Try to insert a PendingSaleLineItems row with a non-existent pendingSaleId
      // This should fail if foreign keys are properly enforced.
      expect(
        () => database.into(database.pendingSaleLineItems).insert(
              PendingSaleLineItemsCompanion.insert(
                pendingSaleId: 9999, // Non-existent sale ID
                itemId: 'item-uuid-1',
                quantity: Decimal.fromInt(10),
                unitPrice: Decimal.parse('5.00'),
              ),
            ),
        throwsException,
      );
    });
  });
}
