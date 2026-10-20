import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/identity_service_api.dart' show AuthException;
import '../../constants/app_limits.dart';
import '../../constants/app_strings.dart';
import '../../models/business_role.dart';
import '../../models/permission.dart';
import '../../models/staff_member.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/roles_provider.dart';
import '../../providers/staff_provider.dart';
import '../../providers/store_api_provider_real.dart';
import '../../providers/store_locations_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/email_validation.dart';
import '../../utils/phone_validation.dart';
import '../../widgets/labeled_form_field.dart';
import '../../widgets/responsive_form_dialog.dart';
import '../../widgets/section_label.dart';
import '../../widgets/selectable_option_card.dart';
import '../../widgets/staff/role_badge.dart';

/// Business-wide vs single-store assignment for a new invite.
enum StaffScope { business, store }

/// Which contact detail identifies the invitee. The backend accepts either
/// and treats them identically: look the person up, otherwise create a
/// pending account they can later sign in to with an OTP.
enum InviteChannel { phone, email }

/// Opens the invite form.
Future<void> showInviteStaffDialog(BuildContext context) {
  return showResponsiveFormDialog<void>(
    context,
    builder: (_) => const InviteStaffDialog(),
  );
}

/// Opens a small dialog for granting one member an additional role.
///
/// Shares the role picker and its permission preview with the invite form, so
/// the two never describe the same role differently. There is no "change"
/// here — the backend allows a staff member to hold more than one role
/// simultaneously and has no replace/revoke-in-one-call endpoint, so this
/// only ever adds; removing a role no longer wanted is a separate action
/// from the staff list ("Remove from team" revokes a specific role).
Future<void> showAddRoleDialog(BuildContext context, StaffMember member) {
  return showResponsiveFormDialog<void>(
    context,
    builder: (_) => AddRoleDialog(member: member),
  );
}

class InviteStaffDialog extends ConsumerStatefulWidget {
  const InviteStaffDialog({super.key});

  @override
  ConsumerState<InviteStaffDialog> createState() => _InviteStaffDialogState();
}

