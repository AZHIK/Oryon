import 'package:flutter/material.dart';

import '../../models/business_role.dart';
import '../../constants/app_strings.dart';
import '../../theme/app_theme.dart';
import '../../theme/role_badge_colors.dart';
import '../data_page/status_badge.dart';

/// A role rendered as a coloured pill.
///
/// Roles are not statuses — "Cashier" is not better or worse than "Manager", so
/// the semantic tones do not apply. Instead each role gets a stable colour from
/// a fixed palette, fed to [StatusBadge] through its colour override so the
/// pill shape, spacing and icon pairing stay identical to every other badge in
/// the app.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, this.dense = false, this.scopeLabel});

  final BusinessRole? role;
  final bool dense;

  /// Store scope for store-held roles ("Branch Two" renders
  /// "Cashier · Branch Two"). Null for business-wide roles.
  final String? scopeLabel;

  @override
  Widget build(BuildContext context) {
    final role = this.role;

    // A member whose role was deleted still has to render as something.
    if (role == null) {
      return StatusBadge(
        label: AppStrings.noRole,
        tone: StatusTone.neutral,
        icon: Icons.help_outline_rounded,
        dense: dense,
      );
    }

    final scope = scopeLabel?.trim();
    return StatusBadge(
      label: scope == null || scope.isEmpty
          ? role.displayName
          : '${role.displayName} · $scope',
      tone: StatusTone.neutral,
      color: roleColor(context, role),
      icon: roleIcon(role),
      dense: dense,
    );
  }

  /// System roles get fixed slots so Owner is always the same colour across
  /// every install; custom roles hash into the remainder of the palette.
  /// The palette itself lives in the theme ([RoleBadgeColors]) — this only
  /// decides the slot.
  static Color roleColor(BuildContext context, BusinessRole role) {
    final palette = context.roleBadges.palette;

    final index = switch (role.id) {
      'role-owner' => 0,
      'role-manager' => 1,
      'role-cashier' => 2,
      _ => 3 + (role.id.hashCode & 0x7fffffff) % (palette.length - 3),
    };

    return palette[index];
  }

  static IconData roleIcon(BusinessRole role) => switch (role.id) {
    'role-owner' => Icons.workspace_premium_outlined,
    'role-manager' => Icons.badge_outlined,
    'role-cashier' => Icons.point_of_sale_outlined,
    _ => role.isProtected
        ? Icons.badge_outlined
        : Icons.person_outline_rounded,
  };
}

/// The circular initials avatar used wherever a staff member is listed.
///
/// Tinted by the member's role, so the table reads as grouped by role even
/// before the badges are scanned.
class StaffAvatar extends StatelessWidget {
  const StaffAvatar({
    super.key,
    required this.initials,
    this.role,
    this.size = 36,
  });

  final String initials;
  final BusinessRole? role;
  final double size;

  @override
  Widget build(BuildContext context) {
    final role = this.role;
    final accent = role == null
        ? context.colors.onSurfaceVariant
        : RoleBadge.roleColor(context, role);

    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        initials,
        maxLines: 1,
        style: context.text.labelLarge?.copyWith(
          color: accent,
          // Scales with the circle so the same widget serves a 36px table cell
          // and a 56px detail header.
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
