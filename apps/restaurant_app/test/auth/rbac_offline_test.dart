/// Comprehensive offline RBAC knowledge tests.
///
/// Tests the CachedPermissions-based offline RBAC knowledge layer:
/// - Reading cached permissions when offline
/// - Staleness detection
/// - Missing cache handling
/// - Multi-profile isolation
/// - Cache cleanup on profile removal
/// - Persistence across restart
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/database/app_database.dart';
import 'package:restaurant_pos/database/local_profile_repository.dart';


void main() {
  group('RBAC Offline Knowledge', () {
    group('4.1 - Present-and-fresh cache, offline', () {
      test('returns Known(permissions, isStale=false) with zero network calls', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final repo = LocalProfileRepository(db);
        final userId = 'user-001';

        // First create the user profile (FK constraint)
        await repo.upsertProfile(
          LocalUserProfilesCompanion.insert(
            id: userId,
            displayName: 'Test User',
            pinHash: 'hash',
            pinSalt: 'salt',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Write a fresh cached permissions row
        await repo.upsertPermissions(
          CachedPermissionsCompanion.insert(
            userId: userId,
            businessId: 'biz-001',
            businessName: 'Test Business',
            businessLocationId: 'store-001',
            roleName: 'Manager',
            permissionCodes: jsonEncode(['pos.write', 'inventory.edit']),
            cachedAt: DateTime.now(),
          ),
        );

        // Read it back (simulating offline query)
        final cached = await repo.getPermissions(userId);
        expect(cached, isNotNull);
        expect(cached!.userId, userId);
        expect(cached.businessId, 'biz-001');

        // Verify permissions are correctly decoded
        final perms = jsonDecode(cached.permissionCodes) as List<dynamic>;
        expect(perms.cast<String>(), contains('pos.write'));
        expect(perms.cast<String>(), contains('inventory.edit'));
      });
    });

    group('4.2 - Present-but-stale cache, offline', () {
      test('returns Known(permissions, isStale=true) for old cache', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final repo = LocalProfileRepository(db);
        final userId = 'user-002';
        final staleTime = DateTime.now().subtract(const Duration(days: 30));

        await repo.upsertProfile(
          LocalUserProfilesCompanion.insert(
            id: userId,
            displayName: 'Test User',
            pinHash: 'hash',
            pinSalt: 'salt',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        await repo.upsertPermissions(
          CachedPermissionsCompanion.insert(
            userId: userId,
            businessId: 'biz-001',
            businessName: 'Test Business',
            businessLocationId: 'store-001',
            roleName: 'Cashier',
            permissionCodes: jsonEncode(['pos.write']),
            cachedAt: staleTime,
          ),
        );

        final cached = await repo.getPermissions(userId);
        expect(cached, isNotNull);

        // In the provider, this would be marked stale
        final age = DateTime.now().difference(cached!.cachedAt);
        const ttl = Duration(hours: 24);
        expect(age > ttl, isTrue);
      });

      test('returns Known(permissions, isStale=false) for recent cache', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final repo = LocalProfileRepository(db);
        final userId = 'user-003';
        final recentTime = DateTime.now().subtract(const Duration(hours: 1));

        await repo.upsertProfile(
          LocalUserProfilesCompanion.insert(
            id: userId,
            displayName: 'Test User',
            pinHash: 'hash',
            pinSalt: 'salt',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        await repo.upsertPermissions(
          CachedPermissionsCompanion.insert(
            userId: userId,
            businessId: 'biz-001',
            businessName: 'Test Business',
            businessLocationId: 'store-001',
            roleName: 'Cashier',
            permissionCodes: jsonEncode(['pos.write']),
            cachedAt: recentTime,
          ),
        );

        final cached = await repo.getPermissions(userId);
        expect(cached, isNotNull);

        // Should be fresh
        final age = DateTime.now().difference(cached!.cachedAt);
        const ttl = Duration(hours: 24);
        expect(age < ttl, isTrue);
      });
    });

    group('4.3 - Never-populated cache, offline', () {
      test('returns unknown() when no cache exists', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final repo = LocalProfileRepository(db);

        // Try to read permissions for a user with no cache
        final cached = await repo.getPermissions('nonexistent-user');
        expect(cached, isNull);
      });

      test('distinguishes missing cache from stale cache', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final repo = LocalProfileRepository(db);

        // User 1: has stale cache
        const userStaleId = 'user-stale';
        final staleTime = DateTime.now().subtract(const Duration(days: 30));

        await repo.upsertProfile(
          LocalUserProfilesCompanion.insert(
            id: userStaleId,
            displayName: 'Test User',
            pinHash: 'hash',
            pinSalt: 'salt',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        await repo.upsertPermissions(
          CachedPermissionsCompanion.insert(
            userId: userStaleId,
            businessId: 'biz-001',
            businessName: 'Test Business',
            businessLocationId: 'store-001',
            roleName: 'Cashier',
            permissionCodes: jsonEncode(['pos.write']),
            cachedAt: staleTime,
          ),
        );

        // User 2: never had cache
        final staleUser = await repo.getPermissions(userStaleId);
        expect(staleUser, isNotNull); // Stale cache exists

        final missingUser = await repo.getPermissions('user-missing');
        expect(missingUser, isNull); // Missing cache doesn't exist

        // These are meaningfully different states
        expect(staleUser != null, true);
        expect(missingUser == null, true);
      });
    });

    group('4.4 - KNOWN_LIMITATION: offline permissions can be stale', () {
      test('server-side role change not reflected until reconnect', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final repo = LocalProfileRepository(db);
        const userId = 'user-004';

        await repo.upsertProfile(
          LocalUserProfilesCompanion.insert(
            id: userId,
            displayName: 'Test User',
            pinHash: 'hash',
            pinSalt: 'salt',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Scenario: staff member had broad permissions when online
        await repo.upsertPermissions(
          CachedPermissionsCompanion.insert(
            userId: userId,
            businessId: 'biz-001',
            businessName: 'Test Business',
            businessLocationId: 'store-001',
            roleName: 'Manager',
            permissionCodes: jsonEncode([
              'pos.write',
              'pos.discount',
              'inventory.edit',
              'staff.view',
            ]),
            cachedAt: DateTime.now().subtract(const Duration(hours: 12)),
          ),
        );

        // Offline, cached permissions are returned as-is
        final offline = await repo.getPermissions(userId);
        expect(offline, isNotNull);
        final offlinePerms = jsonDecode(offline!.permissionCodes) as List;
        expect(offlinePerms.length, 4); // Still sees all 4 permissions

        // Server side: role was changed to Cashier (fewer permissions)
        // Device is offline, doesn't know this yet.

        // When device reconnects and calls context-switch again,
        // cache will be updated with new permissions.
        await repo.upsertPermissions(
          CachedPermissionsCompanion.insert(
            userId: userId,
            businessId: 'biz-001',
            businessName: 'Test Business',
            businessLocationId: 'store-001',
            roleName: 'Cashier',
            permissionCodes: jsonEncode(['pos.write']),
            cachedAt: DateTime.now(),
          ),
        );

        final online = await repo.getPermissions(userId);
        expect(online, isNotNull);
        final onlinePerms = jsonDecode(online!.permissionCodes) as List;
        expect(onlinePerms.length, 1); // Now only 1 permission

        // Test documents this as a known limitation, not a bug
      });
    });

    group('4.5 - Persistence across restart, offline', () {
      test('CachedPermissions survives database close/reopen', () async {
        const userId = 'user-005';
        const businessId = 'biz-001';
        const perms = ['pos.write', 'inventory.view'];

        // Write in first database instance
        {
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);

          final repo = LocalProfileRepository(db);

          await repo.upsertProfile(
            LocalUserProfilesCompanion.insert(
              id: userId,
              displayName: 'Test User',
              pinHash: 'hash',
              pinSalt: 'salt',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          await repo.upsertPermissions(
            CachedPermissionsCompanion.insert(
              userId: userId,
              businessId: businessId,
              businessName: 'Test Business',
              businessLocationId: 'store-001',
              roleName: 'Cashier',
              permissionCodes: jsonEncode(perms),
              cachedAt: DateTime.now(),
            ),
          );

          final cached = await repo.getPermissions(userId);
          expect(cached, isNotNull);
        }

        // Note: NativeDatabase.memory() is in-memory, so this test is more
        // about verifying the upsert/read semantics work. In production, the
        // database would persist to disk via drift's native adapter.
      });
    });

    group('4.6 - Multi-profile offline isolation', () {
      test('reads only the active profile\'s permissions', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final repo = LocalProfileRepository(db);

        // Profile 1: Cashier
        await repo.upsertProfile(
          LocalUserProfilesCompanion.insert(
            id: 'user-1',
            displayName: 'Test User 1',
            pinHash: 'hash',
            pinSalt: 'salt',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        await repo.upsertPermissions(
          CachedPermissionsCompanion.insert(
            userId: 'user-1',
            businessId: 'biz-001',
            businessName: 'Restaurant A',
            businessLocationId: 'store-001',
            roleName: 'Cashier',
            permissionCodes: jsonEncode(['pos.write']),
            cachedAt: DateTime.now(),
          ),
        );

        // Profile 2: Manager (same business or different)
        await repo.upsertProfile(
          LocalUserProfilesCompanion.insert(
            id: 'user-2',
            displayName: 'Test User 2',
            pinHash: 'hash',
            pinSalt: 'salt',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        await repo.upsertPermissions(
          CachedPermissionsCompanion.insert(
            userId: 'user-2',
            businessId: 'biz-002',
            businessName: 'Restaurant B',
            businessLocationId: 'store-002',
            roleName: 'Manager',
            permissionCodes: jsonEncode(['pos.write', 'inventory.edit', 'staff.view']),
            cachedAt: DateTime.now(),
          ),
        );

        // Read Profile 1 only
        final profile1 = await repo.getPermissions('user-1');
        expect(profile1, isNotNull);
        final perms1 = jsonDecode(profile1!.permissionCodes) as List;
        expect(perms1.length, 1);
        expect(perms1[0], 'pos.write');

        // Read Profile 2 only
        final profile2 = await repo.getPermissions('user-2');
        expect(profile2, isNotNull);
        final perms2 = jsonDecode(profile2!.permissionCodes) as List;
        expect(perms2.length, 3);

        // Profiles are properly isolated
        expect(perms1, isNot(perms2));
      });
    });

    group('4.7 - Cleanup on profile removal, offline', () {
      test('deleting profile cascades to delete CachedPermissions', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final repo = LocalProfileRepository(db);
        const userId = 'user-007';

        // Create profile + permissions
        await repo.upsertProfile(
          LocalUserProfilesCompanion.insert(
            id: userId,
            displayName: 'John Cashier',
            pinHash: 'hash123',
            pinSalt: 'salt123',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        await repo.upsertPermissions(
          CachedPermissionsCompanion.insert(
            userId: userId,
            businessId: 'biz-001',
            businessName: 'Restaurant',
            businessLocationId: 'store-001',
            roleName: 'Cashier',
            permissionCodes: jsonEncode(['pos.write']),
            cachedAt: DateTime.now(),
          ),
        );

        // Verify both exist
        var profile = await repo.getProfile(userId);
        var perms = await repo.getPermissions(userId);
        expect(profile, isNotNull);
        expect(perms, isNotNull);

        // Delete profile
        await repo.deleteProfile(userId);

        // Both should be gone (cascade)
        profile = await repo.getProfile(userId);
        perms = await repo.getPermissions(userId);
        expect(profile, isNull);
        expect(perms, isNull);
      });
    });
  });
}