class _InviteStaffDialogState extends ConsumerState<InviteStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  String? _roleId;
  StaffScope _scope = StaffScope.business;
  InviteChannel _channel = InviteChannel.phone;
  String? _storeId;
  bool _seededStore = false;
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _contactValid => _channel == InviteChannel.phone
      ? isValidTanzanianPhone(_phone.text)
      : isValidEmailFormat(_email.text);

  bool get _canSubmit =>
      !_submitting &&
      validateName(_name.text) == null &&
      _contactValid &&
      _roleId != null &&
      (_scope == StaffScope.business || _storeId != null);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_canSubmit) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final storeId = _scope == StaffScope.store ? _storeId : null;
      final isPhone = _channel == InviteChannel.phone;
      await ref.read(staffMembersProvider.notifier).assignRole(
            phone: isPhone ? '+255${_phone.text.trim()}' : null,
            email: isPhone ? null : _email.text.trim(),
            fullName: _name.text.trim(),
            roleId: _roleId!,
            storeId: storeId,
          );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      final storeName = storeId == null
          ? null
          : ref
                .read(storeLocationsProvider)
                .where((s) => s.id == storeId)
                .firstOrNull
                ?.name;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            storeName == null
                ? AppStrings.inviteSentTo(_name.text.trim())
                : AppStrings.inviteSentToStore(_name.text.trim(), storeName),
          ),
        ),
      );
    } on AuthException catch (e) {
      // Surfaces the backend's own message verbatim (e.g. its real 409
      // "already has this role assignment" text) rather than invented copy.
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.statusCode == null
            ? AppStrings.staffNeedsInternet
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = AppStrings.inviteFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(rolesProvider).valueOrNull ?? const <BusinessRole>[];
    final stores = ref.watch(storeLocationsProvider);
    // Loading vs loaded-empty: an empty menu with no explanation looks
    // broken, so the helper says which of the two it is.
    final storesLoading = ref.watch(storesProvider).isLoading;
    // Default to the terminal's own store, falling back to the first loaded
    // one. Seeds only once real data exists — an empty first build (stores
    // still syncing) must not lock in a null default. The cashier's explicit
    // pick always wins after that.
    if (!_seededStore) {
      final current = ref.read(currentStoreIdProvider);
      if (current != null || stores.isNotEmpty) {
        _seededStore = true;
        _storeId = current ?? stores.first.id;
      }
    }

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ResponsiveFormDialog(
        title: AppStrings.inviteStaffTitle,
        width: 520,
        actions: [
          OutlinedButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppStrings.sendInvite),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_submitError != null) ...[
              Container(
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: context.semantic.danger.withValues(alpha: 0.1),
                  borderRadius: Radii.card,
                  border: Border.all(color: context.semantic.danger.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _submitError!,
                  style: context.text.bodySmall?.copyWith(color: context.semantic.danger),
                ),
              ),
              const SizedBox(height: Insets.lg),
            ],
            LabeledFormField(
              label: AppStrings.fullNameLabel,
              isRequired: true,
              child: TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration:
                    InputDecoration(hintText: AppStrings.teammateExample),
                onChanged: (_) => setState(() {}),
                validator: validateName,
              ),
            ),
            const SizedBox(height: Insets.lg),

            SectionLabel(AppStrings.inviteChannelLabel),
            const SizedBox(height: Insets.xs),
            Text(
              AppStrings.inviteChannelHelper,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.sm),
            SelectableOptionGrid(
              perRow: 2,
              children: [
                SelectableOptionCard(
                  label: AppStrings.phoneLabel,
                  subtitle: AppStrings.invitePhoneOptionHelper,
                  icon: Icons.phone_outlined,
                  selected: _channel == InviteChannel.phone,
                  onTap: () => setState(() => _channel = InviteChannel.phone),
                ),
                SelectableOptionCard(
                  label: AppStrings.emailLabel,
                  subtitle: AppStrings.inviteEmailOptionHelper,
                  icon: Icons.mail_outline,
                  selected: _channel == InviteChannel.email,
                  onTap: () => setState(() => _channel = InviteChannel.email),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),

            if (_channel == InviteChannel.phone)
              LabeledFormField(
                label: AppStrings.phoneLabel,
                isRequired: true,
                helper: AppStrings.invitePhoneHelper,
                child: TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(AppLimits.tzPhoneDigits),
                  ],
                  decoration: InputDecoration(
                    hintText: AppStrings.phoneExample,
                    errorText: _phone.text.isEmpty || isValidTanzanianPhone(_phone.text)
                        ? null
                        : tanzanianPhoneHint,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: Insets.lg, right: Insets.sm),
                      child: Text(
                        AppStrings.dialCode,
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              )
            else
              LabeledFormField(
                label: AppStrings.emailLabel,
                isRequired: true,
                helper: AppStrings.inviteEmailHelper,
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    hintText: AppStrings.emailExample,
                    errorText:
                        _email.text.isEmpty || isValidEmailFormat(_email.text)
                        ? null
                        : AppStrings.invalidEmail,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) =>
                      isValidEmailFormat(value ?? '') ? null : AppStrings.invalidEmail,
                ),
              ),
            const SizedBox(height: Insets.lg),

            SectionLabel(AppStrings.staffTypeLabel),
            const SizedBox(height: Insets.xs),
            Text(
              AppStrings.staffTypeHelper,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.sm),
            SelectableOptionGrid(
              perRow: 2,
              children: [
                SelectableOptionCard(
                  label: AppStrings.businessStaffOption,
                  subtitle: AppStrings.businessStaffHelper,
                  icon: Icons.business_outlined,
                  selected: _scope == StaffScope.business,
                  onTap: () => setState(() => _scope = StaffScope.business),
                ),
                SelectableOptionCard(
                  label: AppStrings.storeStaffOption,
                  subtitle: AppStrings.storeStaffHelper,
                  icon: Icons.storefront_outlined,
                  selected: _scope == StaffScope.store,
                  onTap: () => setState(() => _scope = StaffScope.store),
                ),
              ],
            ),
            if (_scope == StaffScope.store) ...[
              const SizedBox(height: Insets.lg),
              LabeledFormField(
                label: AppStrings.inviteStoreLabel,
                isRequired: true,
                helper: stores.isEmpty
                    ? (storesLoading
                          ? AppStrings.inviteStoresSyncing
                          : AppStrings.inviteStoresEmpty)
                    : null,
                child: DropdownButtonFormField<String>(
                  initialValue: _storeId,
                  isExpanded: true,
                  hint: Text(AppStrings.selectStoreHint),
                  items: [
                    for (final store in stores)
                      DropdownMenuItem(
                        value: store.id,
                        child: Text(
                          store.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _storeId = value),
                  validator: (value) =>
                      value == null ? AppStrings.inviteStoreRequired : null,
                ),
              ),
            ],
            const SizedBox(height: Insets.lg),

            RolePickerField(
              roles: roles,
              value: _roleId,
              onChanged: (value) => setState(() => _roleId = value),
            ),
          ],
        ),
      ),
    );
  }
}

class AddRoleDialog extends ConsumerStatefulWidget {
  const AddRoleDialog({super.key, required this.member});

  final StaffMember member;

  @override
  ConsumerState<AddRoleDialog> createState() => _AddRoleDialogState();
}

