import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_strings.dart';
import '../../models/courier.dart';
import '../../providers/couriers_provider.dart';
import '../../services/courier_api_service.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/labeled_form_field.dart';
import '../../widgets/responsive_form_dialog.dart';
import '../../widgets/section_label.dart';

/// Opens the add/edit courier form dialog. Returns the saved courier, or
/// null if dismissed — mirrors `showCustomerFormDialog`.
Future<Courier?> showCourierFormDialog(
  BuildContext context, {
  Courier? existingCourier,
}) {
  return showResponsiveFormDialog<Courier>(
    context,
    builder: (_) => _CourierFormDialog(courier: existingCourier),
  );
}

class _CourierFormDialog extends ConsumerStatefulWidget {
  const _CourierFormDialog({this.courier});

  final Courier? courier;

  @override
  ConsumerState<_CourierFormDialog> createState() => _CourierFormDialogState();
}

class _CourierFormDialogState extends ConsumerState<_CourierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _vehicle;
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.courier?.name ?? '');
    _phone = TextEditingController(text: widget.courier?.phone ?? '');
    _vehicle = TextEditingController(text: widget.courier?.vehicle ?? '');
    _isActive = widget.courier?.status == CourierStatus.inactive
        ? false
        : true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _vehicle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isEdit = widget.courier != null;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final vehicle = _vehicle.text.trim().isEmpty ? null : _vehicle.text.trim();

    try {
      final Courier saved;
      final notifier = ref.read(couriersProvider.notifier);
      if (isEdit) {
        saved = await notifier.edit(
          widget.courier!,
          name: name,
          phone: phone,
          vehicle: vehicle,
          isActive: _isActive,
        );
      } else {
        saved = await notifier.create(
          name: name,
          phone: phone,
          vehicle: vehicle,
          isActive: _isActive,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(saved);
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.courierSaved(saved.name, isEdit))),
      );
    } on CourierApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.saveFailed(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.courier != null;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ResponsiveFormDialog(
        title: isEdit ? AppStrings.editCourier : AppStrings.addCourierTitle,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isEdit ? AppStrings.saveChanges : AppStrings.addCourierTitle,
                  ),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(AppStrings.contactInfo),
            const SizedBox(height: Insets.md),
            LabeledFormField(
              label: AppStrings.nameColumn,
              isRequired: true,
              child: TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: AppStrings.fullNameHint,
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? AppStrings.enterNameError
                    : null,
              ),
            ),
            const SizedBox(height: Insets.lg),
            LabeledFormField(
              label: AppStrings.phoneLabel,
              isRequired: true,
              child: TextFormField(
                controller: _phone,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: AppStrings.phoneExample2,
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? AppStrings.enterPhoneError
                    : null,
              ),
            ),
            const SizedBox(height: Insets.lg),
            LabeledFormField(
              label: AppStrings.vehicleLabel,
              helper: AppStrings.vehicleHint,
              child: TextFormField(
                controller: _vehicle,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(),
              ),
            ),
            const SizedBox(height: Insets.lg),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppStrings.availableLabel),
              subtitle: Text(AppStrings.availableHelper),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
          ],
        ),
      ),
    );
  }
}
