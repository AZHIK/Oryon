/// Shared Tanzanian mobile phone validation, used by every screen that
/// collects a phone number during auth/onboarding — keeping one rule here
/// means the OTP login screen and the business wizard can never disagree
/// about what counts as a valid number.
library;

import '../constants/app_limits.dart';
import '../l10n/l10n.dart';

/// True when [digits] (national number, no +255 prefix) is a valid
/// Tanzanian mobile number: 9 digits, starting with 6 or 7.
bool isValidTanzanianPhone(String digits) {
  if (digits.length != AppLimits.tzPhoneDigits) return false;
  return digits.startsWith('6') || digits.startsWith('7');
}

/// Strips a raw phone entry down to its national digits so forms can accept
/// the formats people actually type: `7XXXXXXXX`, `07XXXXXXXX`, `2557XXXXXXXX`
/// and `+2557XXXXXXXX` (spaces/dashes ignored). Returns the 9-digit national
/// number, or the digit string unchanged when it matches none of those
/// shapes so [isValidTanzanianPhone] still rejects it.
String normalizeTanzanianPhoneDigits(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == AppLimits.tzPhoneDigits) return digits;
  if (digits.length == 10 && digits.startsWith('0')) {
    return digits.substring(1);
  }
  if (digits.length == 12 && digits.startsWith('255')) {
    return digits.substring(3);
  }
  if (digits.length == 13 && digits.startsWith('00255')) {
    return digits.substring(4);
  }
  return digits;
}

/// True when a free-text phone entry is a valid Tanzanian mobile number in
/// any accepted shape (see [normalizeTanzanianPhoneDigits]).
bool isValidTanzanianPhoneInput(String raw) =>
    isValidTanzanianPhone(normalizeTanzanianPhoneDigits(raw));

String get tanzanianPhoneHint => L10n.t(
  'tanzanianPhoneError',
  'Enter a valid Tanzanian phone number (6 or 7XXXXXXXX)',
);