class _AddRoleDialogState extends ConsumerState<AddRoleDialog> {
  String? _roleId;
  bool _submitting = false;
  String? _submitError;

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(rolesProvider).valueOrNull ?? const <BusinessRole>[];
    // Only business-held roles excluded: a store-held role is a different
    // backend triple (user, store, role), so granting it business-wide is
    // still a legal, distinct assignment.
    final heldRoleIds = {
      for (final r in widget.member.roles)
        if (!r.isStoreScoped) r.roleId,
    };
    final available = [
      for (final role in roles)
        if (!heldRoleIds.contains(role.id)) role,
    ];

    return ResponsiveFormDialog(
      title: AppStrings.addRoleTitle,
      width: 480,
      actions: [
        OutlinedButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: _roleId != null && !_submitting ? _submit : null,
          child: _submitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppStrings.addRoleButton),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.member.name,
            style: context.text.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.member.roles.isNotEmpty) ...[
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final r in widget.member.roles)
                  RoleBadge(role: roles.where((role) => role.id == r.roleId).firstOrNull, dense: true),
              ],
            ),
          ],
          const SizedBox(height: Insets.xl),
          if (_submitError != null) ...[
            Text(
              _submitError!,
              style: context.text.bodySmall?.copyWith(color: context.semantic.danger),
            ),
            const SizedBox(height: Insets.md),
          ],
          if (available.isEmpty)
            Text(
              AppStrings.holdsAllRoles,
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            )
          else
            RolePickerField(
              roles: available,
              value: _roleId,
              onChanged: (value) => setState(() => _roleId = value),
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final roleId = _roleId;
    if (roleId == null) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      await ref.read(staffMembersProvider.notifier).assignRole(
            phone: widget.member.phone.isNotEmpty ? widget.member.phone : null,
            email: widget.member.phone.isEmpty && widget.member.email.isNotEmpty
                ? widget.member.email
                : null,
            roleId: roleId,
          );

      if (!mounted) return;
      final roleName =
          ref.read(roleByIdProvider(roleId))?.name ??
          AppStrings.roleFallbackName;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.memberHasRole(widget.member.name, roleName),
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.statusCode == null
            ? AppStrings.staffNeedsInternet
            : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = AppStrings.addRoleFailed;
      });
    }
  }
}

/// A role dropdown with a live preview of what that role can do.
///
/// The preview reads the same [rolesProvider] the Role Form writes to, so a
/// permission granted there shows up here without either screen knowing about
/// the other.
class RolePickerField extends StatelessWidget {
  const RolePickerField({
    super.key,
    required this.roles,
    required this.value,
    required this.onChanged,
  });

  final List<BusinessRole> roles;
  final String? value;
  final ValueChanged<String?> onChanged;

  /// How many permissions to name before summarising the rest. Three is enough
  /// to characterise a role without turning the dialog into a permission
  /// matrix of its own.
  static const int _previewCount = AppLimits.rolePreviewCount;

  @override
  Widget build(BuildContext context) {
    final selected = roles.where((role) => role.id == value).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LabeledFormField(
          label: AppStrings.roleLabel2,
          isRequired: true,
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            hint: Text(AppStrings.selectRoleHint),
            items: [
              for (final role in roles)
                DropdownMenuItem(
                  value: role.id,
                  child: Text(
                    role.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onChanged,
            validator: (v) => v == null ? AppStrings.pickRole : null,
          ),
        ),
        if (selected != null) ...[
          const SizedBox(height: Insets.md),
          _RolePreview(role: selected),
        ],
      ],
    );
  }
}

class _RolePreview extends StatelessWidget {
  const _RolePreview({required this.role});

  final BusinessRole role;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final granted = AppPermissions.resolve(role.permissionIds);
    final shown = granted.take(RolePickerField._previewCount).toList();
    final extra = granted.length - shown.length;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: Radii.card,
        border: Border.all(color: context.semantic.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              RoleBadge(role: role, dense: true),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  role.permissionSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            role.description,
            style: context.text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (granted.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Insets.sm),
              child: Text(
                AppStrings.roleWithoutPermissions,
                style: context.text.bodySmall?.copyWith(
                  color: context.semantic.warning,
                ),
              ),
            )
          else ...[
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.xs + 2,
              runSpacing: Insets.xs + 2,
              children: [
                for (final id in shown)
                  _PermissionChip(label: AppPermissions.labelFor(id)),
                if (extra > 0) _PermissionChip(label: AppStrings.extraRoles(extra)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: context.semantic.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 12, color: colors.primary),
          const SizedBox(width: Insets.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Validation
//
// Static and pure so the field validators and the Send button's enabled state
// answer the same question — the pattern the item form established.
// ---------------------------------------------------------------------------

String? validateName(String? value) =>
    (value ?? '').trim().isEmpty ? AppStrings.enterFullName : null;
