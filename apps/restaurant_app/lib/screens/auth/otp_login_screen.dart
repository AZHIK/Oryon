import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_durations.dart';
import '../../constants/app_limits.dart';
import '../../constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/email_validation.dart';
import '../../utils/phone_validation.dart';
import '../../widgets/auth/auth_scaffold.dart';
import '../../widgets/auth/otp_input.dart';
import '../../widgets/labeled_form_field.dart';

abstract final class OtpLoginKeys {
  static const phone = Key('otpLogin.phone');
  static const email = Key('otpLogin.email');
  static const sendCode = Key('otpLogin.sendCode');
  static const resend = Key('otpLogin.resend');
  static const changeNumber = Key('otpLogin.changeNumber');
  static const changeEmail = Key('otpLogin.changeEmail');
  static const useEmailInstead = Key('otpLogin.useEmailInstead');
  static const usePhoneInstead = Key('otpLogin.usePhoneInstead');

  static Key digit(int index) => Key('otpLogin.digit.$index');
}

/// Sign in by phone number or email address and a six-digit code.
class OtpLoginScreen extends ConsumerStatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  ConsumerState<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends ConsumerState<OtpLoginScreen> {
  static const _codeLength = AppLimits.otpCodeLength;
  static const _resendCooldown = AppDurations.otpResendCooldown;
  static const _verifyDelay = AppDurations.otpFakeVerifyDelay;

  final _phone = TextEditingController();
  final _phoneFocus = FocusNode();
  final _email = TextEditingController();
  final _emailFocus = FocusNode();

