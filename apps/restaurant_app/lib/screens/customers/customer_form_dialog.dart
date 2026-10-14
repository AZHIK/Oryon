import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/customer.dart';
import '../../constants/app_strings.dart';
import '../../providers/customers_provider.dart';
import '../../theme/breakpoints.dart';
import '../../utils/phone_validation.dart';
import '../../widgets/labeled_form_field.dart';
import '../../widgets/responsive_form_dialog.dart';
import '../../widgets/section_label.dart';

/// Opens the add/edit customer form dialog. Returns the saved customer, or
/// null if the dialog was dismissed without saving — the POS checkout
/// picker uses the returned customer to immediately select whoever was
/// just added.
Future<Customer?> showCustomerFormDialog(
  BuildContext context, {
  Customer? existingCustomer,
}) {
  return showResponsiveFormDialog<Customer>(
    context,
    builder: (_) => _CustomerFormDialog(customer: existingCustomer),
  );
}

class _CustomerFormDialog extends ConsumerStatefulWidget {
  const _CustomerFormDialog({this.customer});

  final Customer? customer;

  @override
  ConsumerState<_CustomerFormDialog> createState() =>
      _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.customer?.name ?? '');
    _phone = TextEditingController(text: widget.customer?.phone ?? '');
    _email = TextEditingController(text: widget.customer?.email ?? '');
    _address = TextEditingController(text: widget.customer?.addressLine1 ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isEdit = widget.customer != null;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim().isEmpty ? null : _email.text.trim();
    final address = _address.text.trim().isEmpty ? null : _address.text.trim();

    try {
      final Customer saved;
      final notifier = ref.read(customersProvider.notifier);
      if (isEdit) {
        saved = await notifier.edit(
          widget.customer!,
          name: name,
          phone: phone,
          email: email,
          addressLine1: address,
        );
      } else {
        saved = await notifier.create(
          name: name,
          phone: phone,
          email: email,
          addressLine1: address,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(saved);
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppStrings.customerSaved(saved.name, isEdit)),
        ),
      );
    } on CustomerOfflineMutationException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(AppStrings.saveFailed(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ResponsiveFormDialog(
        title: isEdit ? AppStrings.editCustomer : AppStrings.addCustomerTitle,
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
                    isEdit ? AppStrings.saveChanges : AppStrings.addCustomerTitle,
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
                  hintText: AppStrings.phoneExample,
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return AppStrings.enterPhoneError;
                  if (!isValidTanzanianPhoneInput(text)) {
                    return tanzanianPhoneHint;
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: Insets.lg),
            LabeledFormField(
              label: AppStrings.emailLabel,
              child: TextFormField(
                controller: _email,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: AppStrings.emailExample2,
                ),
              ),
            ),
            const SizedBox(height: Insets.lg),
            LabeledFormField(
              label: AppStrings.addressLabel,
              child: TextFormField(
                controller: _address,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: AppStrings.addressExample2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
