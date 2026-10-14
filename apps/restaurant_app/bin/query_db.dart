/// Debug utility to query the encrypted app.db database.
///
/// Usage: dart run bin/query_db.dart
///
/// This script connects to the local encrypted SQLite database and queries
/// staff profiles to verify role data is being cached correctly.
library;

import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

Future<void> main() async {
  print('🔍 Querying app.db for staff profiles and roles...\n');

  try {
    // Get the database path
    final dbPath = '${Platform.environment['HOME']}/Documents/app.db';
    print('📁 Database path: $dbPath\n');

    // Check if file exists
    if (!File(dbPath).existsSync()) {
      print('❌ Database file not found at $dbPath');
      exit(1);
    }

    // Open the database
    final sqlite = sqlite3.open(dbPath);

    print('✅ Database opened successfully\n');

    // Try to query without encryption key first
    try {
      // Get the schema
      final schemaQuery = sqlite.prepare('''
        SELECT name FROM sqlite_master
        WHERE type='table'
        ORDER BY name
      ''');

      final tables = schemaQuery.select();

      print('📋 Database Tables:');
      print('─' * 80);
      for (final row in tables) {
        print('  • ${row['name']}');
      }
      print('');

      // Query staff profiles
      print('\n📋 Staff Profiles (local_user_profiles):');
      print('─' * 80);

      final profileQuery = sqlite.prepare('''
        SELECT id, displayName, roleLabel, createdAt, lastSignedInAt
        FROM local_user_profiles
        ORDER BY createdAt DESC
      ''');

      final profileResults = profileQuery.select();

      if (profileResults.isEmpty) {
        print('❌ No staff profiles found in database!');
      } else {
        for (final row in profileResults) {
          final id = row['id'] as String;
          final name = row['displayName'] as String;
          final role = row['roleLabel'] as String?;
          final created = row['createdAt'] as String;
          final lastLogin = row['lastSignedInAt'] as String?;

          print('\n👤 Profile: $name (ID: $id)');
          print('   Role Label: ${role ?? '❌ NULL - ROLE NOT SAVED!'}');
          print('   Created: $created');
          print('   Last Sign-in: ${lastLogin ?? 'Never'}');
        }
      }

      // Query cached permissions
      print('\n\n🔐 Cached Permissions (cached_permissions):');
      print('─' * 80);

      final permQuery = sqlite.prepare('''
        SELECT userId, permissionCodes, isStale, cachedAt
        FROM cached_permissions
        ORDER BY cachedAt DESC
      ''');

      final permResults = permQuery.select();

      if (permResults.isEmpty) {
        print('❌ No cached permissions found!');
      } else {
        for (final row in permResults) {
          final userId = row['userId'] as String;
          final perms = row['permissionCodes'] as String?;
          final isStale = row['isStale'] as int;
          final cachedAt = row['cachedAt'] as String;

          print('\n👤 User: $userId');
          print('   Permissions: ${perms ?? '❌ NULL'}');
          print('   Stale: ${isStale == 1 ? '⚠️ Yes' : '✅ No'}');
          print('   Cached: $cachedAt');
        }
      }

      // Query cached roles
      print('\n\n🎯 Cached Business Roles (cached_business_roles):');
      print('─' * 80);

      final rolesQuery = sqlite.prepare('''
        SELECT businessId, roleId, name, permissionCodes, cachedAt
        FROM cached_business_roles
        ORDER BY cachedAt DESC
        LIMIT 10
      ''');

      final rolesResults = rolesQuery.select();

      if (rolesResults.isEmpty) {
        print('❌ No cached roles found!');
      } else {
        for (final row in rolesResults) {
          final businessId = row['businessId'] as String;
          final roleId = row['roleId'] as String;
          final name = row['name'] as String;
          final perms = row['permissionCodes'] as String?;
          final cached = row['cachedAt'] as String;

          print('\n🏢 Business: $businessId');
          print('   Role: $name (ID: $roleId)');
          print('   Permissions: ${perms ?? 'None'}');
          print('   Cached: $cached');
        }
      }

      print('\n${'─' * 80}');
      print('\n✅ Database query complete!\n');
    } catch (e) {
      print('⚠️ Database appears to be encrypted. Error: $e\n');
      print('The database is encrypted with SQLCipher.');
      print('The encryption key is stored in secure storage on the device.\n');
      print('To query the database, you need to either:');
      print('1. Get the encryption key from flutter_secure_storage');
      print('2. Use sqlcipher with the PRAGMA key command');
      print('3. Run the query_db.dart script from within the Flutter app context\n');
    }

    sqlite.close();
  } catch (e, st) {
    print('❌ Error:');
    print('$e');
    print(st);
    exit(1);
  }
}
