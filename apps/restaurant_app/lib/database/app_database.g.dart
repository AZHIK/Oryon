// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalUserProfilesTable extends LocalUserProfiles
    with TableInfo<$LocalUserProfilesTable, LocalUserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalUserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinHashMeta = const VerificationMeta(
    'pinHash',
  );
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
    'pin_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinSaltMeta = const VerificationMeta(
    'pinSalt',
  );
  @override
  late final GeneratedColumn<String> pinSalt = GeneratedColumn<String>(
    'pin_salt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleLabelMeta = const VerificationMeta(
    'roleLabel',
  );
  @override
  late final GeneratedColumn<String> roleLabel = GeneratedColumn<String>(
    'role_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSignedInAtMeta = const VerificationMeta(
    'lastSignedInAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSignedInAt =
      GeneratedColumn<DateTime>(
        'last_signed_in_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _failedPinAttemptsMeta = const VerificationMeta(
    'failedPinAttempts',
  );
  @override
  late final GeneratedColumn<int> failedPinAttempts = GeneratedColumn<int>(
    'failed_pin_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lockedUntilMeta = const VerificationMeta(
    'lockedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> lockedUntil = GeneratedColumn<DateTime>(
    'locked_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastRevocationCheckAtMeta =
      const VerificationMeta('lastRevocationCheckAt');
  @override
  late final GeneratedColumn<DateTime> lastRevocationCheckAt =
      GeneratedColumn<DateTime>(
        'last_revocation_check_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isDeactivatedMeta = const VerificationMeta(
    'isDeactivated',
  );
  @override
  late final GeneratedColumn<bool> isDeactivated = GeneratedColumn<bool>(
    'is_deactivated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deactivated" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    pinHash,
    pinSalt,
    roleLabel,
    lastSignedInAt,
    failedPinAttempts,
    lockedUntil,
    createdAt,
    updatedAt,
    lastRevocationCheckAt,
    isDeactivated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalUserProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('pin_hash')) {
      context.handle(
        _pinHashMeta,
        pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta),
      );
    } else if (isInserting) {
      context.missing(_pinHashMeta);
    }
    if (data.containsKey('pin_salt')) {
      context.handle(
        _pinSaltMeta,
        pinSalt.isAcceptableOrUnknown(data['pin_salt']!, _pinSaltMeta),
      );
    } else if (isInserting) {
      context.missing(_pinSaltMeta);
    }
    if (data.containsKey('role_label')) {
      context.handle(
        _roleLabelMeta,
        roleLabel.isAcceptableOrUnknown(data['role_label']!, _roleLabelMeta),
      );
    }
    if (data.containsKey('last_signed_in_at')) {
      context.handle(
        _lastSignedInAtMeta,
        lastSignedInAt.isAcceptableOrUnknown(
          data['last_signed_in_at']!,
          _lastSignedInAtMeta,
        ),
      );
    }
    if (data.containsKey('failed_pin_attempts')) {
      context.handle(
        _failedPinAttemptsMeta,
        failedPinAttempts.isAcceptableOrUnknown(
          data['failed_pin_attempts']!,
          _failedPinAttemptsMeta,
        ),
      );
    }
    if (data.containsKey('locked_until')) {
      context.handle(
        _lockedUntilMeta,
        lockedUntil.isAcceptableOrUnknown(
          data['locked_until']!,
          _lockedUntilMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_revocation_check_at')) {
      context.handle(
        _lastRevocationCheckAtMeta,
        lastRevocationCheckAt.isAcceptableOrUnknown(
          data['last_revocation_check_at']!,
          _lastRevocationCheckAtMeta,
        ),
      );
    }
    if (data.containsKey('is_deactivated')) {
      context.handle(
        _isDeactivatedMeta,
        isDeactivated.isAcceptableOrUnknown(
          data['is_deactivated']!,
          _isDeactivatedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalUserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalUserProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      pinHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_hash'],
      )!,
      pinSalt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_salt'],
      )!,
      roleLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_label'],
      ),
      lastSignedInAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_signed_in_at'],
      ),
      failedPinAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed_pin_attempts'],
      )!,
      lockedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}locked_until'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastRevocationCheckAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_revocation_check_at'],
      ),
      isDeactivated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deactivated'],
      )!,
    );
  }

  @override
  $LocalUserProfilesTable createAlias(String alias) {
    return $LocalUserProfilesTable(attachedDatabase, alias);
  }
}

class LocalUserProfile extends DataClass
    implements Insertable<LocalUserProfile> {
  /// Staff member's UUID from Identity Service (primary key).
  final String id;

  /// Display name, cached for the Profile Picker.
  final String displayName;

  /// Salted hash of the PIN (HMAC-SHA256).
  final String pinHash;

  /// Per-profile random salt for PIN hashing.
  final String pinSalt;

  /// Cached display-only role name.
  final String? roleLabel;

  /// Last successful sign-in timestamp.
  final DateTime? lastSignedInAt;

  /// Consecutive failed PIN attempts (persisted so lockout survives restart).
  final int failedPinAttempts;

  /// When the current lockout ends, or null when not locked out.
  final DateTime? lockedUntil;

  /// Row creation timestamp.
  final DateTime createdAt;

  /// Row last-updated timestamp.
  final DateTime updatedAt;

  /// When this profile's server-side role/existence was last confirmed via
  /// a revocation check (active-profile-only on reconnect, all-profiles on
  /// Profile Picker open). Null means never checked since local creation.
  final DateTime? lastRevocationCheckAt;

  /// Whether this profile was deactivated by logout. A deactivated row keeps
  /// its PIN hash, role label and cached permissions — so a re-login
  /// reactivates instantly — but is hidden from the Profile Picker, PIN
  /// unlock and every saved-profile list until then. Distinct from row
  /// deletion (`forgetProfile`), which is forgetting the device entirely.
  final bool isDeactivated;
  const LocalUserProfile({
    required this.id,
    required this.displayName,
    required this.pinHash,
    required this.pinSalt,
    this.roleLabel,
    this.lastSignedInAt,
    required this.failedPinAttempts,
    this.lockedUntil,
    required this.createdAt,
    required this.updatedAt,
    this.lastRevocationCheckAt,
    required this.isDeactivated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['pin_hash'] = Variable<String>(pinHash);
    map['pin_salt'] = Variable<String>(pinSalt);
    if (!nullToAbsent || roleLabel != null) {
      map['role_label'] = Variable<String>(roleLabel);
    }
    if (!nullToAbsent || lastSignedInAt != null) {
      map['last_signed_in_at'] = Variable<DateTime>(lastSignedInAt);
    }
    map['failed_pin_attempts'] = Variable<int>(failedPinAttempts);
    if (!nullToAbsent || lockedUntil != null) {
      map['locked_until'] = Variable<DateTime>(lockedUntil);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastRevocationCheckAt != null) {
      map['last_revocation_check_at'] = Variable<DateTime>(
        lastRevocationCheckAt,
      );
    }
    map['is_deactivated'] = Variable<bool>(isDeactivated);
    return map;
  }

  LocalUserProfilesCompanion toCompanion(bool nullToAbsent) {
    return LocalUserProfilesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      pinHash: Value(pinHash),
      pinSalt: Value(pinSalt),
      roleLabel: roleLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(roleLabel),
      lastSignedInAt: lastSignedInAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSignedInAt),
      failedPinAttempts: Value(failedPinAttempts),
      lockedUntil: lockedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(lockedUntil),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastRevocationCheckAt: lastRevocationCheckAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRevocationCheckAt),
      isDeactivated: Value(isDeactivated),
    );
  }

  factory LocalUserProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalUserProfile(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      pinHash: serializer.fromJson<String>(json['pinHash']),
      pinSalt: serializer.fromJson<String>(json['pinSalt']),
      roleLabel: serializer.fromJson<String?>(json['roleLabel']),
      lastSignedInAt: serializer.fromJson<DateTime?>(json['lastSignedInAt']),
      failedPinAttempts: serializer.fromJson<int>(json['failedPinAttempts']),
      lockedUntil: serializer.fromJson<DateTime?>(json['lockedUntil']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastRevocationCheckAt: serializer.fromJson<DateTime?>(
        json['lastRevocationCheckAt'],
      ),
      isDeactivated: serializer.fromJson<bool>(json['isDeactivated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'pinHash': serializer.toJson<String>(pinHash),
      'pinSalt': serializer.toJson<String>(pinSalt),
      'roleLabel': serializer.toJson<String?>(roleLabel),
      'lastSignedInAt': serializer.toJson<DateTime?>(lastSignedInAt),
      'failedPinAttempts': serializer.toJson<int>(failedPinAttempts),
      'lockedUntil': serializer.toJson<DateTime?>(lockedUntil),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastRevocationCheckAt': serializer.toJson<DateTime?>(
        lastRevocationCheckAt,
      ),
      'isDeactivated': serializer.toJson<bool>(isDeactivated),
    };
  }

  LocalUserProfile copyWith({
    String? id,
    String? displayName,
    String? pinHash,
    String? pinSalt,
    Value<String?> roleLabel = const Value.absent(),
    Value<DateTime?> lastSignedInAt = const Value.absent(),
    int? failedPinAttempts,
    Value<DateTime?> lockedUntil = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> lastRevocationCheckAt = const Value.absent(),
    bool? isDeactivated,
  }) => LocalUserProfile(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    pinHash: pinHash ?? this.pinHash,
    pinSalt: pinSalt ?? this.pinSalt,
    roleLabel: roleLabel.present ? roleLabel.value : this.roleLabel,
    lastSignedInAt: lastSignedInAt.present
        ? lastSignedInAt.value
        : this.lastSignedInAt,
    failedPinAttempts: failedPinAttempts ?? this.failedPinAttempts,
    lockedUntil: lockedUntil.present ? lockedUntil.value : this.lockedUntil,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastRevocationCheckAt: lastRevocationCheckAt.present
        ? lastRevocationCheckAt.value
        : this.lastRevocationCheckAt,
    isDeactivated: isDeactivated ?? this.isDeactivated,
  );
  LocalUserProfile copyWithCompanion(LocalUserProfilesCompanion data) {
    return LocalUserProfile(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      pinSalt: data.pinSalt.present ? data.pinSalt.value : this.pinSalt,
      roleLabel: data.roleLabel.present ? data.roleLabel.value : this.roleLabel,
      lastSignedInAt: data.lastSignedInAt.present
          ? data.lastSignedInAt.value
          : this.lastSignedInAt,
      failedPinAttempts: data.failedPinAttempts.present
          ? data.failedPinAttempts.value
          : this.failedPinAttempts,
      lockedUntil: data.lockedUntil.present
          ? data.lockedUntil.value
          : this.lockedUntil,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastRevocationCheckAt: data.lastRevocationCheckAt.present
          ? data.lastRevocationCheckAt.value
          : this.lastRevocationCheckAt,
      isDeactivated: data.isDeactivated.present
          ? data.isDeactivated.value
          : this.isDeactivated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalUserProfile(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('pinHash: $pinHash, ')
          ..write('pinSalt: $pinSalt, ')
          ..write('roleLabel: $roleLabel, ')
          ..write('lastSignedInAt: $lastSignedInAt, ')
          ..write('failedPinAttempts: $failedPinAttempts, ')
          ..write('lockedUntil: $lockedUntil, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastRevocationCheckAt: $lastRevocationCheckAt, ')
          ..write('isDeactivated: $isDeactivated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    pinHash,
    pinSalt,
    roleLabel,
    lastSignedInAt,
    failedPinAttempts,
    lockedUntil,
    createdAt,
    updatedAt,
    lastRevocationCheckAt,
    isDeactivated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalUserProfile &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.pinHash == this.pinHash &&
          other.pinSalt == this.pinSalt &&
          other.roleLabel == this.roleLabel &&
          other.lastSignedInAt == this.lastSignedInAt &&
          other.failedPinAttempts == this.failedPinAttempts &&
          other.lockedUntil == this.lockedUntil &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastRevocationCheckAt == this.lastRevocationCheckAt &&
          other.isDeactivated == this.isDeactivated);
}

class LocalUserProfilesCompanion extends UpdateCompanion<LocalUserProfile> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> pinHash;
  final Value<String> pinSalt;
  final Value<String?> roleLabel;
  final Value<DateTime?> lastSignedInAt;
  final Value<int> failedPinAttempts;
  final Value<DateTime?> lockedUntil;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastRevocationCheckAt;
  final Value<bool> isDeactivated;
  final Value<int> rowid;
  const LocalUserProfilesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.pinSalt = const Value.absent(),
    this.roleLabel = const Value.absent(),
    this.lastSignedInAt = const Value.absent(),
    this.failedPinAttempts = const Value.absent(),
    this.lockedUntil = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastRevocationCheckAt = const Value.absent(),
    this.isDeactivated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalUserProfilesCompanion.insert({
    required String id,
    required String displayName,
    required String pinHash,
    required String pinSalt,
    this.roleLabel = const Value.absent(),
    this.lastSignedInAt = const Value.absent(),
    this.failedPinAttempts = const Value.absent(),
    this.lockedUntil = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastRevocationCheckAt = const Value.absent(),
    this.isDeactivated = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       pinHash = Value(pinHash),
       pinSalt = Value(pinSalt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalUserProfile> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? pinHash,
    Expression<String>? pinSalt,
    Expression<String>? roleLabel,
    Expression<DateTime>? lastSignedInAt,
    Expression<int>? failedPinAttempts,
    Expression<DateTime>? lockedUntil,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastRevocationCheckAt,
    Expression<bool>? isDeactivated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (pinHash != null) 'pin_hash': pinHash,
      if (pinSalt != null) 'pin_salt': pinSalt,
      if (roleLabel != null) 'role_label': roleLabel,
      if (lastSignedInAt != null) 'last_signed_in_at': lastSignedInAt,
      if (failedPinAttempts != null) 'failed_pin_attempts': failedPinAttempts,
      if (lockedUntil != null) 'locked_until': lockedUntil,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastRevocationCheckAt != null)
        'last_revocation_check_at': lastRevocationCheckAt,
      if (isDeactivated != null) 'is_deactivated': isDeactivated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalUserProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String>? pinHash,
    Value<String>? pinSalt,
    Value<String?>? roleLabel,
    Value<DateTime?>? lastSignedInAt,
    Value<int>? failedPinAttempts,
    Value<DateTime?>? lockedUntil,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? lastRevocationCheckAt,
    Value<bool>? isDeactivated,
    Value<int>? rowid,
  }) {
    return LocalUserProfilesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
      roleLabel: roleLabel ?? this.roleLabel,
      lastSignedInAt: lastSignedInAt ?? this.lastSignedInAt,
      failedPinAttempts: failedPinAttempts ?? this.failedPinAttempts,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRevocationCheckAt:
          lastRevocationCheckAt ?? this.lastRevocationCheckAt,
      isDeactivated: isDeactivated ?? this.isDeactivated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (pinSalt.present) {
      map['pin_salt'] = Variable<String>(pinSalt.value);
    }
    if (roleLabel.present) {
      map['role_label'] = Variable<String>(roleLabel.value);
    }
    if (lastSignedInAt.present) {
      map['last_signed_in_at'] = Variable<DateTime>(lastSignedInAt.value);
    }
    if (failedPinAttempts.present) {
      map['failed_pin_attempts'] = Variable<int>(failedPinAttempts.value);
    }
    if (lockedUntil.present) {
      map['locked_until'] = Variable<DateTime>(lockedUntil.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastRevocationCheckAt.present) {
      map['last_revocation_check_at'] = Variable<DateTime>(
        lastRevocationCheckAt.value,
      );
    }
    if (isDeactivated.present) {
      map['is_deactivated'] = Variable<bool>(isDeactivated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalUserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('pinHash: $pinHash, ')
          ..write('pinSalt: $pinSalt, ')
          ..write('roleLabel: $roleLabel, ')
          ..write('lastSignedInAt: $lastSignedInAt, ')
          ..write('failedPinAttempts: $failedPinAttempts, ')
          ..write('lockedUntil: $lockedUntil, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastRevocationCheckAt: $lastRevocationCheckAt, ')
          ..write('isDeactivated: $isDeactivated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeviceConfigTable extends DeviceConfig
    with TableInfo<$DeviceConfigTable, DeviceConfigData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceConfigTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => 0,
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessLocationIdMeta =
      const VerificationMeta('businessLocationId');
  @override
  late final GeneratedColumn<String> businessLocationId =
      GeneratedColumn<String>(
        'business_location_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _businessNameMeta = const VerificationMeta(
    'businessName',
  );
  @override
  late final GeneratedColumn<String> businessName = GeneratedColumn<String>(
    'business_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceLabelMeta = const VerificationMeta(
    'deviceLabel',
  );
  @override
  late final GeneratedColumn<String> deviceLabel = GeneratedColumn<String>(
    'device_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _provisionedAtMeta = const VerificationMeta(
    'provisionedAt',
  );
  @override
  late final GeneratedColumn<DateTime> provisionedAt =
      GeneratedColumn<DateTime>(
        'provisioned_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    businessLocationId,
    businessName,
    deviceLabel,
    provisionedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_config';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceConfigData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('business_location_id')) {
      context.handle(
        _businessLocationIdMeta,
        businessLocationId.isAcceptableOrUnknown(
          data['business_location_id']!,
          _businessLocationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_businessLocationIdMeta);
    }
    if (data.containsKey('business_name')) {
      context.handle(
        _businessNameMeta,
        businessName.isAcceptableOrUnknown(
          data['business_name']!,
          _businessNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_businessNameMeta);
    }
    if (data.containsKey('device_label')) {
      context.handle(
        _deviceLabelMeta,
        deviceLabel.isAcceptableOrUnknown(
          data['device_label']!,
          _deviceLabelMeta,
        ),
      );
    }
    if (data.containsKey('provisioned_at')) {
      context.handle(
        _provisionedAtMeta,
        provisionedAt.isAcceptableOrUnknown(
          data['provisioned_at']!,
          _provisionedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_provisionedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeviceConfigData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceConfigData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      businessLocationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_location_id'],
      )!,
      businessName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_name'],
      )!,
      deviceLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_label'],
      ),
      provisionedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}provisioned_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DeviceConfigTable createAlias(String alias) {
    return $DeviceConfigTable(attachedDatabase, alias);
  }
}

class DeviceConfigData extends DataClass
    implements Insertable<DeviceConfigData> {
  /// Singleton key (always 0).
  final int id;

  /// Business UUID this device is locked to.
  final String businessId;

  /// Business location UUID this device is locked to.
  final String businessLocationId;

  /// Cached business name for offline use (receipts, headers).
  final String businessName;

  /// Optional device label (e.g., "Front counter").
  final String? deviceLabel;

  /// When this device was provisioned.
  final DateTime provisionedAt;

  /// Last provisioning update timestamp.
  final DateTime updatedAt;
  const DeviceConfigData({
    required this.id,
    required this.businessId,
    required this.businessLocationId,
    required this.businessName,
    this.deviceLabel,
    required this.provisionedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['business_id'] = Variable<String>(businessId);
    map['business_location_id'] = Variable<String>(businessLocationId);
    map['business_name'] = Variable<String>(businessName);
    if (!nullToAbsent || deviceLabel != null) {
      map['device_label'] = Variable<String>(deviceLabel);
    }
    map['provisioned_at'] = Variable<DateTime>(provisionedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DeviceConfigCompanion toCompanion(bool nullToAbsent) {
    return DeviceConfigCompanion(
      id: Value(id),
      businessId: Value(businessId),
      businessLocationId: Value(businessLocationId),
      businessName: Value(businessName),
      deviceLabel: deviceLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceLabel),
      provisionedAt: Value(provisionedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DeviceConfigData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceConfigData(
      id: serializer.fromJson<int>(json['id']),
      businessId: serializer.fromJson<String>(json['businessId']),
      businessLocationId: serializer.fromJson<String>(
        json['businessLocationId'],
      ),
      businessName: serializer.fromJson<String>(json['businessName']),
      deviceLabel: serializer.fromJson<String?>(json['deviceLabel']),
      provisionedAt: serializer.fromJson<DateTime>(json['provisionedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'businessId': serializer.toJson<String>(businessId),
      'businessLocationId': serializer.toJson<String>(businessLocationId),
      'businessName': serializer.toJson<String>(businessName),
      'deviceLabel': serializer.toJson<String?>(deviceLabel),
      'provisionedAt': serializer.toJson<DateTime>(provisionedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DeviceConfigData copyWith({
    int? id,
    String? businessId,
    String? businessLocationId,
    String? businessName,
    Value<String?> deviceLabel = const Value.absent(),
    DateTime? provisionedAt,
    DateTime? updatedAt,
  }) => DeviceConfigData(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    businessLocationId: businessLocationId ?? this.businessLocationId,
    businessName: businessName ?? this.businessName,
    deviceLabel: deviceLabel.present ? deviceLabel.value : this.deviceLabel,
    provisionedAt: provisionedAt ?? this.provisionedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DeviceConfigData copyWithCompanion(DeviceConfigCompanion data) {
    return DeviceConfigData(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      businessLocationId: data.businessLocationId.present
          ? data.businessLocationId.value
          : this.businessLocationId,
      businessName: data.businessName.present
          ? data.businessName.value
          : this.businessName,
      deviceLabel: data.deviceLabel.present
          ? data.deviceLabel.value
          : this.deviceLabel,
      provisionedAt: data.provisionedAt.present
          ? data.provisionedAt.value
          : this.provisionedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceConfigData(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('businessLocationId: $businessLocationId, ')
          ..write('businessName: $businessName, ')
          ..write('deviceLabel: $deviceLabel, ')
          ..write('provisionedAt: $provisionedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    businessLocationId,
    businessName,
    deviceLabel,
    provisionedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceConfigData &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.businessLocationId == this.businessLocationId &&
          other.businessName == this.businessName &&
          other.deviceLabel == this.deviceLabel &&
          other.provisionedAt == this.provisionedAt &&
          other.updatedAt == this.updatedAt);
}

class DeviceConfigCompanion extends UpdateCompanion<DeviceConfigData> {
  final Value<int> id;
  final Value<String> businessId;
  final Value<String> businessLocationId;
  final Value<String> businessName;
  final Value<String?> deviceLabel;
  final Value<DateTime> provisionedAt;
  final Value<DateTime> updatedAt;
  const DeviceConfigCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.businessLocationId = const Value.absent(),
    this.businessName = const Value.absent(),
    this.deviceLabel = const Value.absent(),
    this.provisionedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DeviceConfigCompanion.insert({
    this.id = const Value.absent(),
    required String businessId,
    required String businessLocationId,
    required String businessName,
    this.deviceLabel = const Value.absent(),
    required DateTime provisionedAt,
    required DateTime updatedAt,
  }) : businessId = Value(businessId),
       businessLocationId = Value(businessLocationId),
       businessName = Value(businessName),
       provisionedAt = Value(provisionedAt),
       updatedAt = Value(updatedAt);
  static Insertable<DeviceConfigData> custom({
    Expression<int>? id,
    Expression<String>? businessId,
    Expression<String>? businessLocationId,
    Expression<String>? businessName,
    Expression<String>? deviceLabel,
    Expression<DateTime>? provisionedAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (businessLocationId != null)
        'business_location_id': businessLocationId,
      if (businessName != null) 'business_name': businessName,
      if (deviceLabel != null) 'device_label': deviceLabel,
      if (provisionedAt != null) 'provisioned_at': provisionedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DeviceConfigCompanion copyWith({
    Value<int>? id,
    Value<String>? businessId,
    Value<String>? businessLocationId,
    Value<String>? businessName,
    Value<String?>? deviceLabel,
    Value<DateTime>? provisionedAt,
    Value<DateTime>? updatedAt,
  }) {
    return DeviceConfigCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      businessLocationId: businessLocationId ?? this.businessLocationId,
      businessName: businessName ?? this.businessName,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      provisionedAt: provisionedAt ?? this.provisionedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (businessLocationId.present) {
      map['business_location_id'] = Variable<String>(businessLocationId.value);
    }
    if (businessName.present) {
      map['business_name'] = Variable<String>(businessName.value);
    }
    if (deviceLabel.present) {
      map['device_label'] = Variable<String>(deviceLabel.value);
    }
    if (provisionedAt.present) {
      map['provisioned_at'] = Variable<DateTime>(provisionedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceConfigCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('businessLocationId: $businessLocationId, ')
          ..write('businessName: $businessName, ')
          ..write('deviceLabel: $deviceLabel, ')
          ..write('provisionedAt: $provisionedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PendingSalesTable extends PendingSales
    with TableInfo<$PendingSalesTable, PendingSale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingSalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientSaleIdMeta = const VerificationMeta(
    'clientSaleId',
  );
  @override
  late final GeneratedColumn<String> clientSaleId = GeneratedColumn<String>(
    'client_sale_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> discountAmount =
      GeneratedColumn<String>(
        'discount_amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('0'),
      ).withConverter<Decimal>($PendingSalesTable.$converterdiscountAmount);
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceSequenceMeta = const VerificationMeta(
    'deviceSequence',
  );
  @override
  late final GeneratedColumn<int> deviceSequence = GeneratedColumn<int>(
    'device_sequence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voidOrRefundReasonMeta =
      const VerificationMeta('voidOrRefundReason');
  @override
  late final GeneratedColumn<String> voidOrRefundReason =
      GeneratedColumn<String>(
        'void_or_refund_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _localOrderIdMeta = const VerificationMeta(
    'localOrderId',
  );
  @override
  late final GeneratedColumn<String> localOrderId = GeneratedColumn<String>(
    'local_order_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncAttemptCountMeta = const VerificationMeta(
    'syncAttemptCount',
  );
  @override
  late final GeneratedColumn<int> syncAttemptCount = GeneratedColumn<int>(
    'sync_attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientSaleId,
    status,
    storeId,
    discountAmount,
    paymentMethod,
    customerId,
    occurredAt,
    deviceSequence,
    voidOrRefundReason,
    localOrderId,
    syncStatus,
    syncError,
    syncAttemptCount,
    lastAttemptAt,
    syncedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_sales';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingSale> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_sale_id')) {
      context.handle(
        _clientSaleIdMeta,
        clientSaleId.isAcceptableOrUnknown(
          data['client_sale_id']!,
          _clientSaleIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientSaleIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentMethodMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('device_sequence')) {
      context.handle(
        _deviceSequenceMeta,
        deviceSequence.isAcceptableOrUnknown(
          data['device_sequence']!,
          _deviceSequenceMeta,
        ),
      );
    }
    if (data.containsKey('void_or_refund_reason')) {
      context.handle(
        _voidOrRefundReasonMeta,
        voidOrRefundReason.isAcceptableOrUnknown(
          data['void_or_refund_reason']!,
          _voidOrRefundReasonMeta,
        ),
      );
    }
    if (data.containsKey('local_order_id')) {
      context.handle(
        _localOrderIdMeta,
        localOrderId.isAcceptableOrUnknown(
          data['local_order_id']!,
          _localOrderIdMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
      );
    }
    if (data.containsKey('sync_attempt_count')) {
      context.handle(
        _syncAttemptCountMeta,
        syncAttemptCount.isAcceptableOrUnknown(
          data['sync_attempt_count']!,
          _syncAttemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingSale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingSale(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientSaleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_sale_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      discountAmount: $PendingSalesTable.$converterdiscountAmount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}discount_amount'],
        )!,
      ),
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      deviceSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}device_sequence'],
      ),
      voidOrRefundReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_or_refund_reason'],
      ),
      localOrderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_order_id'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      ),
      syncAttemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_attempt_count'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingSalesTable createAlias(String alias) {
    return $PendingSalesTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converterdiscountAmount =
      const DecimalConverter();
}

class PendingSale extends DataClass implements Insertable<PendingSale> {
  /// Local row ID (autoincrement).
  final int id;

  /// Client-side idempotency key (UUID v4, unique).
  final String clientSaleId;

  /// Sale status: `completed`, `voided`, or `refunded`.
  /// The sale arrives in its final state; there is no "open/in-progress".
  final String status;

  /// Store/location this sale belongs to. Matches the backend's `store_id`
  /// field on `SaleSyncInput` (renamed from `business_location_id` by
  /// migration `c3d4e5f6a7b8` — keep this column named to match, since it is
  /// serialized straight into the sync payload).
  final String storeId;

  /// Discount applied to the whole sale.
  final Decimal discountAmount;

  /// Payment method used.
  final String paymentMethod;

  /// Customer this sale is attributed to, if any. Mirrors the backend's
  /// `SaleSyncInput.customer_id` — a real FK to `customers.id` server-side,
  /// resolvable offline because `Customer.id` is client-generated (see
  /// `customer_entries.dart`'s doc comment).
  final String? customerId;

  /// When the sale occurred (device time, UTC).
  final DateTime occurredAt;

  /// Optional monotonic device counter for the sale.
  final int? deviceSequence;

  /// Reason for voiding or refunding (required app-side iff status is
  /// voided/refunded, mirroring the backend's Pydantic validator).
  final String? voidOrRefundReason;

  /// Joins back to the existing UI `Order.id` (e.g., "ORD-0042") so the receipt
  /// can find both local and synced records without data duplication.
  /// No enforced FK (different ID space from `PendingSales.id`).
  final String? localOrderId;

  /// Local sync state: `pending`, `syncing`, `failed`, `synced`.
  /// `syncing` is a row-claim marker used for cross-isolate concurrency safety.
  final String syncStatus;

  /// Error message from the last sync attempt, if any.
  final String? syncError;

  /// Number of times this sale has been attempted.
  final int syncAttemptCount;

  /// Timestamp of the last sync attempt.
  final DateTime? lastAttemptAt;

  /// When the sale was successfully synced to the backend.
  final DateTime? syncedAt;

  /// Local row creation timestamp.
  final DateTime createdAt;
  const PendingSale({
    required this.id,
    required this.clientSaleId,
    required this.status,
    required this.storeId,
    required this.discountAmount,
    required this.paymentMethod,
    this.customerId,
    required this.occurredAt,
    this.deviceSequence,
    this.voidOrRefundReason,
    this.localOrderId,
    required this.syncStatus,
    this.syncError,
    required this.syncAttemptCount,
    this.lastAttemptAt,
    this.syncedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_sale_id'] = Variable<String>(clientSaleId);
    map['status'] = Variable<String>(status);
    map['store_id'] = Variable<String>(storeId);
    {
      map['discount_amount'] = Variable<String>(
        $PendingSalesTable.$converterdiscountAmount.toSql(discountAmount),
      );
    }
    map['payment_method'] = Variable<String>(paymentMethod);
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || deviceSequence != null) {
      map['device_sequence'] = Variable<int>(deviceSequence);
    }
    if (!nullToAbsent || voidOrRefundReason != null) {
      map['void_or_refund_reason'] = Variable<String>(voidOrRefundReason);
    }
    if (!nullToAbsent || localOrderId != null) {
      map['local_order_id'] = Variable<String>(localOrderId);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    map['sync_attempt_count'] = Variable<int>(syncAttemptCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingSalesCompanion toCompanion(bool nullToAbsent) {
    return PendingSalesCompanion(
      id: Value(id),
      clientSaleId: Value(clientSaleId),
      status: Value(status),
      storeId: Value(storeId),
      discountAmount: Value(discountAmount),
      paymentMethod: Value(paymentMethod),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      occurredAt: Value(occurredAt),
      deviceSequence: deviceSequence == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceSequence),
      voidOrRefundReason: voidOrRefundReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidOrRefundReason),
      localOrderId: localOrderId == null && nullToAbsent
          ? const Value.absent()
          : Value(localOrderId),
      syncStatus: Value(syncStatus),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      syncAttemptCount: Value(syncAttemptCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      createdAt: Value(createdAt),
    );
  }

  factory PendingSale.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingSale(
      id: serializer.fromJson<int>(json['id']),
      clientSaleId: serializer.fromJson<String>(json['clientSaleId']),
      status: serializer.fromJson<String>(json['status']),
      storeId: serializer.fromJson<String>(json['storeId']),
      discountAmount: serializer.fromJson<Decimal>(json['discountAmount']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      customerId: serializer.fromJson<String?>(json['customerId']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      deviceSequence: serializer.fromJson<int?>(json['deviceSequence']),
      voidOrRefundReason: serializer.fromJson<String?>(
        json['voidOrRefundReason'],
      ),
      localOrderId: serializer.fromJson<String?>(json['localOrderId']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      syncAttemptCount: serializer.fromJson<int>(json['syncAttemptCount']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientSaleId': serializer.toJson<String>(clientSaleId),
      'status': serializer.toJson<String>(status),
      'storeId': serializer.toJson<String>(storeId),
      'discountAmount': serializer.toJson<Decimal>(discountAmount),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'customerId': serializer.toJson<String?>(customerId),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'deviceSequence': serializer.toJson<int?>(deviceSequence),
      'voidOrRefundReason': serializer.toJson<String?>(voidOrRefundReason),
      'localOrderId': serializer.toJson<String?>(localOrderId),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncError': serializer.toJson<String?>(syncError),
      'syncAttemptCount': serializer.toJson<int>(syncAttemptCount),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingSale copyWith({
    int? id,
    String? clientSaleId,
    String? status,
    String? storeId,
    Decimal? discountAmount,
    String? paymentMethod,
    Value<String?> customerId = const Value.absent(),
    DateTime? occurredAt,
    Value<int?> deviceSequence = const Value.absent(),
    Value<String?> voidOrRefundReason = const Value.absent(),
    Value<String?> localOrderId = const Value.absent(),
    String? syncStatus,
    Value<String?> syncError = const Value.absent(),
    int? syncAttemptCount,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
    DateTime? createdAt,
  }) => PendingSale(
    id: id ?? this.id,
    clientSaleId: clientSaleId ?? this.clientSaleId,
    status: status ?? this.status,
    storeId: storeId ?? this.storeId,
    discountAmount: discountAmount ?? this.discountAmount,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    customerId: customerId.present ? customerId.value : this.customerId,
    occurredAt: occurredAt ?? this.occurredAt,
    deviceSequence: deviceSequence.present
        ? deviceSequence.value
        : this.deviceSequence,
    voidOrRefundReason: voidOrRefundReason.present
        ? voidOrRefundReason.value
        : this.voidOrRefundReason,
    localOrderId: localOrderId.present ? localOrderId.value : this.localOrderId,
    syncStatus: syncStatus ?? this.syncStatus,
    syncError: syncError.present ? syncError.value : this.syncError,
    syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingSale copyWithCompanion(PendingSalesCompanion data) {
    return PendingSale(
      id: data.id.present ? data.id.value : this.id,
      clientSaleId: data.clientSaleId.present
          ? data.clientSaleId.value
          : this.clientSaleId,
      status: data.status.present ? data.status.value : this.status,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      discountAmount: data.discountAmount.present
          ? data.discountAmount.value
          : this.discountAmount,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      deviceSequence: data.deviceSequence.present
          ? data.deviceSequence.value
          : this.deviceSequence,
      voidOrRefundReason: data.voidOrRefundReason.present
          ? data.voidOrRefundReason.value
          : this.voidOrRefundReason,
      localOrderId: data.localOrderId.present
          ? data.localOrderId.value
          : this.localOrderId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      syncAttemptCount: data.syncAttemptCount.present
          ? data.syncAttemptCount.value
          : this.syncAttemptCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingSale(')
          ..write('id: $id, ')
          ..write('clientSaleId: $clientSaleId, ')
          ..write('status: $status, ')
          ..write('storeId: $storeId, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('customerId: $customerId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('deviceSequence: $deviceSequence, ')
          ..write('voidOrRefundReason: $voidOrRefundReason, ')
          ..write('localOrderId: $localOrderId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('syncAttemptCount: $syncAttemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientSaleId,
    status,
    storeId,
    discountAmount,
    paymentMethod,
    customerId,
    occurredAt,
    deviceSequence,
    voidOrRefundReason,
    localOrderId,
    syncStatus,
    syncError,
    syncAttemptCount,
    lastAttemptAt,
    syncedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingSale &&
          other.id == this.id &&
          other.clientSaleId == this.clientSaleId &&
          other.status == this.status &&
          other.storeId == this.storeId &&
          other.discountAmount == this.discountAmount &&
          other.paymentMethod == this.paymentMethod &&
          other.customerId == this.customerId &&
          other.occurredAt == this.occurredAt &&
          other.deviceSequence == this.deviceSequence &&
          other.voidOrRefundReason == this.voidOrRefundReason &&
          other.localOrderId == this.localOrderId &&
          other.syncStatus == this.syncStatus &&
          other.syncError == this.syncError &&
          other.syncAttemptCount == this.syncAttemptCount &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.syncedAt == this.syncedAt &&
          other.createdAt == this.createdAt);
}

class PendingSalesCompanion extends UpdateCompanion<PendingSale> {
  final Value<int> id;
  final Value<String> clientSaleId;
  final Value<String> status;
  final Value<String> storeId;
  final Value<Decimal> discountAmount;
  final Value<String> paymentMethod;
  final Value<String?> customerId;
  final Value<DateTime> occurredAt;
  final Value<int?> deviceSequence;
  final Value<String?> voidOrRefundReason;
  final Value<String?> localOrderId;
  final Value<String> syncStatus;
  final Value<String?> syncError;
  final Value<int> syncAttemptCount;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> syncedAt;
  final Value<DateTime> createdAt;
  const PendingSalesCompanion({
    this.id = const Value.absent(),
    this.clientSaleId = const Value.absent(),
    this.status = const Value.absent(),
    this.storeId = const Value.absent(),
    this.discountAmount = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.customerId = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.deviceSequence = const Value.absent(),
    this.voidOrRefundReason = const Value.absent(),
    this.localOrderId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncAttemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PendingSalesCompanion.insert({
    this.id = const Value.absent(),
    required String clientSaleId,
    required String status,
    required String storeId,
    this.discountAmount = const Value.absent(),
    required String paymentMethod,
    this.customerId = const Value.absent(),
    required DateTime occurredAt,
    this.deviceSequence = const Value.absent(),
    this.voidOrRefundReason = const Value.absent(),
    this.localOrderId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncAttemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required DateTime createdAt,
  }) : clientSaleId = Value(clientSaleId),
       status = Value(status),
       storeId = Value(storeId),
       paymentMethod = Value(paymentMethod),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt);
  static Insertable<PendingSale> custom({
    Expression<int>? id,
    Expression<String>? clientSaleId,
    Expression<String>? status,
    Expression<String>? storeId,
    Expression<String>? discountAmount,
    Expression<String>? paymentMethod,
    Expression<String>? customerId,
    Expression<DateTime>? occurredAt,
    Expression<int>? deviceSequence,
    Expression<String>? voidOrRefundReason,
    Expression<String>? localOrderId,
    Expression<String>? syncStatus,
    Expression<String>? syncError,
    Expression<int>? syncAttemptCount,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientSaleId != null) 'client_sale_id': clientSaleId,
      if (status != null) 'status': status,
      if (storeId != null) 'store_id': storeId,
      if (discountAmount != null) 'discount_amount': discountAmount,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (customerId != null) 'customer_id': customerId,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (deviceSequence != null) 'device_sequence': deviceSequence,
      if (voidOrRefundReason != null)
        'void_or_refund_reason': voidOrRefundReason,
      if (localOrderId != null) 'local_order_id': localOrderId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncError != null) 'sync_error': syncError,
      if (syncAttemptCount != null) 'sync_attempt_count': syncAttemptCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PendingSalesCompanion copyWith({
    Value<int>? id,
    Value<String>? clientSaleId,
    Value<String>? status,
    Value<String>? storeId,
    Value<Decimal>? discountAmount,
    Value<String>? paymentMethod,
    Value<String?>? customerId,
    Value<DateTime>? occurredAt,
    Value<int?>? deviceSequence,
    Value<String?>? voidOrRefundReason,
    Value<String?>? localOrderId,
    Value<String>? syncStatus,
    Value<String?>? syncError,
    Value<int>? syncAttemptCount,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime?>? syncedAt,
    Value<DateTime>? createdAt,
  }) {
    return PendingSalesCompanion(
      id: id ?? this.id,
      clientSaleId: clientSaleId ?? this.clientSaleId,
      status: status ?? this.status,
      storeId: storeId ?? this.storeId,
      discountAmount: discountAmount ?? this.discountAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: customerId ?? this.customerId,
      occurredAt: occurredAt ?? this.occurredAt,
      deviceSequence: deviceSequence ?? this.deviceSequence,
      voidOrRefundReason: voidOrRefundReason ?? this.voidOrRefundReason,
      localOrderId: localOrderId ?? this.localOrderId,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientSaleId.present) {
      map['client_sale_id'] = Variable<String>(clientSaleId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (discountAmount.present) {
      map['discount_amount'] = Variable<String>(
        $PendingSalesTable.$converterdiscountAmount.toSql(discountAmount.value),
      );
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (deviceSequence.present) {
      map['device_sequence'] = Variable<int>(deviceSequence.value);
    }
    if (voidOrRefundReason.present) {
      map['void_or_refund_reason'] = Variable<String>(voidOrRefundReason.value);
    }
    if (localOrderId.present) {
      map['local_order_id'] = Variable<String>(localOrderId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (syncAttemptCount.present) {
      map['sync_attempt_count'] = Variable<int>(syncAttemptCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingSalesCompanion(')
          ..write('id: $id, ')
          ..write('clientSaleId: $clientSaleId, ')
          ..write('status: $status, ')
          ..write('storeId: $storeId, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('customerId: $customerId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('deviceSequence: $deviceSequence, ')
          ..write('voidOrRefundReason: $voidOrRefundReason, ')
          ..write('localOrderId: $localOrderId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('syncAttemptCount: $syncAttemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PendingSaleLineItemsTable extends PendingSaleLineItems
    with TableInfo<$PendingSaleLineItemsTable, PendingSaleLineItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingSaleLineItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pendingSaleIdMeta = const VerificationMeta(
    'pendingSaleId',
  );
  @override
  late final GeneratedColumn<int> pendingSaleId = GeneratedColumn<int>(
    'pending_sale_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pending_sales (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> quantity =
      GeneratedColumn<String>(
        'quantity',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($PendingSaleLineItemsTable.$converterquantity);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> unitPrice =
      GeneratedColumn<String>(
        'unit_price',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($PendingSaleLineItemsTable.$converterunitPrice);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> discountAmount =
      GeneratedColumn<String>(
        'discount_amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('0'),
      ).withConverter<Decimal>(
        $PendingSaleLineItemsTable.$converterdiscountAmount,
      );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal?, String> unitCost =
      GeneratedColumn<String>(
        'unit_cost',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Decimal?>($PendingSaleLineItemsTable.$converterunitCostn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pendingSaleId,
    itemId,
    quantity,
    unitPrice,
    discountAmount,
    unitCost,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_sale_line_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingSaleLineItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('pending_sale_id')) {
      context.handle(
        _pendingSaleIdMeta,
        pendingSaleId.isAcceptableOrUnknown(
          data['pending_sale_id']!,
          _pendingSaleIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pendingSaleIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingSaleLineItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingSaleLineItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      pendingSaleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pending_sale_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      quantity: $PendingSaleLineItemsTable.$converterquantity.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}quantity'],
        )!,
      ),
      unitPrice: $PendingSaleLineItemsTable.$converterunitPrice.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}unit_price'],
        )!,
      ),
      discountAmount: $PendingSaleLineItemsTable.$converterdiscountAmount
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}discount_amount'],
            )!,
          ),
      unitCost: $PendingSaleLineItemsTable.$converterunitCostn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}unit_cost'],
        ),
      ),
    );
  }

  @override
  $PendingSaleLineItemsTable createAlias(String alias) {
    return $PendingSaleLineItemsTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converterquantity =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $converterunitPrice =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $converterdiscountAmount =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $converterunitCost =
      const DecimalConverter();
  static TypeConverter<Decimal?, String?> $converterunitCostn =
      NullAwareTypeConverter.wrap($converterunitCost);
}

class PendingSaleLineItem extends DataClass
    implements Insertable<PendingSaleLineItem> {
  /// Local row ID (autoincrement).
  final int id;

  /// Foreign key to the sale this line belongs to.
  final int pendingSaleId;

  /// Item UUID from the inventory catalog.
  /// Soft-references `CachedItems.id` without an FK constraint
  /// (see `CachedItems` for rationale).
  final String itemId;

  /// Quantity sold (strictly positive, validated app-side).
  final Decimal quantity;

  /// Unit price of the item.
  final Decimal unitPrice;

  /// Discount applied to this line.
  final Decimal discountAmount;

  /// Per-unit production cost snapshot at sale time. Zero means
  /// unknown-but-frozen (no recipe, nothing on file — flagged estimated
  /// downstream); null is legacy rows synced before snapshots existed.
  /// Synced as JSON number (never null for new sales) and stored
  /// server-side for frozen profit history.
  final Decimal? unitCost;
  const PendingSaleLineItem({
    required this.id,
    required this.pendingSaleId,
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    this.unitCost,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['pending_sale_id'] = Variable<int>(pendingSaleId);
    map['item_id'] = Variable<String>(itemId);
    {
      map['quantity'] = Variable<String>(
        $PendingSaleLineItemsTable.$converterquantity.toSql(quantity),
      );
    }
    {
      map['unit_price'] = Variable<String>(
        $PendingSaleLineItemsTable.$converterunitPrice.toSql(unitPrice),
      );
    }
    {
      map['discount_amount'] = Variable<String>(
        $PendingSaleLineItemsTable.$converterdiscountAmount.toSql(
          discountAmount,
        ),
      );
    }
    if (!nullToAbsent || unitCost != null) {
      map['unit_cost'] = Variable<String>(
        $PendingSaleLineItemsTable.$converterunitCostn.toSql(unitCost),
      );
    }
    return map;
  }

  PendingSaleLineItemsCompanion toCompanion(bool nullToAbsent) {
    return PendingSaleLineItemsCompanion(
      id: Value(id),
      pendingSaleId: Value(pendingSaleId),
      itemId: Value(itemId),
      quantity: Value(quantity),
      unitPrice: Value(unitPrice),
      discountAmount: Value(discountAmount),
      unitCost: unitCost == null && nullToAbsent
          ? const Value.absent()
          : Value(unitCost),
    );
  }

  factory PendingSaleLineItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingSaleLineItem(
      id: serializer.fromJson<int>(json['id']),
      pendingSaleId: serializer.fromJson<int>(json['pendingSaleId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      quantity: serializer.fromJson<Decimal>(json['quantity']),
      unitPrice: serializer.fromJson<Decimal>(json['unitPrice']),
      discountAmount: serializer.fromJson<Decimal>(json['discountAmount']),
      unitCost: serializer.fromJson<Decimal?>(json['unitCost']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'pendingSaleId': serializer.toJson<int>(pendingSaleId),
      'itemId': serializer.toJson<String>(itemId),
      'quantity': serializer.toJson<Decimal>(quantity),
      'unitPrice': serializer.toJson<Decimal>(unitPrice),
      'discountAmount': serializer.toJson<Decimal>(discountAmount),
      'unitCost': serializer.toJson<Decimal?>(unitCost),
    };
  }

  PendingSaleLineItem copyWith({
    int? id,
    int? pendingSaleId,
    String? itemId,
    Decimal? quantity,
    Decimal? unitPrice,
    Decimal? discountAmount,
    Value<Decimal?> unitCost = const Value.absent(),
  }) => PendingSaleLineItem(
    id: id ?? this.id,
    pendingSaleId: pendingSaleId ?? this.pendingSaleId,
    itemId: itemId ?? this.itemId,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    discountAmount: discountAmount ?? this.discountAmount,
    unitCost: unitCost.present ? unitCost.value : this.unitCost,
  );
  PendingSaleLineItem copyWithCompanion(PendingSaleLineItemsCompanion data) {
    return PendingSaleLineItem(
      id: data.id.present ? data.id.value : this.id,
      pendingSaleId: data.pendingSaleId.present
          ? data.pendingSaleId.value
          : this.pendingSaleId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      discountAmount: data.discountAmount.present
          ? data.discountAmount.value
          : this.discountAmount,
      unitCost: data.unitCost.present ? data.unitCost.value : this.unitCost,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingSaleLineItem(')
          ..write('id: $id, ')
          ..write('pendingSaleId: $pendingSaleId, ')
          ..write('itemId: $itemId, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('unitCost: $unitCost')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    pendingSaleId,
    itemId,
    quantity,
    unitPrice,
    discountAmount,
    unitCost,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingSaleLineItem &&
          other.id == this.id &&
          other.pendingSaleId == this.pendingSaleId &&
          other.itemId == this.itemId &&
          other.quantity == this.quantity &&
          other.unitPrice == this.unitPrice &&
          other.discountAmount == this.discountAmount &&
          other.unitCost == this.unitCost);
}

class PendingSaleLineItemsCompanion
    extends UpdateCompanion<PendingSaleLineItem> {
  final Value<int> id;
  final Value<int> pendingSaleId;
  final Value<String> itemId;
  final Value<Decimal> quantity;
  final Value<Decimal> unitPrice;
  final Value<Decimal> discountAmount;
  final Value<Decimal?> unitCost;
  const PendingSaleLineItemsCompanion({
    this.id = const Value.absent(),
    this.pendingSaleId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.discountAmount = const Value.absent(),
    this.unitCost = const Value.absent(),
  });
  PendingSaleLineItemsCompanion.insert({
    this.id = const Value.absent(),
    required int pendingSaleId,
    required String itemId,
    required Decimal quantity,
    required Decimal unitPrice,
    this.discountAmount = const Value.absent(),
    this.unitCost = const Value.absent(),
  }) : pendingSaleId = Value(pendingSaleId),
       itemId = Value(itemId),
       quantity = Value(quantity),
       unitPrice = Value(unitPrice);
  static Insertable<PendingSaleLineItem> custom({
    Expression<int>? id,
    Expression<int>? pendingSaleId,
    Expression<String>? itemId,
    Expression<String>? quantity,
    Expression<String>? unitPrice,
    Expression<String>? discountAmount,
    Expression<String>? unitCost,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pendingSaleId != null) 'pending_sale_id': pendingSaleId,
      if (itemId != null) 'item_id': itemId,
      if (quantity != null) 'quantity': quantity,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (discountAmount != null) 'discount_amount': discountAmount,
      if (unitCost != null) 'unit_cost': unitCost,
    });
  }

  PendingSaleLineItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? pendingSaleId,
    Value<String>? itemId,
    Value<Decimal>? quantity,
    Value<Decimal>? unitPrice,
    Value<Decimal>? discountAmount,
    Value<Decimal?>? unitCost,
  }) {
    return PendingSaleLineItemsCompanion(
      id: id ?? this.id,
      pendingSaleId: pendingSaleId ?? this.pendingSaleId,
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      unitCost: unitCost ?? this.unitCost,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (pendingSaleId.present) {
      map['pending_sale_id'] = Variable<int>(pendingSaleId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<String>(
        $PendingSaleLineItemsTable.$converterquantity.toSql(quantity.value),
      );
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<String>(
        $PendingSaleLineItemsTable.$converterunitPrice.toSql(unitPrice.value),
      );
    }
    if (discountAmount.present) {
      map['discount_amount'] = Variable<String>(
        $PendingSaleLineItemsTable.$converterdiscountAmount.toSql(
          discountAmount.value,
        ),
      );
    }
    if (unitCost.present) {
      map['unit_cost'] = Variable<String>(
        $PendingSaleLineItemsTable.$converterunitCostn.toSql(unitCost.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingSaleLineItemsCompanion(')
          ..write('id: $id, ')
          ..write('pendingSaleId: $pendingSaleId, ')
          ..write('itemId: $itemId, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('unitCost: $unitCost')
          ..write(')'))
        .toString();
  }
}

class $CachedItemsTable extends CachedItems
    with TableInfo<$CachedItemsTable, CachedItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessLocationIdMeta =
      const VerificationMeta('businessLocationId');
  @override
  late final GeneratedColumn<String> businessLocationId =
      GeneratedColumn<String>(
        'business_location_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitOfMeasureMeta = const VerificationMeta(
    'unitOfMeasure',
  );
  @override
  late final GeneratedColumn<String> unitOfMeasure = GeneratedColumn<String>(
    'unit_of_measure',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitIdMeta = const VerificationMeta('unitId');
  @override
  late final GeneratedColumn<String> unitId = GeneratedColumn<String>(
    'unit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String>
  reorderThreshold = GeneratedColumn<String>(
    'reorder_threshold',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<Decimal>($CachedItemsTable.$converterreorderThreshold);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> reorderQuantity =
      GeneratedColumn<String>(
        'reorder_quantity',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($CachedItemsTable.$converterreorderQuantity);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal?, String> sellingPrice =
      GeneratedColumn<String>(
        'selling_price',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Decimal?>($CachedItemsTable.$convertersellingPricen);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal?, String> unitCost =
      GeneratedColumn<String>(
        'unit_cost',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Decimal?>($CachedItemsTable.$converterunitCostn);
  static const VerificationMeta _allowNegativeStockMeta =
      const VerificationMeta('allowNegativeStock');
  @override
  late final GeneratedColumn<bool> allowNegativeStock = GeneratedColumn<bool>(
    'allow_negative_stock',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_negative_stock" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _itemTypeMeta = const VerificationMeta(
    'itemType',
  );
  @override
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
    'item_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtServerMeta = const VerificationMeta(
    'createdAtServer',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtServer =
      GeneratedColumn<DateTime>(
        'created_at_server',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _updatedAtServerMeta = const VerificationMeta(
    'updatedAtServer',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtServer =
      GeneratedColumn<DateTime>(
        'updated_at_server',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _supplierIdMeta = const VerificationMeta(
    'supplierId',
  );
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
    'supplier_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    businessLocationId,
    name,
    unitOfMeasure,
    unitId,
    category,
    reorderThreshold,
    reorderQuantity,
    sellingPrice,
    unitCost,
    allowNegativeStock,
    itemType,
    isActive,
    createdAtServer,
    updatedAtServer,
    lastSeenAt,
    lastSyncedAt,
    imageUrl,
    supplierId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('business_location_id')) {
      context.handle(
        _businessLocationIdMeta,
        businessLocationId.isAcceptableOrUnknown(
          data['business_location_id']!,
          _businessLocationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_businessLocationIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('unit_of_measure')) {
      context.handle(
        _unitOfMeasureMeta,
        unitOfMeasure.isAcceptableOrUnknown(
          data['unit_of_measure']!,
          _unitOfMeasureMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitOfMeasureMeta);
    }
    if (data.containsKey('unit_id')) {
      context.handle(
        _unitIdMeta,
        unitId.isAcceptableOrUnknown(data['unit_id']!, _unitIdMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('allow_negative_stock')) {
      context.handle(
        _allowNegativeStockMeta,
        allowNegativeStock.isAcceptableOrUnknown(
          data['allow_negative_stock']!,
          _allowNegativeStockMeta,
        ),
      );
    }
    if (data.containsKey('item_type')) {
      context.handle(
        _itemTypeMeta,
        itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_itemTypeMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at_server')) {
      context.handle(
        _createdAtServerMeta,
        createdAtServer.isAcceptableOrUnknown(
          data['created_at_server']!,
          _createdAtServerMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtServerMeta);
    }
    if (data.containsKey('updated_at_server')) {
      context.handle(
        _updatedAtServerMeta,
        updatedAtServer.isAcceptableOrUnknown(
          data['updated_at_server']!,
          _updatedAtServerMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtServerMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
        _supplierIdMeta,
        supplierId.isAcceptableOrUnknown(data['supplier_id']!, _supplierIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      businessLocationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_location_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      unitOfMeasure: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_of_measure'],
      )!,
      unitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      reorderThreshold: $CachedItemsTable.$converterreorderThreshold.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}reorder_threshold'],
        )!,
      ),
      reorderQuantity: $CachedItemsTable.$converterreorderQuantity.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}reorder_quantity'],
        )!,
      ),
      sellingPrice: $CachedItemsTable.$convertersellingPricen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}selling_price'],
        ),
      ),
      unitCost: $CachedItemsTable.$converterunitCostn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}unit_cost'],
        ),
      ),
      allowNegativeStock: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_negative_stock'],
      )!,
      itemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_type'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAtServer: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_server'],
      )!,
      updatedAtServer: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at_server'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      supplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_id'],
      )!,
    );
  }

  @override
  $CachedItemsTable createAlias(String alias) {
    return $CachedItemsTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converterreorderThreshold =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $converterreorderQuantity =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $convertersellingPrice =
      const DecimalConverter();
  static TypeConverter<Decimal?, String?> $convertersellingPricen =
      NullAwareTypeConverter.wrap($convertersellingPrice);
  static TypeConverter<Decimal, String> $converterunitCost =
      const DecimalConverter();
  static TypeConverter<Decimal?, String?> $converterunitCostn =
      NullAwareTypeConverter.wrap($converterunitCost);
}

class CachedItem extends DataClass implements Insertable<CachedItem> {
  /// Item UUID (primary key).
  final String id;

  /// Business this item belongs to.
  final String businessId;

  /// Business location this item belongs to.
  final String businessLocationId;

  /// Item name.
  final String name;

  /// Unit of measure (e.g., 'kg', 'l', 'unit', 'pack').
  ///
  /// Dead column, kept only because SQLite can't cheaply drop a NOT NULL
  /// column without a table rebuild (see `AppDatabase`'s v10 doc comment):
  /// no longer written or read anywhere — superseded by [unitId] below.
  final String unitOfMeasure;

  /// The backend `Unit` row's UUID (`item.unit_id` on the wire) — see
  /// `CachedUnits`. Empty string means "not yet resolved" (this column is
  /// NOT NULL with a `''` default rather than nullable, matching how
  /// `ItemFormState.categoryId` already treats `''` as its own "unset"
  /// sentinel, for the same SQLite add-a-NOT-NULL-column-with-a-default
  /// reason `unitOfMeasure` above can't just become nullable).
  final String unitId;

  /// Item category (optional) — the backend `Category` row's UUID (see
  /// `CachedCategories`), not a free-text label. Was a raw free-text string
  /// before migration `f1a2b3c4d5e6_create_category_and_migrate_item_category`;
  /// the column itself is unchanged, only what it holds.
  final String? category;

  /// Reorder threshold quantity.
  final Decimal reorderThreshold;

  /// Reorder quantity.
  final Decimal reorderQuantity;

  /// Selling price (optional).
  final Decimal? sellingPrice;

  /// Cost basis for the inventory-value metric (optional).
  final Decimal? unitCost;

  /// Whether negative stock is allowed.
  final bool allowNegativeStock;

  /// Item type: `sellable`, `raw_material`, or `both`.
  final String itemType;

  /// Soft-delete flag: false means the item is no longer available from the
  /// catalog, but existing references to it (e.g., completed sales) remain valid.
  final bool isActive;

  /// Backend creation timestamp.
  final DateTime createdAtServer;

  /// Backend last-update timestamp (used to detect changed rows on pull).
  final DateTime updatedAtServer;

  /// Local timestamp of the most recent pull that included this row.
  /// Anything with a stale `lastSeenAt` after a full pull gets `isActive=false`.
  final DateTime lastSeenAt;

  /// Local timestamp of the last catalog sync that touched this row.
  final DateTime lastSyncedAt;

  /// Service-relative URL of the item's product photo (see `CatalogItemDto.imageUrl`).
  /// Nullable: null means "no photo on the server" and the UI falls back to
  /// its placeholder. Synced from the catalog pull like every other column —
  /// a photo removed server-side clears this on the next pull.
  final String? imageUrl;

  /// The backend `Supplier` row's UUID (`item.supplier_id` on the wire) — the
  /// item's preferred/original supplier, see `CachedSuppliers`. Empty string
  /// means "none assigned" (NOT NULL with a `''` default rather than
  /// nullable, for the same SQLite add-a-NOT-NULL-column-with-a-default
  /// reason as [unitId] above). Synced from the catalog pull; cleared
  /// server-side clears here on the next pull. The order cart pre-assigns
  /// this supplier to a new line, still changeable per line or in bulk.
  final String supplierId;
  const CachedItem({
    required this.id,
    required this.businessId,
    required this.businessLocationId,
    required this.name,
    required this.unitOfMeasure,
    required this.unitId,
    this.category,
    required this.reorderThreshold,
    required this.reorderQuantity,
    this.sellingPrice,
    this.unitCost,
    required this.allowNegativeStock,
    required this.itemType,
    required this.isActive,
    required this.createdAtServer,
    required this.updatedAtServer,
    required this.lastSeenAt,
    required this.lastSyncedAt,
    this.imageUrl,
    required this.supplierId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['business_id'] = Variable<String>(businessId);
    map['business_location_id'] = Variable<String>(businessLocationId);
    map['name'] = Variable<String>(name);
    map['unit_of_measure'] = Variable<String>(unitOfMeasure);
    map['unit_id'] = Variable<String>(unitId);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    {
      map['reorder_threshold'] = Variable<String>(
        $CachedItemsTable.$converterreorderThreshold.toSql(reorderThreshold),
      );
    }
    {
      map['reorder_quantity'] = Variable<String>(
        $CachedItemsTable.$converterreorderQuantity.toSql(reorderQuantity),
      );
    }
    if (!nullToAbsent || sellingPrice != null) {
      map['selling_price'] = Variable<String>(
        $CachedItemsTable.$convertersellingPricen.toSql(sellingPrice),
      );
    }
    if (!nullToAbsent || unitCost != null) {
      map['unit_cost'] = Variable<String>(
        $CachedItemsTable.$converterunitCostn.toSql(unitCost),
      );
    }
    map['allow_negative_stock'] = Variable<bool>(allowNegativeStock);
    map['item_type'] = Variable<String>(itemType);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at_server'] = Variable<DateTime>(createdAtServer);
    map['updated_at_server'] = Variable<DateTime>(updatedAtServer);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['supplier_id'] = Variable<String>(supplierId);
    return map;
  }

  CachedItemsCompanion toCompanion(bool nullToAbsent) {
    return CachedItemsCompanion(
      id: Value(id),
      businessId: Value(businessId),
      businessLocationId: Value(businessLocationId),
      name: Value(name),
      unitOfMeasure: Value(unitOfMeasure),
      unitId: Value(unitId),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      reorderThreshold: Value(reorderThreshold),
      reorderQuantity: Value(reorderQuantity),
      sellingPrice: sellingPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(sellingPrice),
      unitCost: unitCost == null && nullToAbsent
          ? const Value.absent()
          : Value(unitCost),
      allowNegativeStock: Value(allowNegativeStock),
      itemType: Value(itemType),
      isActive: Value(isActive),
      createdAtServer: Value(createdAtServer),
      updatedAtServer: Value(updatedAtServer),
      lastSeenAt: Value(lastSeenAt),
      lastSyncedAt: Value(lastSyncedAt),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      supplierId: Value(supplierId),
    );
  }

  factory CachedItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedItem(
      id: serializer.fromJson<String>(json['id']),
      businessId: serializer.fromJson<String>(json['businessId']),
      businessLocationId: serializer.fromJson<String>(
        json['businessLocationId'],
      ),
      name: serializer.fromJson<String>(json['name']),
      unitOfMeasure: serializer.fromJson<String>(json['unitOfMeasure']),
      unitId: serializer.fromJson<String>(json['unitId']),
      category: serializer.fromJson<String?>(json['category']),
      reorderThreshold: serializer.fromJson<Decimal>(json['reorderThreshold']),
      reorderQuantity: serializer.fromJson<Decimal>(json['reorderQuantity']),
      sellingPrice: serializer.fromJson<Decimal?>(json['sellingPrice']),
      unitCost: serializer.fromJson<Decimal?>(json['unitCost']),
      allowNegativeStock: serializer.fromJson<bool>(json['allowNegativeStock']),
      itemType: serializer.fromJson<String>(json['itemType']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAtServer: serializer.fromJson<DateTime>(json['createdAtServer']),
      updatedAtServer: serializer.fromJson<DateTime>(json['updatedAtServer']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      supplierId: serializer.fromJson<String>(json['supplierId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'businessId': serializer.toJson<String>(businessId),
      'businessLocationId': serializer.toJson<String>(businessLocationId),
      'name': serializer.toJson<String>(name),
      'unitOfMeasure': serializer.toJson<String>(unitOfMeasure),
      'unitId': serializer.toJson<String>(unitId),
      'category': serializer.toJson<String?>(category),
      'reorderThreshold': serializer.toJson<Decimal>(reorderThreshold),
      'reorderQuantity': serializer.toJson<Decimal>(reorderQuantity),
      'sellingPrice': serializer.toJson<Decimal?>(sellingPrice),
      'unitCost': serializer.toJson<Decimal?>(unitCost),
      'allowNegativeStock': serializer.toJson<bool>(allowNegativeStock),
      'itemType': serializer.toJson<String>(itemType),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAtServer': serializer.toJson<DateTime>(createdAtServer),
      'updatedAtServer': serializer.toJson<DateTime>(updatedAtServer),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'supplierId': serializer.toJson<String>(supplierId),
    };
  }

  CachedItem copyWith({
    String? id,
    String? businessId,
    String? businessLocationId,
    String? name,
    String? unitOfMeasure,
    String? unitId,
    Value<String?> category = const Value.absent(),
    Decimal? reorderThreshold,
    Decimal? reorderQuantity,
    Value<Decimal?> sellingPrice = const Value.absent(),
    Value<Decimal?> unitCost = const Value.absent(),
    bool? allowNegativeStock,
    String? itemType,
    bool? isActive,
    DateTime? createdAtServer,
    DateTime? updatedAtServer,
    DateTime? lastSeenAt,
    DateTime? lastSyncedAt,
    Value<String?> imageUrl = const Value.absent(),
    String? supplierId,
  }) => CachedItem(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    businessLocationId: businessLocationId ?? this.businessLocationId,
    name: name ?? this.name,
    unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
    unitId: unitId ?? this.unitId,
    category: category.present ? category.value : this.category,
    reorderThreshold: reorderThreshold ?? this.reorderThreshold,
    reorderQuantity: reorderQuantity ?? this.reorderQuantity,
    sellingPrice: sellingPrice.present ? sellingPrice.value : this.sellingPrice,
    unitCost: unitCost.present ? unitCost.value : this.unitCost,
    allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
    itemType: itemType ?? this.itemType,
    isActive: isActive ?? this.isActive,
    createdAtServer: createdAtServer ?? this.createdAtServer,
    updatedAtServer: updatedAtServer ?? this.updatedAtServer,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    supplierId: supplierId ?? this.supplierId,
  );
  CachedItem copyWithCompanion(CachedItemsCompanion data) {
    return CachedItem(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      businessLocationId: data.businessLocationId.present
          ? data.businessLocationId.value
          : this.businessLocationId,
      name: data.name.present ? data.name.value : this.name,
      unitOfMeasure: data.unitOfMeasure.present
          ? data.unitOfMeasure.value
          : this.unitOfMeasure,
      unitId: data.unitId.present ? data.unitId.value : this.unitId,
      category: data.category.present ? data.category.value : this.category,
      reorderThreshold: data.reorderThreshold.present
          ? data.reorderThreshold.value
          : this.reorderThreshold,
      reorderQuantity: data.reorderQuantity.present
          ? data.reorderQuantity.value
          : this.reorderQuantity,
      sellingPrice: data.sellingPrice.present
          ? data.sellingPrice.value
          : this.sellingPrice,
      unitCost: data.unitCost.present ? data.unitCost.value : this.unitCost,
      allowNegativeStock: data.allowNegativeStock.present
          ? data.allowNegativeStock.value
          : this.allowNegativeStock,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAtServer: data.createdAtServer.present
          ? data.createdAtServer.value
          : this.createdAtServer,
      updatedAtServer: data.updatedAtServer.present
          ? data.updatedAtServer.value
          : this.updatedAtServer,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      supplierId: data.supplierId.present
          ? data.supplierId.value
          : this.supplierId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedItem(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('businessLocationId: $businessLocationId, ')
          ..write('name: $name, ')
          ..write('unitOfMeasure: $unitOfMeasure, ')
          ..write('unitId: $unitId, ')
          ..write('category: $category, ')
          ..write('reorderThreshold: $reorderThreshold, ')
          ..write('reorderQuantity: $reorderQuantity, ')
          ..write('sellingPrice: $sellingPrice, ')
          ..write('unitCost: $unitCost, ')
          ..write('allowNegativeStock: $allowNegativeStock, ')
          ..write('itemType: $itemType, ')
          ..write('isActive: $isActive, ')
          ..write('createdAtServer: $createdAtServer, ')
          ..write('updatedAtServer: $updatedAtServer, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('supplierId: $supplierId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    businessLocationId,
    name,
    unitOfMeasure,
    unitId,
    category,
    reorderThreshold,
    reorderQuantity,
    sellingPrice,
    unitCost,
    allowNegativeStock,
    itemType,
    isActive,
    createdAtServer,
    updatedAtServer,
    lastSeenAt,
    lastSyncedAt,
    imageUrl,
    supplierId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedItem &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.businessLocationId == this.businessLocationId &&
          other.name == this.name &&
          other.unitOfMeasure == this.unitOfMeasure &&
          other.unitId == this.unitId &&
          other.category == this.category &&
          other.reorderThreshold == this.reorderThreshold &&
          other.reorderQuantity == this.reorderQuantity &&
          other.sellingPrice == this.sellingPrice &&
          other.unitCost == this.unitCost &&
          other.allowNegativeStock == this.allowNegativeStock &&
          other.itemType == this.itemType &&
          other.isActive == this.isActive &&
          other.createdAtServer == this.createdAtServer &&
          other.updatedAtServer == this.updatedAtServer &&
          other.lastSeenAt == this.lastSeenAt &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.imageUrl == this.imageUrl &&
          other.supplierId == this.supplierId);
}

class CachedItemsCompanion extends UpdateCompanion<CachedItem> {
  final Value<String> id;
  final Value<String> businessId;
  final Value<String> businessLocationId;
  final Value<String> name;
  final Value<String> unitOfMeasure;
  final Value<String> unitId;
  final Value<String?> category;
  final Value<Decimal> reorderThreshold;
  final Value<Decimal> reorderQuantity;
  final Value<Decimal?> sellingPrice;
  final Value<Decimal?> unitCost;
  final Value<bool> allowNegativeStock;
  final Value<String> itemType;
  final Value<bool> isActive;
  final Value<DateTime> createdAtServer;
  final Value<DateTime> updatedAtServer;
  final Value<DateTime> lastSeenAt;
  final Value<DateTime> lastSyncedAt;
  final Value<String?> imageUrl;
  final Value<String> supplierId;
  final Value<int> rowid;
  const CachedItemsCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.businessLocationId = const Value.absent(),
    this.name = const Value.absent(),
    this.unitOfMeasure = const Value.absent(),
    this.unitId = const Value.absent(),
    this.category = const Value.absent(),
    this.reorderThreshold = const Value.absent(),
    this.reorderQuantity = const Value.absent(),
    this.sellingPrice = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.allowNegativeStock = const Value.absent(),
    this.itemType = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAtServer = const Value.absent(),
    this.updatedAtServer = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedItemsCompanion.insert({
    required String id,
    required String businessId,
    required String businessLocationId,
    required String name,
    required String unitOfMeasure,
    this.unitId = const Value.absent(),
    this.category = const Value.absent(),
    required Decimal reorderThreshold,
    required Decimal reorderQuantity,
    this.sellingPrice = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.allowNegativeStock = const Value.absent(),
    required String itemType,
    this.isActive = const Value.absent(),
    required DateTime createdAtServer,
    required DateTime updatedAtServer,
    required DateTime lastSeenAt,
    required DateTime lastSyncedAt,
    this.imageUrl = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessId = Value(businessId),
       businessLocationId = Value(businessLocationId),
       name = Value(name),
       unitOfMeasure = Value(unitOfMeasure),
       reorderThreshold = Value(reorderThreshold),
       reorderQuantity = Value(reorderQuantity),
       itemType = Value(itemType),
       createdAtServer = Value(createdAtServer),
       updatedAtServer = Value(updatedAtServer),
       lastSeenAt = Value(lastSeenAt),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<CachedItem> custom({
    Expression<String>? id,
    Expression<String>? businessId,
    Expression<String>? businessLocationId,
    Expression<String>? name,
    Expression<String>? unitOfMeasure,
    Expression<String>? unitId,
    Expression<String>? category,
    Expression<String>? reorderThreshold,
    Expression<String>? reorderQuantity,
    Expression<String>? sellingPrice,
    Expression<String>? unitCost,
    Expression<bool>? allowNegativeStock,
    Expression<String>? itemType,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAtServer,
    Expression<DateTime>? updatedAtServer,
    Expression<DateTime>? lastSeenAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<String>? imageUrl,
    Expression<String>? supplierId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (businessLocationId != null)
        'business_location_id': businessLocationId,
      if (name != null) 'name': name,
      if (unitOfMeasure != null) 'unit_of_measure': unitOfMeasure,
      if (unitId != null) 'unit_id': unitId,
      if (category != null) 'category': category,
      if (reorderThreshold != null) 'reorder_threshold': reorderThreshold,
      if (reorderQuantity != null) 'reorder_quantity': reorderQuantity,
      if (sellingPrice != null) 'selling_price': sellingPrice,
      if (unitCost != null) 'unit_cost': unitCost,
      if (allowNegativeStock != null)
        'allow_negative_stock': allowNegativeStock,
      if (itemType != null) 'item_type': itemType,
      if (isActive != null) 'is_active': isActive,
      if (createdAtServer != null) 'created_at_server': createdAtServer,
      if (updatedAtServer != null) 'updated_at_server': updatedAtServer,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (imageUrl != null) 'image_url': imageUrl,
      if (supplierId != null) 'supplier_id': supplierId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? businessId,
    Value<String>? businessLocationId,
    Value<String>? name,
    Value<String>? unitOfMeasure,
    Value<String>? unitId,
    Value<String?>? category,
    Value<Decimal>? reorderThreshold,
    Value<Decimal>? reorderQuantity,
    Value<Decimal?>? sellingPrice,
    Value<Decimal?>? unitCost,
    Value<bool>? allowNegativeStock,
    Value<String>? itemType,
    Value<bool>? isActive,
    Value<DateTime>? createdAtServer,
    Value<DateTime>? updatedAtServer,
    Value<DateTime>? lastSeenAt,
    Value<DateTime>? lastSyncedAt,
    Value<String?>? imageUrl,
    Value<String>? supplierId,
    Value<int>? rowid,
  }) {
    return CachedItemsCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      businessLocationId: businessLocationId ?? this.businessLocationId,
      name: name ?? this.name,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      unitId: unitId ?? this.unitId,
      category: category ?? this.category,
      reorderThreshold: reorderThreshold ?? this.reorderThreshold,
      reorderQuantity: reorderQuantity ?? this.reorderQuantity,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      unitCost: unitCost ?? this.unitCost,
      allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
      itemType: itemType ?? this.itemType,
      isActive: isActive ?? this.isActive,
      createdAtServer: createdAtServer ?? this.createdAtServer,
      updatedAtServer: updatedAtServer ?? this.updatedAtServer,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      supplierId: supplierId ?? this.supplierId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (businessLocationId.present) {
      map['business_location_id'] = Variable<String>(businessLocationId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (unitOfMeasure.present) {
      map['unit_of_measure'] = Variable<String>(unitOfMeasure.value);
    }
    if (unitId.present) {
      map['unit_id'] = Variable<String>(unitId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (reorderThreshold.present) {
      map['reorder_threshold'] = Variable<String>(
        $CachedItemsTable.$converterreorderThreshold.toSql(
          reorderThreshold.value,
        ),
      );
    }
    if (reorderQuantity.present) {
      map['reorder_quantity'] = Variable<String>(
        $CachedItemsTable.$converterreorderQuantity.toSql(
          reorderQuantity.value,
        ),
      );
    }
    if (sellingPrice.present) {
      map['selling_price'] = Variable<String>(
        $CachedItemsTable.$convertersellingPricen.toSql(sellingPrice.value),
      );
    }
    if (unitCost.present) {
      map['unit_cost'] = Variable<String>(
        $CachedItemsTable.$converterunitCostn.toSql(unitCost.value),
      );
    }
    if (allowNegativeStock.present) {
      map['allow_negative_stock'] = Variable<bool>(allowNegativeStock.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAtServer.present) {
      map['created_at_server'] = Variable<DateTime>(createdAtServer.value);
    }
    if (updatedAtServer.present) {
      map['updated_at_server'] = Variable<DateTime>(updatedAtServer.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedItemsCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('businessLocationId: $businessLocationId, ')
          ..write('name: $name, ')
          ..write('unitOfMeasure: $unitOfMeasure, ')
          ..write('unitId: $unitId, ')
          ..write('category: $category, ')
          ..write('reorderThreshold: $reorderThreshold, ')
          ..write('reorderQuantity: $reorderQuantity, ')
          ..write('sellingPrice: $sellingPrice, ')
          ..write('unitCost: $unitCost, ')
          ..write('allowNegativeStock: $allowNegativeStock, ')
          ..write('itemType: $itemType, ')
          ..write('isActive: $isActive, ')
          ..write('createdAtServer: $createdAtServer, ')
          ..write('updatedAtServer: $updatedAtServer, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('supplierId: $supplierId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedPermissionsTable extends CachedPermissions
    with TableInfo<$CachedPermissionsTable, CachedPermission> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedPermissionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_user_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessNameMeta = const VerificationMeta(
    'businessName',
  );
  @override
  late final GeneratedColumn<String> businessName = GeneratedColumn<String>(
    'business_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessLocationIdMeta =
      const VerificationMeta('businessLocationId');
  @override
  late final GeneratedColumn<String> businessLocationId =
      GeneratedColumn<String>(
        'business_location_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _roleNameMeta = const VerificationMeta(
    'roleName',
  );
  @override
  late final GeneratedColumn<String> roleName = GeneratedColumn<String>(
    'role_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _permissionCodesMeta = const VerificationMeta(
    'permissionCodes',
  );
  @override
  late final GeneratedColumn<String> permissionCodes = GeneratedColumn<String>(
    'permission_codes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    businessId,
    businessName,
    businessLocationId,
    roleName,
    permissionCodes,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_permissions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedPermission> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('business_name')) {
      context.handle(
        _businessNameMeta,
        businessName.isAcceptableOrUnknown(
          data['business_name']!,
          _businessNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_businessNameMeta);
    }
    if (data.containsKey('business_location_id')) {
      context.handle(
        _businessLocationIdMeta,
        businessLocationId.isAcceptableOrUnknown(
          data['business_location_id']!,
          _businessLocationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_businessLocationIdMeta);
    }
    if (data.containsKey('role_name')) {
      context.handle(
        _roleNameMeta,
        roleName.isAcceptableOrUnknown(data['role_name']!, _roleNameMeta),
      );
    } else if (isInserting) {
      context.missing(_roleNameMeta);
    }
    if (data.containsKey('permission_codes')) {
      context.handle(
        _permissionCodesMeta,
        permissionCodes.isAcceptableOrUnknown(
          data['permission_codes']!,
          _permissionCodesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_permissionCodesMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  CachedPermission map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedPermission(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      businessName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_name'],
      )!,
      businessLocationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_location_id'],
      )!,
      roleName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_name'],
      )!,
      permissionCodes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permission_codes'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedPermissionsTable createAlias(String alias) {
    return $CachedPermissionsTable(attachedDatabase, alias);
  }
}

class CachedPermission extends DataClass
    implements Insertable<CachedPermission> {
  /// Staff member's UUID; also the foreign key to `LocalUserProfiles.id`.
  final String userId;

  /// Business this permission set applies to.
  final String businessId;

  /// Cached business name for offline display.
  final String businessName;

  /// Business location this permission set applies to.
  final String businessLocationId;

  /// Cached display-only role name.
  final String roleName;

  /// JSON-encoded list of permission codes granted to this role.
  final String permissionCodes;

  /// When this permission set was last refreshed from the server.
  final DateTime cachedAt;
  const CachedPermission({
    required this.userId,
    required this.businessId,
    required this.businessName,
    required this.businessLocationId,
    required this.roleName,
    required this.permissionCodes,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['business_id'] = Variable<String>(businessId);
    map['business_name'] = Variable<String>(businessName);
    map['business_location_id'] = Variable<String>(businessLocationId);
    map['role_name'] = Variable<String>(roleName);
    map['permission_codes'] = Variable<String>(permissionCodes);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedPermissionsCompanion toCompanion(bool nullToAbsent) {
    return CachedPermissionsCompanion(
      userId: Value(userId),
      businessId: Value(businessId),
      businessName: Value(businessName),
      businessLocationId: Value(businessLocationId),
      roleName: Value(roleName),
      permissionCodes: Value(permissionCodes),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedPermission.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedPermission(
      userId: serializer.fromJson<String>(json['userId']),
      businessId: serializer.fromJson<String>(json['businessId']),
      businessName: serializer.fromJson<String>(json['businessName']),
      businessLocationId: serializer.fromJson<String>(
        json['businessLocationId'],
      ),
      roleName: serializer.fromJson<String>(json['roleName']),
      permissionCodes: serializer.fromJson<String>(json['permissionCodes']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'businessId': serializer.toJson<String>(businessId),
      'businessName': serializer.toJson<String>(businessName),
      'businessLocationId': serializer.toJson<String>(businessLocationId),
      'roleName': serializer.toJson<String>(roleName),
      'permissionCodes': serializer.toJson<String>(permissionCodes),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedPermission copyWith({
    String? userId,
    String? businessId,
    String? businessName,
    String? businessLocationId,
    String? roleName,
    String? permissionCodes,
    DateTime? cachedAt,
  }) => CachedPermission(
    userId: userId ?? this.userId,
    businessId: businessId ?? this.businessId,
    businessName: businessName ?? this.businessName,
    businessLocationId: businessLocationId ?? this.businessLocationId,
    roleName: roleName ?? this.roleName,
    permissionCodes: permissionCodes ?? this.permissionCodes,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedPermission copyWithCompanion(CachedPermissionsCompanion data) {
    return CachedPermission(
      userId: data.userId.present ? data.userId.value : this.userId,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      businessName: data.businessName.present
          ? data.businessName.value
          : this.businessName,
      businessLocationId: data.businessLocationId.present
          ? data.businessLocationId.value
          : this.businessLocationId,
      roleName: data.roleName.present ? data.roleName.value : this.roleName,
      permissionCodes: data.permissionCodes.present
          ? data.permissionCodes.value
          : this.permissionCodes,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedPermission(')
          ..write('userId: $userId, ')
          ..write('businessId: $businessId, ')
          ..write('businessName: $businessName, ')
          ..write('businessLocationId: $businessLocationId, ')
          ..write('roleName: $roleName, ')
          ..write('permissionCodes: $permissionCodes, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    businessId,
    businessName,
    businessLocationId,
    roleName,
    permissionCodes,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedPermission &&
          other.userId == this.userId &&
          other.businessId == this.businessId &&
          other.businessName == this.businessName &&
          other.businessLocationId == this.businessLocationId &&
          other.roleName == this.roleName &&
          other.permissionCodes == this.permissionCodes &&
          other.cachedAt == this.cachedAt);
}

class CachedPermissionsCompanion extends UpdateCompanion<CachedPermission> {
  final Value<String> userId;
  final Value<String> businessId;
  final Value<String> businessName;
  final Value<String> businessLocationId;
  final Value<String> roleName;
  final Value<String> permissionCodes;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedPermissionsCompanion({
    this.userId = const Value.absent(),
    this.businessId = const Value.absent(),
    this.businessName = const Value.absent(),
    this.businessLocationId = const Value.absent(),
    this.roleName = const Value.absent(),
    this.permissionCodes = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedPermissionsCompanion.insert({
    required String userId,
    required String businessId,
    required String businessName,
    required String businessLocationId,
    required String roleName,
    required String permissionCodes,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       businessId = Value(businessId),
       businessName = Value(businessName),
       businessLocationId = Value(businessLocationId),
       roleName = Value(roleName),
       permissionCodes = Value(permissionCodes),
       cachedAt = Value(cachedAt);
  static Insertable<CachedPermission> custom({
    Expression<String>? userId,
    Expression<String>? businessId,
    Expression<String>? businessName,
    Expression<String>? businessLocationId,
    Expression<String>? roleName,
    Expression<String>? permissionCodes,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (businessId != null) 'business_id': businessId,
      if (businessName != null) 'business_name': businessName,
      if (businessLocationId != null)
        'business_location_id': businessLocationId,
      if (roleName != null) 'role_name': roleName,
      if (permissionCodes != null) 'permission_codes': permissionCodes,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedPermissionsCompanion copyWith({
    Value<String>? userId,
    Value<String>? businessId,
    Value<String>? businessName,
    Value<String>? businessLocationId,
    Value<String>? roleName,
    Value<String>? permissionCodes,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedPermissionsCompanion(
      userId: userId ?? this.userId,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      businessLocationId: businessLocationId ?? this.businessLocationId,
      roleName: roleName ?? this.roleName,
      permissionCodes: permissionCodes ?? this.permissionCodes,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (businessName.present) {
      map['business_name'] = Variable<String>(businessName.value);
    }
    if (businessLocationId.present) {
      map['business_location_id'] = Variable<String>(businessLocationId.value);
    }
    if (roleName.present) {
      map['role_name'] = Variable<String>(roleName.value);
    }
    if (permissionCodes.present) {
      map['permission_codes'] = Variable<String>(permissionCodes.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedPermissionsCompanion(')
          ..write('userId: $userId, ')
          ..write('businessId: $businessId, ')
          ..write('businessName: $businessName, ')
          ..write('businessLocationId: $businessLocationId, ')
          ..write('roleName: $roleName, ')
          ..write('permissionCodes: $permissionCodes, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedStockLevelsTable extends CachedStockLevels
    with TableInfo<$CachedStockLevelsTable, CachedStockLevel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedStockLevelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessLocationIdMeta =
      const VerificationMeta('businessLocationId');
  @override
  late final GeneratedColumn<String> businessLocationId =
      GeneratedColumn<String>(
        'business_location_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> currentQuantity =
      GeneratedColumn<String>(
        'current_quantity',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>(
        $CachedStockLevelsTable.$convertercurrentQuantity,
      );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    itemId,
    businessLocationId,
    currentQuantity,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_stock_levels';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedStockLevel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('business_location_id')) {
      context.handle(
        _businessLocationIdMeta,
        businessLocationId.isAcceptableOrUnknown(
          data['business_location_id']!,
          _businessLocationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_businessLocationIdMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId, businessLocationId};
  @override
  CachedStockLevel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedStockLevel(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      businessLocationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_location_id'],
      )!,
      currentQuantity: $CachedStockLevelsTable.$convertercurrentQuantity
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}current_quantity'],
            )!,
          ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedStockLevelsTable createAlias(String alias) {
    return $CachedStockLevelsTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $convertercurrentQuantity =
      const DecimalConverter();
}

class CachedStockLevel extends DataClass
    implements Insertable<CachedStockLevel> {
  /// Item UUID from the inventory catalog.
  /// Soft-references `CachedItems.id` without an FK constraint
  /// (see `CachedItems` for rationale).
  final String itemId;

  /// Business location this stock level applies to.
  final String businessLocationId;

  /// Current on-hand quantity, as last reported by the server.
  final Decimal currentQuantity;

  /// When this stock level was last refreshed from the server.
  final DateTime cachedAt;
  const CachedStockLevel({
    required this.itemId,
    required this.businessLocationId,
    required this.currentQuantity,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['business_location_id'] = Variable<String>(businessLocationId);
    {
      map['current_quantity'] = Variable<String>(
        $CachedStockLevelsTable.$convertercurrentQuantity.toSql(
          currentQuantity,
        ),
      );
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedStockLevelsCompanion toCompanion(bool nullToAbsent) {
    return CachedStockLevelsCompanion(
      itemId: Value(itemId),
      businessLocationId: Value(businessLocationId),
      currentQuantity: Value(currentQuantity),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedStockLevel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedStockLevel(
      itemId: serializer.fromJson<String>(json['itemId']),
      businessLocationId: serializer.fromJson<String>(
        json['businessLocationId'],
      ),
      currentQuantity: serializer.fromJson<Decimal>(json['currentQuantity']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'businessLocationId': serializer.toJson<String>(businessLocationId),
      'currentQuantity': serializer.toJson<Decimal>(currentQuantity),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedStockLevel copyWith({
    String? itemId,
    String? businessLocationId,
    Decimal? currentQuantity,
    DateTime? cachedAt,
  }) => CachedStockLevel(
    itemId: itemId ?? this.itemId,
    businessLocationId: businessLocationId ?? this.businessLocationId,
    currentQuantity: currentQuantity ?? this.currentQuantity,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedStockLevel copyWithCompanion(CachedStockLevelsCompanion data) {
    return CachedStockLevel(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      businessLocationId: data.businessLocationId.present
          ? data.businessLocationId.value
          : this.businessLocationId,
      currentQuantity: data.currentQuantity.present
          ? data.currentQuantity.value
          : this.currentQuantity,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedStockLevel(')
          ..write('itemId: $itemId, ')
          ..write('businessLocationId: $businessLocationId, ')
          ..write('currentQuantity: $currentQuantity, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(itemId, businessLocationId, currentQuantity, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedStockLevel &&
          other.itemId == this.itemId &&
          other.businessLocationId == this.businessLocationId &&
          other.currentQuantity == this.currentQuantity &&
          other.cachedAt == this.cachedAt);
}

class CachedStockLevelsCompanion extends UpdateCompanion<CachedStockLevel> {
  final Value<String> itemId;
  final Value<String> businessLocationId;
  final Value<Decimal> currentQuantity;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedStockLevelsCompanion({
    this.itemId = const Value.absent(),
    this.businessLocationId = const Value.absent(),
    this.currentQuantity = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedStockLevelsCompanion.insert({
    required String itemId,
    required String businessLocationId,
    required Decimal currentQuantity,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       businessLocationId = Value(businessLocationId),
       currentQuantity = Value(currentQuantity),
       cachedAt = Value(cachedAt);
  static Insertable<CachedStockLevel> custom({
    Expression<String>? itemId,
    Expression<String>? businessLocationId,
    Expression<String>? currentQuantity,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (businessLocationId != null)
        'business_location_id': businessLocationId,
      if (currentQuantity != null) 'current_quantity': currentQuantity,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedStockLevelsCompanion copyWith({
    Value<String>? itemId,
    Value<String>? businessLocationId,
    Value<Decimal>? currentQuantity,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedStockLevelsCompanion(
      itemId: itemId ?? this.itemId,
      businessLocationId: businessLocationId ?? this.businessLocationId,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (businessLocationId.present) {
      map['business_location_id'] = Variable<String>(businessLocationId.value);
    }
    if (currentQuantity.present) {
      map['current_quantity'] = Variable<String>(
        $CachedStockLevelsTable.$convertercurrentQuantity.toSql(
          currentQuantity.value,
        ),
      );
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedStockLevelsCompanion(')
          ..write('itemId: $itemId, ')
          ..write('businessLocationId: $businessLocationId, ')
          ..write('currentQuantity: $currentQuantity, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedBusinessRolesTable extends CachedBusinessRoles
    with TableInfo<$CachedBusinessRolesTable, CachedBusinessRole> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedBusinessRolesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleIdMeta = const VerificationMeta('roleId');
  @override
  late final GeneratedColumn<String> roleId = GeneratedColumn<String>(
    'role_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isProtectedMeta = const VerificationMeta(
    'isProtected',
  );
  @override
  late final GeneratedColumn<bool> isProtected = GeneratedColumn<bool>(
    'is_protected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_protected" IN (0, 1))',
    ),
  );
  static const VerificationMeta _permissionCodesMeta = const VerificationMeta(
    'permissionCodes',
  );
  @override
  late final GeneratedColumn<String> permissionCodes = GeneratedColumn<String>(
    'permission_codes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    businessId,
    roleId,
    name,
    description,
    isProtected,
    permissionCodes,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_business_roles';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedBusinessRole> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('role_id')) {
      context.handle(
        _roleIdMeta,
        roleId.isAcceptableOrUnknown(data['role_id']!, _roleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roleIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('is_protected')) {
      context.handle(
        _isProtectedMeta,
        isProtected.isAcceptableOrUnknown(
          data['is_protected']!,
          _isProtectedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isProtectedMeta);
    }
    if (data.containsKey('permission_codes')) {
      context.handle(
        _permissionCodesMeta,
        permissionCodes.isAcceptableOrUnknown(
          data['permission_codes']!,
          _permissionCodesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_permissionCodesMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {businessId, roleId};
  @override
  CachedBusinessRole map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedBusinessRole(
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      roleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      isProtected: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_protected'],
      )!,
      permissionCodes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permission_codes'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedBusinessRolesTable createAlias(String alias) {
    return $CachedBusinessRolesTable(attachedDatabase, alias);
  }
}

class CachedBusinessRole extends DataClass
    implements Insertable<CachedBusinessRole> {
  /// The business these roles belong to.
  final String businessId;

  /// Role UUID from the backend.
  final String roleId;

  /// Role display name (e.g., "Manager", "Cashier").
  final String name;

  /// Role description.
  final String description;

  /// Whether this role is protected (system-defined).
  final bool isProtected;

  /// JSON-encoded list of permission codes for this role.
  final String permissionCodes;

  /// When this role cache was last refreshed from the server.
  final DateTime cachedAt;
  const CachedBusinessRole({
    required this.businessId,
    required this.roleId,
    required this.name,
    required this.description,
    required this.isProtected,
    required this.permissionCodes,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['business_id'] = Variable<String>(businessId);
    map['role_id'] = Variable<String>(roleId);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['is_protected'] = Variable<bool>(isProtected);
    map['permission_codes'] = Variable<String>(permissionCodes);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedBusinessRolesCompanion toCompanion(bool nullToAbsent) {
    return CachedBusinessRolesCompanion(
      businessId: Value(businessId),
      roleId: Value(roleId),
      name: Value(name),
      description: Value(description),
      isProtected: Value(isProtected),
      permissionCodes: Value(permissionCodes),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedBusinessRole.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedBusinessRole(
      businessId: serializer.fromJson<String>(json['businessId']),
      roleId: serializer.fromJson<String>(json['roleId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      isProtected: serializer.fromJson<bool>(json['isProtected']),
      permissionCodes: serializer.fromJson<String>(json['permissionCodes']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'businessId': serializer.toJson<String>(businessId),
      'roleId': serializer.toJson<String>(roleId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'isProtected': serializer.toJson<bool>(isProtected),
      'permissionCodes': serializer.toJson<String>(permissionCodes),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedBusinessRole copyWith({
    String? businessId,
    String? roleId,
    String? name,
    String? description,
    bool? isProtected,
    String? permissionCodes,
    DateTime? cachedAt,
  }) => CachedBusinessRole(
    businessId: businessId ?? this.businessId,
    roleId: roleId ?? this.roleId,
    name: name ?? this.name,
    description: description ?? this.description,
    isProtected: isProtected ?? this.isProtected,
    permissionCodes: permissionCodes ?? this.permissionCodes,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedBusinessRole copyWithCompanion(CachedBusinessRolesCompanion data) {
    return CachedBusinessRole(
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      roleId: data.roleId.present ? data.roleId.value : this.roleId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      isProtected: data.isProtected.present
          ? data.isProtected.value
          : this.isProtected,
      permissionCodes: data.permissionCodes.present
          ? data.permissionCodes.value
          : this.permissionCodes,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedBusinessRole(')
          ..write('businessId: $businessId, ')
          ..write('roleId: $roleId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isProtected: $isProtected, ')
          ..write('permissionCodes: $permissionCodes, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    businessId,
    roleId,
    name,
    description,
    isProtected,
    permissionCodes,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedBusinessRole &&
          other.businessId == this.businessId &&
          other.roleId == this.roleId &&
          other.name == this.name &&
          other.description == this.description &&
          other.isProtected == this.isProtected &&
          other.permissionCodes == this.permissionCodes &&
          other.cachedAt == this.cachedAt);
}

class CachedBusinessRolesCompanion extends UpdateCompanion<CachedBusinessRole> {
  final Value<String> businessId;
  final Value<String> roleId;
  final Value<String> name;
  final Value<String> description;
  final Value<bool> isProtected;
  final Value<String> permissionCodes;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedBusinessRolesCompanion({
    this.businessId = const Value.absent(),
    this.roleId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.isProtected = const Value.absent(),
    this.permissionCodes = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedBusinessRolesCompanion.insert({
    required String businessId,
    required String roleId,
    required String name,
    required String description,
    required bool isProtected,
    required String permissionCodes,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : businessId = Value(businessId),
       roleId = Value(roleId),
       name = Value(name),
       description = Value(description),
       isProtected = Value(isProtected),
       permissionCodes = Value(permissionCodes),
       cachedAt = Value(cachedAt);
  static Insertable<CachedBusinessRole> custom({
    Expression<String>? businessId,
    Expression<String>? roleId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<bool>? isProtected,
    Expression<String>? permissionCodes,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (businessId != null) 'business_id': businessId,
      if (roleId != null) 'role_id': roleId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (isProtected != null) 'is_protected': isProtected,
      if (permissionCodes != null) 'permission_codes': permissionCodes,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedBusinessRolesCompanion copyWith({
    Value<String>? businessId,
    Value<String>? roleId,
    Value<String>? name,
    Value<String>? description,
    Value<bool>? isProtected,
    Value<String>? permissionCodes,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedBusinessRolesCompanion(
      businessId: businessId ?? this.businessId,
      roleId: roleId ?? this.roleId,
      name: name ?? this.name,
      description: description ?? this.description,
      isProtected: isProtected ?? this.isProtected,
      permissionCodes: permissionCodes ?? this.permissionCodes,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (roleId.present) {
      map['role_id'] = Variable<String>(roleId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isProtected.present) {
      map['is_protected'] = Variable<bool>(isProtected.value);
    }
    if (permissionCodes.present) {
      map['permission_codes'] = Variable<String>(permissionCodes.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedBusinessRolesCompanion(')
          ..write('businessId: $businessId, ')
          ..write('roleId: $roleId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isProtected: $isProtected, ')
          ..write('permissionCodes: $permissionCodes, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedSalesTable extends CachedSales
    with TableInfo<$CachedSalesTable, CachedSale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedSalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientSaleIdMeta = const VerificationMeta(
    'clientSaleId',
  );
  @override
  late final GeneratedColumn<String> clientSaleId = GeneratedColumn<String>(
    'client_sale_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> subtotal =
      GeneratedColumn<String>(
        'subtotal',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($CachedSalesTable.$convertersubtotal);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> discountAmount =
      GeneratedColumn<String>(
        'discount_amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($CachedSalesTable.$converterdiscountAmount);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> taxAmount =
      GeneratedColumn<String>(
        'tax_amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($CachedSalesTable.$convertertaxAmount);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> total =
      GeneratedColumn<String>(
        'total',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($CachedSalesTable.$convertertotal);
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
    'actor_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voidedAtMeta = const VerificationMeta(
    'voidedAt',
  );
  @override
  late final GeneratedColumn<DateTime> voidedAt = GeneratedColumn<DateTime>(
    'voided_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _refundedAtMeta = const VerificationMeta(
    'refundedAt',
  );
  @override
  late final GeneratedColumn<DateTime> refundedAt = GeneratedColumn<DateTime>(
    'refunded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voidOrRefundReasonMeta =
      const VerificationMeta('voidOrRefundReason');
  @override
  late final GeneratedColumn<String> voidOrRefundReason =
      GeneratedColumn<String>(
        'void_or_refund_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    storeId,
    clientSaleId,
    status,
    subtotal,
    discountAmount,
    taxAmount,
    total,
    paymentMethod,
    actorId,
    customerId,
    occurredAt,
    syncedAt,
    voidedAt,
    refundedAt,
    voidOrRefundReason,
    createdAt,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_sales';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedSale> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('client_sale_id')) {
      context.handle(
        _clientSaleIdMeta,
        clientSaleId.isAcceptableOrUnknown(
          data['client_sale_id']!,
          _clientSaleIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientSaleIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentMethodMeta);
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    if (data.containsKey('voided_at')) {
      context.handle(
        _voidedAtMeta,
        voidedAt.isAcceptableOrUnknown(data['voided_at']!, _voidedAtMeta),
      );
    }
    if (data.containsKey('refunded_at')) {
      context.handle(
        _refundedAtMeta,
        refundedAt.isAcceptableOrUnknown(data['refunded_at']!, _refundedAtMeta),
      );
    }
    if (data.containsKey('void_or_refund_reason')) {
      context.handle(
        _voidOrRefundReasonMeta,
        voidOrRefundReason.isAcceptableOrUnknown(
          data['void_or_refund_reason']!,
          _voidOrRefundReasonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedSale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedSale(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      clientSaleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_sale_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      subtotal: $CachedSalesTable.$convertersubtotal.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}subtotal'],
        )!,
      ),
      discountAmount: $CachedSalesTable.$converterdiscountAmount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}discount_amount'],
        )!,
      ),
      taxAmount: $CachedSalesTable.$convertertaxAmount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tax_amount'],
        )!,
      ),
      total: $CachedSalesTable.$convertertotal.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}total'],
        )!,
      ),
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_id'],
      ),
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
      voidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}voided_at'],
      ),
      refundedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}refunded_at'],
      ),
      voidOrRefundReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_or_refund_reason'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
    );
  }

  @override
  $CachedSalesTable createAlias(String alias) {
    return $CachedSalesTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $convertersubtotal =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $converterdiscountAmount =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $convertertaxAmount =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $convertertotal =
      const DecimalConverter();
}

class CachedSale extends DataClass implements Insertable<CachedSale> {
  /// Sale UUID, assigned by POS Service (primary key).
  final String id;

  /// Business this sale belongs to.
  final String businessId;

  /// Store/location this sale was rung up at.
  final String storeId;

  /// Client-generated idempotency key this sale was created from.
  final String clientSaleId;

  /// Sale status: `completed`, `voided`, or `refunded`.
  final String status;
  final Decimal subtotal;
  final Decimal discountAmount;
  final Decimal taxAmount;
  final Decimal total;

  /// Payment method: `cash`, `mobile_money`, `card`, or `other`.
  final String paymentMethod;

  /// Staff member who rang up the sale, if known.
  final String? actorId;

  /// Customer this sale is attributed to, if any. Mirrors the backend's
  /// `SaleRead.customer_id`.
  final String? customerId;

  /// When the sale occurred (device-reported time, UTC) — the timestamp the
  /// backend sorts and filters the ledger by.
  final DateTime occurredAt;

  /// When POS Service accepted this sale.
  final DateTime syncedAt;
  final DateTime? voidedAt;
  final DateTime? refundedAt;
  final String? voidOrRefundReason;

  /// Backend creation timestamp.
  final DateTime createdAt;

  /// Local timestamp of the most recent pull that included this row.
  final DateTime lastSyncedAt;
  const CachedSale({
    required this.id,
    required this.businessId,
    required this.storeId,
    required this.clientSaleId,
    required this.status,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.total,
    required this.paymentMethod,
    this.actorId,
    this.customerId,
    required this.occurredAt,
    required this.syncedAt,
    this.voidedAt,
    this.refundedAt,
    this.voidOrRefundReason,
    required this.createdAt,
    required this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['business_id'] = Variable<String>(businessId);
    map['store_id'] = Variable<String>(storeId);
    map['client_sale_id'] = Variable<String>(clientSaleId);
    map['status'] = Variable<String>(status);
    {
      map['subtotal'] = Variable<String>(
        $CachedSalesTable.$convertersubtotal.toSql(subtotal),
      );
    }
    {
      map['discount_amount'] = Variable<String>(
        $CachedSalesTable.$converterdiscountAmount.toSql(discountAmount),
      );
    }
    {
      map['tax_amount'] = Variable<String>(
        $CachedSalesTable.$convertertaxAmount.toSql(taxAmount),
      );
    }
    {
      map['total'] = Variable<String>(
        $CachedSalesTable.$convertertotal.toSql(total),
      );
    }
    map['payment_method'] = Variable<String>(paymentMethod);
    if (!nullToAbsent || actorId != null) {
      map['actor_id'] = Variable<String>(actorId);
    }
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    if (!nullToAbsent || voidedAt != null) {
      map['voided_at'] = Variable<DateTime>(voidedAt);
    }
    if (!nullToAbsent || refundedAt != null) {
      map['refunded_at'] = Variable<DateTime>(refundedAt);
    }
    if (!nullToAbsent || voidOrRefundReason != null) {
      map['void_or_refund_reason'] = Variable<String>(voidOrRefundReason);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    return map;
  }

  CachedSalesCompanion toCompanion(bool nullToAbsent) {
    return CachedSalesCompanion(
      id: Value(id),
      businessId: Value(businessId),
      storeId: Value(storeId),
      clientSaleId: Value(clientSaleId),
      status: Value(status),
      subtotal: Value(subtotal),
      discountAmount: Value(discountAmount),
      taxAmount: Value(taxAmount),
      total: Value(total),
      paymentMethod: Value(paymentMethod),
      actorId: actorId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorId),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      occurredAt: Value(occurredAt),
      syncedAt: Value(syncedAt),
      voidedAt: voidedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(voidedAt),
      refundedAt: refundedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(refundedAt),
      voidOrRefundReason: voidOrRefundReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidOrRefundReason),
      createdAt: Value(createdAt),
      lastSyncedAt: Value(lastSyncedAt),
    );
  }

  factory CachedSale.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedSale(
      id: serializer.fromJson<String>(json['id']),
      businessId: serializer.fromJson<String>(json['businessId']),
      storeId: serializer.fromJson<String>(json['storeId']),
      clientSaleId: serializer.fromJson<String>(json['clientSaleId']),
      status: serializer.fromJson<String>(json['status']),
      subtotal: serializer.fromJson<Decimal>(json['subtotal']),
      discountAmount: serializer.fromJson<Decimal>(json['discountAmount']),
      taxAmount: serializer.fromJson<Decimal>(json['taxAmount']),
      total: serializer.fromJson<Decimal>(json['total']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      actorId: serializer.fromJson<String?>(json['actorId']),
      customerId: serializer.fromJson<String?>(json['customerId']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
      voidedAt: serializer.fromJson<DateTime?>(json['voidedAt']),
      refundedAt: serializer.fromJson<DateTime?>(json['refundedAt']),
      voidOrRefundReason: serializer.fromJson<String?>(
        json['voidOrRefundReason'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'businessId': serializer.toJson<String>(businessId),
      'storeId': serializer.toJson<String>(storeId),
      'clientSaleId': serializer.toJson<String>(clientSaleId),
      'status': serializer.toJson<String>(status),
      'subtotal': serializer.toJson<Decimal>(subtotal),
      'discountAmount': serializer.toJson<Decimal>(discountAmount),
      'taxAmount': serializer.toJson<Decimal>(taxAmount),
      'total': serializer.toJson<Decimal>(total),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'actorId': serializer.toJson<String?>(actorId),
      'customerId': serializer.toJson<String?>(customerId),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
      'voidedAt': serializer.toJson<DateTime?>(voidedAt),
      'refundedAt': serializer.toJson<DateTime?>(refundedAt),
      'voidOrRefundReason': serializer.toJson<String?>(voidOrRefundReason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
    };
  }

  CachedSale copyWith({
    String? id,
    String? businessId,
    String? storeId,
    String? clientSaleId,
    String? status,
    Decimal? subtotal,
    Decimal? discountAmount,
    Decimal? taxAmount,
    Decimal? total,
    String? paymentMethod,
    Value<String?> actorId = const Value.absent(),
    Value<String?> customerId = const Value.absent(),
    DateTime? occurredAt,
    DateTime? syncedAt,
    Value<DateTime?> voidedAt = const Value.absent(),
    Value<DateTime?> refundedAt = const Value.absent(),
    Value<String?> voidOrRefundReason = const Value.absent(),
    DateTime? createdAt,
    DateTime? lastSyncedAt,
  }) => CachedSale(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    storeId: storeId ?? this.storeId,
    clientSaleId: clientSaleId ?? this.clientSaleId,
    status: status ?? this.status,
    subtotal: subtotal ?? this.subtotal,
    discountAmount: discountAmount ?? this.discountAmount,
    taxAmount: taxAmount ?? this.taxAmount,
    total: total ?? this.total,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    actorId: actorId.present ? actorId.value : this.actorId,
    customerId: customerId.present ? customerId.value : this.customerId,
    occurredAt: occurredAt ?? this.occurredAt,
    syncedAt: syncedAt ?? this.syncedAt,
    voidedAt: voidedAt.present ? voidedAt.value : this.voidedAt,
    refundedAt: refundedAt.present ? refundedAt.value : this.refundedAt,
    voidOrRefundReason: voidOrRefundReason.present
        ? voidOrRefundReason.value
        : this.voidOrRefundReason,
    createdAt: createdAt ?? this.createdAt,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
  CachedSale copyWithCompanion(CachedSalesCompanion data) {
    return CachedSale(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      clientSaleId: data.clientSaleId.present
          ? data.clientSaleId.value
          : this.clientSaleId,
      status: data.status.present ? data.status.value : this.status,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
      discountAmount: data.discountAmount.present
          ? data.discountAmount.value
          : this.discountAmount,
      taxAmount: data.taxAmount.present ? data.taxAmount.value : this.taxAmount,
      total: data.total.present ? data.total.value : this.total,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      voidedAt: data.voidedAt.present ? data.voidedAt.value : this.voidedAt,
      refundedAt: data.refundedAt.present
          ? data.refundedAt.value
          : this.refundedAt,
      voidOrRefundReason: data.voidOrRefundReason.present
          ? data.voidOrRefundReason.value
          : this.voidOrRefundReason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedSale(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('storeId: $storeId, ')
          ..write('clientSaleId: $clientSaleId, ')
          ..write('status: $status, ')
          ..write('subtotal: $subtotal, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('taxAmount: $taxAmount, ')
          ..write('total: $total, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('actorId: $actorId, ')
          ..write('customerId: $customerId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('refundedAt: $refundedAt, ')
          ..write('voidOrRefundReason: $voidOrRefundReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    storeId,
    clientSaleId,
    status,
    subtotal,
    discountAmount,
    taxAmount,
    total,
    paymentMethod,
    actorId,
    customerId,
    occurredAt,
    syncedAt,
    voidedAt,
    refundedAt,
    voidOrRefundReason,
    createdAt,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedSale &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.storeId == this.storeId &&
          other.clientSaleId == this.clientSaleId &&
          other.status == this.status &&
          other.subtotal == this.subtotal &&
          other.discountAmount == this.discountAmount &&
          other.taxAmount == this.taxAmount &&
          other.total == this.total &&
          other.paymentMethod == this.paymentMethod &&
          other.actorId == this.actorId &&
          other.customerId == this.customerId &&
          other.occurredAt == this.occurredAt &&
          other.syncedAt == this.syncedAt &&
          other.voidedAt == this.voidedAt &&
          other.refundedAt == this.refundedAt &&
          other.voidOrRefundReason == this.voidOrRefundReason &&
          other.createdAt == this.createdAt &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class CachedSalesCompanion extends UpdateCompanion<CachedSale> {
  final Value<String> id;
  final Value<String> businessId;
  final Value<String> storeId;
  final Value<String> clientSaleId;
  final Value<String> status;
  final Value<Decimal> subtotal;
  final Value<Decimal> discountAmount;
  final Value<Decimal> taxAmount;
  final Value<Decimal> total;
  final Value<String> paymentMethod;
  final Value<String?> actorId;
  final Value<String?> customerId;
  final Value<DateTime> occurredAt;
  final Value<DateTime> syncedAt;
  final Value<DateTime?> voidedAt;
  final Value<DateTime?> refundedAt;
  final Value<String?> voidOrRefundReason;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastSyncedAt;
  final Value<int> rowid;
  const CachedSalesCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.storeId = const Value.absent(),
    this.clientSaleId = const Value.absent(),
    this.status = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.discountAmount = const Value.absent(),
    this.taxAmount = const Value.absent(),
    this.total = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.actorId = const Value.absent(),
    this.customerId = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.refundedAt = const Value.absent(),
    this.voidOrRefundReason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedSalesCompanion.insert({
    required String id,
    required String businessId,
    required String storeId,
    required String clientSaleId,
    required String status,
    required Decimal subtotal,
    required Decimal discountAmount,
    required Decimal taxAmount,
    required Decimal total,
    required String paymentMethod,
    this.actorId = const Value.absent(),
    this.customerId = const Value.absent(),
    required DateTime occurredAt,
    required DateTime syncedAt,
    this.voidedAt = const Value.absent(),
    this.refundedAt = const Value.absent(),
    this.voidOrRefundReason = const Value.absent(),
    required DateTime createdAt,
    required DateTime lastSyncedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessId = Value(businessId),
       storeId = Value(storeId),
       clientSaleId = Value(clientSaleId),
       status = Value(status),
       subtotal = Value(subtotal),
       discountAmount = Value(discountAmount),
       taxAmount = Value(taxAmount),
       total = Value(total),
       paymentMethod = Value(paymentMethod),
       occurredAt = Value(occurredAt),
       syncedAt = Value(syncedAt),
       createdAt = Value(createdAt),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<CachedSale> custom({
    Expression<String>? id,
    Expression<String>? businessId,
    Expression<String>? storeId,
    Expression<String>? clientSaleId,
    Expression<String>? status,
    Expression<String>? subtotal,
    Expression<String>? discountAmount,
    Expression<String>? taxAmount,
    Expression<String>? total,
    Expression<String>? paymentMethod,
    Expression<String>? actorId,
    Expression<String>? customerId,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? voidedAt,
    Expression<DateTime>? refundedAt,
    Expression<String>? voidOrRefundReason,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (storeId != null) 'store_id': storeId,
      if (clientSaleId != null) 'client_sale_id': clientSaleId,
      if (status != null) 'status': status,
      if (subtotal != null) 'subtotal': subtotal,
      if (discountAmount != null) 'discount_amount': discountAmount,
      if (taxAmount != null) 'tax_amount': taxAmount,
      if (total != null) 'total': total,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (actorId != null) 'actor_id': actorId,
      if (customerId != null) 'customer_id': customerId,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (voidedAt != null) 'voided_at': voidedAt,
      if (refundedAt != null) 'refunded_at': refundedAt,
      if (voidOrRefundReason != null)
        'void_or_refund_reason': voidOrRefundReason,
      if (createdAt != null) 'created_at': createdAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedSalesCompanion copyWith({
    Value<String>? id,
    Value<String>? businessId,
    Value<String>? storeId,
    Value<String>? clientSaleId,
    Value<String>? status,
    Value<Decimal>? subtotal,
    Value<Decimal>? discountAmount,
    Value<Decimal>? taxAmount,
    Value<Decimal>? total,
    Value<String>? paymentMethod,
    Value<String?>? actorId,
    Value<String?>? customerId,
    Value<DateTime>? occurredAt,
    Value<DateTime>? syncedAt,
    Value<DateTime?>? voidedAt,
    Value<DateTime?>? refundedAt,
    Value<String?>? voidOrRefundReason,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return CachedSalesCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      storeId: storeId ?? this.storeId,
      clientSaleId: clientSaleId ?? this.clientSaleId,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      actorId: actorId ?? this.actorId,
      customerId: customerId ?? this.customerId,
      occurredAt: occurredAt ?? this.occurredAt,
      syncedAt: syncedAt ?? this.syncedAt,
      voidedAt: voidedAt ?? this.voidedAt,
      refundedAt: refundedAt ?? this.refundedAt,
      voidOrRefundReason: voidOrRefundReason ?? this.voidOrRefundReason,
      createdAt: createdAt ?? this.createdAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (clientSaleId.present) {
      map['client_sale_id'] = Variable<String>(clientSaleId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<String>(
        $CachedSalesTable.$convertersubtotal.toSql(subtotal.value),
      );
    }
    if (discountAmount.present) {
      map['discount_amount'] = Variable<String>(
        $CachedSalesTable.$converterdiscountAmount.toSql(discountAmount.value),
      );
    }
    if (taxAmount.present) {
      map['tax_amount'] = Variable<String>(
        $CachedSalesTable.$convertertaxAmount.toSql(taxAmount.value),
      );
    }
    if (total.present) {
      map['total'] = Variable<String>(
        $CachedSalesTable.$convertertotal.toSql(total.value),
      );
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (voidedAt.present) {
      map['voided_at'] = Variable<DateTime>(voidedAt.value);
    }
    if (refundedAt.present) {
      map['refunded_at'] = Variable<DateTime>(refundedAt.value);
    }
    if (voidOrRefundReason.present) {
      map['void_or_refund_reason'] = Variable<String>(voidOrRefundReason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedSalesCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('storeId: $storeId, ')
          ..write('clientSaleId: $clientSaleId, ')
          ..write('status: $status, ')
          ..write('subtotal: $subtotal, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('taxAmount: $taxAmount, ')
          ..write('total: $total, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('actorId: $actorId, ')
          ..write('customerId: $customerId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('refundedAt: $refundedAt, ')
          ..write('voidOrRefundReason: $voidOrRefundReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedSaleLineItemsTable extends CachedSaleLineItems
    with TableInfo<$CachedSaleLineItemsTable, CachedSaleLineItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedSaleLineItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _saleIdMeta = const VerificationMeta('saleId');
  @override
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cached_sales (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> quantity =
      GeneratedColumn<String>(
        'quantity',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($CachedSaleLineItemsTable.$converterquantity);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> unitPrice =
      GeneratedColumn<String>(
        'unit_price',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($CachedSaleLineItemsTable.$converterunitPrice);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> discountAmount =
      GeneratedColumn<String>(
        'discount_amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>(
        $CachedSaleLineItemsTable.$converterdiscountAmount,
      );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> lineTotal =
      GeneratedColumn<String>(
        'line_total',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($CachedSaleLineItemsTable.$converterlineTotal);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal?, String> unitCost =
      GeneratedColumn<String>(
        'unit_cost',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Decimal?>($CachedSaleLineItemsTable.$converterunitCostn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    saleId,
    itemId,
    quantity,
    unitPrice,
    discountAmount,
    lineTotal,
    unitCost,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_sale_line_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedSaleLineItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sale_id')) {
      context.handle(
        _saleIdMeta,
        saleId.isAcceptableOrUnknown(data['sale_id']!, _saleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_saleIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedSaleLineItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedSaleLineItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      saleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      quantity: $CachedSaleLineItemsTable.$converterquantity.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}quantity'],
        )!,
      ),
      unitPrice: $CachedSaleLineItemsTable.$converterunitPrice.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}unit_price'],
        )!,
      ),
      discountAmount: $CachedSaleLineItemsTable.$converterdiscountAmount
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}discount_amount'],
            )!,
          ),
      lineTotal: $CachedSaleLineItemsTable.$converterlineTotal.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}line_total'],
        )!,
      ),
      unitCost: $CachedSaleLineItemsTable.$converterunitCostn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}unit_cost'],
        ),
      ),
    );
  }

  @override
  $CachedSaleLineItemsTable createAlias(String alias) {
    return $CachedSaleLineItemsTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converterquantity =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $converterunitPrice =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $converterdiscountAmount =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $converterlineTotal =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $converterunitCost =
      const DecimalConverter();
  static TypeConverter<Decimal?, String?> $converterunitCostn =
      NullAwareTypeConverter.wrap($converterunitCost);
}

class CachedSaleLineItem extends DataClass
    implements Insertable<CachedSaleLineItem> {
  /// Line item UUID, assigned by POS Service (primary key).
  final String id;

  /// The sale this line belongs to.
  final String saleId;

  /// Item UUID from the inventory catalog.
  /// Soft-references `CachedItems.id` without an FK constraint, matching
  /// `PendingSaleLineItems` — a completed sale's line stays valid even if
  /// the item is later retired from the catalog.
  final String itemId;
  final Decimal quantity;
  final Decimal unitPrice;
  final Decimal discountAmount;

  /// Server-computed `quantity*unitPrice - discountAmount`.
  final Decimal lineTotal;

  /// Per-unit production cost snapshot at sale time. Zero means
  /// unknown-but-frozen; null is legacy sales synced before snapshots
  /// existed — profit figures value those rows at live recipe costs and
  /// flag the total estimated.
  final Decimal? unitCost;
  const CachedSaleLineItem({
    required this.id,
    required this.saleId,
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    required this.lineTotal,
    this.unitCost,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sale_id'] = Variable<String>(saleId);
    map['item_id'] = Variable<String>(itemId);
    {
      map['quantity'] = Variable<String>(
        $CachedSaleLineItemsTable.$converterquantity.toSql(quantity),
      );
    }
    {
      map['unit_price'] = Variable<String>(
        $CachedSaleLineItemsTable.$converterunitPrice.toSql(unitPrice),
      );
    }
    {
      map['discount_amount'] = Variable<String>(
        $CachedSaleLineItemsTable.$converterdiscountAmount.toSql(
          discountAmount,
        ),
      );
    }
    {
      map['line_total'] = Variable<String>(
        $CachedSaleLineItemsTable.$converterlineTotal.toSql(lineTotal),
      );
    }
    if (!nullToAbsent || unitCost != null) {
      map['unit_cost'] = Variable<String>(
        $CachedSaleLineItemsTable.$converterunitCostn.toSql(unitCost),
      );
    }
    return map;
  }

  CachedSaleLineItemsCompanion toCompanion(bool nullToAbsent) {
    return CachedSaleLineItemsCompanion(
      id: Value(id),
      saleId: Value(saleId),
      itemId: Value(itemId),
      quantity: Value(quantity),
      unitPrice: Value(unitPrice),
      discountAmount: Value(discountAmount),
      lineTotal: Value(lineTotal),
      unitCost: unitCost == null && nullToAbsent
          ? const Value.absent()
          : Value(unitCost),
    );
  }

  factory CachedSaleLineItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedSaleLineItem(
      id: serializer.fromJson<String>(json['id']),
      saleId: serializer.fromJson<String>(json['saleId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      quantity: serializer.fromJson<Decimal>(json['quantity']),
      unitPrice: serializer.fromJson<Decimal>(json['unitPrice']),
      discountAmount: serializer.fromJson<Decimal>(json['discountAmount']),
      lineTotal: serializer.fromJson<Decimal>(json['lineTotal']),
      unitCost: serializer.fromJson<Decimal?>(json['unitCost']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'saleId': serializer.toJson<String>(saleId),
      'itemId': serializer.toJson<String>(itemId),
      'quantity': serializer.toJson<Decimal>(quantity),
      'unitPrice': serializer.toJson<Decimal>(unitPrice),
      'discountAmount': serializer.toJson<Decimal>(discountAmount),
      'lineTotal': serializer.toJson<Decimal>(lineTotal),
      'unitCost': serializer.toJson<Decimal?>(unitCost),
    };
  }

  CachedSaleLineItem copyWith({
    String? id,
    String? saleId,
    String? itemId,
    Decimal? quantity,
    Decimal? unitPrice,
    Decimal? discountAmount,
    Decimal? lineTotal,
    Value<Decimal?> unitCost = const Value.absent(),
  }) => CachedSaleLineItem(
    id: id ?? this.id,
    saleId: saleId ?? this.saleId,
    itemId: itemId ?? this.itemId,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    discountAmount: discountAmount ?? this.discountAmount,
    lineTotal: lineTotal ?? this.lineTotal,
    unitCost: unitCost.present ? unitCost.value : this.unitCost,
  );
  CachedSaleLineItem copyWithCompanion(CachedSaleLineItemsCompanion data) {
    return CachedSaleLineItem(
      id: data.id.present ? data.id.value : this.id,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      discountAmount: data.discountAmount.present
          ? data.discountAmount.value
          : this.discountAmount,
      lineTotal: data.lineTotal.present ? data.lineTotal.value : this.lineTotal,
      unitCost: data.unitCost.present ? data.unitCost.value : this.unitCost,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedSaleLineItem(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('itemId: $itemId, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('lineTotal: $lineTotal, ')
          ..write('unitCost: $unitCost')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    saleId,
    itemId,
    quantity,
    unitPrice,
    discountAmount,
    lineTotal,
    unitCost,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedSaleLineItem &&
          other.id == this.id &&
          other.saleId == this.saleId &&
          other.itemId == this.itemId &&
          other.quantity == this.quantity &&
          other.unitPrice == this.unitPrice &&
          other.discountAmount == this.discountAmount &&
          other.lineTotal == this.lineTotal &&
          other.unitCost == this.unitCost);
}

class CachedSaleLineItemsCompanion extends UpdateCompanion<CachedSaleLineItem> {
  final Value<String> id;
  final Value<String> saleId;
  final Value<String> itemId;
  final Value<Decimal> quantity;
  final Value<Decimal> unitPrice;
  final Value<Decimal> discountAmount;
  final Value<Decimal> lineTotal;
  final Value<Decimal?> unitCost;
  final Value<int> rowid;
  const CachedSaleLineItemsCompanion({
    this.id = const Value.absent(),
    this.saleId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.discountAmount = const Value.absent(),
    this.lineTotal = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedSaleLineItemsCompanion.insert({
    required String id,
    required String saleId,
    required String itemId,
    required Decimal quantity,
    required Decimal unitPrice,
    required Decimal discountAmount,
    required Decimal lineTotal,
    this.unitCost = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       saleId = Value(saleId),
       itemId = Value(itemId),
       quantity = Value(quantity),
       unitPrice = Value(unitPrice),
       discountAmount = Value(discountAmount),
       lineTotal = Value(lineTotal);
  static Insertable<CachedSaleLineItem> custom({
    Expression<String>? id,
    Expression<String>? saleId,
    Expression<String>? itemId,
    Expression<String>? quantity,
    Expression<String>? unitPrice,
    Expression<String>? discountAmount,
    Expression<String>? lineTotal,
    Expression<String>? unitCost,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      if (itemId != null) 'item_id': itemId,
      if (quantity != null) 'quantity': quantity,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (discountAmount != null) 'discount_amount': discountAmount,
      if (lineTotal != null) 'line_total': lineTotal,
      if (unitCost != null) 'unit_cost': unitCost,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedSaleLineItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? saleId,
    Value<String>? itemId,
    Value<Decimal>? quantity,
    Value<Decimal>? unitPrice,
    Value<Decimal>? discountAmount,
    Value<Decimal>? lineTotal,
    Value<Decimal?>? unitCost,
    Value<int>? rowid,
  }) {
    return CachedSaleLineItemsCompanion(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      lineTotal: lineTotal ?? this.lineTotal,
      unitCost: unitCost ?? this.unitCost,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<String>(
        $CachedSaleLineItemsTable.$converterquantity.toSql(quantity.value),
      );
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<String>(
        $CachedSaleLineItemsTable.$converterunitPrice.toSql(unitPrice.value),
      );
    }
    if (discountAmount.present) {
      map['discount_amount'] = Variable<String>(
        $CachedSaleLineItemsTable.$converterdiscountAmount.toSql(
          discountAmount.value,
        ),
      );
    }
    if (lineTotal.present) {
      map['line_total'] = Variable<String>(
        $CachedSaleLineItemsTable.$converterlineTotal.toSql(lineTotal.value),
      );
    }
    if (unitCost.present) {
      map['unit_cost'] = Variable<String>(
        $CachedSaleLineItemsTable.$converterunitCostn.toSql(unitCost.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedSaleLineItemsCompanion(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('itemId: $itemId, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('lineTotal: $lineTotal, ')
          ..write('unitCost: $unitCost, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingVoidsRefundsTable extends PendingVoidsRefunds
    with TableInfo<$PendingVoidsRefundsTable, PendingVoidsRefund> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingVoidsRefundsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientActionIdMeta = const VerificationMeta(
    'clientActionId',
  );
  @override
  late final GeneratedColumn<String> clientActionId = GeneratedColumn<String>(
    'client_action_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _saleIdMeta = const VerificationMeta('saleId');
  @override
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pending_sales (client_sale_id)',
    ),
  );
  static const VerificationMeta _newStatusMeta = const VerificationMeta(
    'newStatus',
  );
  @override
  late final GeneratedColumn<String> newStatus = GeneratedColumn<String>(
    'new_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorUserIdMeta = const VerificationMeta(
    'actorUserId',
  );
  @override
  late final GeneratedColumn<String> actorUserId = GeneratedColumn<String>(
    'actor_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncAttemptCountMeta = const VerificationMeta(
    'syncAttemptCount',
  );
  @override
  late final GeneratedColumn<int> syncAttemptCount = GeneratedColumn<int>(
    'sync_attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientActionId,
    saleId,
    newStatus,
    reason,
    actorUserId,
    occurredAt,
    syncStatus,
    syncError,
    syncAttemptCount,
    lastAttemptAt,
    syncedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_voids_refunds';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingVoidsRefund> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_action_id')) {
      context.handle(
        _clientActionIdMeta,
        clientActionId.isAcceptableOrUnknown(
          data['client_action_id']!,
          _clientActionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientActionIdMeta);
    }
    if (data.containsKey('sale_id')) {
      context.handle(
        _saleIdMeta,
        saleId.isAcceptableOrUnknown(data['sale_id']!, _saleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_saleIdMeta);
    }
    if (data.containsKey('new_status')) {
      context.handle(
        _newStatusMeta,
        newStatus.isAcceptableOrUnknown(data['new_status']!, _newStatusMeta),
      );
    } else if (isInserting) {
      context.missing(_newStatusMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('actor_user_id')) {
      context.handle(
        _actorUserIdMeta,
        actorUserId.isAcceptableOrUnknown(
          data['actor_user_id']!,
          _actorUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actorUserIdMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
      );
    }
    if (data.containsKey('sync_attempt_count')) {
      context.handle(
        _syncAttemptCountMeta,
        syncAttemptCount.isAcceptableOrUnknown(
          data['sync_attempt_count']!,
          _syncAttemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingVoidsRefund map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingVoidsRefund(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientActionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_action_id'],
      )!,
      saleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_id'],
      )!,
      newStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_status'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      actorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_user_id'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      ),
      syncAttemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_attempt_count'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingVoidsRefundsTable createAlias(String alias) {
    return $PendingVoidsRefundsTable(attachedDatabase, alias);
  }
}

class PendingVoidsRefund extends DataClass
    implements Insertable<PendingVoidsRefund> {
  /// Local row ID (autoincrement).
  final int id;

  /// Client-side idempotency key (UUID v4, unique).
  final String clientActionId;

  /// The already-synced sale this action applies to.
  final String saleId;

  /// Requested new status: `voided` or `refunded`.
  final String newStatus;

  /// Reason for the void/refund.
  final String reason;

  /// Staff member who performed the action.
  /// Soft-references `LocalUserProfiles.id` without an FK constraint: a
  /// profile that is later remotely revoked and deleted should not block
  /// or cascade-delete a historical void/refund record.
  final String actorUserId;

  /// When the void/refund occurred (device time, UTC).
  final DateTime occurredAt;

  /// Local sync state: `pending`, `syncing`, `failed`, `synced`.
  final String syncStatus;

  /// Error message from the last sync attempt, if any.
  final String? syncError;

  /// Number of times this action has been attempted.
  final int syncAttemptCount;

  /// Timestamp of the last sync attempt.
  final DateTime? lastAttemptAt;

  /// When the action was successfully synced to the backend.
  final DateTime? syncedAt;

  /// Local row creation timestamp.
  final DateTime createdAt;
  const PendingVoidsRefund({
    required this.id,
    required this.clientActionId,
    required this.saleId,
    required this.newStatus,
    required this.reason,
    required this.actorUserId,
    required this.occurredAt,
    required this.syncStatus,
    this.syncError,
    required this.syncAttemptCount,
    this.lastAttemptAt,
    this.syncedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_action_id'] = Variable<String>(clientActionId);
    map['sale_id'] = Variable<String>(saleId);
    map['new_status'] = Variable<String>(newStatus);
    map['reason'] = Variable<String>(reason);
    map['actor_user_id'] = Variable<String>(actorUserId);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    map['sync_attempt_count'] = Variable<int>(syncAttemptCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingVoidsRefundsCompanion toCompanion(bool nullToAbsent) {
    return PendingVoidsRefundsCompanion(
      id: Value(id),
      clientActionId: Value(clientActionId),
      saleId: Value(saleId),
      newStatus: Value(newStatus),
      reason: Value(reason),
      actorUserId: Value(actorUserId),
      occurredAt: Value(occurredAt),
      syncStatus: Value(syncStatus),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      syncAttemptCount: Value(syncAttemptCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      createdAt: Value(createdAt),
    );
  }

  factory PendingVoidsRefund.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingVoidsRefund(
      id: serializer.fromJson<int>(json['id']),
      clientActionId: serializer.fromJson<String>(json['clientActionId']),
      saleId: serializer.fromJson<String>(json['saleId']),
      newStatus: serializer.fromJson<String>(json['newStatus']),
      reason: serializer.fromJson<String>(json['reason']),
      actorUserId: serializer.fromJson<String>(json['actorUserId']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      syncAttemptCount: serializer.fromJson<int>(json['syncAttemptCount']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientActionId': serializer.toJson<String>(clientActionId),
      'saleId': serializer.toJson<String>(saleId),
      'newStatus': serializer.toJson<String>(newStatus),
      'reason': serializer.toJson<String>(reason),
      'actorUserId': serializer.toJson<String>(actorUserId),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncError': serializer.toJson<String?>(syncError),
      'syncAttemptCount': serializer.toJson<int>(syncAttemptCount),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingVoidsRefund copyWith({
    int? id,
    String? clientActionId,
    String? saleId,
    String? newStatus,
    String? reason,
    String? actorUserId,
    DateTime? occurredAt,
    String? syncStatus,
    Value<String?> syncError = const Value.absent(),
    int? syncAttemptCount,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
    DateTime? createdAt,
  }) => PendingVoidsRefund(
    id: id ?? this.id,
    clientActionId: clientActionId ?? this.clientActionId,
    saleId: saleId ?? this.saleId,
    newStatus: newStatus ?? this.newStatus,
    reason: reason ?? this.reason,
    actorUserId: actorUserId ?? this.actorUserId,
    occurredAt: occurredAt ?? this.occurredAt,
    syncStatus: syncStatus ?? this.syncStatus,
    syncError: syncError.present ? syncError.value : this.syncError,
    syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingVoidsRefund copyWithCompanion(PendingVoidsRefundsCompanion data) {
    return PendingVoidsRefund(
      id: data.id.present ? data.id.value : this.id,
      clientActionId: data.clientActionId.present
          ? data.clientActionId.value
          : this.clientActionId,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      newStatus: data.newStatus.present ? data.newStatus.value : this.newStatus,
      reason: data.reason.present ? data.reason.value : this.reason,
      actorUserId: data.actorUserId.present
          ? data.actorUserId.value
          : this.actorUserId,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      syncAttemptCount: data.syncAttemptCount.present
          ? data.syncAttemptCount.value
          : this.syncAttemptCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingVoidsRefund(')
          ..write('id: $id, ')
          ..write('clientActionId: $clientActionId, ')
          ..write('saleId: $saleId, ')
          ..write('newStatus: $newStatus, ')
          ..write('reason: $reason, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('syncAttemptCount: $syncAttemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientActionId,
    saleId,
    newStatus,
    reason,
    actorUserId,
    occurredAt,
    syncStatus,
    syncError,
    syncAttemptCount,
    lastAttemptAt,
    syncedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingVoidsRefund &&
          other.id == this.id &&
          other.clientActionId == this.clientActionId &&
          other.saleId == this.saleId &&
          other.newStatus == this.newStatus &&
          other.reason == this.reason &&
          other.actorUserId == this.actorUserId &&
          other.occurredAt == this.occurredAt &&
          other.syncStatus == this.syncStatus &&
          other.syncError == this.syncError &&
          other.syncAttemptCount == this.syncAttemptCount &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.syncedAt == this.syncedAt &&
          other.createdAt == this.createdAt);
}

class PendingVoidsRefundsCompanion extends UpdateCompanion<PendingVoidsRefund> {
  final Value<int> id;
  final Value<String> clientActionId;
  final Value<String> saleId;
  final Value<String> newStatus;
  final Value<String> reason;
  final Value<String> actorUserId;
  final Value<DateTime> occurredAt;
  final Value<String> syncStatus;
  final Value<String?> syncError;
  final Value<int> syncAttemptCount;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> syncedAt;
  final Value<DateTime> createdAt;
  const PendingVoidsRefundsCompanion({
    this.id = const Value.absent(),
    this.clientActionId = const Value.absent(),
    this.saleId = const Value.absent(),
    this.newStatus = const Value.absent(),
    this.reason = const Value.absent(),
    this.actorUserId = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncAttemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PendingVoidsRefundsCompanion.insert({
    this.id = const Value.absent(),
    required String clientActionId,
    required String saleId,
    required String newStatus,
    required String reason,
    required String actorUserId,
    required DateTime occurredAt,
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncAttemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required DateTime createdAt,
  }) : clientActionId = Value(clientActionId),
       saleId = Value(saleId),
       newStatus = Value(newStatus),
       reason = Value(reason),
       actorUserId = Value(actorUserId),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt);
  static Insertable<PendingVoidsRefund> custom({
    Expression<int>? id,
    Expression<String>? clientActionId,
    Expression<String>? saleId,
    Expression<String>? newStatus,
    Expression<String>? reason,
    Expression<String>? actorUserId,
    Expression<DateTime>? occurredAt,
    Expression<String>? syncStatus,
    Expression<String>? syncError,
    Expression<int>? syncAttemptCount,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientActionId != null) 'client_action_id': clientActionId,
      if (saleId != null) 'sale_id': saleId,
      if (newStatus != null) 'new_status': newStatus,
      if (reason != null) 'reason': reason,
      if (actorUserId != null) 'actor_user_id': actorUserId,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncError != null) 'sync_error': syncError,
      if (syncAttemptCount != null) 'sync_attempt_count': syncAttemptCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PendingVoidsRefundsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientActionId,
    Value<String>? saleId,
    Value<String>? newStatus,
    Value<String>? reason,
    Value<String>? actorUserId,
    Value<DateTime>? occurredAt,
    Value<String>? syncStatus,
    Value<String?>? syncError,
    Value<int>? syncAttemptCount,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime?>? syncedAt,
    Value<DateTime>? createdAt,
  }) {
    return PendingVoidsRefundsCompanion(
      id: id ?? this.id,
      clientActionId: clientActionId ?? this.clientActionId,
      saleId: saleId ?? this.saleId,
      newStatus: newStatus ?? this.newStatus,
      reason: reason ?? this.reason,
      actorUserId: actorUserId ?? this.actorUserId,
      occurredAt: occurredAt ?? this.occurredAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientActionId.present) {
      map['client_action_id'] = Variable<String>(clientActionId.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (newStatus.present) {
      map['new_status'] = Variable<String>(newStatus.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (actorUserId.present) {
      map['actor_user_id'] = Variable<String>(actorUserId.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (syncAttemptCount.present) {
      map['sync_attempt_count'] = Variable<int>(syncAttemptCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingVoidsRefundsCompanion(')
          ..write('id: $id, ')
          ..write('clientActionId: $clientActionId, ')
          ..write('saleId: $saleId, ')
          ..write('newStatus: $newStatus, ')
          ..write('reason: $reason, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('syncAttemptCount: $syncAttemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ExpenseEntriesTable extends ExpenseEntries
    with TableInfo<$ExpenseEntriesTable, ExpenseEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpenseEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _expenseIdMeta = const VerificationMeta(
    'expenseId',
  );
  @override
  late final GeneratedColumn<String> expenseId = GeneratedColumn<String>(
    'expense_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> amount =
      GeneratedColumn<String>(
        'amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($ExpenseEntriesTable.$converteramount);
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payeeMeta = const VerificationMeta('payee');
  @override
  late final GeneratedColumn<String> payee = GeneratedColumn<String>(
    'payee',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('other'),
  );
  static const VerificationMeta _receiptAttachmentIdMeta =
      const VerificationMeta('receiptAttachmentId');
  @override
  late final GeneratedColumn<String> receiptAttachmentId =
      GeneratedColumn<String>(
        'receipt_attachment_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _localReceiptPathMeta = const VerificationMeta(
    'localReceiptPath',
  );
  @override
  late final GeneratedColumn<String> localReceiptPath = GeneratedColumn<String>(
    'local_receipt_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorUserIdMeta = const VerificationMeta(
    'actorUserId',
  );
  @override
  late final GeneratedColumn<String> actorUserId = GeneratedColumn<String>(
    'actor_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncAttemptCountMeta = const VerificationMeta(
    'syncAttemptCount',
  );
  @override
  late final GeneratedColumn<int> syncAttemptCount = GeneratedColumn<int>(
    'sync_attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    expenseId,
    businessId,
    storeId,
    category,
    amount,
    description,
    payee,
    note,
    paymentMethod,
    receiptAttachmentId,
    localReceiptPath,
    occurredAt,
    actorUserId,
    serverId,
    syncStatus,
    syncError,
    syncAttemptCount,
    lastAttemptAt,
    syncedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expense_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpenseEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('expense_id')) {
      context.handle(
        _expenseIdMeta,
        expenseId.isAcceptableOrUnknown(data['expense_id']!, _expenseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_expenseIdMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('payee')) {
      context.handle(
        _payeeMeta,
        payee.isAcceptableOrUnknown(data['payee']!, _payeeMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    }
    if (data.containsKey('receipt_attachment_id')) {
      context.handle(
        _receiptAttachmentIdMeta,
        receiptAttachmentId.isAcceptableOrUnknown(
          data['receipt_attachment_id']!,
          _receiptAttachmentIdMeta,
        ),
      );
    }
    if (data.containsKey('local_receipt_path')) {
      context.handle(
        _localReceiptPathMeta,
        localReceiptPath.isAcceptableOrUnknown(
          data['local_receipt_path']!,
          _localReceiptPathMeta,
        ),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('actor_user_id')) {
      context.handle(
        _actorUserIdMeta,
        actorUserId.isAcceptableOrUnknown(
          data['actor_user_id']!,
          _actorUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actorUserIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
      );
    }
    if (data.containsKey('sync_attempt_count')) {
      context.handle(
        _syncAttemptCountMeta,
        syncAttemptCount.isAcceptableOrUnknown(
          data['sync_attempt_count']!,
          _syncAttemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExpenseEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpenseEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      expenseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expense_id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      amount: $ExpenseEntriesTable.$converteramount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}amount'],
        )!,
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      payee: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      receiptAttachmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_attachment_id'],
      ),
      localReceiptPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_receipt_path'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      actorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_user_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      ),
      syncAttemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_attempt_count'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExpenseEntriesTable createAlias(String alias) {
    return $ExpenseEntriesTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converteramount =
      const DecimalConverter();
}

class ExpenseEntry extends DataClass implements Insertable<ExpenseEntry> {
  /// Local row ID (autoincrement).
  final int id;

  /// Client-side idempotency key (UUID v4, unique).
  final String expenseId;

  /// Business this expense belongs to.
  final String businessId;

  /// Store/location this expense belongs to. Matches POS Service's
  /// `other_expenses.store_id` field (renamed from `businessLocationId`
  /// by schema v6, mirroring `PendingSales`'s own v5 rename).
  final String storeId;

  /// Expense category. Controlled list, not free text, so reporting stays
  /// meaningful — canonical list (mirrors
  /// `services/pos-service/app/models/finance.py::ExpenseCategory`):
  /// rent|utilities|salaries|repairs|supplies|marketing|insurance|
  /// professional_fees|other.
  final String category;

  /// Expense amount.
  final Decimal amount;

  /// Free-text description.
  final String? description;

  /// Who the expense was paid to.
  final String? payee;

  /// Optional free-text note.
  final String? note;

  /// Payment method used: cash|mobile_money|card|other.
  final String paymentMethod;

  /// Server-assigned id of the uploaded receipt (`FinanceAttachment.id`),
  /// set once `FinanceSyncService` has successfully uploaded `localReceiptPath`.
  final String? receiptAttachmentId;

  /// Device-local path to a receipt file awaiting upload. Cleared once
  /// `receiptAttachmentId` is set. See `finance_sync_service.dart`'s
  /// upload-before-sync ordering.
  final String? localReceiptPath;

  /// When the expense occurred (device time, UTC).
  final DateTime occurredAt;

  /// Staff member who recorded the expense.
  /// Soft-references `LocalUserProfiles.id` without an FK constraint: a
  /// profile that is later remotely revoked and deleted should not block
  /// or cascade-delete a historical expense record.
  final String actorUserId;

  /// Server-assigned id (`OtherExpense.id`), set once this row has synced.
  /// A row with a non-null `serverId` is edited/deleted via direct API
  /// calls (`FinanceApiService`), not the outbox.
  final String? serverId;

  /// Local sync state: `pending`, `syncing`, `failed`, `synced`.
  final String syncStatus;

  /// Error message from the last sync attempt, if any.
  final String? syncError;

  /// Number of times this entry has been attempted.
  final int syncAttemptCount;

  /// Timestamp of the last sync attempt.
  final DateTime? lastAttemptAt;

  /// When the entry was successfully synced to the backend.
  final DateTime? syncedAt;

  /// Local row creation timestamp.
  final DateTime createdAt;
  const ExpenseEntry({
    required this.id,
    required this.expenseId,
    required this.businessId,
    required this.storeId,
    required this.category,
    required this.amount,
    this.description,
    this.payee,
    this.note,
    required this.paymentMethod,
    this.receiptAttachmentId,
    this.localReceiptPath,
    required this.occurredAt,
    required this.actorUserId,
    this.serverId,
    required this.syncStatus,
    this.syncError,
    required this.syncAttemptCount,
    this.lastAttemptAt,
    this.syncedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['expense_id'] = Variable<String>(expenseId);
    map['business_id'] = Variable<String>(businessId);
    map['store_id'] = Variable<String>(storeId);
    map['category'] = Variable<String>(category);
    {
      map['amount'] = Variable<String>(
        $ExpenseEntriesTable.$converteramount.toSql(amount),
      );
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || payee != null) {
      map['payee'] = Variable<String>(payee);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['payment_method'] = Variable<String>(paymentMethod);
    if (!nullToAbsent || receiptAttachmentId != null) {
      map['receipt_attachment_id'] = Variable<String>(receiptAttachmentId);
    }
    if (!nullToAbsent || localReceiptPath != null) {
      map['local_receipt_path'] = Variable<String>(localReceiptPath);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['actor_user_id'] = Variable<String>(actorUserId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    map['sync_attempt_count'] = Variable<int>(syncAttemptCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ExpenseEntriesCompanion toCompanion(bool nullToAbsent) {
    return ExpenseEntriesCompanion(
      id: Value(id),
      expenseId: Value(expenseId),
      businessId: Value(businessId),
      storeId: Value(storeId),
      category: Value(category),
      amount: Value(amount),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      payee: payee == null && nullToAbsent
          ? const Value.absent()
          : Value(payee),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      paymentMethod: Value(paymentMethod),
      receiptAttachmentId: receiptAttachmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptAttachmentId),
      localReceiptPath: localReceiptPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localReceiptPath),
      occurredAt: Value(occurredAt),
      actorUserId: Value(actorUserId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      syncStatus: Value(syncStatus),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      syncAttemptCount: Value(syncAttemptCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      createdAt: Value(createdAt),
    );
  }

  factory ExpenseEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpenseEntry(
      id: serializer.fromJson<int>(json['id']),
      expenseId: serializer.fromJson<String>(json['expenseId']),
      businessId: serializer.fromJson<String>(json['businessId']),
      storeId: serializer.fromJson<String>(json['storeId']),
      category: serializer.fromJson<String>(json['category']),
      amount: serializer.fromJson<Decimal>(json['amount']),
      description: serializer.fromJson<String?>(json['description']),
      payee: serializer.fromJson<String?>(json['payee']),
      note: serializer.fromJson<String?>(json['note']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      receiptAttachmentId: serializer.fromJson<String?>(
        json['receiptAttachmentId'],
      ),
      localReceiptPath: serializer.fromJson<String?>(json['localReceiptPath']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      actorUserId: serializer.fromJson<String>(json['actorUserId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      syncAttemptCount: serializer.fromJson<int>(json['syncAttemptCount']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'expenseId': serializer.toJson<String>(expenseId),
      'businessId': serializer.toJson<String>(businessId),
      'storeId': serializer.toJson<String>(storeId),
      'category': serializer.toJson<String>(category),
      'amount': serializer.toJson<Decimal>(amount),
      'description': serializer.toJson<String?>(description),
      'payee': serializer.toJson<String?>(payee),
      'note': serializer.toJson<String?>(note),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'receiptAttachmentId': serializer.toJson<String?>(receiptAttachmentId),
      'localReceiptPath': serializer.toJson<String?>(localReceiptPath),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'actorUserId': serializer.toJson<String>(actorUserId),
      'serverId': serializer.toJson<String?>(serverId),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncError': serializer.toJson<String?>(syncError),
      'syncAttemptCount': serializer.toJson<int>(syncAttemptCount),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ExpenseEntry copyWith({
    int? id,
    String? expenseId,
    String? businessId,
    String? storeId,
    String? category,
    Decimal? amount,
    Value<String?> description = const Value.absent(),
    Value<String?> payee = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? paymentMethod,
    Value<String?> receiptAttachmentId = const Value.absent(),
    Value<String?> localReceiptPath = const Value.absent(),
    DateTime? occurredAt,
    String? actorUserId,
    Value<String?> serverId = const Value.absent(),
    String? syncStatus,
    Value<String?> syncError = const Value.absent(),
    int? syncAttemptCount,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
    DateTime? createdAt,
  }) => ExpenseEntry(
    id: id ?? this.id,
    expenseId: expenseId ?? this.expenseId,
    businessId: businessId ?? this.businessId,
    storeId: storeId ?? this.storeId,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    description: description.present ? description.value : this.description,
    payee: payee.present ? payee.value : this.payee,
    note: note.present ? note.value : this.note,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    receiptAttachmentId: receiptAttachmentId.present
        ? receiptAttachmentId.value
        : this.receiptAttachmentId,
    localReceiptPath: localReceiptPath.present
        ? localReceiptPath.value
        : this.localReceiptPath,
    occurredAt: occurredAt ?? this.occurredAt,
    actorUserId: actorUserId ?? this.actorUserId,
    serverId: serverId.present ? serverId.value : this.serverId,
    syncStatus: syncStatus ?? this.syncStatus,
    syncError: syncError.present ? syncError.value : this.syncError,
    syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  ExpenseEntry copyWithCompanion(ExpenseEntriesCompanion data) {
    return ExpenseEntry(
      id: data.id.present ? data.id.value : this.id,
      expenseId: data.expenseId.present ? data.expenseId.value : this.expenseId,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      category: data.category.present ? data.category.value : this.category,
      amount: data.amount.present ? data.amount.value : this.amount,
      description: data.description.present
          ? data.description.value
          : this.description,
      payee: data.payee.present ? data.payee.value : this.payee,
      note: data.note.present ? data.note.value : this.note,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      receiptAttachmentId: data.receiptAttachmentId.present
          ? data.receiptAttachmentId.value
          : this.receiptAttachmentId,
      localReceiptPath: data.localReceiptPath.present
          ? data.localReceiptPath.value
          : this.localReceiptPath,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      actorUserId: data.actorUserId.present
          ? data.actorUserId.value
          : this.actorUserId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      syncAttemptCount: data.syncAttemptCount.present
          ? data.syncAttemptCount.value
          : this.syncAttemptCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseEntry(')
          ..write('id: $id, ')
          ..write('expenseId: $expenseId, ')
          ..write('businessId: $businessId, ')
          ..write('storeId: $storeId, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('payee: $payee, ')
          ..write('note: $note, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('receiptAttachmentId: $receiptAttachmentId, ')
          ..write('localReceiptPath: $localReceiptPath, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('syncAttemptCount: $syncAttemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    expenseId,
    businessId,
    storeId,
    category,
    amount,
    description,
    payee,
    note,
    paymentMethod,
    receiptAttachmentId,
    localReceiptPath,
    occurredAt,
    actorUserId,
    serverId,
    syncStatus,
    syncError,
    syncAttemptCount,
    lastAttemptAt,
    syncedAt,
    createdAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseEntry &&
          other.id == this.id &&
          other.expenseId == this.expenseId &&
          other.businessId == this.businessId &&
          other.storeId == this.storeId &&
          other.category == this.category &&
          other.amount == this.amount &&
          other.description == this.description &&
          other.payee == this.payee &&
          other.note == this.note &&
          other.paymentMethod == this.paymentMethod &&
          other.receiptAttachmentId == this.receiptAttachmentId &&
          other.localReceiptPath == this.localReceiptPath &&
          other.occurredAt == this.occurredAt &&
          other.actorUserId == this.actorUserId &&
          other.serverId == this.serverId &&
          other.syncStatus == this.syncStatus &&
          other.syncError == this.syncError &&
          other.syncAttemptCount == this.syncAttemptCount &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.syncedAt == this.syncedAt &&
          other.createdAt == this.createdAt);
}

class ExpenseEntriesCompanion extends UpdateCompanion<ExpenseEntry> {
  final Value<int> id;
  final Value<String> expenseId;
  final Value<String> businessId;
  final Value<String> storeId;
  final Value<String> category;
  final Value<Decimal> amount;
  final Value<String?> description;
  final Value<String?> payee;
  final Value<String?> note;
  final Value<String> paymentMethod;
  final Value<String?> receiptAttachmentId;
  final Value<String?> localReceiptPath;
  final Value<DateTime> occurredAt;
  final Value<String> actorUserId;
  final Value<String?> serverId;
  final Value<String> syncStatus;
  final Value<String?> syncError;
  final Value<int> syncAttemptCount;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> syncedAt;
  final Value<DateTime> createdAt;
  const ExpenseEntriesCompanion({
    this.id = const Value.absent(),
    this.expenseId = const Value.absent(),
    this.businessId = const Value.absent(),
    this.storeId = const Value.absent(),
    this.category = const Value.absent(),
    this.amount = const Value.absent(),
    this.description = const Value.absent(),
    this.payee = const Value.absent(),
    this.note = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.receiptAttachmentId = const Value.absent(),
    this.localReceiptPath = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.actorUserId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncAttemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ExpenseEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String expenseId,
    required String businessId,
    required String storeId,
    required String category,
    required Decimal amount,
    this.description = const Value.absent(),
    this.payee = const Value.absent(),
    this.note = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.receiptAttachmentId = const Value.absent(),
    this.localReceiptPath = const Value.absent(),
    required DateTime occurredAt,
    required String actorUserId,
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncAttemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required DateTime createdAt,
  }) : expenseId = Value(expenseId),
       businessId = Value(businessId),
       storeId = Value(storeId),
       category = Value(category),
       amount = Value(amount),
       occurredAt = Value(occurredAt),
       actorUserId = Value(actorUserId),
       createdAt = Value(createdAt);
  static Insertable<ExpenseEntry> custom({
    Expression<int>? id,
    Expression<String>? expenseId,
    Expression<String>? businessId,
    Expression<String>? storeId,
    Expression<String>? category,
    Expression<String>? amount,
    Expression<String>? description,
    Expression<String>? payee,
    Expression<String>? note,
    Expression<String>? paymentMethod,
    Expression<String>? receiptAttachmentId,
    Expression<String>? localReceiptPath,
    Expression<DateTime>? occurredAt,
    Expression<String>? actorUserId,
    Expression<String>? serverId,
    Expression<String>? syncStatus,
    Expression<String>? syncError,
    Expression<int>? syncAttemptCount,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (expenseId != null) 'expense_id': expenseId,
      if (businessId != null) 'business_id': businessId,
      if (storeId != null) 'store_id': storeId,
      if (category != null) 'category': category,
      if (amount != null) 'amount': amount,
      if (description != null) 'description': description,
      if (payee != null) 'payee': payee,
      if (note != null) 'note': note,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (receiptAttachmentId != null)
        'receipt_attachment_id': receiptAttachmentId,
      if (localReceiptPath != null) 'local_receipt_path': localReceiptPath,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (actorUserId != null) 'actor_user_id': actorUserId,
      if (serverId != null) 'server_id': serverId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncError != null) 'sync_error': syncError,
      if (syncAttemptCount != null) 'sync_attempt_count': syncAttemptCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ExpenseEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? expenseId,
    Value<String>? businessId,
    Value<String>? storeId,
    Value<String>? category,
    Value<Decimal>? amount,
    Value<String?>? description,
    Value<String?>? payee,
    Value<String?>? note,
    Value<String>? paymentMethod,
    Value<String?>? receiptAttachmentId,
    Value<String?>? localReceiptPath,
    Value<DateTime>? occurredAt,
    Value<String>? actorUserId,
    Value<String?>? serverId,
    Value<String>? syncStatus,
    Value<String?>? syncError,
    Value<int>? syncAttemptCount,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime?>? syncedAt,
    Value<DateTime>? createdAt,
  }) {
    return ExpenseEntriesCompanion(
      id: id ?? this.id,
      expenseId: expenseId ?? this.expenseId,
      businessId: businessId ?? this.businessId,
      storeId: storeId ?? this.storeId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      payee: payee ?? this.payee,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptAttachmentId: receiptAttachmentId ?? this.receiptAttachmentId,
      localReceiptPath: localReceiptPath ?? this.localReceiptPath,
      occurredAt: occurredAt ?? this.occurredAt,
      actorUserId: actorUserId ?? this.actorUserId,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (expenseId.present) {
      map['expense_id'] = Variable<String>(expenseId.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(
        $ExpenseEntriesTable.$converteramount.toSql(amount.value),
      );
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (payee.present) {
      map['payee'] = Variable<String>(payee.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (receiptAttachmentId.present) {
      map['receipt_attachment_id'] = Variable<String>(
        receiptAttachmentId.value,
      );
    }
    if (localReceiptPath.present) {
      map['local_receipt_path'] = Variable<String>(localReceiptPath.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (actorUserId.present) {
      map['actor_user_id'] = Variable<String>(actorUserId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (syncAttemptCount.present) {
      map['sync_attempt_count'] = Variable<int>(syncAttemptCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseEntriesCompanion(')
          ..write('id: $id, ')
          ..write('expenseId: $expenseId, ')
          ..write('businessId: $businessId, ')
          ..write('storeId: $storeId, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('payee: $payee, ')
          ..write('note: $note, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('receiptAttachmentId: $receiptAttachmentId, ')
          ..write('localReceiptPath: $localReceiptPath, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('syncAttemptCount: $syncAttemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $OtherIncomeEntriesTable extends OtherIncomeEntries
    with TableInfo<$OtherIncomeEntriesTable, OtherIncomeEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OtherIncomeEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _incomeIdMeta = const VerificationMeta(
    'incomeId',
  );
  @override
  late final GeneratedColumn<String> incomeId = GeneratedColumn<String>(
    'income_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> amount =
      GeneratedColumn<String>(
        'amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($OtherIncomeEntriesTable.$converteramount);
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('other'),
  );
  static const VerificationMeta _receiptAttachmentIdMeta =
      const VerificationMeta('receiptAttachmentId');
  @override
  late final GeneratedColumn<String> receiptAttachmentId =
      GeneratedColumn<String>(
        'receipt_attachment_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _localReceiptPathMeta = const VerificationMeta(
    'localReceiptPath',
  );
  @override
  late final GeneratedColumn<String> localReceiptPath = GeneratedColumn<String>(
    'local_receipt_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorUserIdMeta = const VerificationMeta(
    'actorUserId',
  );
  @override
  late final GeneratedColumn<String> actorUserId = GeneratedColumn<String>(
    'actor_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncAttemptCountMeta = const VerificationMeta(
    'syncAttemptCount',
  );
  @override
  late final GeneratedColumn<int> syncAttemptCount = GeneratedColumn<int>(
    'sync_attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    incomeId,
    businessId,
    storeId,
    category,
    amount,
    description,
    source,
    note,
    paymentMethod,
    receiptAttachmentId,
    localReceiptPath,
    occurredAt,
    actorUserId,
    serverId,
    syncStatus,
    syncError,
    syncAttemptCount,
    lastAttemptAt,
    syncedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'other_income_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<OtherIncomeEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('income_id')) {
      context.handle(
        _incomeIdMeta,
        incomeId.isAcceptableOrUnknown(data['income_id']!, _incomeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_incomeIdMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    }
    if (data.containsKey('receipt_attachment_id')) {
      context.handle(
        _receiptAttachmentIdMeta,
        receiptAttachmentId.isAcceptableOrUnknown(
          data['receipt_attachment_id']!,
          _receiptAttachmentIdMeta,
        ),
      );
    }
    if (data.containsKey('local_receipt_path')) {
      context.handle(
        _localReceiptPathMeta,
        localReceiptPath.isAcceptableOrUnknown(
          data['local_receipt_path']!,
          _localReceiptPathMeta,
        ),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('actor_user_id')) {
      context.handle(
        _actorUserIdMeta,
        actorUserId.isAcceptableOrUnknown(
          data['actor_user_id']!,
          _actorUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actorUserIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
      );
    }
    if (data.containsKey('sync_attempt_count')) {
      context.handle(
        _syncAttemptCountMeta,
        syncAttemptCount.isAcceptableOrUnknown(
          data['sync_attempt_count']!,
          _syncAttemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OtherIncomeEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OtherIncomeEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      incomeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}income_id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      amount: $OtherIncomeEntriesTable.$converteramount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}amount'],
        )!,
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      receiptAttachmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_attachment_id'],
      ),
      localReceiptPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_receipt_path'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      actorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_user_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      ),
      syncAttemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_attempt_count'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OtherIncomeEntriesTable createAlias(String alias) {
    return $OtherIncomeEntriesTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converteramount =
      const DecimalConverter();
}

class OtherIncomeEntry extends DataClass
    implements Insertable<OtherIncomeEntry> {
  /// Local row ID (autoincrement).
  final int id;

  /// Client-side idempotency key (UUID v4, unique).
  final String incomeId;

  /// Business this income belongs to.
  final String businessId;

  /// Store/location this income belongs to. Matches POS Service's
  /// `other_incomes.store_id` field (renamed from `businessLocationId`
  /// by schema v6, mirroring `PendingSales`'s own v5 rename).
  final String storeId;

  /// Income category. Controlled list, not free text — canonical list
  /// (mirrors
  /// `services/pos-service/app/models/finance.py::IncomeCategory`):
  /// catering|grants|rebates|space_rental|equipment_rental|other.
  final String category;

  /// Income amount.
  final Decimal amount;

  /// Free-text description.
  final String? description;

  /// Who/what the income came from.
  final String? source;

  /// Optional free-text note.
  final String? note;

  /// Payment method used: cash|mobile_money|card|other.
  final String paymentMethod;

  /// Server-assigned id of the uploaded receipt (`FinanceAttachment.id`).
  final String? receiptAttachmentId;

  /// Device-local path to a receipt file awaiting upload. See
  /// `ExpenseEntries.localReceiptPath`.
  final String? localReceiptPath;

  /// When the income occurred (device time, UTC).
  final DateTime occurredAt;

  /// Staff member who recorded the income.
  /// Soft-references `LocalUserProfiles.id` without an FK constraint, same
  /// rationale as `ExpenseEntries.actorUserId`.
  final String actorUserId;

  /// Server-assigned id (`OtherIncome.id`), set once this row has synced.
  final String? serverId;

  /// Local sync state: `pending`, `syncing`, `failed`, `synced`.
  final String syncStatus;

  /// Error message from the last sync attempt, if any.
  final String? syncError;

  /// Number of times this entry has been attempted.
  final int syncAttemptCount;

  /// Timestamp of the last sync attempt.
  final DateTime? lastAttemptAt;

  /// When the entry was successfully synced to the backend.
  final DateTime? syncedAt;

  /// Local row creation timestamp.
  final DateTime createdAt;
  const OtherIncomeEntry({
    required this.id,
    required this.incomeId,
    required this.businessId,
    required this.storeId,
    required this.category,
    required this.amount,
    this.description,
    this.source,
    this.note,
    required this.paymentMethod,
    this.receiptAttachmentId,
    this.localReceiptPath,
    required this.occurredAt,
    required this.actorUserId,
    this.serverId,
    required this.syncStatus,
    this.syncError,
    required this.syncAttemptCount,
    this.lastAttemptAt,
    this.syncedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['income_id'] = Variable<String>(incomeId);
    map['business_id'] = Variable<String>(businessId);
    map['store_id'] = Variable<String>(storeId);
    map['category'] = Variable<String>(category);
    {
      map['amount'] = Variable<String>(
        $OtherIncomeEntriesTable.$converteramount.toSql(amount),
      );
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['payment_method'] = Variable<String>(paymentMethod);
    if (!nullToAbsent || receiptAttachmentId != null) {
      map['receipt_attachment_id'] = Variable<String>(receiptAttachmentId);
    }
    if (!nullToAbsent || localReceiptPath != null) {
      map['local_receipt_path'] = Variable<String>(localReceiptPath);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['actor_user_id'] = Variable<String>(actorUserId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    map['sync_attempt_count'] = Variable<int>(syncAttemptCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OtherIncomeEntriesCompanion toCompanion(bool nullToAbsent) {
    return OtherIncomeEntriesCompanion(
      id: Value(id),
      incomeId: Value(incomeId),
      businessId: Value(businessId),
      storeId: Value(storeId),
      category: Value(category),
      amount: Value(amount),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      paymentMethod: Value(paymentMethod),
      receiptAttachmentId: receiptAttachmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptAttachmentId),
      localReceiptPath: localReceiptPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localReceiptPath),
      occurredAt: Value(occurredAt),
      actorUserId: Value(actorUserId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      syncStatus: Value(syncStatus),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      syncAttemptCount: Value(syncAttemptCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      createdAt: Value(createdAt),
    );
  }

  factory OtherIncomeEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OtherIncomeEntry(
      id: serializer.fromJson<int>(json['id']),
      incomeId: serializer.fromJson<String>(json['incomeId']),
      businessId: serializer.fromJson<String>(json['businessId']),
      storeId: serializer.fromJson<String>(json['storeId']),
      category: serializer.fromJson<String>(json['category']),
      amount: serializer.fromJson<Decimal>(json['amount']),
      description: serializer.fromJson<String?>(json['description']),
      source: serializer.fromJson<String?>(json['source']),
      note: serializer.fromJson<String?>(json['note']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      receiptAttachmentId: serializer.fromJson<String?>(
        json['receiptAttachmentId'],
      ),
      localReceiptPath: serializer.fromJson<String?>(json['localReceiptPath']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      actorUserId: serializer.fromJson<String>(json['actorUserId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      syncAttemptCount: serializer.fromJson<int>(json['syncAttemptCount']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'incomeId': serializer.toJson<String>(incomeId),
      'businessId': serializer.toJson<String>(businessId),
      'storeId': serializer.toJson<String>(storeId),
      'category': serializer.toJson<String>(category),
      'amount': serializer.toJson<Decimal>(amount),
      'description': serializer.toJson<String?>(description),
      'source': serializer.toJson<String?>(source),
      'note': serializer.toJson<String?>(note),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'receiptAttachmentId': serializer.toJson<String?>(receiptAttachmentId),
      'localReceiptPath': serializer.toJson<String?>(localReceiptPath),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'actorUserId': serializer.toJson<String>(actorUserId),
      'serverId': serializer.toJson<String?>(serverId),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncError': serializer.toJson<String?>(syncError),
      'syncAttemptCount': serializer.toJson<int>(syncAttemptCount),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OtherIncomeEntry copyWith({
    int? id,
    String? incomeId,
    String? businessId,
    String? storeId,
    String? category,
    Decimal? amount,
    Value<String?> description = const Value.absent(),
    Value<String?> source = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? paymentMethod,
    Value<String?> receiptAttachmentId = const Value.absent(),
    Value<String?> localReceiptPath = const Value.absent(),
    DateTime? occurredAt,
    String? actorUserId,
    Value<String?> serverId = const Value.absent(),
    String? syncStatus,
    Value<String?> syncError = const Value.absent(),
    int? syncAttemptCount,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
    DateTime? createdAt,
  }) => OtherIncomeEntry(
    id: id ?? this.id,
    incomeId: incomeId ?? this.incomeId,
    businessId: businessId ?? this.businessId,
    storeId: storeId ?? this.storeId,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    description: description.present ? description.value : this.description,
    source: source.present ? source.value : this.source,
    note: note.present ? note.value : this.note,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    receiptAttachmentId: receiptAttachmentId.present
        ? receiptAttachmentId.value
        : this.receiptAttachmentId,
    localReceiptPath: localReceiptPath.present
        ? localReceiptPath.value
        : this.localReceiptPath,
    occurredAt: occurredAt ?? this.occurredAt,
    actorUserId: actorUserId ?? this.actorUserId,
    serverId: serverId.present ? serverId.value : this.serverId,
    syncStatus: syncStatus ?? this.syncStatus,
    syncError: syncError.present ? syncError.value : this.syncError,
    syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  OtherIncomeEntry copyWithCompanion(OtherIncomeEntriesCompanion data) {
    return OtherIncomeEntry(
      id: data.id.present ? data.id.value : this.id,
      incomeId: data.incomeId.present ? data.incomeId.value : this.incomeId,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      category: data.category.present ? data.category.value : this.category,
      amount: data.amount.present ? data.amount.value : this.amount,
      description: data.description.present
          ? data.description.value
          : this.description,
      source: data.source.present ? data.source.value : this.source,
      note: data.note.present ? data.note.value : this.note,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      receiptAttachmentId: data.receiptAttachmentId.present
          ? data.receiptAttachmentId.value
          : this.receiptAttachmentId,
      localReceiptPath: data.localReceiptPath.present
          ? data.localReceiptPath.value
          : this.localReceiptPath,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      actorUserId: data.actorUserId.present
          ? data.actorUserId.value
          : this.actorUserId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      syncAttemptCount: data.syncAttemptCount.present
          ? data.syncAttemptCount.value
          : this.syncAttemptCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OtherIncomeEntry(')
          ..write('id: $id, ')
          ..write('incomeId: $incomeId, ')
          ..write('businessId: $businessId, ')
          ..write('storeId: $storeId, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('source: $source, ')
          ..write('note: $note, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('receiptAttachmentId: $receiptAttachmentId, ')
          ..write('localReceiptPath: $localReceiptPath, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('syncAttemptCount: $syncAttemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    incomeId,
    businessId,
    storeId,
    category,
    amount,
    description,
    source,
    note,
    paymentMethod,
    receiptAttachmentId,
    localReceiptPath,
    occurredAt,
    actorUserId,
    serverId,
    syncStatus,
    syncError,
    syncAttemptCount,
    lastAttemptAt,
    syncedAt,
    createdAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OtherIncomeEntry &&
          other.id == this.id &&
          other.incomeId == this.incomeId &&
          other.businessId == this.businessId &&
          other.storeId == this.storeId &&
          other.category == this.category &&
          other.amount == this.amount &&
          other.description == this.description &&
          other.source == this.source &&
          other.note == this.note &&
          other.paymentMethod == this.paymentMethod &&
          other.receiptAttachmentId == this.receiptAttachmentId &&
          other.localReceiptPath == this.localReceiptPath &&
          other.occurredAt == this.occurredAt &&
          other.actorUserId == this.actorUserId &&
          other.serverId == this.serverId &&
          other.syncStatus == this.syncStatus &&
          other.syncError == this.syncError &&
          other.syncAttemptCount == this.syncAttemptCount &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.syncedAt == this.syncedAt &&
          other.createdAt == this.createdAt);
}

class OtherIncomeEntriesCompanion extends UpdateCompanion<OtherIncomeEntry> {
  final Value<int> id;
  final Value<String> incomeId;
  final Value<String> businessId;
  final Value<String> storeId;
  final Value<String> category;
  final Value<Decimal> amount;
  final Value<String?> description;
  final Value<String?> source;
  final Value<String?> note;
  final Value<String> paymentMethod;
  final Value<String?> receiptAttachmentId;
  final Value<String?> localReceiptPath;
  final Value<DateTime> occurredAt;
  final Value<String> actorUserId;
  final Value<String?> serverId;
  final Value<String> syncStatus;
  final Value<String?> syncError;
  final Value<int> syncAttemptCount;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> syncedAt;
  final Value<DateTime> createdAt;
  const OtherIncomeEntriesCompanion({
    this.id = const Value.absent(),
    this.incomeId = const Value.absent(),
    this.businessId = const Value.absent(),
    this.storeId = const Value.absent(),
    this.category = const Value.absent(),
    this.amount = const Value.absent(),
    this.description = const Value.absent(),
    this.source = const Value.absent(),
    this.note = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.receiptAttachmentId = const Value.absent(),
    this.localReceiptPath = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.actorUserId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncAttemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OtherIncomeEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String incomeId,
    required String businessId,
    required String storeId,
    required String category,
    required Decimal amount,
    this.description = const Value.absent(),
    this.source = const Value.absent(),
    this.note = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.receiptAttachmentId = const Value.absent(),
    this.localReceiptPath = const Value.absent(),
    required DateTime occurredAt,
    required String actorUserId,
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncAttemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required DateTime createdAt,
  }) : incomeId = Value(incomeId),
       businessId = Value(businessId),
       storeId = Value(storeId),
       category = Value(category),
       amount = Value(amount),
       occurredAt = Value(occurredAt),
       actorUserId = Value(actorUserId),
       createdAt = Value(createdAt);
  static Insertable<OtherIncomeEntry> custom({
    Expression<int>? id,
    Expression<String>? incomeId,
    Expression<String>? businessId,
    Expression<String>? storeId,
    Expression<String>? category,
    Expression<String>? amount,
    Expression<String>? description,
    Expression<String>? source,
    Expression<String>? note,
    Expression<String>? paymentMethod,
    Expression<String>? receiptAttachmentId,
    Expression<String>? localReceiptPath,
    Expression<DateTime>? occurredAt,
    Expression<String>? actorUserId,
    Expression<String>? serverId,
    Expression<String>? syncStatus,
    Expression<String>? syncError,
    Expression<int>? syncAttemptCount,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (incomeId != null) 'income_id': incomeId,
      if (businessId != null) 'business_id': businessId,
      if (storeId != null) 'store_id': storeId,
      if (category != null) 'category': category,
      if (amount != null) 'amount': amount,
      if (description != null) 'description': description,
      if (source != null) 'source': source,
      if (note != null) 'note': note,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (receiptAttachmentId != null)
        'receipt_attachment_id': receiptAttachmentId,
      if (localReceiptPath != null) 'local_receipt_path': localReceiptPath,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (actorUserId != null) 'actor_user_id': actorUserId,
      if (serverId != null) 'server_id': serverId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncError != null) 'sync_error': syncError,
      if (syncAttemptCount != null) 'sync_attempt_count': syncAttemptCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OtherIncomeEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? incomeId,
    Value<String>? businessId,
    Value<String>? storeId,
    Value<String>? category,
    Value<Decimal>? amount,
    Value<String?>? description,
    Value<String?>? source,
    Value<String?>? note,
    Value<String>? paymentMethod,
    Value<String?>? receiptAttachmentId,
    Value<String?>? localReceiptPath,
    Value<DateTime>? occurredAt,
    Value<String>? actorUserId,
    Value<String?>? serverId,
    Value<String>? syncStatus,
    Value<String?>? syncError,
    Value<int>? syncAttemptCount,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime?>? syncedAt,
    Value<DateTime>? createdAt,
  }) {
    return OtherIncomeEntriesCompanion(
      id: id ?? this.id,
      incomeId: incomeId ?? this.incomeId,
      businessId: businessId ?? this.businessId,
      storeId: storeId ?? this.storeId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      source: source ?? this.source,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptAttachmentId: receiptAttachmentId ?? this.receiptAttachmentId,
      localReceiptPath: localReceiptPath ?? this.localReceiptPath,
      occurredAt: occurredAt ?? this.occurredAt,
      actorUserId: actorUserId ?? this.actorUserId,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (incomeId.present) {
      map['income_id'] = Variable<String>(incomeId.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(
        $OtherIncomeEntriesTable.$converteramount.toSql(amount.value),
      );
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (receiptAttachmentId.present) {
      map['receipt_attachment_id'] = Variable<String>(
        receiptAttachmentId.value,
      );
    }
    if (localReceiptPath.present) {
      map['local_receipt_path'] = Variable<String>(localReceiptPath.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (actorUserId.present) {
      map['actor_user_id'] = Variable<String>(actorUserId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (syncAttemptCount.present) {
      map['sync_attempt_count'] = Variable<int>(syncAttemptCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OtherIncomeEntriesCompanion(')
          ..write('id: $id, ')
          ..write('incomeId: $incomeId, ')
          ..write('businessId: $businessId, ')
          ..write('storeId: $storeId, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('source: $source, ')
          ..write('note: $note, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('receiptAttachmentId: $receiptAttachmentId, ')
          ..write('localReceiptPath: $localReceiptPath, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('syncAttemptCount: $syncAttemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CachedOtherExpensesTable extends CachedOtherExpenses
    with TableInfo<$CachedOtherExpensesTable, CachedOtherExpense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedOtherExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientExpenseIdMeta = const VerificationMeta(
    'clientExpenseId',
  );
  @override
  late final GeneratedColumn<String> clientExpenseId = GeneratedColumn<String>(
    'client_expense_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> amount =
      GeneratedColumn<String>(
        'amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($CachedOtherExpensesTable.$converteramount);
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payeeMeta = const VerificationMeta('payee');
  @override
  late final GeneratedColumn<String> payee = GeneratedColumn<String>(
    'payee',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiptAttachmentIdMeta =
      const VerificationMeta('receiptAttachmentId');
  @override
  late final GeneratedColumn<String> receiptAttachmentId =
      GeneratedColumn<String>(
        'receipt_attachment_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
    'actor_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    storeId,
    clientExpenseId,
    category,
    amount,
    description,
    payee,
    note,
    paymentMethod,
    receiptAttachmentId,
    actorId,
    occurredAt,
    syncedAt,
    updatedAt,
    isDeleted,
    createdAt,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_other_expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedOtherExpense> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('client_expense_id')) {
      context.handle(
        _clientExpenseIdMeta,
        clientExpenseId.isAcceptableOrUnknown(
          data['client_expense_id']!,
          _clientExpenseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientExpenseIdMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('payee')) {
      context.handle(
        _payeeMeta,
        payee.isAcceptableOrUnknown(data['payee']!, _payeeMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentMethodMeta);
    }
    if (data.containsKey('receipt_attachment_id')) {
      context.handle(
        _receiptAttachmentIdMeta,
        receiptAttachmentId.isAcceptableOrUnknown(
          data['receipt_attachment_id']!,
          _receiptAttachmentIdMeta,
        ),
      );
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedOtherExpense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedOtherExpense(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      clientExpenseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_expense_id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      amount: $CachedOtherExpensesTable.$converteramount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}amount'],
        )!,
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      payee: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      receiptAttachmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_attachment_id'],
      ),
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_id'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
    );
  }

  @override
  $CachedOtherExpensesTable createAlias(String alias) {
    return $CachedOtherExpensesTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converteramount =
      const DecimalConverter();
}

class CachedOtherExpense extends DataClass
    implements Insertable<CachedOtherExpense> {
  /// Expense UUID, assigned by POS Service (primary key).
  final String id;

  /// Business this expense belongs to.
  final String businessId;

  /// Store/location this expense belongs to.
  final String storeId;

  /// Client-generated idempotency key this expense was created from.
  final String clientExpenseId;
  final String category;
  final Decimal amount;
  final String description;
  final String? payee;
  final String? note;

  /// Payment method: `cash`, `mobile_money`, `card`, or `other`.
  final String paymentMethod;
  final String? receiptAttachmentId;

  /// Staff member who recorded the expense, if known.
  final String? actorId;

  /// When the expense occurred (device-reported time, UTC).
  final DateTime occurredAt;

  /// When POS Service accepted this expense.
  final DateTime syncedAt;

  /// Last-edited timestamp (server-computed).
  final DateTime updatedAt;

  /// Soft-delete flag — see class doc for why deleted rows are still pulled.
  final bool isDeleted;

  /// Backend creation timestamp.
  final DateTime createdAt;

  /// Local timestamp of the most recent pull that included this row.
  final DateTime lastSyncedAt;
  const CachedOtherExpense({
    required this.id,
    required this.businessId,
    required this.storeId,
    required this.clientExpenseId,
    required this.category,
    required this.amount,
    required this.description,
    this.payee,
    this.note,
    required this.paymentMethod,
    this.receiptAttachmentId,
    this.actorId,
    required this.occurredAt,
    required this.syncedAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.createdAt,
    required this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['business_id'] = Variable<String>(businessId);
    map['store_id'] = Variable<String>(storeId);
    map['client_expense_id'] = Variable<String>(clientExpenseId);
    map['category'] = Variable<String>(category);
    {
      map['amount'] = Variable<String>(
        $CachedOtherExpensesTable.$converteramount.toSql(amount),
      );
    }
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || payee != null) {
      map['payee'] = Variable<String>(payee);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['payment_method'] = Variable<String>(paymentMethod);
    if (!nullToAbsent || receiptAttachmentId != null) {
      map['receipt_attachment_id'] = Variable<String>(receiptAttachmentId);
    }
    if (!nullToAbsent || actorId != null) {
      map['actor_id'] = Variable<String>(actorId);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    return map;
  }

  CachedOtherExpensesCompanion toCompanion(bool nullToAbsent) {
    return CachedOtherExpensesCompanion(
      id: Value(id),
      businessId: Value(businessId),
      storeId: Value(storeId),
      clientExpenseId: Value(clientExpenseId),
      category: Value(category),
      amount: Value(amount),
      description: Value(description),
      payee: payee == null && nullToAbsent
          ? const Value.absent()
          : Value(payee),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      paymentMethod: Value(paymentMethod),
      receiptAttachmentId: receiptAttachmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptAttachmentId),
      actorId: actorId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorId),
      occurredAt: Value(occurredAt),
      syncedAt: Value(syncedAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt),
      lastSyncedAt: Value(lastSyncedAt),
    );
  }

  factory CachedOtherExpense.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedOtherExpense(
      id: serializer.fromJson<String>(json['id']),
      businessId: serializer.fromJson<String>(json['businessId']),
      storeId: serializer.fromJson<String>(json['storeId']),
      clientExpenseId: serializer.fromJson<String>(json['clientExpenseId']),
      category: serializer.fromJson<String>(json['category']),
      amount: serializer.fromJson<Decimal>(json['amount']),
      description: serializer.fromJson<String>(json['description']),
      payee: serializer.fromJson<String?>(json['payee']),
      note: serializer.fromJson<String?>(json['note']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      receiptAttachmentId: serializer.fromJson<String?>(
        json['receiptAttachmentId'],
      ),
      actorId: serializer.fromJson<String?>(json['actorId']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'businessId': serializer.toJson<String>(businessId),
      'storeId': serializer.toJson<String>(storeId),
      'clientExpenseId': serializer.toJson<String>(clientExpenseId),
      'category': serializer.toJson<String>(category),
      'amount': serializer.toJson<Decimal>(amount),
      'description': serializer.toJson<String>(description),
      'payee': serializer.toJson<String?>(payee),
      'note': serializer.toJson<String?>(note),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'receiptAttachmentId': serializer.toJson<String?>(receiptAttachmentId),
      'actorId': serializer.toJson<String?>(actorId),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
    };
  }

  CachedOtherExpense copyWith({
    String? id,
    String? businessId,
    String? storeId,
    String? clientExpenseId,
    String? category,
    Decimal? amount,
    String? description,
    Value<String?> payee = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? paymentMethod,
    Value<String?> receiptAttachmentId = const Value.absent(),
    Value<String?> actorId = const Value.absent(),
    DateTime? occurredAt,
    DateTime? syncedAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? lastSyncedAt,
  }) => CachedOtherExpense(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    storeId: storeId ?? this.storeId,
    clientExpenseId: clientExpenseId ?? this.clientExpenseId,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    description: description ?? this.description,
    payee: payee.present ? payee.value : this.payee,
    note: note.present ? note.value : this.note,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    receiptAttachmentId: receiptAttachmentId.present
        ? receiptAttachmentId.value
        : this.receiptAttachmentId,
    actorId: actorId.present ? actorId.value : this.actorId,
    occurredAt: occurredAt ?? this.occurredAt,
    syncedAt: syncedAt ?? this.syncedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    createdAt: createdAt ?? this.createdAt,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
  CachedOtherExpense copyWithCompanion(CachedOtherExpensesCompanion data) {
    return CachedOtherExpense(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      clientExpenseId: data.clientExpenseId.present
          ? data.clientExpenseId.value
          : this.clientExpenseId,
      category: data.category.present ? data.category.value : this.category,
      amount: data.amount.present ? data.amount.value : this.amount,
      description: data.description.present
          ? data.description.value
          : this.description,
      payee: data.payee.present ? data.payee.value : this.payee,
      note: data.note.present ? data.note.value : this.note,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      receiptAttachmentId: data.receiptAttachmentId.present
          ? data.receiptAttachmentId.value
          : this.receiptAttachmentId,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedOtherExpense(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('storeId: $storeId, ')
          ..write('clientExpenseId: $clientExpenseId, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('payee: $payee, ')
          ..write('note: $note, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('receiptAttachmentId: $receiptAttachmentId, ')
          ..write('actorId: $actorId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    storeId,
    clientExpenseId,
    category,
    amount,
    description,
    payee,
    note,
    paymentMethod,
    receiptAttachmentId,
    actorId,
    occurredAt,
    syncedAt,
    updatedAt,
    isDeleted,
    createdAt,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedOtherExpense &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.storeId == this.storeId &&
          other.clientExpenseId == this.clientExpenseId &&
          other.category == this.category &&
          other.amount == this.amount &&
          other.description == this.description &&
          other.payee == this.payee &&
          other.note == this.note &&
          other.paymentMethod == this.paymentMethod &&
          other.receiptAttachmentId == this.receiptAttachmentId &&
          other.actorId == this.actorId &&
          other.occurredAt == this.occurredAt &&
          other.syncedAt == this.syncedAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted &&
          other.createdAt == this.createdAt &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class CachedOtherExpensesCompanion extends UpdateCompanion<CachedOtherExpense> {
  final Value<String> id;
  final Value<String> businessId;
  final Value<String> storeId;
  final Value<String> clientExpenseId;
  final Value<String> category;
  final Value<Decimal> amount;
  final Value<String> description;
  final Value<String?> payee;
  final Value<String?> note;
  final Value<String> paymentMethod;
  final Value<String?> receiptAttachmentId;
  final Value<String?> actorId;
  final Value<DateTime> occurredAt;
  final Value<DateTime> syncedAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastSyncedAt;
  final Value<int> rowid;
  const CachedOtherExpensesCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.storeId = const Value.absent(),
    this.clientExpenseId = const Value.absent(),
    this.category = const Value.absent(),
    this.amount = const Value.absent(),
    this.description = const Value.absent(),
    this.payee = const Value.absent(),
    this.note = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.receiptAttachmentId = const Value.absent(),
    this.actorId = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedOtherExpensesCompanion.insert({
    required String id,
    required String businessId,
    required String storeId,
    required String clientExpenseId,
    required String category,
    required Decimal amount,
    required String description,
    this.payee = const Value.absent(),
    this.note = const Value.absent(),
    required String paymentMethod,
    this.receiptAttachmentId = const Value.absent(),
    this.actorId = const Value.absent(),
    required DateTime occurredAt,
    required DateTime syncedAt,
    required DateTime updatedAt,
    this.isDeleted = const Value.absent(),
    required DateTime createdAt,
    required DateTime lastSyncedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessId = Value(businessId),
       storeId = Value(storeId),
       clientExpenseId = Value(clientExpenseId),
       category = Value(category),
       amount = Value(amount),
       description = Value(description),
       paymentMethod = Value(paymentMethod),
       occurredAt = Value(occurredAt),
       syncedAt = Value(syncedAt),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<CachedOtherExpense> custom({
    Expression<String>? id,
    Expression<String>? businessId,
    Expression<String>? storeId,
    Expression<String>? clientExpenseId,
    Expression<String>? category,
    Expression<String>? amount,
    Expression<String>? description,
    Expression<String>? payee,
    Expression<String>? note,
    Expression<String>? paymentMethod,
    Expression<String>? receiptAttachmentId,
    Expression<String>? actorId,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (storeId != null) 'store_id': storeId,
      if (clientExpenseId != null) 'client_expense_id': clientExpenseId,
      if (category != null) 'category': category,
      if (amount != null) 'amount': amount,
      if (description != null) 'description': description,
      if (payee != null) 'payee': payee,
      if (note != null) 'note': note,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (receiptAttachmentId != null)
        'receipt_attachment_id': receiptAttachmentId,
      if (actorId != null) 'actor_id': actorId,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedOtherExpensesCompanion copyWith({
    Value<String>? id,
    Value<String>? businessId,
    Value<String>? storeId,
    Value<String>? clientExpenseId,
    Value<String>? category,
    Value<Decimal>? amount,
    Value<String>? description,
    Value<String?>? payee,
    Value<String?>? note,
    Value<String>? paymentMethod,
    Value<String?>? receiptAttachmentId,
    Value<String?>? actorId,
    Value<DateTime>? occurredAt,
    Value<DateTime>? syncedAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return CachedOtherExpensesCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      storeId: storeId ?? this.storeId,
      clientExpenseId: clientExpenseId ?? this.clientExpenseId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      payee: payee ?? this.payee,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptAttachmentId: receiptAttachmentId ?? this.receiptAttachmentId,
      actorId: actorId ?? this.actorId,
      occurredAt: occurredAt ?? this.occurredAt,
      syncedAt: syncedAt ?? this.syncedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (clientExpenseId.present) {
      map['client_expense_id'] = Variable<String>(clientExpenseId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(
        $CachedOtherExpensesTable.$converteramount.toSql(amount.value),
      );
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (payee.present) {
      map['payee'] = Variable<String>(payee.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (receiptAttachmentId.present) {
      map['receipt_attachment_id'] = Variable<String>(
        receiptAttachmentId.value,
      );
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedOtherExpensesCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('storeId: $storeId, ')
          ..write('clientExpenseId: $clientExpenseId, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('payee: $payee, ')
          ..write('note: $note, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('receiptAttachmentId: $receiptAttachmentId, ')
          ..write('actorId: $actorId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedOtherIncomesTable extends CachedOtherIncomes
    with TableInfo<$CachedOtherIncomesTable, CachedOtherIncome> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedOtherIncomesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIncomeIdMeta = const VerificationMeta(
    'clientIncomeId',
  );
  @override
  late final GeneratedColumn<String> clientIncomeId = GeneratedColumn<String>(
    'client_income_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> amount =
      GeneratedColumn<String>(
        'amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($CachedOtherIncomesTable.$converteramount);
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiptAttachmentIdMeta =
      const VerificationMeta('receiptAttachmentId');
  @override
  late final GeneratedColumn<String> receiptAttachmentId =
      GeneratedColumn<String>(
        'receipt_attachment_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
    'actor_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    storeId,
    clientIncomeId,
    category,
    amount,
    description,
    source,
    note,
    paymentMethod,
    receiptAttachmentId,
    actorId,
    occurredAt,
    syncedAt,
    updatedAt,
    isDeleted,
    createdAt,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_other_incomes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedOtherIncome> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('client_income_id')) {
      context.handle(
        _clientIncomeIdMeta,
        clientIncomeId.isAcceptableOrUnknown(
          data['client_income_id']!,
          _clientIncomeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientIncomeIdMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentMethodMeta);
    }
    if (data.containsKey('receipt_attachment_id')) {
      context.handle(
        _receiptAttachmentIdMeta,
        receiptAttachmentId.isAcceptableOrUnknown(
          data['receipt_attachment_id']!,
          _receiptAttachmentIdMeta,
        ),
      );
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedOtherIncome map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedOtherIncome(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      clientIncomeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_income_id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      amount: $CachedOtherIncomesTable.$converteramount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}amount'],
        )!,
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      receiptAttachmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_attachment_id'],
      ),
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_id'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
    );
  }

  @override
  $CachedOtherIncomesTable createAlias(String alias) {
    return $CachedOtherIncomesTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converteramount =
      const DecimalConverter();
}

class CachedOtherIncome extends DataClass
    implements Insertable<CachedOtherIncome> {
  /// Income UUID, assigned by POS Service (primary key).
  final String id;
  final String businessId;
  final String storeId;

  /// Client-generated idempotency key this income was created from.
  final String clientIncomeId;
  final String category;
  final Decimal amount;
  final String description;
  final String? source;
  final String? note;

  /// Payment method: `cash`, `mobile_money`, `card`, or `other`.
  final String paymentMethod;
  final String? receiptAttachmentId;

  /// Staff member who recorded the income, if known.
  final String? actorId;
  final DateTime occurredAt;
  final DateTime syncedAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime createdAt;

  /// Local timestamp of the most recent pull that included this row.
  final DateTime lastSyncedAt;
  const CachedOtherIncome({
    required this.id,
    required this.businessId,
    required this.storeId,
    required this.clientIncomeId,
    required this.category,
    required this.amount,
    required this.description,
    this.source,
    this.note,
    required this.paymentMethod,
    this.receiptAttachmentId,
    this.actorId,
    required this.occurredAt,
    required this.syncedAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.createdAt,
    required this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['business_id'] = Variable<String>(businessId);
    map['store_id'] = Variable<String>(storeId);
    map['client_income_id'] = Variable<String>(clientIncomeId);
    map['category'] = Variable<String>(category);
    {
      map['amount'] = Variable<String>(
        $CachedOtherIncomesTable.$converteramount.toSql(amount),
      );
    }
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['payment_method'] = Variable<String>(paymentMethod);
    if (!nullToAbsent || receiptAttachmentId != null) {
      map['receipt_attachment_id'] = Variable<String>(receiptAttachmentId);
    }
    if (!nullToAbsent || actorId != null) {
      map['actor_id'] = Variable<String>(actorId);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    return map;
  }

  CachedOtherIncomesCompanion toCompanion(bool nullToAbsent) {
    return CachedOtherIncomesCompanion(
      id: Value(id),
      businessId: Value(businessId),
      storeId: Value(storeId),
      clientIncomeId: Value(clientIncomeId),
      category: Value(category),
      amount: Value(amount),
      description: Value(description),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      paymentMethod: Value(paymentMethod),
      receiptAttachmentId: receiptAttachmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptAttachmentId),
      actorId: actorId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorId),
      occurredAt: Value(occurredAt),
      syncedAt: Value(syncedAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt),
      lastSyncedAt: Value(lastSyncedAt),
    );
  }

  factory CachedOtherIncome.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedOtherIncome(
      id: serializer.fromJson<String>(json['id']),
      businessId: serializer.fromJson<String>(json['businessId']),
      storeId: serializer.fromJson<String>(json['storeId']),
      clientIncomeId: serializer.fromJson<String>(json['clientIncomeId']),
      category: serializer.fromJson<String>(json['category']),
      amount: serializer.fromJson<Decimal>(json['amount']),
      description: serializer.fromJson<String>(json['description']),
      source: serializer.fromJson<String?>(json['source']),
      note: serializer.fromJson<String?>(json['note']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      receiptAttachmentId: serializer.fromJson<String?>(
        json['receiptAttachmentId'],
      ),
      actorId: serializer.fromJson<String?>(json['actorId']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'businessId': serializer.toJson<String>(businessId),
      'storeId': serializer.toJson<String>(storeId),
      'clientIncomeId': serializer.toJson<String>(clientIncomeId),
      'category': serializer.toJson<String>(category),
      'amount': serializer.toJson<Decimal>(amount),
      'description': serializer.toJson<String>(description),
      'source': serializer.toJson<String?>(source),
      'note': serializer.toJson<String?>(note),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'receiptAttachmentId': serializer.toJson<String?>(receiptAttachmentId),
      'actorId': serializer.toJson<String?>(actorId),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
    };
  }

  CachedOtherIncome copyWith({
    String? id,
    String? businessId,
    String? storeId,
    String? clientIncomeId,
    String? category,
    Decimal? amount,
    String? description,
    Value<String?> source = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? paymentMethod,
    Value<String?> receiptAttachmentId = const Value.absent(),
    Value<String?> actorId = const Value.absent(),
    DateTime? occurredAt,
    DateTime? syncedAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? lastSyncedAt,
  }) => CachedOtherIncome(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    storeId: storeId ?? this.storeId,
    clientIncomeId: clientIncomeId ?? this.clientIncomeId,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    description: description ?? this.description,
    source: source.present ? source.value : this.source,
    note: note.present ? note.value : this.note,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    receiptAttachmentId: receiptAttachmentId.present
        ? receiptAttachmentId.value
        : this.receiptAttachmentId,
    actorId: actorId.present ? actorId.value : this.actorId,
    occurredAt: occurredAt ?? this.occurredAt,
    syncedAt: syncedAt ?? this.syncedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    createdAt: createdAt ?? this.createdAt,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
  CachedOtherIncome copyWithCompanion(CachedOtherIncomesCompanion data) {
    return CachedOtherIncome(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      clientIncomeId: data.clientIncomeId.present
          ? data.clientIncomeId.value
          : this.clientIncomeId,
      category: data.category.present ? data.category.value : this.category,
      amount: data.amount.present ? data.amount.value : this.amount,
      description: data.description.present
          ? data.description.value
          : this.description,
      source: data.source.present ? data.source.value : this.source,
      note: data.note.present ? data.note.value : this.note,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      receiptAttachmentId: data.receiptAttachmentId.present
          ? data.receiptAttachmentId.value
          : this.receiptAttachmentId,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedOtherIncome(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('storeId: $storeId, ')
          ..write('clientIncomeId: $clientIncomeId, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('source: $source, ')
          ..write('note: $note, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('receiptAttachmentId: $receiptAttachmentId, ')
          ..write('actorId: $actorId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    storeId,
    clientIncomeId,
    category,
    amount,
    description,
    source,
    note,
    paymentMethod,
    receiptAttachmentId,
    actorId,
    occurredAt,
    syncedAt,
    updatedAt,
    isDeleted,
    createdAt,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedOtherIncome &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.storeId == this.storeId &&
          other.clientIncomeId == this.clientIncomeId &&
          other.category == this.category &&
          other.amount == this.amount &&
          other.description == this.description &&
          other.source == this.source &&
          other.note == this.note &&
          other.paymentMethod == this.paymentMethod &&
          other.receiptAttachmentId == this.receiptAttachmentId &&
          other.actorId == this.actorId &&
          other.occurredAt == this.occurredAt &&
          other.syncedAt == this.syncedAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted &&
          other.createdAt == this.createdAt &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class CachedOtherIncomesCompanion extends UpdateCompanion<CachedOtherIncome> {
  final Value<String> id;
  final Value<String> businessId;
  final Value<String> storeId;
  final Value<String> clientIncomeId;
  final Value<String> category;
  final Value<Decimal> amount;
  final Value<String> description;
  final Value<String?> source;
  final Value<String?> note;
  final Value<String> paymentMethod;
  final Value<String?> receiptAttachmentId;
  final Value<String?> actorId;
  final Value<DateTime> occurredAt;
  final Value<DateTime> syncedAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastSyncedAt;
  final Value<int> rowid;
  const CachedOtherIncomesCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.storeId = const Value.absent(),
    this.clientIncomeId = const Value.absent(),
    this.category = const Value.absent(),
    this.amount = const Value.absent(),
    this.description = const Value.absent(),
    this.source = const Value.absent(),
    this.note = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.receiptAttachmentId = const Value.absent(),
    this.actorId = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedOtherIncomesCompanion.insert({
    required String id,
    required String businessId,
    required String storeId,
    required String clientIncomeId,
    required String category,
    required Decimal amount,
    required String description,
    this.source = const Value.absent(),
    this.note = const Value.absent(),
    required String paymentMethod,
    this.receiptAttachmentId = const Value.absent(),
    this.actorId = const Value.absent(),
    required DateTime occurredAt,
    required DateTime syncedAt,
    required DateTime updatedAt,
    this.isDeleted = const Value.absent(),
    required DateTime createdAt,
    required DateTime lastSyncedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessId = Value(businessId),
       storeId = Value(storeId),
       clientIncomeId = Value(clientIncomeId),
       category = Value(category),
       amount = Value(amount),
       description = Value(description),
       paymentMethod = Value(paymentMethod),
       occurredAt = Value(occurredAt),
       syncedAt = Value(syncedAt),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<CachedOtherIncome> custom({
    Expression<String>? id,
    Expression<String>? businessId,
    Expression<String>? storeId,
    Expression<String>? clientIncomeId,
    Expression<String>? category,
    Expression<String>? amount,
    Expression<String>? description,
    Expression<String>? source,
    Expression<String>? note,
    Expression<String>? paymentMethod,
    Expression<String>? receiptAttachmentId,
    Expression<String>? actorId,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (storeId != null) 'store_id': storeId,
      if (clientIncomeId != null) 'client_income_id': clientIncomeId,
      if (category != null) 'category': category,
      if (amount != null) 'amount': amount,
      if (description != null) 'description': description,
      if (source != null) 'source': source,
      if (note != null) 'note': note,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (receiptAttachmentId != null)
        'receipt_attachment_id': receiptAttachmentId,
      if (actorId != null) 'actor_id': actorId,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedOtherIncomesCompanion copyWith({
    Value<String>? id,
    Value<String>? businessId,
    Value<String>? storeId,
    Value<String>? clientIncomeId,
    Value<String>? category,
    Value<Decimal>? amount,
    Value<String>? description,
    Value<String?>? source,
    Value<String?>? note,
    Value<String>? paymentMethod,
    Value<String?>? receiptAttachmentId,
    Value<String?>? actorId,
    Value<DateTime>? occurredAt,
    Value<DateTime>? syncedAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return CachedOtherIncomesCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      storeId: storeId ?? this.storeId,
      clientIncomeId: clientIncomeId ?? this.clientIncomeId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      source: source ?? this.source,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptAttachmentId: receiptAttachmentId ?? this.receiptAttachmentId,
      actorId: actorId ?? this.actorId,
      occurredAt: occurredAt ?? this.occurredAt,
      syncedAt: syncedAt ?? this.syncedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (clientIncomeId.present) {
      map['client_income_id'] = Variable<String>(clientIncomeId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(
        $CachedOtherIncomesTable.$converteramount.toSql(amount.value),
      );
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (receiptAttachmentId.present) {
      map['receipt_attachment_id'] = Variable<String>(
        receiptAttachmentId.value,
      );
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedOtherIncomesCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('storeId: $storeId, ')
          ..write('clientIncomeId: $clientIncomeId, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('source: $source, ')
          ..write('note: $note, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('receiptAttachmentId: $receiptAttachmentId, ')
          ..write('actorId: $actorId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomerEntriesTable extends CustomerEntries
    with TableInfo<$CustomerEntriesTable, CustomerEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomerEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressLine1Meta = const VerificationMeta(
    'addressLine1',
  );
  @override
  late final GeneratedColumn<String> addressLine1 = GeneratedColumn<String>(
    'address_line1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _joinedAtMeta = const VerificationMeta(
    'joinedAt',
  );
  @override
  late final GeneratedColumn<DateTime> joinedAt = GeneratedColumn<DateTime>(
    'joined_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorUserIdMeta = const VerificationMeta(
    'actorUserId',
  );
  @override
  late final GeneratedColumn<String> actorUserId = GeneratedColumn<String>(
    'actor_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncAttemptCountMeta = const VerificationMeta(
    'syncAttemptCount',
  );
  @override
  late final GeneratedColumn<int> syncAttemptCount = GeneratedColumn<int>(
    'sync_attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerId,
    businessId,
    name,
    phone,
    email,
    addressLine1,
    joinedAt,
    actorUserId,
    syncStatus,
    syncError,
    syncAttemptCount,
    lastAttemptAt,
    syncedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customer_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomerEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('address_line1')) {
      context.handle(
        _addressLine1Meta,
        addressLine1.isAcceptableOrUnknown(
          data['address_line1']!,
          _addressLine1Meta,
        ),
      );
    }
    if (data.containsKey('joined_at')) {
      context.handle(
        _joinedAtMeta,
        joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_joinedAtMeta);
    }
    if (data.containsKey('actor_user_id')) {
      context.handle(
        _actorUserIdMeta,
        actorUserId.isAcceptableOrUnknown(
          data['actor_user_id']!,
          _actorUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actorUserIdMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
      );
    }
    if (data.containsKey('sync_attempt_count')) {
      context.handle(
        _syncAttemptCountMeta,
        syncAttemptCount.isAcceptableOrUnknown(
          data['sync_attempt_count']!,
          _syncAttemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomerEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomerEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      addressLine1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address_line1'],
      ),
      joinedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}joined_at'],
      )!,
      actorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_user_id'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      ),
      syncAttemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_attempt_count'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CustomerEntriesTable createAlias(String alias) {
    return $CustomerEntriesTable(attachedDatabase, alias);
  }
}

class CustomerEntry extends DataClass implements Insertable<CustomerEntry> {
  /// Local row ID (autoincrement).
  final int id;

  /// The customer's real, permanent id (UUID v4, generated on-device) —
  /// unique locally, and becomes the server's primary key on sync.
  final String customerId;

  /// Business this customer belongs to.
  final String businessId;
  final String name;
  final String phone;
  final String? email;
  final String? addressLine1;

  /// When the customer was added (device time, UTC).
  final DateTime joinedAt;

  /// Staff member who added the customer.
  /// Soft-references `LocalUserProfiles.id` without an FK constraint, same
  /// rationale as `ExpenseEntries.actorUserId`.
  final String actorUserId;

  /// Local sync state: `pending`, `syncing`, `failed`, `synced`.
  final String syncStatus;

  /// Error message from the last sync attempt, if any.
  final String? syncError;

  /// Number of times this entry has been attempted.
  final int syncAttemptCount;

  /// Timestamp of the last sync attempt.
  final DateTime? lastAttemptAt;

  /// When the entry was successfully synced to the backend.
  final DateTime? syncedAt;

  /// Local row creation timestamp.
  final DateTime createdAt;
  const CustomerEntry({
    required this.id,
    required this.customerId,
    required this.businessId,
    required this.name,
    required this.phone,
    this.email,
    this.addressLine1,
    required this.joinedAt,
    required this.actorUserId,
    required this.syncStatus,
    this.syncError,
    required this.syncAttemptCount,
    this.lastAttemptAt,
    this.syncedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['customer_id'] = Variable<String>(customerId);
    map['business_id'] = Variable<String>(businessId);
    map['name'] = Variable<String>(name);
    map['phone'] = Variable<String>(phone);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || addressLine1 != null) {
      map['address_line1'] = Variable<String>(addressLine1);
    }
    map['joined_at'] = Variable<DateTime>(joinedAt);
    map['actor_user_id'] = Variable<String>(actorUserId);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    map['sync_attempt_count'] = Variable<int>(syncAttemptCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CustomerEntriesCompanion toCompanion(bool nullToAbsent) {
    return CustomerEntriesCompanion(
      id: Value(id),
      customerId: Value(customerId),
      businessId: Value(businessId),
      name: Value(name),
      phone: Value(phone),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      addressLine1: addressLine1 == null && nullToAbsent
          ? const Value.absent()
          : Value(addressLine1),
      joinedAt: Value(joinedAt),
      actorUserId: Value(actorUserId),
      syncStatus: Value(syncStatus),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      syncAttemptCount: Value(syncAttemptCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      createdAt: Value(createdAt),
    );
  }

  factory CustomerEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomerEntry(
      id: serializer.fromJson<int>(json['id']),
      customerId: serializer.fromJson<String>(json['customerId']),
      businessId: serializer.fromJson<String>(json['businessId']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      addressLine1: serializer.fromJson<String?>(json['addressLine1']),
      joinedAt: serializer.fromJson<DateTime>(json['joinedAt']),
      actorUserId: serializer.fromJson<String>(json['actorUserId']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      syncAttemptCount: serializer.fromJson<int>(json['syncAttemptCount']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'customerId': serializer.toJson<String>(customerId),
      'businessId': serializer.toJson<String>(businessId),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String>(phone),
      'email': serializer.toJson<String?>(email),
      'addressLine1': serializer.toJson<String?>(addressLine1),
      'joinedAt': serializer.toJson<DateTime>(joinedAt),
      'actorUserId': serializer.toJson<String>(actorUserId),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncError': serializer.toJson<String?>(syncError),
      'syncAttemptCount': serializer.toJson<int>(syncAttemptCount),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CustomerEntry copyWith({
    int? id,
    String? customerId,
    String? businessId,
    String? name,
    String? phone,
    Value<String?> email = const Value.absent(),
    Value<String?> addressLine1 = const Value.absent(),
    DateTime? joinedAt,
    String? actorUserId,
    String? syncStatus,
    Value<String?> syncError = const Value.absent(),
    int? syncAttemptCount,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
    DateTime? createdAt,
  }) => CustomerEntry(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    businessId: businessId ?? this.businessId,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    email: email.present ? email.value : this.email,
    addressLine1: addressLine1.present ? addressLine1.value : this.addressLine1,
    joinedAt: joinedAt ?? this.joinedAt,
    actorUserId: actorUserId ?? this.actorUserId,
    syncStatus: syncStatus ?? this.syncStatus,
    syncError: syncError.present ? syncError.value : this.syncError,
    syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  CustomerEntry copyWithCompanion(CustomerEntriesCompanion data) {
    return CustomerEntry(
      id: data.id.present ? data.id.value : this.id,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      addressLine1: data.addressLine1.present
          ? data.addressLine1.value
          : this.addressLine1,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
      actorUserId: data.actorUserId.present
          ? data.actorUserId.value
          : this.actorUserId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      syncAttemptCount: data.syncAttemptCount.present
          ? data.syncAttemptCount.value
          : this.syncAttemptCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomerEntry(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('businessId: $businessId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('addressLine1: $addressLine1, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('syncAttemptCount: $syncAttemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerId,
    businessId,
    name,
    phone,
    email,
    addressLine1,
    joinedAt,
    actorUserId,
    syncStatus,
    syncError,
    syncAttemptCount,
    lastAttemptAt,
    syncedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomerEntry &&
          other.id == this.id &&
          other.customerId == this.customerId &&
          other.businessId == this.businessId &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.addressLine1 == this.addressLine1 &&
          other.joinedAt == this.joinedAt &&
          other.actorUserId == this.actorUserId &&
          other.syncStatus == this.syncStatus &&
          other.syncError == this.syncError &&
          other.syncAttemptCount == this.syncAttemptCount &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.syncedAt == this.syncedAt &&
          other.createdAt == this.createdAt);
}

class CustomerEntriesCompanion extends UpdateCompanion<CustomerEntry> {
  final Value<int> id;
  final Value<String> customerId;
  final Value<String> businessId;
  final Value<String> name;
  final Value<String> phone;
  final Value<String?> email;
  final Value<String?> addressLine1;
  final Value<DateTime> joinedAt;
  final Value<String> actorUserId;
  final Value<String> syncStatus;
  final Value<String?> syncError;
  final Value<int> syncAttemptCount;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> syncedAt;
  final Value<DateTime> createdAt;
  const CustomerEntriesCompanion({
    this.id = const Value.absent(),
    this.customerId = const Value.absent(),
    this.businessId = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.addressLine1 = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.actorUserId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncAttemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CustomerEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String customerId,
    required String businessId,
    required String name,
    required String phone,
    this.email = const Value.absent(),
    this.addressLine1 = const Value.absent(),
    required DateTime joinedAt,
    required String actorUserId,
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncAttemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required DateTime createdAt,
  }) : customerId = Value(customerId),
       businessId = Value(businessId),
       name = Value(name),
       phone = Value(phone),
       joinedAt = Value(joinedAt),
       actorUserId = Value(actorUserId),
       createdAt = Value(createdAt);
  static Insertable<CustomerEntry> custom({
    Expression<int>? id,
    Expression<String>? customerId,
    Expression<String>? businessId,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? addressLine1,
    Expression<DateTime>? joinedAt,
    Expression<String>? actorUserId,
    Expression<String>? syncStatus,
    Expression<String>? syncError,
    Expression<int>? syncAttemptCount,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      if (businessId != null) 'business_id': businessId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (addressLine1 != null) 'address_line1': addressLine1,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (actorUserId != null) 'actor_user_id': actorUserId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncError != null) 'sync_error': syncError,
      if (syncAttemptCount != null) 'sync_attempt_count': syncAttemptCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CustomerEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? customerId,
    Value<String>? businessId,
    Value<String>? name,
    Value<String>? phone,
    Value<String?>? email,
    Value<String?>? addressLine1,
    Value<DateTime>? joinedAt,
    Value<String>? actorUserId,
    Value<String>? syncStatus,
    Value<String?>? syncError,
    Value<int>? syncAttemptCount,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime?>? syncedAt,
    Value<DateTime>? createdAt,
  }) {
    return CustomerEntriesCompanion(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      addressLine1: addressLine1 ?? this.addressLine1,
      joinedAt: joinedAt ?? this.joinedAt,
      actorUserId: actorUserId ?? this.actorUserId,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (addressLine1.present) {
      map['address_line1'] = Variable<String>(addressLine1.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<DateTime>(joinedAt.value);
    }
    if (actorUserId.present) {
      map['actor_user_id'] = Variable<String>(actorUserId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (syncAttemptCount.present) {
      map['sync_attempt_count'] = Variable<int>(syncAttemptCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomerEntriesCompanion(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('businessId: $businessId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('addressLine1: $addressLine1, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('syncAttemptCount: $syncAttemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CachedCustomersTable extends CachedCustomers
    with TableInfo<$CachedCustomersTable, CachedCustomer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressLine1Meta = const VerificationMeta(
    'addressLine1',
  );
  @override
  late final GeneratedColumn<String> addressLine1 = GeneratedColumn<String>(
    'address_line1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
    'actor_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _joinedAtMeta = const VerificationMeta(
    'joinedAt',
  );
  @override
  late final GeneratedColumn<DateTime> joinedAt = GeneratedColumn<DateTime>(
    'joined_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalOrdersMeta = const VerificationMeta(
    'totalOrders',
  );
  @override
  late final GeneratedColumn<int> totalOrders = GeneratedColumn<int>(
    'total_orders',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> totalSpent =
      GeneratedColumn<String>(
        'total_spent',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($CachedCustomersTable.$convertertotalSpent);
  static const VerificationMeta _lastOrderAtMeta = const VerificationMeta(
    'lastOrderAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOrderAt = GeneratedColumn<DateTime>(
    'last_order_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    name,
    phone,
    email,
    addressLine1,
    actorId,
    joinedAt,
    syncedAt,
    updatedAt,
    isDeleted,
    createdAt,
    totalOrders,
    totalSpent,
    lastOrderAt,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_customers';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCustomer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('address_line1')) {
      context.handle(
        _addressLine1Meta,
        addressLine1.isAcceptableOrUnknown(
          data['address_line1']!,
          _addressLine1Meta,
        ),
      );
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    }
    if (data.containsKey('joined_at')) {
      context.handle(
        _joinedAtMeta,
        joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_joinedAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('total_orders')) {
      context.handle(
        _totalOrdersMeta,
        totalOrders.isAcceptableOrUnknown(
          data['total_orders']!,
          _totalOrdersMeta,
        ),
      );
    }
    if (data.containsKey('last_order_at')) {
      context.handle(
        _lastOrderAtMeta,
        lastOrderAt.isAcceptableOrUnknown(
          data['last_order_at']!,
          _lastOrderAtMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedCustomer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCustomer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      addressLine1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address_line1'],
      ),
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_id'],
      ),
      joinedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}joined_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      totalOrders: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_orders'],
      )!,
      totalSpent: $CachedCustomersTable.$convertertotalSpent.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}total_spent'],
        )!,
      ),
      lastOrderAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_order_at'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
    );
  }

  @override
  $CachedCustomersTable createAlias(String alias) {
    return $CachedCustomersTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $convertertotalSpent =
      const DecimalConverter();
}

class CachedCustomer extends DataClass implements Insertable<CachedCustomer> {
  /// Customer UUID — server-assigned, but identical to the id the device
  /// generated when this customer was first created (primary key).
  final String id;

  /// Business this customer belongs to.
  final String businessId;
  final String name;
  final String phone;
  final String? email;
  final String? addressLine1;

  /// Staff member who added the customer, if known.
  final String? actorId;

  /// When the customer was added (device-reported time, UTC).
  final DateTime joinedAt;

  /// When POS Service accepted this customer.
  final DateTime syncedAt;

  /// Last-edited timestamp (server-computed).
  final DateTime updatedAt;

  /// Soft-delete flag — see class doc for why deleted rows are still pulled.
  final bool isDeleted;

  /// Backend creation timestamp.
  final DateTime createdAt;

  /// Server-computed order count, from completed sales only.
  final int totalOrders;

  /// Server-computed lifetime spend, from completed sales only.
  final Decimal totalSpent;

  /// Server-computed most recent completed-sale timestamp.
  final DateTime? lastOrderAt;

  /// Local timestamp of the most recent pull that included this row.
  final DateTime lastSyncedAt;
  const CachedCustomer({
    required this.id,
    required this.businessId,
    required this.name,
    required this.phone,
    this.email,
    this.addressLine1,
    this.actorId,
    required this.joinedAt,
    required this.syncedAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.createdAt,
    required this.totalOrders,
    required this.totalSpent,
    this.lastOrderAt,
    required this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['business_id'] = Variable<String>(businessId);
    map['name'] = Variable<String>(name);
    map['phone'] = Variable<String>(phone);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || addressLine1 != null) {
      map['address_line1'] = Variable<String>(addressLine1);
    }
    if (!nullToAbsent || actorId != null) {
      map['actor_id'] = Variable<String>(actorId);
    }
    map['joined_at'] = Variable<DateTime>(joinedAt);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['total_orders'] = Variable<int>(totalOrders);
    {
      map['total_spent'] = Variable<String>(
        $CachedCustomersTable.$convertertotalSpent.toSql(totalSpent),
      );
    }
    if (!nullToAbsent || lastOrderAt != null) {
      map['last_order_at'] = Variable<DateTime>(lastOrderAt);
    }
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    return map;
  }

  CachedCustomersCompanion toCompanion(bool nullToAbsent) {
    return CachedCustomersCompanion(
      id: Value(id),
      businessId: Value(businessId),
      name: Value(name),
      phone: Value(phone),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      addressLine1: addressLine1 == null && nullToAbsent
          ? const Value.absent()
          : Value(addressLine1),
      actorId: actorId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorId),
      joinedAt: Value(joinedAt),
      syncedAt: Value(syncedAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt),
      totalOrders: Value(totalOrders),
      totalSpent: Value(totalSpent),
      lastOrderAt: lastOrderAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOrderAt),
      lastSyncedAt: Value(lastSyncedAt),
    );
  }

  factory CachedCustomer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCustomer(
      id: serializer.fromJson<String>(json['id']),
      businessId: serializer.fromJson<String>(json['businessId']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      addressLine1: serializer.fromJson<String?>(json['addressLine1']),
      actorId: serializer.fromJson<String?>(json['actorId']),
      joinedAt: serializer.fromJson<DateTime>(json['joinedAt']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      totalOrders: serializer.fromJson<int>(json['totalOrders']),
      totalSpent: serializer.fromJson<Decimal>(json['totalSpent']),
      lastOrderAt: serializer.fromJson<DateTime?>(json['lastOrderAt']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'businessId': serializer.toJson<String>(businessId),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String>(phone),
      'email': serializer.toJson<String?>(email),
      'addressLine1': serializer.toJson<String?>(addressLine1),
      'actorId': serializer.toJson<String?>(actorId),
      'joinedAt': serializer.toJson<DateTime>(joinedAt),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'totalOrders': serializer.toJson<int>(totalOrders),
      'totalSpent': serializer.toJson<Decimal>(totalSpent),
      'lastOrderAt': serializer.toJson<DateTime?>(lastOrderAt),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
    };
  }

  CachedCustomer copyWith({
    String? id,
    String? businessId,
    String? name,
    String? phone,
    Value<String?> email = const Value.absent(),
    Value<String?> addressLine1 = const Value.absent(),
    Value<String?> actorId = const Value.absent(),
    DateTime? joinedAt,
    DateTime? syncedAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? createdAt,
    int? totalOrders,
    Decimal? totalSpent,
    Value<DateTime?> lastOrderAt = const Value.absent(),
    DateTime? lastSyncedAt,
  }) => CachedCustomer(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    email: email.present ? email.value : this.email,
    addressLine1: addressLine1.present ? addressLine1.value : this.addressLine1,
    actorId: actorId.present ? actorId.value : this.actorId,
    joinedAt: joinedAt ?? this.joinedAt,
    syncedAt: syncedAt ?? this.syncedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    createdAt: createdAt ?? this.createdAt,
    totalOrders: totalOrders ?? this.totalOrders,
    totalSpent: totalSpent ?? this.totalSpent,
    lastOrderAt: lastOrderAt.present ? lastOrderAt.value : this.lastOrderAt,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
  CachedCustomer copyWithCompanion(CachedCustomersCompanion data) {
    return CachedCustomer(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      addressLine1: data.addressLine1.present
          ? data.addressLine1.value
          : this.addressLine1,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      totalOrders: data.totalOrders.present
          ? data.totalOrders.value
          : this.totalOrders,
      totalSpent: data.totalSpent.present
          ? data.totalSpent.value
          : this.totalSpent,
      lastOrderAt: data.lastOrderAt.present
          ? data.lastOrderAt.value
          : this.lastOrderAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCustomer(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('addressLine1: $addressLine1, ')
          ..write('actorId: $actorId, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('totalOrders: $totalOrders, ')
          ..write('totalSpent: $totalSpent, ')
          ..write('lastOrderAt: $lastOrderAt, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    name,
    phone,
    email,
    addressLine1,
    actorId,
    joinedAt,
    syncedAt,
    updatedAt,
    isDeleted,
    createdAt,
    totalOrders,
    totalSpent,
    lastOrderAt,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCustomer &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.addressLine1 == this.addressLine1 &&
          other.actorId == this.actorId &&
          other.joinedAt == this.joinedAt &&
          other.syncedAt == this.syncedAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted &&
          other.createdAt == this.createdAt &&
          other.totalOrders == this.totalOrders &&
          other.totalSpent == this.totalSpent &&
          other.lastOrderAt == this.lastOrderAt &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class CachedCustomersCompanion extends UpdateCompanion<CachedCustomer> {
  final Value<String> id;
  final Value<String> businessId;
  final Value<String> name;
  final Value<String> phone;
  final Value<String?> email;
  final Value<String?> addressLine1;
  final Value<String?> actorId;
  final Value<DateTime> joinedAt;
  final Value<DateTime> syncedAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  final Value<DateTime> createdAt;
  final Value<int> totalOrders;
  final Value<Decimal> totalSpent;
  final Value<DateTime?> lastOrderAt;
  final Value<DateTime> lastSyncedAt;
  final Value<int> rowid;
  const CachedCustomersCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.addressLine1 = const Value.absent(),
    this.actorId = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.totalOrders = const Value.absent(),
    this.totalSpent = const Value.absent(),
    this.lastOrderAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCustomersCompanion.insert({
    required String id,
    required String businessId,
    required String name,
    required String phone,
    this.email = const Value.absent(),
    this.addressLine1 = const Value.absent(),
    this.actorId = const Value.absent(),
    required DateTime joinedAt,
    required DateTime syncedAt,
    required DateTime updatedAt,
    this.isDeleted = const Value.absent(),
    required DateTime createdAt,
    this.totalOrders = const Value.absent(),
    required Decimal totalSpent,
    this.lastOrderAt = const Value.absent(),
    required DateTime lastSyncedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessId = Value(businessId),
       name = Value(name),
       phone = Value(phone),
       joinedAt = Value(joinedAt),
       syncedAt = Value(syncedAt),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt),
       totalSpent = Value(totalSpent),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<CachedCustomer> custom({
    Expression<String>? id,
    Expression<String>? businessId,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? addressLine1,
    Expression<String>? actorId,
    Expression<DateTime>? joinedAt,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
    Expression<DateTime>? createdAt,
    Expression<int>? totalOrders,
    Expression<String>? totalSpent,
    Expression<DateTime>? lastOrderAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (addressLine1 != null) 'address_line1': addressLine1,
      if (actorId != null) 'actor_id': actorId,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt,
      if (totalOrders != null) 'total_orders': totalOrders,
      if (totalSpent != null) 'total_spent': totalSpent,
      if (lastOrderAt != null) 'last_order_at': lastOrderAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCustomersCompanion copyWith({
    Value<String>? id,
    Value<String>? businessId,
    Value<String>? name,
    Value<String>? phone,
    Value<String?>? email,
    Value<String?>? addressLine1,
    Value<String?>? actorId,
    Value<DateTime>? joinedAt,
    Value<DateTime>? syncedAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
    Value<DateTime>? createdAt,
    Value<int>? totalOrders,
    Value<Decimal>? totalSpent,
    Value<DateTime?>? lastOrderAt,
    Value<DateTime>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return CachedCustomersCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      addressLine1: addressLine1 ?? this.addressLine1,
      actorId: actorId ?? this.actorId,
      joinedAt: joinedAt ?? this.joinedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
      lastOrderAt: lastOrderAt ?? this.lastOrderAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (addressLine1.present) {
      map['address_line1'] = Variable<String>(addressLine1.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<DateTime>(joinedAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (totalOrders.present) {
      map['total_orders'] = Variable<int>(totalOrders.value);
    }
    if (totalSpent.present) {
      map['total_spent'] = Variable<String>(
        $CachedCustomersTable.$convertertotalSpent.toSql(totalSpent.value),
      );
    }
    if (lastOrderAt.present) {
      map['last_order_at'] = Variable<DateTime>(lastOrderAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCustomersCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('addressLine1: $addressLine1, ')
          ..write('actorId: $actorId, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('totalOrders: $totalOrders, ')
          ..write('totalSpent: $totalSpent, ')
          ..write('lastOrderAt: $lastOrderAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedSuppliersTable extends CachedSuppliers
    with TableInfo<$CachedSuppliersTable, CachedSupplier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedSuppliersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressLine1Meta = const VerificationMeta(
    'addressLine1',
  );
  @override
  late final GeneratedColumn<String> addressLine1 = GeneratedColumn<String>(
    'address_line1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessId,
    name,
    phone,
    email,
    addressLine1,
    notes,
    updatedAt,
    isDeleted,
    createdAt,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_suppliers';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedSupplier> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    } else if (isInserting) {
      context.missing(_businessIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('address_line1')) {
      context.handle(
        _addressLine1Meta,
        addressLine1.isAcceptableOrUnknown(
          data['address_line1']!,
          _addressLine1Meta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedSupplier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedSupplier(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      addressLine1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address_line1'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
    );
  }

  @override
  $CachedSuppliersTable createAlias(String alias) {
    return $CachedSuppliersTable(attachedDatabase, alias);
  }
}

class CachedSupplier extends DataClass implements Insertable<CachedSupplier> {
  /// Supplier UUID (primary key), server-assigned.
  final String id;

  /// Business this supplier belongs to.
  final String businessId;
  final String name;
  final String? phone;
  final String? email;
  final String? addressLine1;
  final String? notes;

  /// Last-edited timestamp (server-computed).
  final DateTime updatedAt;

  /// Soft-delete flag — see class doc for why deleted rows are still pulled.
  final bool isDeleted;

  /// Backend creation timestamp.
  final DateTime createdAt;

  /// Local timestamp of the most recent pull that included this row.
  final DateTime lastSyncedAt;
  const CachedSupplier({
    required this.id,
    required this.businessId,
    required this.name,
    this.phone,
    this.email,
    this.addressLine1,
    this.notes,
    required this.updatedAt,
    required this.isDeleted,
    required this.createdAt,
    required this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['business_id'] = Variable<String>(businessId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || addressLine1 != null) {
      map['address_line1'] = Variable<String>(addressLine1);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    return map;
  }

  CachedSuppliersCompanion toCompanion(bool nullToAbsent) {
    return CachedSuppliersCompanion(
      id: Value(id),
      businessId: Value(businessId),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      addressLine1: addressLine1 == null && nullToAbsent
          ? const Value.absent()
          : Value(addressLine1),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt),
      lastSyncedAt: Value(lastSyncedAt),
    );
  }

  factory CachedSupplier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedSupplier(
      id: serializer.fromJson<String>(json['id']),
      businessId: serializer.fromJson<String>(json['businessId']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      addressLine1: serializer.fromJson<String?>(json['addressLine1']),
      notes: serializer.fromJson<String?>(json['notes']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'businessId': serializer.toJson<String>(businessId),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'addressLine1': serializer.toJson<String?>(addressLine1),
      'notes': serializer.toJson<String?>(notes),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
    };
  }

  CachedSupplier copyWith({
    String? id,
    String? businessId,
    String? name,
    Value<String?> phone = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> addressLine1 = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? lastSyncedAt,
  }) => CachedSupplier(
    id: id ?? this.id,
    businessId: businessId ?? this.businessId,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    email: email.present ? email.value : this.email,
    addressLine1: addressLine1.present ? addressLine1.value : this.addressLine1,
    notes: notes.present ? notes.value : this.notes,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    createdAt: createdAt ?? this.createdAt,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
  CachedSupplier copyWithCompanion(CachedSuppliersCompanion data) {
    return CachedSupplier(
      id: data.id.present ? data.id.value : this.id,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      addressLine1: data.addressLine1.present
          ? data.addressLine1.value
          : this.addressLine1,
      notes: data.notes.present ? data.notes.value : this.notes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedSupplier(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('addressLine1: $addressLine1, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    name,
    phone,
    email,
    addressLine1,
    notes,
    updatedAt,
    isDeleted,
    createdAt,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedSupplier &&
          other.id == this.id &&
          other.businessId == this.businessId &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.addressLine1 == this.addressLine1 &&
          other.notes == this.notes &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted &&
          other.createdAt == this.createdAt &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class CachedSuppliersCompanion extends UpdateCompanion<CachedSupplier> {
  final Value<String> id;
  final Value<String> businessId;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<String?> addressLine1;
  final Value<String?> notes;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastSyncedAt;
  final Value<int> rowid;
  const CachedSuppliersCompanion({
    this.id = const Value.absent(),
    this.businessId = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.addressLine1 = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedSuppliersCompanion.insert({
    required String id,
    required String businessId,
    required String name,
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.addressLine1 = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime updatedAt,
    this.isDeleted = const Value.absent(),
    required DateTime createdAt,
    required DateTime lastSyncedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessId = Value(businessId),
       name = Value(name),
       updatedAt = Value(updatedAt),
       createdAt = Value(createdAt),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<CachedSupplier> custom({
    Expression<String>? id,
    Expression<String>? businessId,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? addressLine1,
    Expression<String>? notes,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (addressLine1 != null) 'address_line1': addressLine1,
      if (notes != null) 'notes': notes,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedSuppliersCompanion copyWith({
    Value<String>? id,
    Value<String>? businessId,
    Value<String>? name,
    Value<String?>? phone,
    Value<String?>? email,
    Value<String?>? addressLine1,
    Value<String?>? notes,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return CachedSuppliersCompanion(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      addressLine1: addressLine1 ?? this.addressLine1,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (addressLine1.present) {
      map['address_line1'] = Variable<String>(addressLine1.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedSuppliersCompanion(')
          ..write('id: $id, ')
          ..write('businessId: $businessId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('addressLine1: $addressLine1, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedCategoriesTable extends CachedCategories
    with TableInfo<$CachedCategoriesTable, CachedCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    code,
    name,
    sortOrder,
    isActive,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
    );
  }

  @override
  $CachedCategoriesTable createAlias(String alias) {
    return $CachedCategoriesTable(attachedDatabase, alias);
  }
}

class CachedCategory extends DataClass implements Insertable<CachedCategory> {
  /// Category UUID (primary key), server-assigned.
  final String id;

  /// Stable slug (e.g. `produce`) — not used by the UI directly, kept for
  /// debugging/traceability back to the seed migration.
  final String code;
  final String name;

  /// Display ordering for pickers/filters, ascending.
  final int sortOrder;
  final bool isActive;

  /// Local timestamp of the most recent pull that included this row.
  final DateTime lastSyncedAt;
  const CachedCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    required this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_active'] = Variable<bool>(isActive);
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    return map;
  }

  CachedCategoriesCompanion toCompanion(bool nullToAbsent) {
    return CachedCategoriesCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      sortOrder: Value(sortOrder),
      isActive: Value(isActive),
      lastSyncedAt: Value(lastSyncedAt),
    );
  }

  factory CachedCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCategory(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isActive': serializer.toJson<bool>(isActive),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
    };
  }

  CachedCategory copyWith({
    String? id,
    String? code,
    String? name,
    int? sortOrder,
    bool? isActive,
    DateTime? lastSyncedAt,
  }) => CachedCategory(
    id: id ?? this.id,
    code: code ?? this.code,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    isActive: isActive ?? this.isActive,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
  CachedCategory copyWithCompanion(CachedCategoriesCompanion data) {
    return CachedCategory(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCategory(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isActive: $isActive, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, code, name, sortOrder, isActive, lastSyncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCategory &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.isActive == this.isActive &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class CachedCategoriesCompanion extends UpdateCompanion<CachedCategory> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<bool> isActive;
  final Value<DateTime> lastSyncedAt;
  final Value<int> rowid;
  const CachedCategoriesCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCategoriesCompanion.insert({
    required String id,
    required String code,
    required String name,
    this.sortOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime lastSyncedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       name = Value(name),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<CachedCategory> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<bool>? isActive,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isActive != null) 'is_active': isActive,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<bool>? isActive,
    Value<DateTime>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return CachedCategoriesCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isActive: $isActive, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedUnitsTable extends CachedUnits
    with TableInfo<$CachedUnitsTable, CachedUnit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedUnitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _abbreviationMeta = const VerificationMeta(
    'abbreviation',
  );
  @override
  late final GeneratedColumn<String> abbreviation = GeneratedColumn<String>(
    'abbreviation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    code,
    name,
    abbreviation,
    sortOrder,
    isActive,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_units';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedUnit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('abbreviation')) {
      context.handle(
        _abbreviationMeta,
        abbreviation.isAcceptableOrUnknown(
          data['abbreviation']!,
          _abbreviationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_abbreviationMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedUnit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedUnit(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      abbreviation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}abbreviation'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
    );
  }

  @override
  $CachedUnitsTable createAlias(String alias) {
    return $CachedUnitsTable(attachedDatabase, alias);
  }
}

class CachedUnit extends DataClass implements Insertable<CachedUnit> {
  /// Unit UUID (primary key), server-assigned.
  final String id;

  /// Stable slug (e.g. `kg`) — not used by the UI directly, kept for
  /// debugging/traceability back to the seed script.
  final String code;
  final String name;

  /// Short display label shown next to a quantity (e.g. `L`, `ea`) — what
  /// the item form's dropdown actually shows and what gets stored on
  /// `InventoryItem.unit`.
  final String abbreviation;

  /// Display ordering for pickers, ascending.
  final int sortOrder;
  final bool isActive;

  /// Local timestamp of the most recent pull that included this row.
  final DateTime lastSyncedAt;
  const CachedUnit({
    required this.id,
    required this.code,
    required this.name,
    required this.abbreviation,
    required this.sortOrder,
    required this.isActive,
    required this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['abbreviation'] = Variable<String>(abbreviation);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_active'] = Variable<bool>(isActive);
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    return map;
  }

  CachedUnitsCompanion toCompanion(bool nullToAbsent) {
    return CachedUnitsCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      abbreviation: Value(abbreviation),
      sortOrder: Value(sortOrder),
      isActive: Value(isActive),
      lastSyncedAt: Value(lastSyncedAt),
    );
  }

  factory CachedUnit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedUnit(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      abbreviation: serializer.fromJson<String>(json['abbreviation']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'abbreviation': serializer.toJson<String>(abbreviation),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isActive': serializer.toJson<bool>(isActive),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
    };
  }

  CachedUnit copyWith({
    String? id,
    String? code,
    String? name,
    String? abbreviation,
    int? sortOrder,
    bool? isActive,
    DateTime? lastSyncedAt,
  }) => CachedUnit(
    id: id ?? this.id,
    code: code ?? this.code,
    name: name ?? this.name,
    abbreviation: abbreviation ?? this.abbreviation,
    sortOrder: sortOrder ?? this.sortOrder,
    isActive: isActive ?? this.isActive,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
  CachedUnit copyWithCompanion(CachedUnitsCompanion data) {
    return CachedUnit(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      abbreviation: data.abbreviation.present
          ? data.abbreviation.value
          : this.abbreviation,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedUnit(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('abbreviation: $abbreviation, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isActive: $isActive, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    abbreviation,
    sortOrder,
    isActive,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedUnit &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.abbreviation == this.abbreviation &&
          other.sortOrder == this.sortOrder &&
          other.isActive == this.isActive &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class CachedUnitsCompanion extends UpdateCompanion<CachedUnit> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<String> abbreviation;
  final Value<int> sortOrder;
  final Value<bool> isActive;
  final Value<DateTime> lastSyncedAt;
  final Value<int> rowid;
  const CachedUnitsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.abbreviation = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedUnitsCompanion.insert({
    required String id,
    required String code,
    required String name,
    required String abbreviation,
    this.sortOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime lastSyncedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       name = Value(name),
       abbreviation = Value(abbreviation),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<CachedUnit> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? abbreviation,
    Expression<int>? sortOrder,
    Expression<bool>? isActive,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (abbreviation != null) 'abbreviation': abbreviation,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isActive != null) 'is_active': isActive,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedUnitsCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? name,
    Value<String>? abbreviation,
    Value<int>? sortOrder,
    Value<bool>? isActive,
    Value<DateTime>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return CachedUnitsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (abbreviation.present) {
      map['abbreviation'] = Variable<String>(abbreviation.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedUnitsCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('abbreviation: $abbreviation, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isActive: $isActive, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAuditLogTable extends LocalAuditLog
    with TableInfo<$LocalAuditLogTable, LocalAuditLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAuditLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _actorUserIdMeta = const VerificationMeta(
    'actorUserId',
  );
  @override
  late final GeneratedColumn<String> actorUserId = GeneratedColumn<String>(
    'actor_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resourceTypeMeta = const VerificationMeta(
    'resourceType',
  );
  @override
  late final GeneratedColumn<String> resourceType = GeneratedColumn<String>(
    'resource_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resourceIdMeta = const VerificationMeta(
    'resourceId',
  );
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
    'resource_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailsJsonMeta = const VerificationMeta(
    'detailsJson',
  );
  @override
  late final GeneratedColumn<String> detailsJson = GeneratedColumn<String>(
    'details_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncAttemptCountMeta = const VerificationMeta(
    'syncAttemptCount',
  );
  @override
  late final GeneratedColumn<int> syncAttemptCount = GeneratedColumn<int>(
    'sync_attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    actorUserId,
    action,
    resourceType,
    resourceId,
    detailsJson,
    occurredAt,
    syncStatus,
    syncError,
    syncAttemptCount,
    lastAttemptAt,
    syncedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_audit_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAuditLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('actor_user_id')) {
      context.handle(
        _actorUserIdMeta,
        actorUserId.isAcceptableOrUnknown(
          data['actor_user_id']!,
          _actorUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actorUserIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('resource_type')) {
      context.handle(
        _resourceTypeMeta,
        resourceType.isAcceptableOrUnknown(
          data['resource_type']!,
          _resourceTypeMeta,
        ),
      );
    }
    if (data.containsKey('resource_id')) {
      context.handle(
        _resourceIdMeta,
        resourceId.isAcceptableOrUnknown(data['resource_id']!, _resourceIdMeta),
      );
    }
    if (data.containsKey('details_json')) {
      context.handle(
        _detailsJsonMeta,
        detailsJson.isAcceptableOrUnknown(
          data['details_json']!,
          _detailsJsonMeta,
        ),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
      );
    }
    if (data.containsKey('sync_attempt_count')) {
      context.handle(
        _syncAttemptCountMeta,
        syncAttemptCount.isAcceptableOrUnknown(
          data['sync_attempt_count']!,
          _syncAttemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAuditLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAuditLogData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      actorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_user_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      resourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_type'],
      ),
      resourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_id'],
      ),
      detailsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details_json'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      ),
      syncAttemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_attempt_count'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalAuditLogTable createAlias(String alias) {
    return $LocalAuditLogTable(attachedDatabase, alias);
  }
}

class LocalAuditLogData extends DataClass
    implements Insertable<LocalAuditLogData> {
  /// Local row ID (autoincrement).
  final int id;

  /// Staff member (or system) responsible for the action.
  /// Soft-references `LocalUserProfiles.id` without an FK constraint: a
  /// profile that is later remotely revoked and deleted should not block
  /// or cascade-delete a historical audit entry.
  final String actorUserId;

  /// Event identifier, e.g. `pin.unlock_failed`, `sale.completed`,
  /// `expense.recorded`, `profile.remotely_revoked`.
  final String action;

  /// Optional type of the resource this event concerns.
  final String? resourceType;

  /// Optional ID of the resource this event concerns.
  final String? resourceId;

  /// Optional JSON-encoded event details.
  final String? detailsJson;

  /// When the event occurred (device time, UTC).
  final DateTime occurredAt;

  /// Local sync state: `pending`, `syncing`, `failed`, `synced`.
  final String syncStatus;

  /// Error message from the last sync attempt, if any.
  final String? syncError;

  /// Number of times this entry has been attempted.
  final int syncAttemptCount;

  /// Timestamp of the last sync attempt.
  final DateTime? lastAttemptAt;

  /// When the entry was successfully synced to the backend.
  final DateTime? syncedAt;

  /// Local row creation timestamp.
  final DateTime createdAt;
  const LocalAuditLogData({
    required this.id,
    required this.actorUserId,
    required this.action,
    this.resourceType,
    this.resourceId,
    this.detailsJson,
    required this.occurredAt,
    required this.syncStatus,
    this.syncError,
    required this.syncAttemptCount,
    this.lastAttemptAt,
    this.syncedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['actor_user_id'] = Variable<String>(actorUserId);
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || resourceType != null) {
      map['resource_type'] = Variable<String>(resourceType);
    }
    if (!nullToAbsent || resourceId != null) {
      map['resource_id'] = Variable<String>(resourceId);
    }
    if (!nullToAbsent || detailsJson != null) {
      map['details_json'] = Variable<String>(detailsJson);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    map['sync_attempt_count'] = Variable<int>(syncAttemptCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalAuditLogCompanion toCompanion(bool nullToAbsent) {
    return LocalAuditLogCompanion(
      id: Value(id),
      actorUserId: Value(actorUserId),
      action: Value(action),
      resourceType: resourceType == null && nullToAbsent
          ? const Value.absent()
          : Value(resourceType),
      resourceId: resourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(resourceId),
      detailsJson: detailsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(detailsJson),
      occurredAt: Value(occurredAt),
      syncStatus: Value(syncStatus),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      syncAttemptCount: Value(syncAttemptCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      createdAt: Value(createdAt),
    );
  }

  factory LocalAuditLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAuditLogData(
      id: serializer.fromJson<int>(json['id']),
      actorUserId: serializer.fromJson<String>(json['actorUserId']),
      action: serializer.fromJson<String>(json['action']),
      resourceType: serializer.fromJson<String?>(json['resourceType']),
      resourceId: serializer.fromJson<String?>(json['resourceId']),
      detailsJson: serializer.fromJson<String?>(json['detailsJson']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      syncAttemptCount: serializer.fromJson<int>(json['syncAttemptCount']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'actorUserId': serializer.toJson<String>(actorUserId),
      'action': serializer.toJson<String>(action),
      'resourceType': serializer.toJson<String?>(resourceType),
      'resourceId': serializer.toJson<String?>(resourceId),
      'detailsJson': serializer.toJson<String?>(detailsJson),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncError': serializer.toJson<String?>(syncError),
      'syncAttemptCount': serializer.toJson<int>(syncAttemptCount),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalAuditLogData copyWith({
    int? id,
    String? actorUserId,
    String? action,
    Value<String?> resourceType = const Value.absent(),
    Value<String?> resourceId = const Value.absent(),
    Value<String?> detailsJson = const Value.absent(),
    DateTime? occurredAt,
    String? syncStatus,
    Value<String?> syncError = const Value.absent(),
    int? syncAttemptCount,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
    DateTime? createdAt,
  }) => LocalAuditLogData(
    id: id ?? this.id,
    actorUserId: actorUserId ?? this.actorUserId,
    action: action ?? this.action,
    resourceType: resourceType.present ? resourceType.value : this.resourceType,
    resourceId: resourceId.present ? resourceId.value : this.resourceId,
    detailsJson: detailsJson.present ? detailsJson.value : this.detailsJson,
    occurredAt: occurredAt ?? this.occurredAt,
    syncStatus: syncStatus ?? this.syncStatus,
    syncError: syncError.present ? syncError.value : this.syncError,
    syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalAuditLogData copyWithCompanion(LocalAuditLogCompanion data) {
    return LocalAuditLogData(
      id: data.id.present ? data.id.value : this.id,
      actorUserId: data.actorUserId.present
          ? data.actorUserId.value
          : this.actorUserId,
      action: data.action.present ? data.action.value : this.action,
      resourceType: data.resourceType.present
          ? data.resourceType.value
          : this.resourceType,
      resourceId: data.resourceId.present
          ? data.resourceId.value
          : this.resourceId,
      detailsJson: data.detailsJson.present
          ? data.detailsJson.value
          : this.detailsJson,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      syncAttemptCount: data.syncAttemptCount.present
          ? data.syncAttemptCount.value
          : this.syncAttemptCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAuditLogData(')
          ..write('id: $id, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('action: $action, ')
          ..write('resourceType: $resourceType, ')
          ..write('resourceId: $resourceId, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('syncAttemptCount: $syncAttemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    actorUserId,
    action,
    resourceType,
    resourceId,
    detailsJson,
    occurredAt,
    syncStatus,
    syncError,
    syncAttemptCount,
    lastAttemptAt,
    syncedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAuditLogData &&
          other.id == this.id &&
          other.actorUserId == this.actorUserId &&
          other.action == this.action &&
          other.resourceType == this.resourceType &&
          other.resourceId == this.resourceId &&
          other.detailsJson == this.detailsJson &&
          other.occurredAt == this.occurredAt &&
          other.syncStatus == this.syncStatus &&
          other.syncError == this.syncError &&
          other.syncAttemptCount == this.syncAttemptCount &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.syncedAt == this.syncedAt &&
          other.createdAt == this.createdAt);
}

class LocalAuditLogCompanion extends UpdateCompanion<LocalAuditLogData> {
  final Value<int> id;
  final Value<String> actorUserId;
  final Value<String> action;
  final Value<String?> resourceType;
  final Value<String?> resourceId;
  final Value<String?> detailsJson;
  final Value<DateTime> occurredAt;
  final Value<String> syncStatus;
  final Value<String?> syncError;
  final Value<int> syncAttemptCount;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> syncedAt;
  final Value<DateTime> createdAt;
  const LocalAuditLogCompanion({
    this.id = const Value.absent(),
    this.actorUserId = const Value.absent(),
    this.action = const Value.absent(),
    this.resourceType = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncAttemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LocalAuditLogCompanion.insert({
    this.id = const Value.absent(),
    required String actorUserId,
    required String action,
    this.resourceType = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.detailsJson = const Value.absent(),
    required DateTime occurredAt,
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.syncAttemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    required DateTime createdAt,
  }) : actorUserId = Value(actorUserId),
       action = Value(action),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt);
  static Insertable<LocalAuditLogData> custom({
    Expression<int>? id,
    Expression<String>? actorUserId,
    Expression<String>? action,
    Expression<String>? resourceType,
    Expression<String>? resourceId,
    Expression<String>? detailsJson,
    Expression<DateTime>? occurredAt,
    Expression<String>? syncStatus,
    Expression<String>? syncError,
    Expression<int>? syncAttemptCount,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (actorUserId != null) 'actor_user_id': actorUserId,
      if (action != null) 'action': action,
      if (resourceType != null) 'resource_type': resourceType,
      if (resourceId != null) 'resource_id': resourceId,
      if (detailsJson != null) 'details_json': detailsJson,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncError != null) 'sync_error': syncError,
      if (syncAttemptCount != null) 'sync_attempt_count': syncAttemptCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LocalAuditLogCompanion copyWith({
    Value<int>? id,
    Value<String>? actorUserId,
    Value<String>? action,
    Value<String?>? resourceType,
    Value<String?>? resourceId,
    Value<String?>? detailsJson,
    Value<DateTime>? occurredAt,
    Value<String>? syncStatus,
    Value<String?>? syncError,
    Value<int>? syncAttemptCount,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime?>? syncedAt,
    Value<DateTime>? createdAt,
  }) {
    return LocalAuditLogCompanion(
      id: id ?? this.id,
      actorUserId: actorUserId ?? this.actorUserId,
      action: action ?? this.action,
      resourceType: resourceType ?? this.resourceType,
      resourceId: resourceId ?? this.resourceId,
      detailsJson: detailsJson ?? this.detailsJson,
      occurredAt: occurredAt ?? this.occurredAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (actorUserId.present) {
      map['actor_user_id'] = Variable<String>(actorUserId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (resourceType.present) {
      map['resource_type'] = Variable<String>(resourceType.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (detailsJson.present) {
      map['details_json'] = Variable<String>(detailsJson.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (syncAttemptCount.present) {
      map['sync_attempt_count'] = Variable<int>(syncAttemptCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAuditLogCompanion(')
          ..write('id: $id, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('action: $action, ')
          ..write('resourceType: $resourceType, ')
          ..write('resourceId: $resourceId, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('syncAttemptCount: $syncAttemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, syncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  /// Area key: `sales` | `finance` | `customers` | `pull`.
  final String key;

  /// When that area last finished a sync without error.
  final DateTime syncedAt;
  const SyncStateData({required this.key, required this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(key: Value(key), syncedAt: Value(syncedAt));
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      key: serializer.fromJson<String>(json['key']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  SyncStateData copyWith({String? key, DateTime? syncedAt}) =>
      SyncStateData(key: key ?? this.key, syncedAt: syncedAt ?? this.syncedAt);
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      key: data.key.present ? data.key.value : this.key,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('key: $key, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.key == this.key &&
          other.syncedAt == this.syncedAt);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<String> key;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.key = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String key,
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       syncedAt = Value(syncedAt);
  static Insertable<SyncStateData> custom({
    Expression<String>? key,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? key,
    Value<DateTime>? syncedAt,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      key: key ?? this.key,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('key: $key, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalUserProfilesTable localUserProfiles =
      $LocalUserProfilesTable(this);
  late final $DeviceConfigTable deviceConfig = $DeviceConfigTable(this);
  late final $PendingSalesTable pendingSales = $PendingSalesTable(this);
  late final $PendingSaleLineItemsTable pendingSaleLineItems =
      $PendingSaleLineItemsTable(this);
  late final $CachedItemsTable cachedItems = $CachedItemsTable(this);
  late final $CachedPermissionsTable cachedPermissions =
      $CachedPermissionsTable(this);
  late final $CachedStockLevelsTable cachedStockLevels =
      $CachedStockLevelsTable(this);
  late final $CachedBusinessRolesTable cachedBusinessRoles =
      $CachedBusinessRolesTable(this);
  late final $CachedSalesTable cachedSales = $CachedSalesTable(this);
  late final $CachedSaleLineItemsTable cachedSaleLineItems =
      $CachedSaleLineItemsTable(this);
  late final $PendingVoidsRefundsTable pendingVoidsRefunds =
      $PendingVoidsRefundsTable(this);
  late final $ExpenseEntriesTable expenseEntries = $ExpenseEntriesTable(this);
  late final $OtherIncomeEntriesTable otherIncomeEntries =
      $OtherIncomeEntriesTable(this);
  late final $CachedOtherExpensesTable cachedOtherExpenses =
      $CachedOtherExpensesTable(this);
  late final $CachedOtherIncomesTable cachedOtherIncomes =
      $CachedOtherIncomesTable(this);
  late final $CustomerEntriesTable customerEntries = $CustomerEntriesTable(
    this,
  );
  late final $CachedCustomersTable cachedCustomers = $CachedCustomersTable(
    this,
  );
  late final $CachedSuppliersTable cachedSuppliers = $CachedSuppliersTable(
    this,
  );
  late final $CachedCategoriesTable cachedCategories = $CachedCategoriesTable(
    this,
  );
  late final $CachedUnitsTable cachedUnits = $CachedUnitsTable(this);
  late final $LocalAuditLogTable localAuditLog = $LocalAuditLogTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localUserProfiles,
    deviceConfig,
    pendingSales,
    pendingSaleLineItems,
    cachedItems,
    cachedPermissions,
    cachedStockLevels,
    cachedBusinessRoles,
    cachedSales,
    cachedSaleLineItems,
    pendingVoidsRefunds,
    expenseEntries,
    otherIncomeEntries,
    cachedOtherExpenses,
    cachedOtherIncomes,
    customerEntries,
    cachedCustomers,
    cachedSuppliers,
    cachedCategories,
    cachedUnits,
    localAuditLog,
    syncState,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'pending_sales',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('pending_sale_line_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_user_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cached_permissions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cached_sales',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cached_sale_line_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LocalUserProfilesTableCreateCompanionBuilder =
    LocalUserProfilesCompanion Function({
      required String id,
      required String displayName,
      required String pinHash,
      required String pinSalt,
      Value<String?> roleLabel,
      Value<DateTime?> lastSignedInAt,
      Value<int> failedPinAttempts,
      Value<DateTime?> lockedUntil,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> lastRevocationCheckAt,
      Value<bool> isDeactivated,
      Value<int> rowid,
    });
typedef $$LocalUserProfilesTableUpdateCompanionBuilder =
    LocalUserProfilesCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<String> pinHash,
      Value<String> pinSalt,
      Value<String?> roleLabel,
      Value<DateTime?> lastSignedInAt,
      Value<int> failedPinAttempts,
      Value<DateTime?> lockedUntil,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastRevocationCheckAt,
      Value<bool> isDeactivated,
      Value<int> rowid,
    });

final class $$LocalUserProfilesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocalUserProfilesTable,
          LocalUserProfile
        > {
  $$LocalUserProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$CachedPermissionsTable, List<CachedPermission>>
  _cachedPermissionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cachedPermissions,
        aliasName: 'local_user_profiles__id__cached_permissions__user_id',
      );

  $$CachedPermissionsTableProcessedTableManager get cachedPermissionsRefs {
    final manager = $$CachedPermissionsTableTableManager(
      $_db,
      $_db.cachedPermissions,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cachedPermissionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalUserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalUserProfilesTable> {
  $$LocalUserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinSalt => $composableBuilder(
    column: $table.pinSalt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roleLabel => $composableBuilder(
    column: $table.roleLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSignedInAt => $composableBuilder(
    column: $table.lastSignedInAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failedPinAttempts => $composableBuilder(
    column: $table.failedPinAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lockedUntil => $composableBuilder(
    column: $table.lockedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastRevocationCheckAt => $composableBuilder(
    column: $table.lastRevocationCheckAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeactivated => $composableBuilder(
    column: $table.isDeactivated,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cachedPermissionsRefs(
    Expression<bool> Function($$CachedPermissionsTableFilterComposer f) f,
  ) {
    final $$CachedPermissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cachedPermissions,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedPermissionsTableFilterComposer(
            $db: $db,
            $table: $db.cachedPermissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalUserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalUserProfilesTable> {
  $$LocalUserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinSalt => $composableBuilder(
    column: $table.pinSalt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roleLabel => $composableBuilder(
    column: $table.roleLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSignedInAt => $composableBuilder(
    column: $table.lastSignedInAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failedPinAttempts => $composableBuilder(
    column: $table.failedPinAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lockedUntil => $composableBuilder(
    column: $table.lockedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastRevocationCheckAt => $composableBuilder(
    column: $table.lastRevocationCheckAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeactivated => $composableBuilder(
    column: $table.isDeactivated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalUserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalUserProfilesTable> {
  $$LocalUserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pinHash =>
      $composableBuilder(column: $table.pinHash, builder: (column) => column);

  GeneratedColumn<String> get pinSalt =>
      $composableBuilder(column: $table.pinSalt, builder: (column) => column);

  GeneratedColumn<String> get roleLabel =>
      $composableBuilder(column: $table.roleLabel, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSignedInAt => $composableBuilder(
    column: $table.lastSignedInAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get failedPinAttempts => $composableBuilder(
    column: $table.failedPinAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lockedUntil => $composableBuilder(
    column: $table.lockedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastRevocationCheckAt => $composableBuilder(
    column: $table.lastRevocationCheckAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeactivated => $composableBuilder(
    column: $table.isDeactivated,
    builder: (column) => column,
  );

  Expression<T> cachedPermissionsRefs<T extends Object>(
    Expression<T> Function($$CachedPermissionsTableAnnotationComposer a) f,
  ) {
    final $$CachedPermissionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cachedPermissions,
          getReferencedColumn: (t) => t.userId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CachedPermissionsTableAnnotationComposer(
                $db: $db,
                $table: $db.cachedPermissions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LocalUserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalUserProfilesTable,
          LocalUserProfile,
          $$LocalUserProfilesTableFilterComposer,
          $$LocalUserProfilesTableOrderingComposer,
          $$LocalUserProfilesTableAnnotationComposer,
          $$LocalUserProfilesTableCreateCompanionBuilder,
          $$LocalUserProfilesTableUpdateCompanionBuilder,
          (LocalUserProfile, $$LocalUserProfilesTableReferences),
          LocalUserProfile,
          PrefetchHooks Function({bool cachedPermissionsRefs})
        > {
  $$LocalUserProfilesTableTableManager(
    _$AppDatabase db,
    $LocalUserProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalUserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalUserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalUserProfilesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> pinHash = const Value.absent(),
                Value<String> pinSalt = const Value.absent(),
                Value<String?> roleLabel = const Value.absent(),
                Value<DateTime?> lastSignedInAt = const Value.absent(),
                Value<int> failedPinAttempts = const Value.absent(),
                Value<DateTime?> lockedUntil = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastRevocationCheckAt = const Value.absent(),
                Value<bool> isDeactivated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalUserProfilesCompanion(
                id: id,
                displayName: displayName,
                pinHash: pinHash,
                pinSalt: pinSalt,
                roleLabel: roleLabel,
                lastSignedInAt: lastSignedInAt,
                failedPinAttempts: failedPinAttempts,
                lockedUntil: lockedUntil,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastRevocationCheckAt: lastRevocationCheckAt,
                isDeactivated: isDeactivated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                required String pinHash,
                required String pinSalt,
                Value<String?> roleLabel = const Value.absent(),
                Value<DateTime?> lastSignedInAt = const Value.absent(),
                Value<int> failedPinAttempts = const Value.absent(),
                Value<DateTime?> lockedUntil = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> lastRevocationCheckAt = const Value.absent(),
                Value<bool> isDeactivated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalUserProfilesCompanion.insert(
                id: id,
                displayName: displayName,
                pinHash: pinHash,
                pinSalt: pinSalt,
                roleLabel: roleLabel,
                lastSignedInAt: lastSignedInAt,
                failedPinAttempts: failedPinAttempts,
                lockedUntil: lockedUntil,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastRevocationCheckAt: lastRevocationCheckAt,
                isDeactivated: isDeactivated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalUserProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cachedPermissionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (cachedPermissionsRefs) db.cachedPermissions,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cachedPermissionsRefs)
                    await $_getPrefetchedData<
                      LocalUserProfile,
                      $LocalUserProfilesTable,
                      CachedPermission
                    >(
                      currentTable: table,
                      referencedTable: $$LocalUserProfilesTableReferences
                          ._cachedPermissionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalUserProfilesTableReferences(
                            db,
                            table,
                            p0,
                          ).cachedPermissionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.userId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalUserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalUserProfilesTable,
      LocalUserProfile,
      $$LocalUserProfilesTableFilterComposer,
      $$LocalUserProfilesTableOrderingComposer,
      $$LocalUserProfilesTableAnnotationComposer,
      $$LocalUserProfilesTableCreateCompanionBuilder,
      $$LocalUserProfilesTableUpdateCompanionBuilder,
      (LocalUserProfile, $$LocalUserProfilesTableReferences),
      LocalUserProfile,
      PrefetchHooks Function({bool cachedPermissionsRefs})
    >;
typedef $$DeviceConfigTableCreateCompanionBuilder =
    DeviceConfigCompanion Function({
      Value<int> id,
      required String businessId,
      required String businessLocationId,
      required String businessName,
      Value<String?> deviceLabel,
      required DateTime provisionedAt,
      required DateTime updatedAt,
    });
typedef $$DeviceConfigTableUpdateCompanionBuilder =
    DeviceConfigCompanion Function({
      Value<int> id,
      Value<String> businessId,
      Value<String> businessLocationId,
      Value<String> businessName,
      Value<String?> deviceLabel,
      Value<DateTime> provisionedAt,
      Value<DateTime> updatedAt,
    });

class $$DeviceConfigTableFilterComposer
    extends Composer<_$AppDatabase, $DeviceConfigTable> {
  $$DeviceConfigTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessLocationId => $composableBuilder(
    column: $table.businessLocationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get provisionedAt => $composableBuilder(
    column: $table.provisionedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceConfigTableOrderingComposer
    extends Composer<_$AppDatabase, $DeviceConfigTable> {
  $$DeviceConfigTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessLocationId => $composableBuilder(
    column: $table.businessLocationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get provisionedAt => $composableBuilder(
    column: $table.provisionedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceConfigTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeviceConfigTable> {
  $$DeviceConfigTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get businessLocationId => $composableBuilder(
    column: $table.businessLocationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get provisionedAt => $composableBuilder(
    column: $table.provisionedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DeviceConfigTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeviceConfigTable,
          DeviceConfigData,
          $$DeviceConfigTableFilterComposer,
          $$DeviceConfigTableOrderingComposer,
          $$DeviceConfigTableAnnotationComposer,
          $$DeviceConfigTableCreateCompanionBuilder,
          $$DeviceConfigTableUpdateCompanionBuilder,
          (
            DeviceConfigData,
            BaseReferences<_$AppDatabase, $DeviceConfigTable, DeviceConfigData>,
          ),
          DeviceConfigData,
          PrefetchHooks Function()
        > {
  $$DeviceConfigTableTableManager(_$AppDatabase db, $DeviceConfigTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceConfigTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceConfigTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceConfigTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> businessLocationId = const Value.absent(),
                Value<String> businessName = const Value.absent(),
                Value<String?> deviceLabel = const Value.absent(),
                Value<DateTime> provisionedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DeviceConfigCompanion(
                id: id,
                businessId: businessId,
                businessLocationId: businessLocationId,
                businessName: businessName,
                deviceLabel: deviceLabel,
                provisionedAt: provisionedAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String businessId,
                required String businessLocationId,
                required String businessName,
                Value<String?> deviceLabel = const Value.absent(),
                required DateTime provisionedAt,
                required DateTime updatedAt,
              }) => DeviceConfigCompanion.insert(
                id: id,
                businessId: businessId,
                businessLocationId: businessLocationId,
                businessName: businessName,
                deviceLabel: deviceLabel,
                provisionedAt: provisionedAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceConfigTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeviceConfigTable,
      DeviceConfigData,
      $$DeviceConfigTableFilterComposer,
      $$DeviceConfigTableOrderingComposer,
      $$DeviceConfigTableAnnotationComposer,
      $$DeviceConfigTableCreateCompanionBuilder,
      $$DeviceConfigTableUpdateCompanionBuilder,
      (
        DeviceConfigData,
        BaseReferences<_$AppDatabase, $DeviceConfigTable, DeviceConfigData>,
      ),
      DeviceConfigData,
      PrefetchHooks Function()
    >;
typedef $$PendingSalesTableCreateCompanionBuilder =
    PendingSalesCompanion Function({
      Value<int> id,
      required String clientSaleId,
      required String status,
      required String storeId,
      Value<Decimal> discountAmount,
      required String paymentMethod,
      Value<String?> customerId,
      required DateTime occurredAt,
      Value<int?> deviceSequence,
      Value<String?> voidOrRefundReason,
      Value<String?> localOrderId,
      Value<String> syncStatus,
      Value<String?> syncError,
      Value<int> syncAttemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      required DateTime createdAt,
    });
typedef $$PendingSalesTableUpdateCompanionBuilder =
    PendingSalesCompanion Function({
      Value<int> id,
      Value<String> clientSaleId,
      Value<String> status,
      Value<String> storeId,
      Value<Decimal> discountAmount,
      Value<String> paymentMethod,
      Value<String?> customerId,
      Value<DateTime> occurredAt,
      Value<int?> deviceSequence,
      Value<String?> voidOrRefundReason,
      Value<String?> localOrderId,
      Value<String> syncStatus,
      Value<String?> syncError,
      Value<int> syncAttemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      Value<DateTime> createdAt,
    });

final class $$PendingSalesTableReferences
    extends BaseReferences<_$AppDatabase, $PendingSalesTable, PendingSale> {
  $$PendingSalesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $PendingSaleLineItemsTable,
    List<PendingSaleLineItem>
  >
  _pendingSaleLineItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pendingSaleLineItems,
        aliasName:
            'pending_sales__id__pending_sale_line_items__pending_sale_id',
      );

  $$PendingSaleLineItemsTableProcessedTableManager
  get pendingSaleLineItemsRefs {
    final manager = $$PendingSaleLineItemsTableTableManager(
      $_db,
      $_db.pendingSaleLineItems,
    ).filter((f) => f.pendingSaleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _pendingSaleLineItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PendingVoidsRefundsTable,
    List<PendingVoidsRefund>
  >
  _pendingVoidsRefundsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pendingVoidsRefunds,
        aliasName:
            'pending_sales__client_sale_id__pending_voids_refunds__sale_id',
      );

  $$PendingVoidsRefundsTableProcessedTableManager get pendingVoidsRefundsRefs {
    final manager =
        $$PendingVoidsRefundsTableTableManager(
          $_db,
          $_db.pendingVoidsRefunds,
        ).filter(
          (f) => f.saleId.clientSaleId.sqlEquals(
            $_itemColumn<String>('client_sale_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _pendingVoidsRefundsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PendingSalesTableFilterComposer
    extends Composer<_$AppDatabase, $PendingSalesTable> {
  $$PendingSalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientSaleId => $composableBuilder(
    column: $table.clientSaleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get discountAmount =>
      $composableBuilder(
        column: $table.discountAmount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deviceSequence => $composableBuilder(
    column: $table.deviceSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voidOrRefundReason => $composableBuilder(
    column: $table.voidOrRefundReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localOrderId => $composableBuilder(
    column: $table.localOrderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> pendingSaleLineItemsRefs(
    Expression<bool> Function($$PendingSaleLineItemsTableFilterComposer f) f,
  ) {
    final $$PendingSaleLineItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pendingSaleLineItems,
      getReferencedColumn: (t) => t.pendingSaleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingSaleLineItemsTableFilterComposer(
            $db: $db,
            $table: $db.pendingSaleLineItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pendingVoidsRefundsRefs(
    Expression<bool> Function($$PendingVoidsRefundsTableFilterComposer f) f,
  ) {
    final $$PendingVoidsRefundsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clientSaleId,
      referencedTable: $db.pendingVoidsRefunds,
      getReferencedColumn: (t) => t.saleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingVoidsRefundsTableFilterComposer(
            $db: $db,
            $table: $db.pendingVoidsRefunds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PendingSalesTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingSalesTable> {
  $$PendingSalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientSaleId => $composableBuilder(
    column: $table.clientSaleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get discountAmount => $composableBuilder(
    column: $table.discountAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deviceSequence => $composableBuilder(
    column: $table.deviceSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voidOrRefundReason => $composableBuilder(
    column: $table.voidOrRefundReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localOrderId => $composableBuilder(
    column: $table.localOrderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingSalesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingSalesTable> {
  $$PendingSalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientSaleId => $composableBuilder(
    column: $table.clientSaleId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get discountAmount =>
      $composableBuilder(
        column: $table.discountAmount,
        builder: (column) => column,
      );

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deviceSequence => $composableBuilder(
    column: $table.deviceSequence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voidOrRefundReason => $composableBuilder(
    column: $table.voidOrRefundReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localOrderId => $composableBuilder(
    column: $table.localOrderId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> pendingSaleLineItemsRefs<T extends Object>(
    Expression<T> Function($$PendingSaleLineItemsTableAnnotationComposer a) f,
  ) {
    final $$PendingSaleLineItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pendingSaleLineItems,
          getReferencedColumn: (t) => t.pendingSaleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PendingSaleLineItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.pendingSaleLineItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> pendingVoidsRefundsRefs<T extends Object>(
    Expression<T> Function($$PendingVoidsRefundsTableAnnotationComposer a) f,
  ) {
    final $$PendingVoidsRefundsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.clientSaleId,
          referencedTable: $db.pendingVoidsRefunds,
          getReferencedColumn: (t) => t.saleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PendingVoidsRefundsTableAnnotationComposer(
                $db: $db,
                $table: $db.pendingVoidsRefunds,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PendingSalesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingSalesTable,
          PendingSale,
          $$PendingSalesTableFilterComposer,
          $$PendingSalesTableOrderingComposer,
          $$PendingSalesTableAnnotationComposer,
          $$PendingSalesTableCreateCompanionBuilder,
          $$PendingSalesTableUpdateCompanionBuilder,
          (PendingSale, $$PendingSalesTableReferences),
          PendingSale,
          PrefetchHooks Function({
            bool pendingSaleLineItemsRefs,
            bool pendingVoidsRefundsRefs,
          })
        > {
  $$PendingSalesTableTableManager(_$AppDatabase db, $PendingSalesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingSalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingSalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingSalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientSaleId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> storeId = const Value.absent(),
                Value<Decimal> discountAmount = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<int?> deviceSequence = const Value.absent(),
                Value<String?> voidOrRefundReason = const Value.absent(),
                Value<String?> localOrderId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> syncAttemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingSalesCompanion(
                id: id,
                clientSaleId: clientSaleId,
                status: status,
                storeId: storeId,
                discountAmount: discountAmount,
                paymentMethod: paymentMethod,
                customerId: customerId,
                occurredAt: occurredAt,
                deviceSequence: deviceSequence,
                voidOrRefundReason: voidOrRefundReason,
                localOrderId: localOrderId,
                syncStatus: syncStatus,
                syncError: syncError,
                syncAttemptCount: syncAttemptCount,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientSaleId,
                required String status,
                required String storeId,
                Value<Decimal> discountAmount = const Value.absent(),
                required String paymentMethod,
                Value<String?> customerId = const Value.absent(),
                required DateTime occurredAt,
                Value<int?> deviceSequence = const Value.absent(),
                Value<String?> voidOrRefundReason = const Value.absent(),
                Value<String?> localOrderId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> syncAttemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                required DateTime createdAt,
              }) => PendingSalesCompanion.insert(
                id: id,
                clientSaleId: clientSaleId,
                status: status,
                storeId: storeId,
                discountAmount: discountAmount,
                paymentMethod: paymentMethod,
                customerId: customerId,
                occurredAt: occurredAt,
                deviceSequence: deviceSequence,
                voidOrRefundReason: voidOrRefundReason,
                localOrderId: localOrderId,
                syncStatus: syncStatus,
                syncError: syncError,
                syncAttemptCount: syncAttemptCount,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PendingSalesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                pendingSaleLineItemsRefs = false,
                pendingVoidsRefundsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (pendingSaleLineItemsRefs) db.pendingSaleLineItems,
                    if (pendingVoidsRefundsRefs) db.pendingVoidsRefunds,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (pendingSaleLineItemsRefs)
                        await $_getPrefetchedData<
                          PendingSale,
                          $PendingSalesTable,
                          PendingSaleLineItem
                        >(
                          currentTable: table,
                          referencedTable: $$PendingSalesTableReferences
                              ._pendingSaleLineItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PendingSalesTableReferences(
                                db,
                                table,
                                p0,
                              ).pendingSaleLineItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.pendingSaleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pendingVoidsRefundsRefs)
                        await $_getPrefetchedData<
                          PendingSale,
                          $PendingSalesTable,
                          PendingVoidsRefund
                        >(
                          currentTable: table,
                          referencedTable: $$PendingSalesTableReferences
                              ._pendingVoidsRefundsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PendingSalesTableReferences(
                                db,
                                table,
                                p0,
                              ).pendingVoidsRefundsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.saleId == item.clientSaleId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PendingSalesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingSalesTable,
      PendingSale,
      $$PendingSalesTableFilterComposer,
      $$PendingSalesTableOrderingComposer,
      $$PendingSalesTableAnnotationComposer,
      $$PendingSalesTableCreateCompanionBuilder,
      $$PendingSalesTableUpdateCompanionBuilder,
      (PendingSale, $$PendingSalesTableReferences),
      PendingSale,
      PrefetchHooks Function({
        bool pendingSaleLineItemsRefs,
        bool pendingVoidsRefundsRefs,
      })
    >;
typedef $$PendingSaleLineItemsTableCreateCompanionBuilder =
    PendingSaleLineItemsCompanion Function({
      Value<int> id,
      required int pendingSaleId,
      required String itemId,
      required Decimal quantity,
      required Decimal unitPrice,
      Value<Decimal> discountAmount,
      Value<Decimal?> unitCost,
    });
typedef $$PendingSaleLineItemsTableUpdateCompanionBuilder =
    PendingSaleLineItemsCompanion Function({
      Value<int> id,
      Value<int> pendingSaleId,
      Value<String> itemId,
      Value<Decimal> quantity,
      Value<Decimal> unitPrice,
      Value<Decimal> discountAmount,
      Value<Decimal?> unitCost,
    });

final class $$PendingSaleLineItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PendingSaleLineItemsTable,
          PendingSaleLineItem
        > {
  $$PendingSaleLineItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PendingSalesTable _pendingSaleIdTable(_$AppDatabase db) =>
      db.pendingSales.createAlias(
        'pending_sale_line_items__pending_sale_id__pending_sales__id',
      );

  $$PendingSalesTableProcessedTableManager get pendingSaleId {
    final $_column = $_itemColumn<int>('pending_sale_id')!;

    final manager = $$PendingSalesTableTableManager(
      $_db,
      $_db.pendingSales,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pendingSaleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PendingSaleLineItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingSaleLineItemsTable> {
  $$PendingSaleLineItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get quantity =>
      $composableBuilder(
        column: $table.quantity,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get unitPrice =>
      $composableBuilder(
        column: $table.unitPrice,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get discountAmount =>
      $composableBuilder(
        column: $table.discountAmount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal?, Decimal, String> get unitCost =>
      $composableBuilder(
        column: $table.unitCost,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$PendingSalesTableFilterComposer get pendingSaleId {
    final $$PendingSalesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pendingSaleId,
      referencedTable: $db.pendingSales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingSalesTableFilterComposer(
            $db: $db,
            $table: $db.pendingSales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingSaleLineItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingSaleLineItemsTable> {
  $$PendingSaleLineItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get discountAmount => $composableBuilder(
    column: $table.discountAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnOrderings(column),
  );

  $$PendingSalesTableOrderingComposer get pendingSaleId {
    final $$PendingSalesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pendingSaleId,
      referencedTable: $db.pendingSales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingSalesTableOrderingComposer(
            $db: $db,
            $table: $db.pendingSales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingSaleLineItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingSaleLineItemsTable> {
  $$PendingSaleLineItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get discountAmount =>
      $composableBuilder(
        column: $table.discountAmount,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal?, String> get unitCost =>
      $composableBuilder(column: $table.unitCost, builder: (column) => column);

  $$PendingSalesTableAnnotationComposer get pendingSaleId {
    final $$PendingSalesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pendingSaleId,
      referencedTable: $db.pendingSales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingSalesTableAnnotationComposer(
            $db: $db,
            $table: $db.pendingSales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingSaleLineItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingSaleLineItemsTable,
          PendingSaleLineItem,
          $$PendingSaleLineItemsTableFilterComposer,
          $$PendingSaleLineItemsTableOrderingComposer,
          $$PendingSaleLineItemsTableAnnotationComposer,
          $$PendingSaleLineItemsTableCreateCompanionBuilder,
          $$PendingSaleLineItemsTableUpdateCompanionBuilder,
          (PendingSaleLineItem, $$PendingSaleLineItemsTableReferences),
          PendingSaleLineItem,
          PrefetchHooks Function({bool pendingSaleId})
        > {
  $$PendingSaleLineItemsTableTableManager(
    _$AppDatabase db,
    $PendingSaleLineItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingSaleLineItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingSaleLineItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingSaleLineItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> pendingSaleId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<Decimal> quantity = const Value.absent(),
                Value<Decimal> unitPrice = const Value.absent(),
                Value<Decimal> discountAmount = const Value.absent(),
                Value<Decimal?> unitCost = const Value.absent(),
              }) => PendingSaleLineItemsCompanion(
                id: id,
                pendingSaleId: pendingSaleId,
                itemId: itemId,
                quantity: quantity,
                unitPrice: unitPrice,
                discountAmount: discountAmount,
                unitCost: unitCost,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int pendingSaleId,
                required String itemId,
                required Decimal quantity,
                required Decimal unitPrice,
                Value<Decimal> discountAmount = const Value.absent(),
                Value<Decimal?> unitCost = const Value.absent(),
              }) => PendingSaleLineItemsCompanion.insert(
                id: id,
                pendingSaleId: pendingSaleId,
                itemId: itemId,
                quantity: quantity,
                unitPrice: unitPrice,
                discountAmount: discountAmount,
                unitCost: unitCost,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PendingSaleLineItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({pendingSaleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (pendingSaleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.pendingSaleId,
                                referencedTable:
                                    $$PendingSaleLineItemsTableReferences
                                        ._pendingSaleIdTable(db),
                                referencedColumn:
                                    $$PendingSaleLineItemsTableReferences
                                        ._pendingSaleIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PendingSaleLineItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingSaleLineItemsTable,
      PendingSaleLineItem,
      $$PendingSaleLineItemsTableFilterComposer,
      $$PendingSaleLineItemsTableOrderingComposer,
      $$PendingSaleLineItemsTableAnnotationComposer,
      $$PendingSaleLineItemsTableCreateCompanionBuilder,
      $$PendingSaleLineItemsTableUpdateCompanionBuilder,
      (PendingSaleLineItem, $$PendingSaleLineItemsTableReferences),
      PendingSaleLineItem,
      PrefetchHooks Function({bool pendingSaleId})
    >;
typedef $$CachedItemsTableCreateCompanionBuilder =
    CachedItemsCompanion Function({
      required String id,
      required String businessId,
      required String businessLocationId,
      required String name,
      required String unitOfMeasure,
      Value<String> unitId,
      Value<String?> category,
      required Decimal reorderThreshold,
      required Decimal reorderQuantity,
      Value<Decimal?> sellingPrice,
      Value<Decimal?> unitCost,
      Value<bool> allowNegativeStock,
      required String itemType,
      Value<bool> isActive,
      required DateTime createdAtServer,
      required DateTime updatedAtServer,
      required DateTime lastSeenAt,
      required DateTime lastSyncedAt,
      Value<String?> imageUrl,
      Value<String> supplierId,
      Value<int> rowid,
    });
typedef $$CachedItemsTableUpdateCompanionBuilder =
    CachedItemsCompanion Function({
      Value<String> id,
      Value<String> businessId,
      Value<String> businessLocationId,
      Value<String> name,
      Value<String> unitOfMeasure,
      Value<String> unitId,
      Value<String?> category,
      Value<Decimal> reorderThreshold,
      Value<Decimal> reorderQuantity,
      Value<Decimal?> sellingPrice,
      Value<Decimal?> unitCost,
      Value<bool> allowNegativeStock,
      Value<String> itemType,
      Value<bool> isActive,
      Value<DateTime> createdAtServer,
      Value<DateTime> updatedAtServer,
      Value<DateTime> lastSeenAt,
      Value<DateTime> lastSyncedAt,
      Value<String?> imageUrl,
      Value<String> supplierId,
      Value<int> rowid,
    });

class $$CachedItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedItemsTable> {
  $$CachedItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessLocationId => $composableBuilder(
    column: $table.businessLocationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitOfMeasure => $composableBuilder(
    column: $table.unitOfMeasure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitId => $composableBuilder(
    column: $table.unitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String>
  get reorderThreshold => $composableBuilder(
    column: $table.reorderThreshold,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String>
  get reorderQuantity => $composableBuilder(
    column: $table.reorderQuantity,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal?, Decimal, String> get sellingPrice =>
      $composableBuilder(
        column: $table.sellingPrice,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal?, Decimal, String> get unitCost =>
      $composableBuilder(
        column: $table.unitCost,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get allowNegativeStock => $composableBuilder(
    column: $table.allowNegativeStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtServer => $composableBuilder(
    column: $table.createdAtServer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtServer => $composableBuilder(
    column: $table.updatedAtServer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedItemsTable> {
  $$CachedItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessLocationId => $composableBuilder(
    column: $table.businessLocationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitOfMeasure => $composableBuilder(
    column: $table.unitOfMeasure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitId => $composableBuilder(
    column: $table.unitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reorderThreshold => $composableBuilder(
    column: $table.reorderThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reorderQuantity => $composableBuilder(
    column: $table.reorderQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sellingPrice => $composableBuilder(
    column: $table.sellingPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowNegativeStock => $composableBuilder(
    column: $table.allowNegativeStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtServer => $composableBuilder(
    column: $table.createdAtServer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtServer => $composableBuilder(
    column: $table.updatedAtServer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedItemsTable> {
  $$CachedItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get businessLocationId => $composableBuilder(
    column: $table.businessLocationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get unitOfMeasure => $composableBuilder(
    column: $table.unitOfMeasure,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unitId =>
      $composableBuilder(column: $table.unitId, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get reorderThreshold =>
      $composableBuilder(
        column: $table.reorderThreshold,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal, String> get reorderQuantity =>
      $composableBuilder(
        column: $table.reorderQuantity,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal?, String> get sellingPrice =>
      $composableBuilder(
        column: $table.sellingPrice,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal?, String> get unitCost =>
      $composableBuilder(column: $table.unitCost, builder: (column) => column);

  GeneratedColumn<bool> get allowNegativeStock => $composableBuilder(
    column: $table.allowNegativeStock,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAtServer => $composableBuilder(
    column: $table.createdAtServer,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAtServer => $composableBuilder(
    column: $table.updatedAtServer,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => column,
  );
}

class $$CachedItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedItemsTable,
          CachedItem,
          $$CachedItemsTableFilterComposer,
          $$CachedItemsTableOrderingComposer,
          $$CachedItemsTableAnnotationComposer,
          $$CachedItemsTableCreateCompanionBuilder,
          $$CachedItemsTableUpdateCompanionBuilder,
          (
            CachedItem,
            BaseReferences<_$AppDatabase, $CachedItemsTable, CachedItem>,
          ),
          CachedItem,
          PrefetchHooks Function()
        > {
  $$CachedItemsTableTableManager(_$AppDatabase db, $CachedItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> businessLocationId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> unitOfMeasure = const Value.absent(),
                Value<String> unitId = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<Decimal> reorderThreshold = const Value.absent(),
                Value<Decimal> reorderQuantity = const Value.absent(),
                Value<Decimal?> sellingPrice = const Value.absent(),
                Value<Decimal?> unitCost = const Value.absent(),
                Value<bool> allowNegativeStock = const Value.absent(),
                Value<String> itemType = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAtServer = const Value.absent(),
                Value<DateTime> updatedAtServer = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String> supplierId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedItemsCompanion(
                id: id,
                businessId: businessId,
                businessLocationId: businessLocationId,
                name: name,
                unitOfMeasure: unitOfMeasure,
                unitId: unitId,
                category: category,
                reorderThreshold: reorderThreshold,
                reorderQuantity: reorderQuantity,
                sellingPrice: sellingPrice,
                unitCost: unitCost,
                allowNegativeStock: allowNegativeStock,
                itemType: itemType,
                isActive: isActive,
                createdAtServer: createdAtServer,
                updatedAtServer: updatedAtServer,
                lastSeenAt: lastSeenAt,
                lastSyncedAt: lastSyncedAt,
                imageUrl: imageUrl,
                supplierId: supplierId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String businessId,
                required String businessLocationId,
                required String name,
                required String unitOfMeasure,
                Value<String> unitId = const Value.absent(),
                Value<String?> category = const Value.absent(),
                required Decimal reorderThreshold,
                required Decimal reorderQuantity,
                Value<Decimal?> sellingPrice = const Value.absent(),
                Value<Decimal?> unitCost = const Value.absent(),
                Value<bool> allowNegativeStock = const Value.absent(),
                required String itemType,
                Value<bool> isActive = const Value.absent(),
                required DateTime createdAtServer,
                required DateTime updatedAtServer,
                required DateTime lastSeenAt,
                required DateTime lastSyncedAt,
                Value<String?> imageUrl = const Value.absent(),
                Value<String> supplierId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedItemsCompanion.insert(
                id: id,
                businessId: businessId,
                businessLocationId: businessLocationId,
                name: name,
                unitOfMeasure: unitOfMeasure,
                unitId: unitId,
                category: category,
                reorderThreshold: reorderThreshold,
                reorderQuantity: reorderQuantity,
                sellingPrice: sellingPrice,
                unitCost: unitCost,
                allowNegativeStock: allowNegativeStock,
                itemType: itemType,
                isActive: isActive,
                createdAtServer: createdAtServer,
                updatedAtServer: updatedAtServer,
                lastSeenAt: lastSeenAt,
                lastSyncedAt: lastSyncedAt,
                imageUrl: imageUrl,
                supplierId: supplierId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedItemsTable,
      CachedItem,
      $$CachedItemsTableFilterComposer,
      $$CachedItemsTableOrderingComposer,
      $$CachedItemsTableAnnotationComposer,
      $$CachedItemsTableCreateCompanionBuilder,
      $$CachedItemsTableUpdateCompanionBuilder,
      (
        CachedItem,
        BaseReferences<_$AppDatabase, $CachedItemsTable, CachedItem>,
      ),
      CachedItem,
      PrefetchHooks Function()
    >;
typedef $$CachedPermissionsTableCreateCompanionBuilder =
    CachedPermissionsCompanion Function({
      required String userId,
      required String businessId,
      required String businessName,
      required String businessLocationId,
      required String roleName,
      required String permissionCodes,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedPermissionsTableUpdateCompanionBuilder =
    CachedPermissionsCompanion Function({
      Value<String> userId,
      Value<String> businessId,
      Value<String> businessName,
      Value<String> businessLocationId,
      Value<String> roleName,
      Value<String> permissionCodes,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

final class $$CachedPermissionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CachedPermissionsTable,
          CachedPermission
        > {
  $$CachedPermissionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalUserProfilesTable _userIdTable(_$AppDatabase db) => db
      .localUserProfiles
      .createAlias('cached_permissions__user_id__local_user_profiles__id');

  $$LocalUserProfilesTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$LocalUserProfilesTableTableManager(
      $_db,
      $_db.localUserProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CachedPermissionsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedPermissionsTable> {
  $$CachedPermissionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessLocationId => $composableBuilder(
    column: $table.businessLocationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roleName => $composableBuilder(
    column: $table.roleName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get permissionCodes => $composableBuilder(
    column: $table.permissionCodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalUserProfilesTableFilterComposer get userId {
    final $$LocalUserProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.localUserProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalUserProfilesTableFilterComposer(
            $db: $db,
            $table: $db.localUserProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedPermissionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedPermissionsTable> {
  $$CachedPermissionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessLocationId => $composableBuilder(
    column: $table.businessLocationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roleName => $composableBuilder(
    column: $table.roleName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get permissionCodes => $composableBuilder(
    column: $table.permissionCodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalUserProfilesTableOrderingComposer get userId {
    final $$LocalUserProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.localUserProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalUserProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.localUserProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedPermissionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedPermissionsTable> {
  $$CachedPermissionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get businessLocationId => $composableBuilder(
    column: $table.businessLocationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get roleName =>
      $composableBuilder(column: $table.roleName, builder: (column) => column);

  GeneratedColumn<String> get permissionCodes => $composableBuilder(
    column: $table.permissionCodes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  $$LocalUserProfilesTableAnnotationComposer get userId {
    final $$LocalUserProfilesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.userId,
          referencedTable: $db.localUserProfiles,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalUserProfilesTableAnnotationComposer(
                $db: $db,
                $table: $db.localUserProfiles,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$CachedPermissionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedPermissionsTable,
          CachedPermission,
          $$CachedPermissionsTableFilterComposer,
          $$CachedPermissionsTableOrderingComposer,
          $$CachedPermissionsTableAnnotationComposer,
          $$CachedPermissionsTableCreateCompanionBuilder,
          $$CachedPermissionsTableUpdateCompanionBuilder,
          (CachedPermission, $$CachedPermissionsTableReferences),
          CachedPermission,
          PrefetchHooks Function({bool userId})
        > {
  $$CachedPermissionsTableTableManager(
    _$AppDatabase db,
    $CachedPermissionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedPermissionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedPermissionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedPermissionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> businessName = const Value.absent(),
                Value<String> businessLocationId = const Value.absent(),
                Value<String> roleName = const Value.absent(),
                Value<String> permissionCodes = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedPermissionsCompanion(
                userId: userId,
                businessId: businessId,
                businessName: businessName,
                businessLocationId: businessLocationId,
                roleName: roleName,
                permissionCodes: permissionCodes,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String businessId,
                required String businessName,
                required String businessLocationId,
                required String roleName,
                required String permissionCodes,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedPermissionsCompanion.insert(
                userId: userId,
                businessId: businessId,
                businessName: businessName,
                businessLocationId: businessLocationId,
                roleName: roleName,
                permissionCodes: permissionCodes,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CachedPermissionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable:
                                    $$CachedPermissionsTableReferences
                                        ._userIdTable(db),
                                referencedColumn:
                                    $$CachedPermissionsTableReferences
                                        ._userIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CachedPermissionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedPermissionsTable,
      CachedPermission,
      $$CachedPermissionsTableFilterComposer,
      $$CachedPermissionsTableOrderingComposer,
      $$CachedPermissionsTableAnnotationComposer,
      $$CachedPermissionsTableCreateCompanionBuilder,
      $$CachedPermissionsTableUpdateCompanionBuilder,
      (CachedPermission, $$CachedPermissionsTableReferences),
      CachedPermission,
      PrefetchHooks Function({bool userId})
    >;
typedef $$CachedStockLevelsTableCreateCompanionBuilder =
    CachedStockLevelsCompanion Function({
      required String itemId,
      required String businessLocationId,
      required Decimal currentQuantity,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedStockLevelsTableUpdateCompanionBuilder =
    CachedStockLevelsCompanion Function({
      Value<String> itemId,
      Value<String> businessLocationId,
      Value<Decimal> currentQuantity,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedStockLevelsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedStockLevelsTable> {
  $$CachedStockLevelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessLocationId => $composableBuilder(
    column: $table.businessLocationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String>
  get currentQuantity => $composableBuilder(
    column: $table.currentQuantity,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedStockLevelsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedStockLevelsTable> {
  $$CachedStockLevelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessLocationId => $composableBuilder(
    column: $table.businessLocationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentQuantity => $composableBuilder(
    column: $table.currentQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedStockLevelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedStockLevelsTable> {
  $$CachedStockLevelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get businessLocationId => $composableBuilder(
    column: $table.businessLocationId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Decimal, String> get currentQuantity =>
      $composableBuilder(
        column: $table.currentQuantity,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedStockLevelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedStockLevelsTable,
          CachedStockLevel,
          $$CachedStockLevelsTableFilterComposer,
          $$CachedStockLevelsTableOrderingComposer,
          $$CachedStockLevelsTableAnnotationComposer,
          $$CachedStockLevelsTableCreateCompanionBuilder,
          $$CachedStockLevelsTableUpdateCompanionBuilder,
          (
            CachedStockLevel,
            BaseReferences<
              _$AppDatabase,
              $CachedStockLevelsTable,
              CachedStockLevel
            >,
          ),
          CachedStockLevel,
          PrefetchHooks Function()
        > {
  $$CachedStockLevelsTableTableManager(
    _$AppDatabase db,
    $CachedStockLevelsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedStockLevelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedStockLevelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedStockLevelsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<String> businessLocationId = const Value.absent(),
                Value<Decimal> currentQuantity = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedStockLevelsCompanion(
                itemId: itemId,
                businessLocationId: businessLocationId,
                currentQuantity: currentQuantity,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                required String businessLocationId,
                required Decimal currentQuantity,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedStockLevelsCompanion.insert(
                itemId: itemId,
                businessLocationId: businessLocationId,
                currentQuantity: currentQuantity,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedStockLevelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedStockLevelsTable,
      CachedStockLevel,
      $$CachedStockLevelsTableFilterComposer,
      $$CachedStockLevelsTableOrderingComposer,
      $$CachedStockLevelsTableAnnotationComposer,
      $$CachedStockLevelsTableCreateCompanionBuilder,
      $$CachedStockLevelsTableUpdateCompanionBuilder,
      (
        CachedStockLevel,
        BaseReferences<
          _$AppDatabase,
          $CachedStockLevelsTable,
          CachedStockLevel
        >,
      ),
      CachedStockLevel,
      PrefetchHooks Function()
    >;
typedef $$CachedBusinessRolesTableCreateCompanionBuilder =
    CachedBusinessRolesCompanion Function({
      required String businessId,
      required String roleId,
      required String name,
      required String description,
      required bool isProtected,
      required String permissionCodes,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedBusinessRolesTableUpdateCompanionBuilder =
    CachedBusinessRolesCompanion Function({
      Value<String> businessId,
      Value<String> roleId,
      Value<String> name,
      Value<String> description,
      Value<bool> isProtected,
      Value<String> permissionCodes,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedBusinessRolesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedBusinessRolesTable> {
  $$CachedBusinessRolesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roleId => $composableBuilder(
    column: $table.roleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isProtected => $composableBuilder(
    column: $table.isProtected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get permissionCodes => $composableBuilder(
    column: $table.permissionCodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedBusinessRolesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedBusinessRolesTable> {
  $$CachedBusinessRolesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roleId => $composableBuilder(
    column: $table.roleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isProtected => $composableBuilder(
    column: $table.isProtected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get permissionCodes => $composableBuilder(
    column: $table.permissionCodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedBusinessRolesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedBusinessRolesTable> {
  $$CachedBusinessRolesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get roleId =>
      $composableBuilder(column: $table.roleId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isProtected => $composableBuilder(
    column: $table.isProtected,
    builder: (column) => column,
  );

  GeneratedColumn<String> get permissionCodes => $composableBuilder(
    column: $table.permissionCodes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedBusinessRolesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedBusinessRolesTable,
          CachedBusinessRole,
          $$CachedBusinessRolesTableFilterComposer,
          $$CachedBusinessRolesTableOrderingComposer,
          $$CachedBusinessRolesTableAnnotationComposer,
          $$CachedBusinessRolesTableCreateCompanionBuilder,
          $$CachedBusinessRolesTableUpdateCompanionBuilder,
          (
            CachedBusinessRole,
            BaseReferences<
              _$AppDatabase,
              $CachedBusinessRolesTable,
              CachedBusinessRole
            >,
          ),
          CachedBusinessRole,
          PrefetchHooks Function()
        > {
  $$CachedBusinessRolesTableTableManager(
    _$AppDatabase db,
    $CachedBusinessRolesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedBusinessRolesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedBusinessRolesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedBusinessRolesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> businessId = const Value.absent(),
                Value<String> roleId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<bool> isProtected = const Value.absent(),
                Value<String> permissionCodes = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedBusinessRolesCompanion(
                businessId: businessId,
                roleId: roleId,
                name: name,
                description: description,
                isProtected: isProtected,
                permissionCodes: permissionCodes,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String businessId,
                required String roleId,
                required String name,
                required String description,
                required bool isProtected,
                required String permissionCodes,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedBusinessRolesCompanion.insert(
                businessId: businessId,
                roleId: roleId,
                name: name,
                description: description,
                isProtected: isProtected,
                permissionCodes: permissionCodes,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedBusinessRolesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedBusinessRolesTable,
      CachedBusinessRole,
      $$CachedBusinessRolesTableFilterComposer,
      $$CachedBusinessRolesTableOrderingComposer,
      $$CachedBusinessRolesTableAnnotationComposer,
      $$CachedBusinessRolesTableCreateCompanionBuilder,
      $$CachedBusinessRolesTableUpdateCompanionBuilder,
      (
        CachedBusinessRole,
        BaseReferences<
          _$AppDatabase,
          $CachedBusinessRolesTable,
          CachedBusinessRole
        >,
      ),
      CachedBusinessRole,
      PrefetchHooks Function()
    >;
typedef $$CachedSalesTableCreateCompanionBuilder =
    CachedSalesCompanion Function({
      required String id,
      required String businessId,
      required String storeId,
      required String clientSaleId,
      required String status,
      required Decimal subtotal,
      required Decimal discountAmount,
      required Decimal taxAmount,
      required Decimal total,
      required String paymentMethod,
      Value<String?> actorId,
      Value<String?> customerId,
      required DateTime occurredAt,
      required DateTime syncedAt,
      Value<DateTime?> voidedAt,
      Value<DateTime?> refundedAt,
      Value<String?> voidOrRefundReason,
      required DateTime createdAt,
      required DateTime lastSyncedAt,
      Value<int> rowid,
    });
typedef $$CachedSalesTableUpdateCompanionBuilder =
    CachedSalesCompanion Function({
      Value<String> id,
      Value<String> businessId,
      Value<String> storeId,
      Value<String> clientSaleId,
      Value<String> status,
      Value<Decimal> subtotal,
      Value<Decimal> discountAmount,
      Value<Decimal> taxAmount,
      Value<Decimal> total,
      Value<String> paymentMethod,
      Value<String?> actorId,
      Value<String?> customerId,
      Value<DateTime> occurredAt,
      Value<DateTime> syncedAt,
      Value<DateTime?> voidedAt,
      Value<DateTime?> refundedAt,
      Value<String?> voidOrRefundReason,
      Value<DateTime> createdAt,
      Value<DateTime> lastSyncedAt,
      Value<int> rowid,
    });

final class $$CachedSalesTableReferences
    extends BaseReferences<_$AppDatabase, $CachedSalesTable, CachedSale> {
  $$CachedSalesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $CachedSaleLineItemsTable,
    List<CachedSaleLineItem>
  >
  _cachedSaleLineItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cachedSaleLineItems,
        aliasName: 'cached_sales__id__cached_sale_line_items__sale_id',
      );

  $$CachedSaleLineItemsTableProcessedTableManager get cachedSaleLineItemsRefs {
    final manager = $$CachedSaleLineItemsTableTableManager(
      $_db,
      $_db.cachedSaleLineItems,
    ).filter((f) => f.saleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cachedSaleLineItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CachedSalesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedSalesTable> {
  $$CachedSalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientSaleId => $composableBuilder(
    column: $table.clientSaleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get subtotal =>
      $composableBuilder(
        column: $table.subtotal,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get discountAmount =>
      $composableBuilder(
        column: $table.discountAmount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get taxAmount =>
      $composableBuilder(
        column: $table.taxAmount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get total =>
      $composableBuilder(
        column: $table.total,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get voidedAt => $composableBuilder(
    column: $table.voidedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get refundedAt => $composableBuilder(
    column: $table.refundedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voidOrRefundReason => $composableBuilder(
    column: $table.voidOrRefundReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cachedSaleLineItemsRefs(
    Expression<bool> Function($$CachedSaleLineItemsTableFilterComposer f) f,
  ) {
    final $$CachedSaleLineItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cachedSaleLineItems,
      getReferencedColumn: (t) => t.saleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedSaleLineItemsTableFilterComposer(
            $db: $db,
            $table: $db.cachedSaleLineItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CachedSalesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedSalesTable> {
  $$CachedSalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientSaleId => $composableBuilder(
    column: $table.clientSaleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get discountAmount => $composableBuilder(
    column: $table.discountAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taxAmount => $composableBuilder(
    column: $table.taxAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get voidedAt => $composableBuilder(
    column: $table.voidedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get refundedAt => $composableBuilder(
    column: $table.refundedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voidOrRefundReason => $composableBuilder(
    column: $table.voidOrRefundReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedSalesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedSalesTable> {
  $$CachedSalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get clientSaleId => $composableBuilder(
    column: $table.clientSaleId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get discountAmount =>
      $composableBuilder(
        column: $table.discountAmount,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal, String> get taxAmount =>
      $composableBuilder(column: $table.taxAmount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get voidedAt =>
      $composableBuilder(column: $table.voidedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get refundedAt => $composableBuilder(
    column: $table.refundedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voidOrRefundReason => $composableBuilder(
    column: $table.voidOrRefundReason,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  Expression<T> cachedSaleLineItemsRefs<T extends Object>(
    Expression<T> Function($$CachedSaleLineItemsTableAnnotationComposer a) f,
  ) {
    final $$CachedSaleLineItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cachedSaleLineItems,
          getReferencedColumn: (t) => t.saleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CachedSaleLineItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.cachedSaleLineItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CachedSalesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedSalesTable,
          CachedSale,
          $$CachedSalesTableFilterComposer,
          $$CachedSalesTableOrderingComposer,
          $$CachedSalesTableAnnotationComposer,
          $$CachedSalesTableCreateCompanionBuilder,
          $$CachedSalesTableUpdateCompanionBuilder,
          (CachedSale, $$CachedSalesTableReferences),
          CachedSale,
          PrefetchHooks Function({bool cachedSaleLineItemsRefs})
        > {
  $$CachedSalesTableTableManager(_$AppDatabase db, $CachedSalesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedSalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedSalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedSalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> storeId = const Value.absent(),
                Value<String> clientSaleId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<Decimal> subtotal = const Value.absent(),
                Value<Decimal> discountAmount = const Value.absent(),
                Value<Decimal> taxAmount = const Value.absent(),
                Value<Decimal> total = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> actorId = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<DateTime?> voidedAt = const Value.absent(),
                Value<DateTime?> refundedAt = const Value.absent(),
                Value<String?> voidOrRefundReason = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedSalesCompanion(
                id: id,
                businessId: businessId,
                storeId: storeId,
                clientSaleId: clientSaleId,
                status: status,
                subtotal: subtotal,
                discountAmount: discountAmount,
                taxAmount: taxAmount,
                total: total,
                paymentMethod: paymentMethod,
                actorId: actorId,
                customerId: customerId,
                occurredAt: occurredAt,
                syncedAt: syncedAt,
                voidedAt: voidedAt,
                refundedAt: refundedAt,
                voidOrRefundReason: voidOrRefundReason,
                createdAt: createdAt,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String businessId,
                required String storeId,
                required String clientSaleId,
                required String status,
                required Decimal subtotal,
                required Decimal discountAmount,
                required Decimal taxAmount,
                required Decimal total,
                required String paymentMethod,
                Value<String?> actorId = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                required DateTime occurredAt,
                required DateTime syncedAt,
                Value<DateTime?> voidedAt = const Value.absent(),
                Value<DateTime?> refundedAt = const Value.absent(),
                Value<String?> voidOrRefundReason = const Value.absent(),
                required DateTime createdAt,
                required DateTime lastSyncedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedSalesCompanion.insert(
                id: id,
                businessId: businessId,
                storeId: storeId,
                clientSaleId: clientSaleId,
                status: status,
                subtotal: subtotal,
                discountAmount: discountAmount,
                taxAmount: taxAmount,
                total: total,
                paymentMethod: paymentMethod,
                actorId: actorId,
                customerId: customerId,
                occurredAt: occurredAt,
                syncedAt: syncedAt,
                voidedAt: voidedAt,
                refundedAt: refundedAt,
                voidOrRefundReason: voidOrRefundReason,
                createdAt: createdAt,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CachedSalesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cachedSaleLineItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (cachedSaleLineItemsRefs) db.cachedSaleLineItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cachedSaleLineItemsRefs)
                    await $_getPrefetchedData<
                      CachedSale,
                      $CachedSalesTable,
                      CachedSaleLineItem
                    >(
                      currentTable: table,
                      referencedTable: $$CachedSalesTableReferences
                          ._cachedSaleLineItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CachedSalesTableReferences(
                            db,
                            table,
                            p0,
                          ).cachedSaleLineItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.saleId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CachedSalesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedSalesTable,
      CachedSale,
      $$CachedSalesTableFilterComposer,
      $$CachedSalesTableOrderingComposer,
      $$CachedSalesTableAnnotationComposer,
      $$CachedSalesTableCreateCompanionBuilder,
      $$CachedSalesTableUpdateCompanionBuilder,
      (CachedSale, $$CachedSalesTableReferences),
      CachedSale,
      PrefetchHooks Function({bool cachedSaleLineItemsRefs})
    >;
typedef $$CachedSaleLineItemsTableCreateCompanionBuilder =
    CachedSaleLineItemsCompanion Function({
      required String id,
      required String saleId,
      required String itemId,
      required Decimal quantity,
      required Decimal unitPrice,
      required Decimal discountAmount,
      required Decimal lineTotal,
      Value<Decimal?> unitCost,
      Value<int> rowid,
    });
typedef $$CachedSaleLineItemsTableUpdateCompanionBuilder =
    CachedSaleLineItemsCompanion Function({
      Value<String> id,
      Value<String> saleId,
      Value<String> itemId,
      Value<Decimal> quantity,
      Value<Decimal> unitPrice,
      Value<Decimal> discountAmount,
      Value<Decimal> lineTotal,
      Value<Decimal?> unitCost,
      Value<int> rowid,
    });

final class $$CachedSaleLineItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CachedSaleLineItemsTable,
          CachedSaleLineItem
        > {
  $$CachedSaleLineItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CachedSalesTable _saleIdTable(_$AppDatabase db) => db.cachedSales
      .createAlias('cached_sale_line_items__sale_id__cached_sales__id');

  $$CachedSalesTableProcessedTableManager get saleId {
    final $_column = $_itemColumn<String>('sale_id')!;

    final manager = $$CachedSalesTableTableManager(
      $_db,
      $_db.cachedSales,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_saleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CachedSaleLineItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedSaleLineItemsTable> {
  $$CachedSaleLineItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get quantity =>
      $composableBuilder(
        column: $table.quantity,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get unitPrice =>
      $composableBuilder(
        column: $table.unitPrice,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get discountAmount =>
      $composableBuilder(
        column: $table.discountAmount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get lineTotal =>
      $composableBuilder(
        column: $table.lineTotal,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal?, Decimal, String> get unitCost =>
      $composableBuilder(
        column: $table.unitCost,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$CachedSalesTableFilterComposer get saleId {
    final $$CachedSalesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.cachedSales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedSalesTableFilterComposer(
            $db: $db,
            $table: $db.cachedSales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedSaleLineItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedSaleLineItemsTable> {
  $$CachedSaleLineItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get discountAmount => $composableBuilder(
    column: $table.discountAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lineTotal => $composableBuilder(
    column: $table.lineTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnOrderings(column),
  );

  $$CachedSalesTableOrderingComposer get saleId {
    final $$CachedSalesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.cachedSales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedSalesTableOrderingComposer(
            $db: $db,
            $table: $db.cachedSales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedSaleLineItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedSaleLineItemsTable> {
  $$CachedSaleLineItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get discountAmount =>
      $composableBuilder(
        column: $table.discountAmount,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal, String> get lineTotal =>
      $composableBuilder(column: $table.lineTotal, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal?, String> get unitCost =>
      $composableBuilder(column: $table.unitCost, builder: (column) => column);

  $$CachedSalesTableAnnotationComposer get saleId {
    final $$CachedSalesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.cachedSales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedSalesTableAnnotationComposer(
            $db: $db,
            $table: $db.cachedSales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachedSaleLineItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedSaleLineItemsTable,
          CachedSaleLineItem,
          $$CachedSaleLineItemsTableFilterComposer,
          $$CachedSaleLineItemsTableOrderingComposer,
          $$CachedSaleLineItemsTableAnnotationComposer,
          $$CachedSaleLineItemsTableCreateCompanionBuilder,
          $$CachedSaleLineItemsTableUpdateCompanionBuilder,
          (CachedSaleLineItem, $$CachedSaleLineItemsTableReferences),
          CachedSaleLineItem,
          PrefetchHooks Function({bool saleId})
        > {
  $$CachedSaleLineItemsTableTableManager(
    _$AppDatabase db,
    $CachedSaleLineItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedSaleLineItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedSaleLineItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedSaleLineItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> saleId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<Decimal> quantity = const Value.absent(),
                Value<Decimal> unitPrice = const Value.absent(),
                Value<Decimal> discountAmount = const Value.absent(),
                Value<Decimal> lineTotal = const Value.absent(),
                Value<Decimal?> unitCost = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedSaleLineItemsCompanion(
                id: id,
                saleId: saleId,
                itemId: itemId,
                quantity: quantity,
                unitPrice: unitPrice,
                discountAmount: discountAmount,
                lineTotal: lineTotal,
                unitCost: unitCost,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String saleId,
                required String itemId,
                required Decimal quantity,
                required Decimal unitPrice,
                required Decimal discountAmount,
                required Decimal lineTotal,
                Value<Decimal?> unitCost = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedSaleLineItemsCompanion.insert(
                id: id,
                saleId: saleId,
                itemId: itemId,
                quantity: quantity,
                unitPrice: unitPrice,
                discountAmount: discountAmount,
                lineTotal: lineTotal,
                unitCost: unitCost,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CachedSaleLineItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({saleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (saleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.saleId,
                                referencedTable:
                                    $$CachedSaleLineItemsTableReferences
                                        ._saleIdTable(db),
                                referencedColumn:
                                    $$CachedSaleLineItemsTableReferences
                                        ._saleIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CachedSaleLineItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedSaleLineItemsTable,
      CachedSaleLineItem,
      $$CachedSaleLineItemsTableFilterComposer,
      $$CachedSaleLineItemsTableOrderingComposer,
      $$CachedSaleLineItemsTableAnnotationComposer,
      $$CachedSaleLineItemsTableCreateCompanionBuilder,
      $$CachedSaleLineItemsTableUpdateCompanionBuilder,
      (CachedSaleLineItem, $$CachedSaleLineItemsTableReferences),
      CachedSaleLineItem,
      PrefetchHooks Function({bool saleId})
    >;
typedef $$PendingVoidsRefundsTableCreateCompanionBuilder =
    PendingVoidsRefundsCompanion Function({
      Value<int> id,
      required String clientActionId,
      required String saleId,
      required String newStatus,
      required String reason,
      required String actorUserId,
      required DateTime occurredAt,
      Value<String> syncStatus,
      Value<String?> syncError,
      Value<int> syncAttemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      required DateTime createdAt,
    });
typedef $$PendingVoidsRefundsTableUpdateCompanionBuilder =
    PendingVoidsRefundsCompanion Function({
      Value<int> id,
      Value<String> clientActionId,
      Value<String> saleId,
      Value<String> newStatus,
      Value<String> reason,
      Value<String> actorUserId,
      Value<DateTime> occurredAt,
      Value<String> syncStatus,
      Value<String?> syncError,
      Value<int> syncAttemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      Value<DateTime> createdAt,
    });

final class $$PendingVoidsRefundsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PendingVoidsRefundsTable,
          PendingVoidsRefund
        > {
  $$PendingVoidsRefundsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PendingSalesTable _saleIdTable(_$AppDatabase db) =>
      db.pendingSales.createAlias(
        'pending_voids_refunds__sale_id__pending_sales__client_sale_id',
      );

  $$PendingSalesTableProcessedTableManager get saleId {
    final $_column = $_itemColumn<String>('sale_id')!;

    final manager = $$PendingSalesTableTableManager(
      $_db,
      $_db.pendingSales,
    ).filter((f) => f.clientSaleId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_saleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PendingVoidsRefundsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingVoidsRefundsTable> {
  $$PendingVoidsRefundsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientActionId => $composableBuilder(
    column: $table.clientActionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newStatus => $composableBuilder(
    column: $table.newStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PendingSalesTableFilterComposer get saleId {
    final $$PendingSalesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.pendingSales,
      getReferencedColumn: (t) => t.clientSaleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingSalesTableFilterComposer(
            $db: $db,
            $table: $db.pendingSales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingVoidsRefundsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingVoidsRefundsTable> {
  $$PendingVoidsRefundsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientActionId => $composableBuilder(
    column: $table.clientActionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newStatus => $composableBuilder(
    column: $table.newStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PendingSalesTableOrderingComposer get saleId {
    final $$PendingSalesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.pendingSales,
      getReferencedColumn: (t) => t.clientSaleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingSalesTableOrderingComposer(
            $db: $db,
            $table: $db.pendingSales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingVoidsRefundsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingVoidsRefundsTable> {
  $$PendingVoidsRefundsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientActionId => $composableBuilder(
    column: $table.clientActionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get newStatus =>
      $composableBuilder(column: $table.newStatus, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PendingSalesTableAnnotationComposer get saleId {
    final $$PendingSalesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.pendingSales,
      getReferencedColumn: (t) => t.clientSaleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingSalesTableAnnotationComposer(
            $db: $db,
            $table: $db.pendingSales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingVoidsRefundsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingVoidsRefundsTable,
          PendingVoidsRefund,
          $$PendingVoidsRefundsTableFilterComposer,
          $$PendingVoidsRefundsTableOrderingComposer,
          $$PendingVoidsRefundsTableAnnotationComposer,
          $$PendingVoidsRefundsTableCreateCompanionBuilder,
          $$PendingVoidsRefundsTableUpdateCompanionBuilder,
          (PendingVoidsRefund, $$PendingVoidsRefundsTableReferences),
          PendingVoidsRefund,
          PrefetchHooks Function({bool saleId})
        > {
  $$PendingVoidsRefundsTableTableManager(
    _$AppDatabase db,
    $PendingVoidsRefundsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingVoidsRefundsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingVoidsRefundsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingVoidsRefundsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientActionId = const Value.absent(),
                Value<String> saleId = const Value.absent(),
                Value<String> newStatus = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String> actorUserId = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> syncAttemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingVoidsRefundsCompanion(
                id: id,
                clientActionId: clientActionId,
                saleId: saleId,
                newStatus: newStatus,
                reason: reason,
                actorUserId: actorUserId,
                occurredAt: occurredAt,
                syncStatus: syncStatus,
                syncError: syncError,
                syncAttemptCount: syncAttemptCount,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientActionId,
                required String saleId,
                required String newStatus,
                required String reason,
                required String actorUserId,
                required DateTime occurredAt,
                Value<String> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> syncAttemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                required DateTime createdAt,
              }) => PendingVoidsRefundsCompanion.insert(
                id: id,
                clientActionId: clientActionId,
                saleId: saleId,
                newStatus: newStatus,
                reason: reason,
                actorUserId: actorUserId,
                occurredAt: occurredAt,
                syncStatus: syncStatus,
                syncError: syncError,
                syncAttemptCount: syncAttemptCount,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PendingVoidsRefundsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({saleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (saleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.saleId,
                                referencedTable:
                                    $$PendingVoidsRefundsTableReferences
                                        ._saleIdTable(db),
                                referencedColumn:
                                    $$PendingVoidsRefundsTableReferences
                                        ._saleIdTable(db)
                                        .clientSaleId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PendingVoidsRefundsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingVoidsRefundsTable,
      PendingVoidsRefund,
      $$PendingVoidsRefundsTableFilterComposer,
      $$PendingVoidsRefundsTableOrderingComposer,
      $$PendingVoidsRefundsTableAnnotationComposer,
      $$PendingVoidsRefundsTableCreateCompanionBuilder,
      $$PendingVoidsRefundsTableUpdateCompanionBuilder,
      (PendingVoidsRefund, $$PendingVoidsRefundsTableReferences),
      PendingVoidsRefund,
      PrefetchHooks Function({bool saleId})
    >;
typedef $$ExpenseEntriesTableCreateCompanionBuilder =
    ExpenseEntriesCompanion Function({
      Value<int> id,
      required String expenseId,
      required String businessId,
      required String storeId,
      required String category,
      required Decimal amount,
      Value<String?> description,
      Value<String?> payee,
      Value<String?> note,
      Value<String> paymentMethod,
      Value<String?> receiptAttachmentId,
      Value<String?> localReceiptPath,
      required DateTime occurredAt,
      required String actorUserId,
      Value<String?> serverId,
      Value<String> syncStatus,
      Value<String?> syncError,
      Value<int> syncAttemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      required DateTime createdAt,
    });
typedef $$ExpenseEntriesTableUpdateCompanionBuilder =
    ExpenseEntriesCompanion Function({
      Value<int> id,
      Value<String> expenseId,
      Value<String> businessId,
      Value<String> storeId,
      Value<String> category,
      Value<Decimal> amount,
      Value<String?> description,
      Value<String?> payee,
      Value<String?> note,
      Value<String> paymentMethod,
      Value<String?> receiptAttachmentId,
      Value<String?> localReceiptPath,
      Value<DateTime> occurredAt,
      Value<String> actorUserId,
      Value<String?> serverId,
      Value<String> syncStatus,
      Value<String?> syncError,
      Value<int> syncAttemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      Value<DateTime> createdAt,
    });

class $$ExpenseEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ExpenseEntriesTable> {
  $$ExpenseEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expenseId => $composableBuilder(
    column: $table.expenseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payee => $composableBuilder(
    column: $table.payee,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptAttachmentId => $composableBuilder(
    column: $table.receiptAttachmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localReceiptPath => $composableBuilder(
    column: $table.localReceiptPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExpenseEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpenseEntriesTable> {
  $$ExpenseEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expenseId => $composableBuilder(
    column: $table.expenseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payee => $composableBuilder(
    column: $table.payee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptAttachmentId => $composableBuilder(
    column: $table.receiptAttachmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localReceiptPath => $composableBuilder(
    column: $table.localReceiptPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExpenseEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpenseEntriesTable> {
  $$ExpenseEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get expenseId =>
      $composableBuilder(column: $table.expenseId, builder: (column) => column);

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payee =>
      $composableBuilder(column: $table.payee, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptAttachmentId => $composableBuilder(
    column: $table.receiptAttachmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localReceiptPath => $composableBuilder(
    column: $table.localReceiptPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ExpenseEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExpenseEntriesTable,
          ExpenseEntry,
          $$ExpenseEntriesTableFilterComposer,
          $$ExpenseEntriesTableOrderingComposer,
          $$ExpenseEntriesTableAnnotationComposer,
          $$ExpenseEntriesTableCreateCompanionBuilder,
          $$ExpenseEntriesTableUpdateCompanionBuilder,
          (
            ExpenseEntry,
            BaseReferences<_$AppDatabase, $ExpenseEntriesTable, ExpenseEntry>,
          ),
          ExpenseEntry,
          PrefetchHooks Function()
        > {
  $$ExpenseEntriesTableTableManager(
    _$AppDatabase db,
    $ExpenseEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpenseEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpenseEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpenseEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> expenseId = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> storeId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<Decimal> amount = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> payee = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> receiptAttachmentId = const Value.absent(),
                Value<String?> localReceiptPath = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> actorUserId = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> syncAttemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ExpenseEntriesCompanion(
                id: id,
                expenseId: expenseId,
                businessId: businessId,
                storeId: storeId,
                category: category,
                amount: amount,
                description: description,
                payee: payee,
                note: note,
                paymentMethod: paymentMethod,
                receiptAttachmentId: receiptAttachmentId,
                localReceiptPath: localReceiptPath,
                occurredAt: occurredAt,
                actorUserId: actorUserId,
                serverId: serverId,
                syncStatus: syncStatus,
                syncError: syncError,
                syncAttemptCount: syncAttemptCount,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String expenseId,
                required String businessId,
                required String storeId,
                required String category,
                required Decimal amount,
                Value<String?> description = const Value.absent(),
                Value<String?> payee = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> receiptAttachmentId = const Value.absent(),
                Value<String?> localReceiptPath = const Value.absent(),
                required DateTime occurredAt,
                required String actorUserId,
                Value<String?> serverId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> syncAttemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                required DateTime createdAt,
              }) => ExpenseEntriesCompanion.insert(
                id: id,
                expenseId: expenseId,
                businessId: businessId,
                storeId: storeId,
                category: category,
                amount: amount,
                description: description,
                payee: payee,
                note: note,
                paymentMethod: paymentMethod,
                receiptAttachmentId: receiptAttachmentId,
                localReceiptPath: localReceiptPath,
                occurredAt: occurredAt,
                actorUserId: actorUserId,
                serverId: serverId,
                syncStatus: syncStatus,
                syncError: syncError,
                syncAttemptCount: syncAttemptCount,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExpenseEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExpenseEntriesTable,
      ExpenseEntry,
      $$ExpenseEntriesTableFilterComposer,
      $$ExpenseEntriesTableOrderingComposer,
      $$ExpenseEntriesTableAnnotationComposer,
      $$ExpenseEntriesTableCreateCompanionBuilder,
      $$ExpenseEntriesTableUpdateCompanionBuilder,
      (
        ExpenseEntry,
        BaseReferences<_$AppDatabase, $ExpenseEntriesTable, ExpenseEntry>,
      ),
      ExpenseEntry,
      PrefetchHooks Function()
    >;
typedef $$OtherIncomeEntriesTableCreateCompanionBuilder =
    OtherIncomeEntriesCompanion Function({
      Value<int> id,
      required String incomeId,
      required String businessId,
      required String storeId,
      required String category,
      required Decimal amount,
      Value<String?> description,
      Value<String?> source,
      Value<String?> note,
      Value<String> paymentMethod,
      Value<String?> receiptAttachmentId,
      Value<String?> localReceiptPath,
      required DateTime occurredAt,
      required String actorUserId,
      Value<String?> serverId,
      Value<String> syncStatus,
      Value<String?> syncError,
      Value<int> syncAttemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      required DateTime createdAt,
    });
typedef $$OtherIncomeEntriesTableUpdateCompanionBuilder =
    OtherIncomeEntriesCompanion Function({
      Value<int> id,
      Value<String> incomeId,
      Value<String> businessId,
      Value<String> storeId,
      Value<String> category,
      Value<Decimal> amount,
      Value<String?> description,
      Value<String?> source,
      Value<String?> note,
      Value<String> paymentMethod,
      Value<String?> receiptAttachmentId,
      Value<String?> localReceiptPath,
      Value<DateTime> occurredAt,
      Value<String> actorUserId,
      Value<String?> serverId,
      Value<String> syncStatus,
      Value<String?> syncError,
      Value<int> syncAttemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      Value<DateTime> createdAt,
    });

class $$OtherIncomeEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $OtherIncomeEntriesTable> {
  $$OtherIncomeEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incomeId => $composableBuilder(
    column: $table.incomeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptAttachmentId => $composableBuilder(
    column: $table.receiptAttachmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localReceiptPath => $composableBuilder(
    column: $table.localReceiptPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OtherIncomeEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $OtherIncomeEntriesTable> {
  $$OtherIncomeEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incomeId => $composableBuilder(
    column: $table.incomeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptAttachmentId => $composableBuilder(
    column: $table.receiptAttachmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localReceiptPath => $composableBuilder(
    column: $table.localReceiptPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OtherIncomeEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OtherIncomeEntriesTable> {
  $$OtherIncomeEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get incomeId =>
      $composableBuilder(column: $table.incomeId, builder: (column) => column);

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptAttachmentId => $composableBuilder(
    column: $table.receiptAttachmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localReceiptPath => $composableBuilder(
    column: $table.localReceiptPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OtherIncomeEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OtherIncomeEntriesTable,
          OtherIncomeEntry,
          $$OtherIncomeEntriesTableFilterComposer,
          $$OtherIncomeEntriesTableOrderingComposer,
          $$OtherIncomeEntriesTableAnnotationComposer,
          $$OtherIncomeEntriesTableCreateCompanionBuilder,
          $$OtherIncomeEntriesTableUpdateCompanionBuilder,
          (
            OtherIncomeEntry,
            BaseReferences<
              _$AppDatabase,
              $OtherIncomeEntriesTable,
              OtherIncomeEntry
            >,
          ),
          OtherIncomeEntry,
          PrefetchHooks Function()
        > {
  $$OtherIncomeEntriesTableTableManager(
    _$AppDatabase db,
    $OtherIncomeEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OtherIncomeEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OtherIncomeEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OtherIncomeEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> incomeId = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> storeId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<Decimal> amount = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> receiptAttachmentId = const Value.absent(),
                Value<String?> localReceiptPath = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> actorUserId = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> syncAttemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OtherIncomeEntriesCompanion(
                id: id,
                incomeId: incomeId,
                businessId: businessId,
                storeId: storeId,
                category: category,
                amount: amount,
                description: description,
                source: source,
                note: note,
                paymentMethod: paymentMethod,
                receiptAttachmentId: receiptAttachmentId,
                localReceiptPath: localReceiptPath,
                occurredAt: occurredAt,
                actorUserId: actorUserId,
                serverId: serverId,
                syncStatus: syncStatus,
                syncError: syncError,
                syncAttemptCount: syncAttemptCount,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String incomeId,
                required String businessId,
                required String storeId,
                required String category,
                required Decimal amount,
                Value<String?> description = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> receiptAttachmentId = const Value.absent(),
                Value<String?> localReceiptPath = const Value.absent(),
                required DateTime occurredAt,
                required String actorUserId,
                Value<String?> serverId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> syncAttemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                required DateTime createdAt,
              }) => OtherIncomeEntriesCompanion.insert(
                id: id,
                incomeId: incomeId,
                businessId: businessId,
                storeId: storeId,
                category: category,
                amount: amount,
                description: description,
                source: source,
                note: note,
                paymentMethod: paymentMethod,
                receiptAttachmentId: receiptAttachmentId,
                localReceiptPath: localReceiptPath,
                occurredAt: occurredAt,
                actorUserId: actorUserId,
                serverId: serverId,
                syncStatus: syncStatus,
                syncError: syncError,
                syncAttemptCount: syncAttemptCount,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OtherIncomeEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OtherIncomeEntriesTable,
      OtherIncomeEntry,
      $$OtherIncomeEntriesTableFilterComposer,
      $$OtherIncomeEntriesTableOrderingComposer,
      $$OtherIncomeEntriesTableAnnotationComposer,
      $$OtherIncomeEntriesTableCreateCompanionBuilder,
      $$OtherIncomeEntriesTableUpdateCompanionBuilder,
      (
        OtherIncomeEntry,
        BaseReferences<
          _$AppDatabase,
          $OtherIncomeEntriesTable,
          OtherIncomeEntry
        >,
      ),
      OtherIncomeEntry,
      PrefetchHooks Function()
    >;
typedef $$CachedOtherExpensesTableCreateCompanionBuilder =
    CachedOtherExpensesCompanion Function({
      required String id,
      required String businessId,
      required String storeId,
      required String clientExpenseId,
      required String category,
      required Decimal amount,
      required String description,
      Value<String?> payee,
      Value<String?> note,
      required String paymentMethod,
      Value<String?> receiptAttachmentId,
      Value<String?> actorId,
      required DateTime occurredAt,
      required DateTime syncedAt,
      required DateTime updatedAt,
      Value<bool> isDeleted,
      required DateTime createdAt,
      required DateTime lastSyncedAt,
      Value<int> rowid,
    });
typedef $$CachedOtherExpensesTableUpdateCompanionBuilder =
    CachedOtherExpensesCompanion Function({
      Value<String> id,
      Value<String> businessId,
      Value<String> storeId,
      Value<String> clientExpenseId,
      Value<String> category,
      Value<Decimal> amount,
      Value<String> description,
      Value<String?> payee,
      Value<String?> note,
      Value<String> paymentMethod,
      Value<String?> receiptAttachmentId,
      Value<String?> actorId,
      Value<DateTime> occurredAt,
      Value<DateTime> syncedAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
      Value<DateTime> createdAt,
      Value<DateTime> lastSyncedAt,
      Value<int> rowid,
    });

class $$CachedOtherExpensesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedOtherExpensesTable> {
  $$CachedOtherExpensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientExpenseId => $composableBuilder(
    column: $table.clientExpenseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payee => $composableBuilder(
    column: $table.payee,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptAttachmentId => $composableBuilder(
    column: $table.receiptAttachmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedOtherExpensesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedOtherExpensesTable> {
  $$CachedOtherExpensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientExpenseId => $composableBuilder(
    column: $table.clientExpenseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payee => $composableBuilder(
    column: $table.payee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptAttachmentId => $composableBuilder(
    column: $table.receiptAttachmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedOtherExpensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedOtherExpensesTable> {
  $$CachedOtherExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get clientExpenseId => $composableBuilder(
    column: $table.clientExpenseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payee =>
      $composableBuilder(column: $table.payee, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptAttachmentId => $composableBuilder(
    column: $table.receiptAttachmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$CachedOtherExpensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedOtherExpensesTable,
          CachedOtherExpense,
          $$CachedOtherExpensesTableFilterComposer,
          $$CachedOtherExpensesTableOrderingComposer,
          $$CachedOtherExpensesTableAnnotationComposer,
          $$CachedOtherExpensesTableCreateCompanionBuilder,
          $$CachedOtherExpensesTableUpdateCompanionBuilder,
          (
            CachedOtherExpense,
            BaseReferences<
              _$AppDatabase,
              $CachedOtherExpensesTable,
              CachedOtherExpense
            >,
          ),
          CachedOtherExpense,
          PrefetchHooks Function()
        > {
  $$CachedOtherExpensesTableTableManager(
    _$AppDatabase db,
    $CachedOtherExpensesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedOtherExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedOtherExpensesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedOtherExpensesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> storeId = const Value.absent(),
                Value<String> clientExpenseId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<Decimal> amount = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> payee = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> receiptAttachmentId = const Value.absent(),
                Value<String?> actorId = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedOtherExpensesCompanion(
                id: id,
                businessId: businessId,
                storeId: storeId,
                clientExpenseId: clientExpenseId,
                category: category,
                amount: amount,
                description: description,
                payee: payee,
                note: note,
                paymentMethod: paymentMethod,
                receiptAttachmentId: receiptAttachmentId,
                actorId: actorId,
                occurredAt: occurredAt,
                syncedAt: syncedAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                createdAt: createdAt,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String businessId,
                required String storeId,
                required String clientExpenseId,
                required String category,
                required Decimal amount,
                required String description,
                Value<String?> payee = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String paymentMethod,
                Value<String?> receiptAttachmentId = const Value.absent(),
                Value<String?> actorId = const Value.absent(),
                required DateTime occurredAt,
                required DateTime syncedAt,
                required DateTime updatedAt,
                Value<bool> isDeleted = const Value.absent(),
                required DateTime createdAt,
                required DateTime lastSyncedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedOtherExpensesCompanion.insert(
                id: id,
                businessId: businessId,
                storeId: storeId,
                clientExpenseId: clientExpenseId,
                category: category,
                amount: amount,
                description: description,
                payee: payee,
                note: note,
                paymentMethod: paymentMethod,
                receiptAttachmentId: receiptAttachmentId,
                actorId: actorId,
                occurredAt: occurredAt,
                syncedAt: syncedAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                createdAt: createdAt,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedOtherExpensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedOtherExpensesTable,
      CachedOtherExpense,
      $$CachedOtherExpensesTableFilterComposer,
      $$CachedOtherExpensesTableOrderingComposer,
      $$CachedOtherExpensesTableAnnotationComposer,
      $$CachedOtherExpensesTableCreateCompanionBuilder,
      $$CachedOtherExpensesTableUpdateCompanionBuilder,
      (
        CachedOtherExpense,
        BaseReferences<
          _$AppDatabase,
          $CachedOtherExpensesTable,
          CachedOtherExpense
        >,
      ),
      CachedOtherExpense,
      PrefetchHooks Function()
    >;
typedef $$CachedOtherIncomesTableCreateCompanionBuilder =
    CachedOtherIncomesCompanion Function({
      required String id,
      required String businessId,
      required String storeId,
      required String clientIncomeId,
      required String category,
      required Decimal amount,
      required String description,
      Value<String?> source,
      Value<String?> note,
      required String paymentMethod,
      Value<String?> receiptAttachmentId,
      Value<String?> actorId,
      required DateTime occurredAt,
      required DateTime syncedAt,
      required DateTime updatedAt,
      Value<bool> isDeleted,
      required DateTime createdAt,
      required DateTime lastSyncedAt,
      Value<int> rowid,
    });
typedef $$CachedOtherIncomesTableUpdateCompanionBuilder =
    CachedOtherIncomesCompanion Function({
      Value<String> id,
      Value<String> businessId,
      Value<String> storeId,
      Value<String> clientIncomeId,
      Value<String> category,
      Value<Decimal> amount,
      Value<String> description,
      Value<String?> source,
      Value<String?> note,
      Value<String> paymentMethod,
      Value<String?> receiptAttachmentId,
      Value<String?> actorId,
      Value<DateTime> occurredAt,
      Value<DateTime> syncedAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
      Value<DateTime> createdAt,
      Value<DateTime> lastSyncedAt,
      Value<int> rowid,
    });

class $$CachedOtherIncomesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedOtherIncomesTable> {
  $$CachedOtherIncomesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientIncomeId => $composableBuilder(
    column: $table.clientIncomeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptAttachmentId => $composableBuilder(
    column: $table.receiptAttachmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedOtherIncomesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedOtherIncomesTable> {
  $$CachedOtherIncomesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientIncomeId => $composableBuilder(
    column: $table.clientIncomeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptAttachmentId => $composableBuilder(
    column: $table.receiptAttachmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedOtherIncomesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedOtherIncomesTable> {
  $$CachedOtherIncomesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get clientIncomeId => $composableBuilder(
    column: $table.clientIncomeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptAttachmentId => $composableBuilder(
    column: $table.receiptAttachmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$CachedOtherIncomesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedOtherIncomesTable,
          CachedOtherIncome,
          $$CachedOtherIncomesTableFilterComposer,
          $$CachedOtherIncomesTableOrderingComposer,
          $$CachedOtherIncomesTableAnnotationComposer,
          $$CachedOtherIncomesTableCreateCompanionBuilder,
          $$CachedOtherIncomesTableUpdateCompanionBuilder,
          (
            CachedOtherIncome,
            BaseReferences<
              _$AppDatabase,
              $CachedOtherIncomesTable,
              CachedOtherIncome
            >,
          ),
          CachedOtherIncome,
          PrefetchHooks Function()
        > {
  $$CachedOtherIncomesTableTableManager(
    _$AppDatabase db,
    $CachedOtherIncomesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedOtherIncomesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedOtherIncomesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedOtherIncomesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> storeId = const Value.absent(),
                Value<String> clientIncomeId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<Decimal> amount = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> receiptAttachmentId = const Value.absent(),
                Value<String?> actorId = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedOtherIncomesCompanion(
                id: id,
                businessId: businessId,
                storeId: storeId,
                clientIncomeId: clientIncomeId,
                category: category,
                amount: amount,
                description: description,
                source: source,
                note: note,
                paymentMethod: paymentMethod,
                receiptAttachmentId: receiptAttachmentId,
                actorId: actorId,
                occurredAt: occurredAt,
                syncedAt: syncedAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                createdAt: createdAt,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String businessId,
                required String storeId,
                required String clientIncomeId,
                required String category,
                required Decimal amount,
                required String description,
                Value<String?> source = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String paymentMethod,
                Value<String?> receiptAttachmentId = const Value.absent(),
                Value<String?> actorId = const Value.absent(),
                required DateTime occurredAt,
                required DateTime syncedAt,
                required DateTime updatedAt,
                Value<bool> isDeleted = const Value.absent(),
                required DateTime createdAt,
                required DateTime lastSyncedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedOtherIncomesCompanion.insert(
                id: id,
                businessId: businessId,
                storeId: storeId,
                clientIncomeId: clientIncomeId,
                category: category,
                amount: amount,
                description: description,
                source: source,
                note: note,
                paymentMethod: paymentMethod,
                receiptAttachmentId: receiptAttachmentId,
                actorId: actorId,
                occurredAt: occurredAt,
                syncedAt: syncedAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                createdAt: createdAt,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedOtherIncomesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedOtherIncomesTable,
      CachedOtherIncome,
      $$CachedOtherIncomesTableFilterComposer,
      $$CachedOtherIncomesTableOrderingComposer,
      $$CachedOtherIncomesTableAnnotationComposer,
      $$CachedOtherIncomesTableCreateCompanionBuilder,
      $$CachedOtherIncomesTableUpdateCompanionBuilder,
      (
        CachedOtherIncome,
        BaseReferences<
          _$AppDatabase,
          $CachedOtherIncomesTable,
          CachedOtherIncome
        >,
      ),
      CachedOtherIncome,
      PrefetchHooks Function()
    >;
typedef $$CustomerEntriesTableCreateCompanionBuilder =
    CustomerEntriesCompanion Function({
      Value<int> id,
      required String customerId,
      required String businessId,
      required String name,
      required String phone,
      Value<String?> email,
      Value<String?> addressLine1,
      required DateTime joinedAt,
      required String actorUserId,
      Value<String> syncStatus,
      Value<String?> syncError,
      Value<int> syncAttemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      required DateTime createdAt,
    });
typedef $$CustomerEntriesTableUpdateCompanionBuilder =
    CustomerEntriesCompanion Function({
      Value<int> id,
      Value<String> customerId,
      Value<String> businessId,
      Value<String> name,
      Value<String> phone,
      Value<String?> email,
      Value<String?> addressLine1,
      Value<DateTime> joinedAt,
      Value<String> actorUserId,
      Value<String> syncStatus,
      Value<String?> syncError,
      Value<int> syncAttemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      Value<DateTime> createdAt,
    });

class $$CustomerEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CustomerEntriesTable> {
  $$CustomerEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addressLine1 => $composableBuilder(
    column: $table.addressLine1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomerEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomerEntriesTable> {
  $$CustomerEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addressLine1 => $composableBuilder(
    column: $table.addressLine1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomerEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomerEntriesTable> {
  $$CustomerEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get addressLine1 => $composableBuilder(
    column: $table.addressLine1,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  GeneratedColumn<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CustomerEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomerEntriesTable,
          CustomerEntry,
          $$CustomerEntriesTableFilterComposer,
          $$CustomerEntriesTableOrderingComposer,
          $$CustomerEntriesTableAnnotationComposer,
          $$CustomerEntriesTableCreateCompanionBuilder,
          $$CustomerEntriesTableUpdateCompanionBuilder,
          (
            CustomerEntry,
            BaseReferences<_$AppDatabase, $CustomerEntriesTable, CustomerEntry>,
          ),
          CustomerEntry,
          PrefetchHooks Function()
        > {
  $$CustomerEntriesTableTableManager(
    _$AppDatabase db,
    $CustomerEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomerEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomerEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomerEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> addressLine1 = const Value.absent(),
                Value<DateTime> joinedAt = const Value.absent(),
                Value<String> actorUserId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> syncAttemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CustomerEntriesCompanion(
                id: id,
                customerId: customerId,
                businessId: businessId,
                name: name,
                phone: phone,
                email: email,
                addressLine1: addressLine1,
                joinedAt: joinedAt,
                actorUserId: actorUserId,
                syncStatus: syncStatus,
                syncError: syncError,
                syncAttemptCount: syncAttemptCount,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String customerId,
                required String businessId,
                required String name,
                required String phone,
                Value<String?> email = const Value.absent(),
                Value<String?> addressLine1 = const Value.absent(),
                required DateTime joinedAt,
                required String actorUserId,
                Value<String> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> syncAttemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                required DateTime createdAt,
              }) => CustomerEntriesCompanion.insert(
                id: id,
                customerId: customerId,
                businessId: businessId,
                name: name,
                phone: phone,
                email: email,
                addressLine1: addressLine1,
                joinedAt: joinedAt,
                actorUserId: actorUserId,
                syncStatus: syncStatus,
                syncError: syncError,
                syncAttemptCount: syncAttemptCount,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomerEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomerEntriesTable,
      CustomerEntry,
      $$CustomerEntriesTableFilterComposer,
      $$CustomerEntriesTableOrderingComposer,
      $$CustomerEntriesTableAnnotationComposer,
      $$CustomerEntriesTableCreateCompanionBuilder,
      $$CustomerEntriesTableUpdateCompanionBuilder,
      (
        CustomerEntry,
        BaseReferences<_$AppDatabase, $CustomerEntriesTable, CustomerEntry>,
      ),
      CustomerEntry,
      PrefetchHooks Function()
    >;
typedef $$CachedCustomersTableCreateCompanionBuilder =
    CachedCustomersCompanion Function({
      required String id,
      required String businessId,
      required String name,
      required String phone,
      Value<String?> email,
      Value<String?> addressLine1,
      Value<String?> actorId,
      required DateTime joinedAt,
      required DateTime syncedAt,
      required DateTime updatedAt,
      Value<bool> isDeleted,
      required DateTime createdAt,
      Value<int> totalOrders,
      required Decimal totalSpent,
      Value<DateTime?> lastOrderAt,
      required DateTime lastSyncedAt,
      Value<int> rowid,
    });
typedef $$CachedCustomersTableUpdateCompanionBuilder =
    CachedCustomersCompanion Function({
      Value<String> id,
      Value<String> businessId,
      Value<String> name,
      Value<String> phone,
      Value<String?> email,
      Value<String?> addressLine1,
      Value<String?> actorId,
      Value<DateTime> joinedAt,
      Value<DateTime> syncedAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
      Value<DateTime> createdAt,
      Value<int> totalOrders,
      Value<Decimal> totalSpent,
      Value<DateTime?> lastOrderAt,
      Value<DateTime> lastSyncedAt,
      Value<int> rowid,
    });

class $$CachedCustomersTableFilterComposer
    extends Composer<_$AppDatabase, $CachedCustomersTable> {
  $$CachedCustomersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addressLine1 => $composableBuilder(
    column: $table.addressLine1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalOrders => $composableBuilder(
    column: $table.totalOrders,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get totalSpent =>
      $composableBuilder(
        column: $table.totalSpent,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get lastOrderAt => $composableBuilder(
    column: $table.lastOrderAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedCustomersTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedCustomersTable> {
  $$CachedCustomersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addressLine1 => $composableBuilder(
    column: $table.addressLine1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalOrders => $composableBuilder(
    column: $table.totalOrders,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get totalSpent => $composableBuilder(
    column: $table.totalSpent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOrderAt => $composableBuilder(
    column: $table.lastOrderAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedCustomersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedCustomersTable> {
  $$CachedCustomersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get addressLine1 => $composableBuilder(
    column: $table.addressLine1,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<DateTime> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get totalOrders => $composableBuilder(
    column: $table.totalOrders,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Decimal, String> get totalSpent =>
      $composableBuilder(
        column: $table.totalSpent,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get lastOrderAt => $composableBuilder(
    column: $table.lastOrderAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$CachedCustomersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedCustomersTable,
          CachedCustomer,
          $$CachedCustomersTableFilterComposer,
          $$CachedCustomersTableOrderingComposer,
          $$CachedCustomersTableAnnotationComposer,
          $$CachedCustomersTableCreateCompanionBuilder,
          $$CachedCustomersTableUpdateCompanionBuilder,
          (
            CachedCustomer,
            BaseReferences<
              _$AppDatabase,
              $CachedCustomersTable,
              CachedCustomer
            >,
          ),
          CachedCustomer,
          PrefetchHooks Function()
        > {
  $$CachedCustomersTableTableManager(
    _$AppDatabase db,
    $CachedCustomersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedCustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedCustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> addressLine1 = const Value.absent(),
                Value<String?> actorId = const Value.absent(),
                Value<DateTime> joinedAt = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> totalOrders = const Value.absent(),
                Value<Decimal> totalSpent = const Value.absent(),
                Value<DateTime?> lastOrderAt = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCustomersCompanion(
                id: id,
                businessId: businessId,
                name: name,
                phone: phone,
                email: email,
                addressLine1: addressLine1,
                actorId: actorId,
                joinedAt: joinedAt,
                syncedAt: syncedAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                createdAt: createdAt,
                totalOrders: totalOrders,
                totalSpent: totalSpent,
                lastOrderAt: lastOrderAt,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String businessId,
                required String name,
                required String phone,
                Value<String?> email = const Value.absent(),
                Value<String?> addressLine1 = const Value.absent(),
                Value<String?> actorId = const Value.absent(),
                required DateTime joinedAt,
                required DateTime syncedAt,
                required DateTime updatedAt,
                Value<bool> isDeleted = const Value.absent(),
                required DateTime createdAt,
                Value<int> totalOrders = const Value.absent(),
                required Decimal totalSpent,
                Value<DateTime?> lastOrderAt = const Value.absent(),
                required DateTime lastSyncedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedCustomersCompanion.insert(
                id: id,
                businessId: businessId,
                name: name,
                phone: phone,
                email: email,
                addressLine1: addressLine1,
                actorId: actorId,
                joinedAt: joinedAt,
                syncedAt: syncedAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                createdAt: createdAt,
                totalOrders: totalOrders,
                totalSpent: totalSpent,
                lastOrderAt: lastOrderAt,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedCustomersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedCustomersTable,
      CachedCustomer,
      $$CachedCustomersTableFilterComposer,
      $$CachedCustomersTableOrderingComposer,
      $$CachedCustomersTableAnnotationComposer,
      $$CachedCustomersTableCreateCompanionBuilder,
      $$CachedCustomersTableUpdateCompanionBuilder,
      (
        CachedCustomer,
        BaseReferences<_$AppDatabase, $CachedCustomersTable, CachedCustomer>,
      ),
      CachedCustomer,
      PrefetchHooks Function()
    >;
typedef $$CachedSuppliersTableCreateCompanionBuilder =
    CachedSuppliersCompanion Function({
      required String id,
      required String businessId,
      required String name,
      Value<String?> phone,
      Value<String?> email,
      Value<String?> addressLine1,
      Value<String?> notes,
      required DateTime updatedAt,
      Value<bool> isDeleted,
      required DateTime createdAt,
      required DateTime lastSyncedAt,
      Value<int> rowid,
    });
typedef $$CachedSuppliersTableUpdateCompanionBuilder =
    CachedSuppliersCompanion Function({
      Value<String> id,
      Value<String> businessId,
      Value<String> name,
      Value<String?> phone,
      Value<String?> email,
      Value<String?> addressLine1,
      Value<String?> notes,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
      Value<DateTime> createdAt,
      Value<DateTime> lastSyncedAt,
      Value<int> rowid,
    });

class $$CachedSuppliersTableFilterComposer
    extends Composer<_$AppDatabase, $CachedSuppliersTable> {
  $$CachedSuppliersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addressLine1 => $composableBuilder(
    column: $table.addressLine1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedSuppliersTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedSuppliersTable> {
  $$CachedSuppliersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addressLine1 => $composableBuilder(
    column: $table.addressLine1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedSuppliersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedSuppliersTable> {
  $$CachedSuppliersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get addressLine1 => $composableBuilder(
    column: $table.addressLine1,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$CachedSuppliersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedSuppliersTable,
          CachedSupplier,
          $$CachedSuppliersTableFilterComposer,
          $$CachedSuppliersTableOrderingComposer,
          $$CachedSuppliersTableAnnotationComposer,
          $$CachedSuppliersTableCreateCompanionBuilder,
          $$CachedSuppliersTableUpdateCompanionBuilder,
          (
            CachedSupplier,
            BaseReferences<
              _$AppDatabase,
              $CachedSuppliersTable,
              CachedSupplier
            >,
          ),
          CachedSupplier,
          PrefetchHooks Function()
        > {
  $$CachedSuppliersTableTableManager(
    _$AppDatabase db,
    $CachedSuppliersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedSuppliersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedSuppliersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedSuppliersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> businessId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> addressLine1 = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedSuppliersCompanion(
                id: id,
                businessId: businessId,
                name: name,
                phone: phone,
                email: email,
                addressLine1: addressLine1,
                notes: notes,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                createdAt: createdAt,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String businessId,
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> addressLine1 = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> isDeleted = const Value.absent(),
                required DateTime createdAt,
                required DateTime lastSyncedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedSuppliersCompanion.insert(
                id: id,
                businessId: businessId,
                name: name,
                phone: phone,
                email: email,
                addressLine1: addressLine1,
                notes: notes,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                createdAt: createdAt,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedSuppliersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedSuppliersTable,
      CachedSupplier,
      $$CachedSuppliersTableFilterComposer,
      $$CachedSuppliersTableOrderingComposer,
      $$CachedSuppliersTableAnnotationComposer,
      $$CachedSuppliersTableCreateCompanionBuilder,
      $$CachedSuppliersTableUpdateCompanionBuilder,
      (
        CachedSupplier,
        BaseReferences<_$AppDatabase, $CachedSuppliersTable, CachedSupplier>,
      ),
      CachedSupplier,
      PrefetchHooks Function()
    >;
typedef $$CachedCategoriesTableCreateCompanionBuilder =
    CachedCategoriesCompanion Function({
      required String id,
      required String code,
      required String name,
      Value<int> sortOrder,
      Value<bool> isActive,
      required DateTime lastSyncedAt,
      Value<int> rowid,
    });
typedef $$CachedCategoriesTableUpdateCompanionBuilder =
    CachedCategoriesCompanion Function({
      Value<String> id,
      Value<String> code,
      Value<String> name,
      Value<int> sortOrder,
      Value<bool> isActive,
      Value<DateTime> lastSyncedAt,
      Value<int> rowid,
    });

class $$CachedCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$CachedCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedCategoriesTable,
          CachedCategory,
          $$CachedCategoriesTableFilterComposer,
          $$CachedCategoriesTableOrderingComposer,
          $$CachedCategoriesTableAnnotationComposer,
          $$CachedCategoriesTableCreateCompanionBuilder,
          $$CachedCategoriesTableUpdateCompanionBuilder,
          (
            CachedCategory,
            BaseReferences<
              _$AppDatabase,
              $CachedCategoriesTable,
              CachedCategory
            >,
          ),
          CachedCategory,
          PrefetchHooks Function()
        > {
  $$CachedCategoriesTableTableManager(
    _$AppDatabase db,
    $CachedCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCategoriesCompanion(
                id: id,
                code: code,
                name: name,
                sortOrder: sortOrder,
                isActive: isActive,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String code,
                required String name,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required DateTime lastSyncedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedCategoriesCompanion.insert(
                id: id,
                code: code,
                name: name,
                sortOrder: sortOrder,
                isActive: isActive,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedCategoriesTable,
      CachedCategory,
      $$CachedCategoriesTableFilterComposer,
      $$CachedCategoriesTableOrderingComposer,
      $$CachedCategoriesTableAnnotationComposer,
      $$CachedCategoriesTableCreateCompanionBuilder,
      $$CachedCategoriesTableUpdateCompanionBuilder,
      (
        CachedCategory,
        BaseReferences<_$AppDatabase, $CachedCategoriesTable, CachedCategory>,
      ),
      CachedCategory,
      PrefetchHooks Function()
    >;
typedef $$CachedUnitsTableCreateCompanionBuilder =
    CachedUnitsCompanion Function({
      required String id,
      required String code,
      required String name,
      required String abbreviation,
      Value<int> sortOrder,
      Value<bool> isActive,
      required DateTime lastSyncedAt,
      Value<int> rowid,
    });
typedef $$CachedUnitsTableUpdateCompanionBuilder =
    CachedUnitsCompanion Function({
      Value<String> id,
      Value<String> code,
      Value<String> name,
      Value<String> abbreviation,
      Value<int> sortOrder,
      Value<bool> isActive,
      Value<DateTime> lastSyncedAt,
      Value<int> rowid,
    });

class $$CachedUnitsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedUnitsTable> {
  $$CachedUnitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get abbreviation => $composableBuilder(
    column: $table.abbreviation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedUnitsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedUnitsTable> {
  $$CachedUnitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get abbreviation => $composableBuilder(
    column: $table.abbreviation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedUnitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedUnitsTable> {
  $$CachedUnitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get abbreviation => $composableBuilder(
    column: $table.abbreviation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$CachedUnitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedUnitsTable,
          CachedUnit,
          $$CachedUnitsTableFilterComposer,
          $$CachedUnitsTableOrderingComposer,
          $$CachedUnitsTableAnnotationComposer,
          $$CachedUnitsTableCreateCompanionBuilder,
          $$CachedUnitsTableUpdateCompanionBuilder,
          (
            CachedUnit,
            BaseReferences<_$AppDatabase, $CachedUnitsTable, CachedUnit>,
          ),
          CachedUnit,
          PrefetchHooks Function()
        > {
  $$CachedUnitsTableTableManager(_$AppDatabase db, $CachedUnitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedUnitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedUnitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedUnitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> abbreviation = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedUnitsCompanion(
                id: id,
                code: code,
                name: name,
                abbreviation: abbreviation,
                sortOrder: sortOrder,
                isActive: isActive,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String code,
                required String name,
                required String abbreviation,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required DateTime lastSyncedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedUnitsCompanion.insert(
                id: id,
                code: code,
                name: name,
                abbreviation: abbreviation,
                sortOrder: sortOrder,
                isActive: isActive,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedUnitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedUnitsTable,
      CachedUnit,
      $$CachedUnitsTableFilterComposer,
      $$CachedUnitsTableOrderingComposer,
      $$CachedUnitsTableAnnotationComposer,
      $$CachedUnitsTableCreateCompanionBuilder,
      $$CachedUnitsTableUpdateCompanionBuilder,
      (
        CachedUnit,
        BaseReferences<_$AppDatabase, $CachedUnitsTable, CachedUnit>,
      ),
      CachedUnit,
      PrefetchHooks Function()
    >;
typedef $$LocalAuditLogTableCreateCompanionBuilder =
    LocalAuditLogCompanion Function({
      Value<int> id,
      required String actorUserId,
      required String action,
      Value<String?> resourceType,
      Value<String?> resourceId,
      Value<String?> detailsJson,
      required DateTime occurredAt,
      Value<String> syncStatus,
      Value<String?> syncError,
      Value<int> syncAttemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      required DateTime createdAt,
    });
typedef $$LocalAuditLogTableUpdateCompanionBuilder =
    LocalAuditLogCompanion Function({
      Value<int> id,
      Value<String> actorUserId,
      Value<String> action,
      Value<String?> resourceType,
      Value<String?> resourceId,
      Value<String?> detailsJson,
      Value<DateTime> occurredAt,
      Value<String> syncStatus,
      Value<String?> syncError,
      Value<int> syncAttemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      Value<DateTime> createdAt,
    });

class $$LocalAuditLogTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAuditLogTable> {
  $$LocalAuditLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceType => $composableBuilder(
    column: $table.resourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAuditLogTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAuditLogTable> {
  $$LocalAuditLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceType => $composableBuilder(
    column: $table.resourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAuditLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAuditLogTable> {
  $$LocalAuditLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get resourceType => $composableBuilder(
    column: $table.resourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<int> get syncAttemptCount => $composableBuilder(
    column: $table.syncAttemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalAuditLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalAuditLogTable,
          LocalAuditLogData,
          $$LocalAuditLogTableFilterComposer,
          $$LocalAuditLogTableOrderingComposer,
          $$LocalAuditLogTableAnnotationComposer,
          $$LocalAuditLogTableCreateCompanionBuilder,
          $$LocalAuditLogTableUpdateCompanionBuilder,
          (
            LocalAuditLogData,
            BaseReferences<
              _$AppDatabase,
              $LocalAuditLogTable,
              LocalAuditLogData
            >,
          ),
          LocalAuditLogData,
          PrefetchHooks Function()
        > {
  $$LocalAuditLogTableTableManager(_$AppDatabase db, $LocalAuditLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAuditLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAuditLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAuditLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> actorUserId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String?> resourceType = const Value.absent(),
                Value<String?> resourceId = const Value.absent(),
                Value<String?> detailsJson = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> syncAttemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LocalAuditLogCompanion(
                id: id,
                actorUserId: actorUserId,
                action: action,
                resourceType: resourceType,
                resourceId: resourceId,
                detailsJson: detailsJson,
                occurredAt: occurredAt,
                syncStatus: syncStatus,
                syncError: syncError,
                syncAttemptCount: syncAttemptCount,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String actorUserId,
                required String action,
                Value<String?> resourceType = const Value.absent(),
                Value<String?> resourceId = const Value.absent(),
                Value<String?> detailsJson = const Value.absent(),
                required DateTime occurredAt,
                Value<String> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> syncAttemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                required DateTime createdAt,
              }) => LocalAuditLogCompanion.insert(
                id: id,
                actorUserId: actorUserId,
                action: action,
                resourceType: resourceType,
                resourceId: resourceId,
                detailsJson: detailsJson,
                occurredAt: occurredAt,
                syncStatus: syncStatus,
                syncError: syncError,
                syncAttemptCount: syncAttemptCount,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAuditLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalAuditLogTable,
      LocalAuditLogData,
      $$LocalAuditLogTableFilterComposer,
      $$LocalAuditLogTableOrderingComposer,
      $$LocalAuditLogTableAnnotationComposer,
      $$LocalAuditLogTableCreateCompanionBuilder,
      $$LocalAuditLogTableUpdateCompanionBuilder,
      (
        LocalAuditLogData,
        BaseReferences<_$AppDatabase, $LocalAuditLogTable, LocalAuditLogData>,
      ),
      LocalAuditLogData,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      required String key,
      required DateTime syncedAt,
      Value<int> rowid,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<String> key,
      Value<DateTime> syncedAt,
      Value<int> rowid,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateData,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
          ),
          SyncStateData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(
                key: key,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required DateTime syncedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                key: key,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateData,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
      ),
      SyncStateData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalUserProfilesTableTableManager get localUserProfiles =>
      $$LocalUserProfilesTableTableManager(_db, _db.localUserProfiles);
  $$DeviceConfigTableTableManager get deviceConfig =>
      $$DeviceConfigTableTableManager(_db, _db.deviceConfig);
  $$PendingSalesTableTableManager get pendingSales =>
      $$PendingSalesTableTableManager(_db, _db.pendingSales);
  $$PendingSaleLineItemsTableTableManager get pendingSaleLineItems =>
      $$PendingSaleLineItemsTableTableManager(_db, _db.pendingSaleLineItems);
  $$CachedItemsTableTableManager get cachedItems =>
      $$CachedItemsTableTableManager(_db, _db.cachedItems);
  $$CachedPermissionsTableTableManager get cachedPermissions =>
      $$CachedPermissionsTableTableManager(_db, _db.cachedPermissions);
  $$CachedStockLevelsTableTableManager get cachedStockLevels =>
      $$CachedStockLevelsTableTableManager(_db, _db.cachedStockLevels);
  $$CachedBusinessRolesTableTableManager get cachedBusinessRoles =>
      $$CachedBusinessRolesTableTableManager(_db, _db.cachedBusinessRoles);
  $$CachedSalesTableTableManager get cachedSales =>
      $$CachedSalesTableTableManager(_db, _db.cachedSales);
  $$CachedSaleLineItemsTableTableManager get cachedSaleLineItems =>
      $$CachedSaleLineItemsTableTableManager(_db, _db.cachedSaleLineItems);
  $$PendingVoidsRefundsTableTableManager get pendingVoidsRefunds =>
      $$PendingVoidsRefundsTableTableManager(_db, _db.pendingVoidsRefunds);
  $$ExpenseEntriesTableTableManager get expenseEntries =>
      $$ExpenseEntriesTableTableManager(_db, _db.expenseEntries);
  $$OtherIncomeEntriesTableTableManager get otherIncomeEntries =>
      $$OtherIncomeEntriesTableTableManager(_db, _db.otherIncomeEntries);
  $$CachedOtherExpensesTableTableManager get cachedOtherExpenses =>
      $$CachedOtherExpensesTableTableManager(_db, _db.cachedOtherExpenses);
  $$CachedOtherIncomesTableTableManager get cachedOtherIncomes =>
      $$CachedOtherIncomesTableTableManager(_db, _db.cachedOtherIncomes);
  $$CustomerEntriesTableTableManager get customerEntries =>
      $$CustomerEntriesTableTableManager(_db, _db.customerEntries);
  $$CachedCustomersTableTableManager get cachedCustomers =>
      $$CachedCustomersTableTableManager(_db, _db.cachedCustomers);
  $$CachedSuppliersTableTableManager get cachedSuppliers =>
      $$CachedSuppliersTableTableManager(_db, _db.cachedSuppliers);
  $$CachedCategoriesTableTableManager get cachedCategories =>
      $$CachedCategoriesTableTableManager(_db, _db.cachedCategories);
  $$CachedUnitsTableTableManager get cachedUnits =>
      $$CachedUnitsTableTableManager(_db, _db.cachedUnits);
  $$LocalAuditLogTableTableManager get localAuditLog =>
      $$LocalAuditLogTableTableManager(_db, _db.localAuditLog);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
}
