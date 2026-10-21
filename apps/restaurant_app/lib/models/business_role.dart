import 'package:flutter/material.dart';

import '../utils/role_name.dart';
import 'permission.dart';

/// A named set of permissions that staff are assigned to.
@immutable
class BusinessRole {
  const BusinessRole({
    required this.id,
    required this.name,
    required this.description,
    this.permissionIds = const {},
    this.isProtected = false,
  });

  final String id;
  final String name;
  final String description;

  /// The name as it should be read on screen. Backend role names are
  /// snake_case identifiers, so every UI surface uses this rather than [name].
  String get displayName => humanizeRoleName(name);

  /// Ids from [AppPermissions]. A set because order carries no meaning and
  /// membership is the only question ever asked of it.
  ///
  /// The backend returns roles and their permissions from two separate
  /// endpoints — this is populated by the roles provider after joining
  /// them, not embedded in the role-list response itself. Defaults to
  /// empty rather than requiring it up front so a freshly-listed role
  /// (permissions not yet fetched) can still exist as a value.
  final Set<String> permissionIds;

  /// Protected roles (the seeded Owner role) ship with the business. They
  /// can never be renamed, redescribed, or deleted — staff and reporting
  /// both reference them by name. Driven by the backend's real
  /// `is_protected` field, not a hardcoded assumption.
  final bool isProtected;

  /// Resolved against the catalogue, so a retired permission id left over in
  /// the data never inflates the count shown in the table.
  int get permissionCount => AppPermissions.resolve(permissionIds).length;

  bool has(String permissionId) => permissionIds.contains(permissionId);

  /// Whether this role works a till. Drives the performance block on a staff
  /// member's detail screen — a stock controller has no orders to summarise.
  bool get hasPosAccess => has(AppPermissions.posAccess);

  /// "12 of 18 permissions", the table's at-a-glance summary.
  String get permissionSummary =>
      '$permissionCount of ${AppPermissions.count} permissions';

  BusinessRole copyWith({
    String? name,
    String? description,
    Set<String>? permissionIds,
  }) {
    return BusinessRole(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      permissionIds: permissionIds ?? this.permissionIds,
      isProtected: isProtected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BusinessRole && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
