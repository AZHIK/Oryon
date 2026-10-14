import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/supplier.dart';
import '../../constants/app_strings.dart';
import '../../providers/suppliers_provider.dart';
import '../../theme/breakpoints.dart';
import '../../utils/phone_validation.dart';
import '../labeled_form_field.dart';
import '../responsive_form_dialog.dart';
import '../section_label.dart';

/// Opens the add/edit supplier form dialog. Returns the saved supplier, or
/// null if the dialog was dismissed without saving — supplier pickers use
/// the returned supplier to immediately select whoever was just added,
/// mirroring `showCustomerFormDialog`.
Future<Supplier?> showSupplierFormDialog(
  BuildContext context, {
  Supplier? existingSupplier,
}) {
  return showResponsiveFormDialog<Supplier>(
    context,
    builder: (_) => _SupplierFormDialog(supplier: existingSupplier),
  );
}

class _SupplierFormDialog extends ConsumerStatefulWidget {
  const _SupplierFormDialog({this.supplier});

  final Supplier? supplier;

  @override
  ConsumerState<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<_SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.supplier?.name ?? '');
    _phone = TextEditingController(text: widget.supplier?.phone ?? '');
    _email = TextEditingController(text: widget.supplier?.email ?? '');
    _address = TextEditingController(text: widget.supplier?.addressLine1 ?? '');
    _notes = TextEditingController(text: widget.supplier?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isEdit = widget.supplier != null;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    final name = _name.text.trim();
    final phone = _phone.text.trim().isEmpty ? null : _phone.text.trim();
    final email = _email.text.trim().isEmpty ? null : _email.text.trim();
    final address = _address.text.trim().isEmpty ? null : _address.text.trim();
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();

    try {
      final Supplier saved;
      final notifier = ref.read(suppliersProvider.notifier);
      if (isEdit) {
        saved = await notifier.edit(
          widget.supplier!,
          name: name,
          phone: phone,
          email: email,
          addressLine1: address,
          notes: notes,
        );
      } else {
        saved = await notifier.create(
          name: name,
          phone: phone,
          email: email,
          addressLine1: address,
          notes: notes,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(saved);
      messenger.showSnackBar(
        SnackBar(content: Text(isEdit ? '${saved.name} updated' : '${saved.name} added')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(AppStrings.saveFailed(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.supplier != null;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ResponsiveFormDialog(
        title: isEdit ? 'Edit supplier' : 'Add supplier',
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isEdit ? 'Save changes' : 'Add supplier'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Supplier info'),
            const SizedBox(height: Insets.md),
            LabeledFormField(
              label: 'Name',
              isRequired: true,
              child: TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Supplier or company name'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a name' : null,
              ),
            ),
            const SizedBox(height: Insets.lg),
            LabeledFormField(
              label: 'Phone',
              child: TextFormField(
                controller: _phone,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '6XXXXXXXX or 7XXXXXXXX'),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  if (!isValidTanzanianPhoneInput(text)) {
                    return tanzanianPhoneHint;
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: Insets.lg),
            LabeledFormField(
              label: 'Email',
              child: TextFormField(
                controller: _email,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'orders@supplier.com'),
              ),
            ),
            const SizedBox(height: Insets.lg),
            LabeledFormField(
              label: 'Address',
              child: TextFormField(
                controller: _address,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Street address (optional)'),
              ),
            ),
            const SizedBox(height: Insets.lg),
            LabeledFormField(
              label: 'Notes',
              child: TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Delivery notes, account number...'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
