import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../constants/app_limits.dart';
import '../../constants/app_strings.dart';
import '../../providers/session_provider.dart';
import '../../theme/breakpoints.dart';
import '../../utils/email_validation.dart';
import '../../utils/phone_validation.dart';
import '../../widgets/auth/auth_scaffold.dart';
import '../../widgets/labeled_form_field.dart';

abstract final class CompleteProfileKeys {
  static const fullName = Key('completeProfile.fullName');
  static const email = Key('completeProfile.email');
  static const phone = Key('completeProfile.phone');
  static const submit = Key('completeProfile.submit');
}

/// Collects the registrant's name (and optionally email) right after OTP
/// verification.
///
/// The phone-first (OTP-only) sign-in never asks for a name — a phone number
/// is all it needs to create the account — so this is the one place that
/// gap gets closed, before the business wizard starts putting that name on
/// receipts and staff lists.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _emailLooksValid =>
      _email.text.trim().isEmpty || isValidEmailFormat(_email.text);

  bool get _phoneLooksValid {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty || isValidTanzanianPhone(digits);
  }

  bool get _canSubmit =>
      _fullName.text.trim().isNotEmpty &&
      _emailLooksValid &&
      _phoneLooksValid &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final email = _email.text.trim();
      final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
      await ref.read(authProvider.notifier).completeProfile(
            fullName: _fullName.text.trim(),
            email: email.isEmpty ? null : email,
            phone: digits.isEmpty ? null : '+255$digits',
          );
      if (!mounted) return;
      context.go(ref.read(sessionProvider).entryRoute);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = AppStrings.saveDetailsFailed(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // An email-first signup already has its login address; asking for it
    // again would be redundant and risks changing the identifier mid-flow.
    // That flow instead gets the optional phone field.
    final isEmailSignup = ref.read(authProvider).email != null;
    final showEmail = !isEmailSignup;

    return AuthScaffold(
      title: AppStrings.tellUsWhoYouAre,
      subtitle: AppStrings.profileSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LabeledFormField(
            label: AppStrings.fullName,
            isRequired: true,
            child: TextField(
              key: CompleteProfileKeys.fullName,
              controller: _fullName,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: AppStrings.nameExample),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
          ),
          if (isEmailSignup) ...[
            const SizedBox(height: 16),
            LabeledFormField(
              label: AppStrings.phoneLabel,
              helper: AppStrings.profilePhoneHelper,
              child: TextField(
                key: CompleteProfileKeys.phone,
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(AppLimits.tzPhoneDigits),
                ],
                decoration: InputDecoration(
                  hintText: AppStrings.phoneExample,
                  errorText: _phoneLooksValid ? null : tanzanianPhoneHint,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(
                      left: Insets.lg,
                      right: Insets.sm,
                    ),
                    child: Text(
                      AppStrings.dialCode,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
          if (showEmail) ...[
            const SizedBox(height: 16),
            LabeledFormField(
              label: AppStrings.emailLabel,
              helper: AppStrings.emailHelper,
              child: TextField(
                key: CompleteProfileKeys.email,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: AppStrings.emailExample,
                  errorText:
                      _emailLooksValid ? null : AppStrings.invalidEmail,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            key: CompleteProfileKeys.submit,
            onPressed: _canSubmit ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppStrings.continueAction),
          ),
        ],
      ),
    );
  }
}
