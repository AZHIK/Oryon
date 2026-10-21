import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../utils/role_name.dart';
import '../widgets/data_page/status_badge.dart';

/// Where a staff account stands.
enum StaffStatus {
  active('activeStatus', 'Active'),
  inactive('inactiveStatus', 'Inactive'),
  pendingInvite('pendingInviteStatus', 'Pending invite');

  const StaffStatus(this.labelKey, this.labelDefault);
  final String labelKey;
  final String labelDefault;

  String get label => L10n.t(labelKey, labelDefault);

  StatusTone get tone => switch (this) {
    StaffStatus.active => StatusTone.positive,
    StaffStatus.inactive => StatusTone.neutral,
    StaffStatus.pendingInvite => StatusTone.warning,
  };

  IconData get badgeIcon => switch (this) {
    StaffStatus.active => Icons.check_circle_rounded,
    StaffStatus.inactive => Icons.pause_circle_outline_rounded,
    StaffStatus.pendingInvite => Icons.mark_email_unread_outlined,
  };
}

/// One role a staff member holds at the business, embedded on [StaffMember].
///
/// The backend allows a staff member to hold more than one role
/// simultaneously (confirmed: `POST .../staff` has no single-role
/// replace/duplicate-block beyond the exact same role twice) — this list
/// reflects that directly rather than assuming one role per person.
@immutable
class StaffRoleAssignment {
  const StaffRoleAssignment({
    required this.roleId,
    required this.roleName,
    this.storeId,
    this.storeName,
  });

  /// References [BusinessRole.id].
  final String roleId;

  /// Denormalized so the staff list can render a role name without a join
  /// against the roles provider — matches what the backend's staff-list
  /// response already returns inline.
  final String roleName;

  /// Set for store-scoped assignments: which location this role applies to.
  /// Null means business-wide.
  final String? storeId;
  final String? storeName;

  /// True for a role pinned to one location rather than the whole business.
  bool get isStoreScoped => storeId != null;

  /// The role name as people read it, without backend underscores.
  String get displayName => humanizeRoleName(roleName);

  /// "Cashier · Branch Two" for store roles, plain "Cashier" otherwise — the
  /// form every list, badge and export uses so scope never silently drops.
  String get label => storeName == null || storeName!.isEmpty
      ? displayName
      : '$displayName · $storeName';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StaffRoleAssignment &&
          other.roleId == roleId &&
          other.storeId == storeId);

  @override
  int get hashCode => Object.hash(roleId, storeId);
}

/// A person with access to the business.
@immutable
class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    required this.status,
    required this.joinedAt,
    this.phone = '',
    this.lastActiveAt,
    this.inviteNote,
  });

  final String id;
  final String name;
  final String email;
  final String phone;

  /// Every role this person currently holds at the business — a staff
  /// member can hold more than one simultaneously.
  final List<StaffRoleAssignment> roles;

  /// The role shown wherever the UI only has room for one (avatar row,
  /// filter chips). The first assignment, or null for someone with none.
  StaffRoleAssignment? get primaryRole => roles.isEmpty ? null : roles.first;

  /// Kept for call sites that only ever cared about a single role id
  /// (filtering, display) — resolves to [primaryRole], or `''` for none.
  String get roleId => primaryRole?.roleId ?? '';

  final StaffStatus status;

  /// When they joined, or when the invite was sent for a pending member.
  final DateTime joinedAt;

  /// Null for a member who has never signed in — a pending invite.
  final DateTime? lastActiveAt;

  /// Personal message sent with the invite. Kept so a pending member's detail
  /// screen can show what they were told.
  final String? inviteNote;

  bool get isPending => status == StaffStatus.pendingInvite;

  /// Up to two letters for the avatar circle. Falls back to "?" rather than
  /// throwing on a name that is somehow empty.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final only = parts.first;
      return (only.length <= 2 ? only : only.substring(0, 2)).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  StaffMember copyWith({
    String? name,
    String? email,
    String? phone,
    List<StaffRoleAssignment>? roles,
    StaffStatus? status,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    String? inviteNote,
  }) {
    return StaffMember(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      roles: roles ?? this.roles,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      inviteNote: inviteNote ?? this.inviteNote,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is StaffMember && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
