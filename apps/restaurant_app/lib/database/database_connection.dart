/// Database connection setup with at-rest SQLCipher encryption.
///
/// `driftDatabaseConnection` creates a `LazyDatabase` that:
/// 1. Opens (or creates) `app.db` in the app's private data directory.
/// 2. Applies `PRAGMA key` to enable SQLCipher encryption.
/// 3. Returns a `NativeDatabase` via `drift_flutter` on all native platforms.
///
/// ## Storage location
///
/// The database is application state, not a user document, so on desktop it is
/// kept out of the user's Documents folder:
///
/// - **Windows**: `%APPDATA%\Oryon Foods\Oryon\app.db`
/// - **Linux**: `$XDG_DATA_HOME/oryon` (usually `~/.local/share/oryon`)
/// - **macOS**: `~/Library/Application Support/...`
///
/// These come from `getApplicationSupportDirectory()`; `AppData` is hidden from
/// normal Explorer browsing and is per-user. The Windows uninstaller removes
/// this directory (see `windows/installer/oryon.iss`), so uninstalling also
/// deletes the encrypted database and its `-wal`/`-shm` companions.
///
/// Android and iOS keep using `getApplicationDocumentsDirectory()`, which is
/// already private app storage inside the app sandbox and is removed with the
/// app.
///
/// ## Legacy locations
///
/// Earlier desktop builds wrote `app.db` into the user's Documents folder. On
/// first launch after upgrading, [`_migrateFromDocuments`] moves that file (and
/// any WAL/SHM companions) next to the new location so unsynced rows survive
/// and no database is left behind in Documents.
///
/// The `key` parameter is the 64-character hex-encoded encryption key (32 bytes,
/// generated once by `EncryptionKeyService` on first launch). The same key must
/// be used to reopen an existing encrypted database.
library;

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

const _databaseFileName = 'app.db';

/// SQLite writes the database plus up to two sidecar files next to it.
const _databaseSuffixes = ['', '-wal', '-shm'];

/// Creates a Drift database connection with SQLCipher encryption.
///
/// The database file (`app.db`) is stored in the app's private data directory.
/// SQLCipher encryption is configured via `PRAGMA key` with the provided key.
/// Foreign key constraints are enforced at all times.
LazyDatabase driftDatabaseConnection(String encryptionKey) =>
    LazyDatabase(() async {
      final dir = await _dataDirectory();
      final file = File(p.join(dir.path, _databaseFileName));
      if (!await file.exists()) {
        await _migrateFromDocuments(dir);
      }
      return NativeDatabase.createInBackground(
        file,
        setup: (rawDb) {
          // At-rest SQLCipher encryption (sqlite3mc build): the same key
          // must open the file on every launch. NOTE: devices/CI with a
          // pre-existing PLAINTEXT app.db (created while this was disabled)
          // will fail to open ("file is not a database") — reset local data
          // once (delete app.db); unsynced rows are re-pulled on next sync.
          rawDb.execute("PRAGMA key = '$encryptionKey';");
          // Enforce foreign key constraints.
          rawDb.execute('PRAGMA foreign_keys = ON');
        },
      );
    });

/// The directory that owns the database file.
///
/// Desktop platforms use the application support directory so the file never
/// appears among the user's documents; mobile platforms use their (already
/// private) documents directory.
Future<Directory> _dataDirectory() async {
  final Directory dir;
  if (Platform.isAndroid || Platform.isIOS) {
    dir = await getApplicationDocumentsDirectory();
  } else {
    dir = await getApplicationSupportDirectory();
  }
  await dir.create(recursive: true);
  return dir;
}

/// Moves a database left in the old Documents location by a previous desktop
/// build into [target], the current private data directory.
///
/// This runs only when the new location has no database yet, so it can never
/// overwrite live state. Any failure is non-fatal: the app then starts with a
/// fresh database rather than refusing to launch.
Future<void> _migrateFromDocuments(Directory target) async {
  // Mobile databases have always lived in the sandbox documents directory.
  if (Platform.isAndroid || Platform.isIOS) return;

  final Directory legacyDir;
  try {
    legacyDir = await getApplicationDocumentsDirectory();
  } on Object catch (error) {
    debugPrint('Database: no legacy Documents directory ($error)');
    return;
  }
  if (legacyDir.path == target.path) return;

  for (final suffix in _databaseSuffixes) {
    final legacy = File(p.join(legacyDir.path, '$_databaseFileName$suffix'));
    if (!await legacy.exists()) continue;

    final destination = File(p.join(target.path, '$_databaseFileName$suffix'));
    if (await destination.exists()) continue;

    try {
      await legacy.rename(destination.path);
    } on FileSystemException {
      // Different volume (or a locked file): copy, then remove the original so
      // the database does not stay visible in Documents.
      await legacy.copy(destination.path);
      await legacy.delete();
    }
    debugPrint('Database: moved ${legacy.path} -> ${destination.path}');
  }
}
