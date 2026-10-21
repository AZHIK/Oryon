import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/identity_service_api.dart' show AuthException;
import '../../models/business_role.dart';
import '../../constants/app_strings.dart';
import '../../models/permission.dart';
import '../../providers/roles_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/labeled_form_field.dart';
import '../../widgets/responsive_form_dialog.dart';
import '../../widgets/section_label.dart';

/// Opens the role form. Pass [existingRole] to edit, omit it to create.
Future<void> showRoleFormDialog(
  BuildContext context, {
  BusinessRole? existingRole,
}) {
  return showResponsiveFormDialog<void>(
    context,
    builder: (_) => RoleFormDialog(roleId: existingRole?.id),
  );
}

class RoleFormDialog extends ConsumerStatefulWidget {
  const RoleFormDialog({super.key, this.roleId});

  /// Id of the role being edited, or null to create one.
  final String? roleId;

  /// Wider than any other dialog in the app, because this one has to fit a
  /// permission matrix. Two columns of toggles at 460px would be unreadable and
  /// one column would be a scroll of eighteen rows.
  static const double dialogWidth = 740;

  /// Below this the matrix drops to a single column. Two columns need roughly
  /// 300px each plus the gutter before a permission label starts wrapping.
  static const double _twoColumnMin = 640;

  @override
  ConsumerState<RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends ConsumerState<RoleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();

  /// The working copy. Edits are held here and only written to the provider on
  /// save, so cancelling a half-made change to a live role leaves every staff
  /// badge exactly as it was.
  late Set<String> _selected;

  /// Which groups are open. All of them on a wide screen, none on a phone —
  /// eighteen expanded toggles is not a form anyone can navigate on mobile.
  late Set<String> _expanded;

  BusinessRole? _existing;
  bool _seeded = false;
  bool _saving = false;
  String? _saveError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;

    final role = widget.roleId == null
        ? null
        : ref.read(roleByIdProvider(widget.roleId!));

    _existing = role;
    _name.text = role?.displayName ?? '';
    _description.text = role?.description ?? '';
    _selected = Set.of(role?.permissionIds ?? const <String>{});

    final isMobile = MediaQuery.sizeOf(context).width < Breakpoints.tablet;
    _expanded = isMobile
        ? <String>{}
        : {for (final group in AppPermissions.groups) group.id};
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _isEdit => _existing != null;

  /// A built-in role's identity is referenced by staff records and reporting,
  /// so its name and description are fixed — but what it *can do* is still the
  /// business's decision, so the matrix stays live.
  bool get _isProtected => _existing?.isProtected ?? false;

  bool get _canSave =>
      !_saving && _name.text.trim().isNotEmpty && _selected.isNotEmpty;

  void _toggle(String permissionId, bool on) {
    setState(() {
      on ? _selected.add(permissionId) : _selected.remove(permissionId);
    });
  }

  void _setGroup(PermissionGroup group, {required bool on}) {
    setState(() {
      on
          ? _selected.addAll(group.permissionIds)
          : _selected.removeAll(group.permissionIds);
    });
  }