  /// One controller and one focus node per box. Six separate fields rather
  /// than one masked field because that is what makes each digit individually
  /// correctable — the thing people actually do when they mistype a code.
  late final List<TextEditingController> _digits = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _digitFocus = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );

  bool _codeSent = false;
  bool _verifying = false;
  bool _useEmail = false;
  String? _inputError;
  String? _codeError;
  int _shakeToken = 0;

  Timer? _cooldown;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _cooldown?.cancel();
    _phone.dispose();
    _phoneFocus.dispose();
    _email.dispose();
    _emailFocus.dispose();
    for (final controller in _digits) {
      controller.dispose();
    }
    for (final node in _digitFocus) {
      node.dispose();
    }
    super.dispose();
  }

  String get _code => _digits.map((c) => c.text).join();

  // -------------------------------------------------------------------------
  // Identifier step
  // -------------------------------------------------------------------------

  Future<void> _sendCode() async {
    if (_useEmail) {
      await _sendEmailCode();
      return;
    }

    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      setState(() => _inputError = AppStrings.enterPhoneNumber);
      return;
    }
    if (!isValidTanzanianPhone(digits)) {
      setState(() => _inputError = tanzanianPhoneHint);
      return;
    }

    try {
      // Request OTP from the auth provider.
      await ref.read(sessionProvider.notifier).requestOtp('+255$digits');
    } catch (e) {
      if (!mounted) return;
      setState(() => _inputError = AppStrings.sendCodeFailed(e));
      return;
    }

    _onCodeSent();
  }

  Future<void> _sendEmailCode() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _inputError = AppStrings.enterEmail);
      return;
    }
    if (!isValidEmailFormat(email)) {
      setState(() => _inputError = AppStrings.invalidEmail);
      return;
    }

    try {
      await ref.read(sessionProvider.notifier).requestEmailOtp(email);
    } catch (e) {
      if (!mounted) return;
      setState(() => _inputError = AppStrings.sendCodeFailed(e));
      return;
    }

    _onCodeSent();
  }

  void _onCodeSent() {
    setState(() {
      _inputError = null;
      _codeSent = true;
    });
    _startCooldown();
    // The first box takes focus so the code can be typed without a tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _digitFocus.first.requestFocus();
    });
  }

  /// Re-requests a code for whichever channel this sign-in is using, then
  /// restarts the cooldown. The lingering error slot is cleared first so a
  /// successful resend does not stay visually rejected.
  Future<void> _resend() async {
    setState(() => _codeError = null);
    try {
      if (_useEmail) {
        await ref
            .read(sessionProvider.notifier)
            .requestEmailOtp(_email.text.trim());
      } else {
        final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
        await ref.read(sessionProvider.notifier).requestOtp('+255$digits');
      }
      if (!mounted) return;
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _codeError = AppStrings.sendCodeFailed(e));
    }
  }

  void _startCooldown() {
    _cooldown?.cancel();
    setState(() => _secondsLeft = _resendCooldown.inSeconds);

    _cooldown = Timer.periodic(AppDurations.ticker, (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  void _changeTarget() {
    _cooldown?.cancel();
    setState(() {
      _codeSent = false;
      _codeError = null;
      _secondsLeft = 0;
      for (final controller in _digits) {
        controller.clear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_useEmail ? _emailFocus : _phoneFocus).requestFocus();
    });
  }

  /// Swaps between the SMS and email channels without leaving the card.
  void _toggleChannel() {
    _cooldown?.cancel();
    setState(() {
      _useEmail = !_useEmail;
      _inputError = null;
      _codeSent = false;
      _codeError = null;
      _secondsLeft = 0;
      for (final controller in _digits) {
        controller.clear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_useEmail ? _emailFocus : _phoneFocus).requestFocus();
    });
  }

  // -------------------------------------------------------------------------
  // Code step
  // -------------------------------------------------------------------------

  void _onDigitChanged(int index, String value) {
    // A paste lands the whole code in one box; spread it across the row rather
    // than truncating it to one character.
    if (value.length > 1) {
      final pasted = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _codeLength; i++) {
        _digits[i].text = i < pasted.length ? pasted[i] : '';
      }
      _digitFocus[(pasted.length - 1).clamp(0, _codeLength - 1)]
          .requestFocus();
    } else if (value.isNotEmpty && index < _codeLength - 1) {
      _digitFocus[index + 1].requestFocus();
    }

    // Clearing a box steps focus back to the one before it, which is what
    // deleting a mistyped digit is actually trying to do.
    if (value.isEmpty && index > 0) _digitFocus[index - 1].requestFocus();

    if (_codeError != null) setState(() => _codeError = null);
    if (_code.length == _codeLength) _verify();
  }


  Future<void> _verify() async {
    final entered = _code;
    setState(() => _verifying = true);
    FocusScope.of(context).unfocus();

    await Future<void>.delayed(_verifyDelay);
    if (!mounted) return;

    try {
      // Verify the code via the channel it was sent on.
      final session = ref.read(sessionProvider.notifier);
      if (_useEmail) {
        await session.completeEmailOtpLogin(entered);
      } else {
        await session.completeOtpLogin(entered);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _codeError = AppStrings.codeNotRight;
        _shakeToken++;
        for (final controller in _digits) {
          controller.clear();
        }
      });
      _digitFocus.first.requestFocus();
      return;
    }

    if (!mounted) return;
    // A brand-new (phone-first, OTP-only) account has no name on file yet —
    // collect it before anything else. Otherwise where this lands — Set PIN
    // for a first-time device, Dashboard for a returning one — is the
    // guard's decision, read off the session it just wrote to.
    if (ref.read(authProvider).needsProfile) {
      context.go(AppRoute.completeProfilePath);
      return;
    }
    context.go(ref.read(sessionProvider).entryRoute);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _codeSent ? AppStrings.enterYourCode : AppStrings.signIn,
      subtitle: _codeSent
          ? AppStrings.codeSentTo(_formattedTarget())
          : _useEmail
          ? AppStrings.useRegisteredEmail
          : AppStrings.useRegisteredPhone,
      footer: _codeSent
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AuthLink(
                  key: _useEmail
                      ? OtpLoginKeys.usePhoneInstead
                      : OtpLoginKeys.useEmailInstead,
                  label: _useEmail
                      ? AppStrings.usePhoneInstead
                      : AppStrings.useEmailInstead,
                  icon: _useEmail
                      ? Icons.phone_iphone_rounded
                      : Icons.alternate_email_rounded,
                  onPressed: _toggleChannel,
                ),
                AuthLink(
                  label: AppStrings.backToProfiles,
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => context.goNamed(AppRoute.profilesName),
                ),
              ],
            ),
      child: AnimatedSize(
        duration: AppDurations.screen,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: _codeSent
            ? _buildCodeStep(context)
            : _buildIdentifierStep(context),
      ),
    );
  }

  String _formattedTarget() {
    if (_useEmail) {
      final email = _email.text.trim();
      return email.isEmpty ? 'your email' : email;
    }
    final text = _phone.text.trim();
    return text.isEmpty ? 'your phone' : '+255 $text';
  }

  Widget _buildIdentifierStep(BuildContext context) {
    return Column(
      key: ValueKey(_useEmail ? 'email' : 'phone'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_useEmail) _buildEmailField(context) else _buildPhoneField(context),
        const SizedBox(height: Insets.xl),
        FilledButton(
          key: OtpLoginKeys.sendCode,
          onPressed: _sendCode,
          child: Text(AppStrings.sendCode),
        ),
      ],
    );
  }

  Widget _buildPhoneField(BuildContext context) {
    return LabeledFormField(
      label: AppStrings.phoneNumber,
      isRequired: true,
      child: TextField(
        key: OtpLoginKeys.phone,
        controller: _phone,
        focusNode: _phoneFocus,
        autofocus: true,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(AppLimits.tzPhoneDigits),
        ],
        onChanged: (value) {
          final digits = value.replaceAll(RegExp(r'\D'), '');
          if (digits.isEmpty) {
            setState(() => _inputError = null);
          } else if (!isValidTanzanianPhone(digits)) {
            setState(() => _inputError = tanzanianPhoneHint);
          } else {
            setState(() => _inputError = null);
          }
        },
        onSubmitted: (_) => _sendCode(),
        decoration: InputDecoration(
          hintText: AppStrings.phoneExample,
          errorText: _inputError,
          // A fixed dial code rather than a country picker: this build
          // serves one market, and a picker with one entry is a control
          // that only costs a tap.
          prefixIcon: Padding(
            padding: const EdgeInsets.only(
              left: Insets.lg,
              right: Insets.sm,
            ),
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
      ),
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return LabeledFormField(
      label: AppStrings.emailLabel,
      isRequired: true,
      child: TextField(
        key: OtpLoginKeys.email,
        controller: _email,
        focusNode: _emailFocus,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.email],
        inputFormatters: [LengthLimitingTextInputFormatter(255)],
        onChanged: (value) {
          final email = value.trim();
          if (email.isEmpty) {
            setState(() => _inputError = null);
          } else if (!isValidEmailFormat(email)) {
            setState(() => _inputError = AppStrings.invalidEmail);
          } else {
            setState(() => _inputError = null);
          }
        },
        onSubmitted: (_) => _sendCode(),
        decoration: InputDecoration(
          hintText: AppStrings.emailExample,
          errorText: _inputError,
          prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
        ),
      ),
    );
  }

  Widget _buildCodeStep(BuildContext context) {
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OtpInput(
          controllers: _digits,
          focusNodes: _digitFocus,
          hasError: _codeError != null,
          enabled: !_verifying,
          shakeToken: _shakeToken,
          onChanged: _onDigitChanged,
          keyBuilder: OtpLoginKeys.digit,
        ),
        const SizedBox(height: Insets.md),
        // The error takes the hint's place rather than appearing under it —
        // two lines of small print where one was is how a layout jumps.
        _CodeHint(error: _codeError, isEmail: _useEmail),
        const SizedBox(height: Insets.lg),
        SizedBox(
          height: 24,
          child: Center(
            child: _verifying
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 15,
                        width: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.primary,
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Text(AppStrings.verifying, style: context.text.bodySmall),
                    ],
                  )
                : _secondsLeft > 0
                ? Text(
                    AppStrings.resendIn(_secondsLeft),
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  )
                : TextButton(
                    key: OtpLoginKeys.resend,
                    onPressed: _resend,
                    child: Text(AppStrings.resendCode),
                  ),
          ),
        ),
        const SizedBox(height: Insets.sm),
        AuthLink(
          key: _useEmail ? OtpLoginKeys.changeEmail : OtpLoginKeys.changeNumber,
          label: _useEmail ? AppStrings.changeEmail : AppStrings.changeNumber,
          onPressed: _verifying ? null : _changeTarget,
        ),
      ],
    );
  }
}

/// The demo code, or the reason the last one was refused.
///
/// One slot for both so the card does not grow a line when a code is rejected.
class _CodeHint extends StatelessWidget {
  const _CodeHint({required this.error, required this.isEmail});

  final String? error;
  final bool isEmail;

  @override
  Widget build(BuildContext context) {
    final rejected = error != null;

    return AnimatedSwitcher(
      duration: AppDurations.authStep,
      child: rejected
          ? Text(
              error!,
              key: const ValueKey('error'),
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(
                color: context.semantic.danger,
              ),
            )
          : Row(
              key: const ValueKey('hint'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: context.colors.onSurfaceVariant,
                ),
                const SizedBox(width: Insets.sm - 2),
                Flexible(
                  child: Text(
                    isEmail ? AppStrings.emailCodeHint : AppStrings.codeHint,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