  void _toggleExpanded(String groupId) {
    setState(() {
      _expanded.contains(groupId)
          ? _expanded.remove(groupId)
          : _expanded.add(groupId);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_canSave) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    final notifier = ref.read(rolesProvider.notifier);
    final existing = _existing;
    final name = _name.text.trim();

    try {
      if (existing == null) {
        await notifier.create(
          name: name,
          description: _description.text.trim(),
          permissionCodes: _selected,
        );
      } else {
        // A protected role keeps its stored name/description regardless of
        // what the (disabled) fields contain — only its permissions move.
        if (!_isProtected) {
          await notifier.updateRole(
            existing.id,
            name: name,
            description: _description.text.trim(),
          );
        }
        await notifier.syncPermissions(existing.id, _selected);
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.roleSaved(name, _isEdit))),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = AppStrings.roleSaveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ResponsiveFormDialog(
        title: _isEdit ? AppStrings.editRole : AppStrings.createRole,
        width: RoleFormDialog.dialogWidth,
        actions: [
          OutlinedButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isEdit ? AppStrings.saveRole : AppStrings.createRole,
                  ),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_saveError != null) ...[
              Container(
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: context.semantic.danger.withValues(alpha: 0.1),
                  borderRadius: Radii.card,
                  border: Border.all(color: context.semantic.danger.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _saveError!,
                  style: context.text.bodySmall?.copyWith(color: context.semantic.danger),
                ),
              ),
              const SizedBox(height: Insets.lg),
            ],
            SectionLabel(AppStrings.basicInfoSection),
            const SizedBox(height: Insets.md),

            if (_isProtected) ...[
              const _SystemRoleNotice(),
              const SizedBox(height: Insets.lg),
            ],

            LabeledFormField(
              label: AppStrings.roleNameLabel,
              isRequired: true,
              enabled: !_isProtected,
              child: TextFormField(
                controller: _name,
                enabled: !_isProtected,
                autofocus: !_isProtected,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: AppStrings.roleNameExample,
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? AppStrings.nameRequired
                    : null,
              ),
            ),
            const SizedBox(height: Insets.lg),

            LabeledFormField(
              label: AppStrings.descriptionLabel2,
              enabled: !_isProtected,
              helper: AppStrings.roleDescriptionHelper,
              child: TextFormField(
                controller: _description,
                enabled: !_isProtected,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: AppStrings.roleDescriptionExample,
                ),
              ),
            ),

            const SizedBox(height: Insets.xl),
            _PermissionsHeader(
              selectedCount: _selected.length,
              onSelectAll: () => setState(
                () => _selected = {for (final p in AppPermissions.all) p.id},
              ),
              onClearAll: () => setState(_selected.clear),
            ),
            const SizedBox(height: Insets.md),

            _PermissionMatrix(
              selected: _selected,
              expanded: _expanded,
              onToggle: _toggle,
              onToggleGroup: _setGroup,
              onToggleExpanded: _toggleExpanded,
            ),

            if (_selected.isEmpty) ...[
              const SizedBox(height: Insets.md),
              Text(
                AppStrings.pickPermissionWarning,
                style: context.text.bodySmall?.copyWith(
                  color: context.semantic.warning,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SystemRoleNotice extends StatelessWidget {
  const _SystemRoleNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: Radii.card,
        border: Border.all(color: context.semantic.hairline),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 17, color: colors.primary),
          const SizedBox(width: Insets.md - 2),
          Expanded(
            child: Text(
              AppStrings.builtinNameLocked,
              style: context.text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionsHeader extends StatelessWidget {
  const _PermissionsHeader({
    required this.selectedCount,
    required this.onSelectAll,
    required this.onClearAll,
  });

  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionLabel(AppStrings.permissionsSection),
            const SizedBox(height: 2),
            Text(
              AppStrings.permissionsSelected(
                selectedCount,
                AppPermissions.count,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        );

        final buttons = Wrap(
          spacing: Insets.xs,
          children: [
            TextButton(
              onPressed: onSelectAll,
              child: Text(AppStrings.selectAll),
            ),
            TextButton(
              onPressed: onClearAll,
              child: Text(AppStrings.clearAllFilters),
            ),
          ],
        );

        if (constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, buttons],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Expanded(child: label), buttons],
        );
      },
    );
  }
}

/// The permission groups, laid out in two columns where there is room.
///
/// Not a true masonry: the groups are dealt alternately into two columns, which
/// keeps related permissions together and costs nothing in layout passes. A
/// real masonry would balance the columns' heights better and be considerably
/// more machinery than five collapsible cards justify.
class _PermissionMatrix extends StatelessWidget {
  const _PermissionMatrix({
    required this.selected,
    required this.expanded,
    required this.onToggle,
    required this.onToggleGroup,
    required this.onToggleExpanded,
  });

  final Set<String> selected;
  final Set<String> expanded;
  final void Function(String permissionId, bool on) onToggle;
  final void Function(PermissionGroup group, {required bool on}) onToggleGroup;
  final ValueChanged<String> onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final groups = AppPermissions.groups;

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumn =
            constraints.maxWidth >= RoleFormDialog._twoColumnMin;

        if (!twoColumn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < groups.length; i++) ...[
                if (i > 0) const SizedBox(height: Insets.md),
                _buildGroup(groups[i]),
              ],
            ],
          );
        }

        final left = <PermissionGroup>[];
        final right = <PermissionGroup>[];
        for (var i = 0; i < groups.length; i++) {
          (i.isEven ? left : right).add(groups[i]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _columnOf(left)),
            const SizedBox(width: Insets.md),
            Expanded(child: _columnOf(right)),
          ],
        );
      },
    );
  }

  Widget _columnOf(List<PermissionGroup> groups) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < groups.length; i++) ...[
        if (i > 0) const SizedBox(height: Insets.md),
        _buildGroup(groups[i]),
      ],
    ],
  );

  Widget _buildGroup(PermissionGroup group) => _PermissionGroupCard(
    group: group,
    selected: selected,
    expanded: expanded.contains(group.id),
    onToggle: onToggle,
    onToggleGroup: onToggleGroup,
    onToggleExpanded: () => onToggleExpanded(group.id),
  );
}

class _PermissionGroupCard extends StatelessWidget {
  const _PermissionGroupCard({
    required this.group,
    required this.selected,
    required this.expanded,
    required this.onToggle,
    required this.onToggleGroup,
    required this.onToggleExpanded,
  });

  final PermissionGroup group;
  final Set<String> selected;
  final bool expanded;
  final void Function(String permissionId, bool on) onToggle;
  final void Function(PermissionGroup group, {required bool on}) onToggleGroup;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ids = group.permissionIds;
    final on = ids.where(selected.contains).length;
    final all = on == ids.length;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: Radii.card,
        border: Border.all(
          color: on > 0
              ? colors.primary.withValues(alpha: 0.35)
              : context.semantic.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.md,
                Insets.sm,
                Insets.md,
              ),
              child: Row(
                children: [
                  Icon(group.icon, size: 18, color: colors.primary),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          group.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall,
                        ),
                        Text(
                          AppStrings.groupSelected(on, ids.length),
                          maxLines: 1,
                          style: context.text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Per-group bulk action, labelled by what it will do next
                  // rather than by the group's current state.
                  TextButton(
                    onPressed: () => onToggleGroup(group, on: !all),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                      ),
                      minimumSize: const Size(0, 36),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(all ? AppStrings.clear : AppStrings.allGroup),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            for (final permission in group.permissions)
              _PermissionRow(
                permission: permission,
                value: selected.contains(permission.id),
                onChanged: (on) => onToggle(permission.id, on),
              ),
          ],
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.permission,
    required this.value,
    required this.onChanged,
  });

  final Permission permission;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.sm,
          Insets.md,
          Insets.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A checkbox rather than a switch: a matrix of eighteen switches
            // reads as eighteen separate settings, where checkboxes read as one
            // list being ticked off.
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    permission.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  Text(
                    permission.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
