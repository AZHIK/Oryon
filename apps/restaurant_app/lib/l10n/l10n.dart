import 'package:flutter/widgets.dart';

import 'en_map.dart';
import 'sw_map.dart';

/// Minimal synchronous localization runtime — no codegen step.
///
/// Every [AppStrings] member delegates here: English is the compiled-in
/// default, Swahili comes from [kSwStrings] (generated from
/// `lib/l10n/arb/app_sw.arb` — that file stays the source of truth for
/// translators, `sw_map.dart` is its compiled form).
///
/// Why not `flutter gen-l10n`? It needs a build step every translator edit
/// breaks the build until it runs, and 1358 keys migrated gradually would
/// leave two systems of record. This keeps one static call shape
/// (`AppStrings.save`) working in both languages with zero call-site churn.
///
/// Persistence (SharedPreferences / secure storage) lives in
/// `AppLanguageNotifier` — this class only holds the active code so that
/// plain unit tests can flip it without async setup.
abstract final class L10n {
  static final ValueNotifier<String> code = ValueNotifier<String>('en');

  static bool get isSw => code.value.startsWith('sw');

  static String get localeCode => code.value;

  static Locale get locale => Locale(isSw ? 'sw' : 'en');

  static const supportedLocales = <Locale>[Locale('en'), Locale('sw')];

  /// English default with Swahili override. Missing keys fall back to
  /// English rather than blanking the UI — a gap is a bug report, not a
  /// blank button.
  static String t(String key, String enDefault) {
    if (!isSw) return enDefault;
    return kSwStrings[key] ?? enDefault;
  }

  /// Key-only lookup for enum labels and other `const`-context refugees:
  /// English ships compiled in [kEnStrings], Swahili in [kSwStrings].
  static String tk(String key) {
    if (isSw) return kSwStrings[key] ?? kEnStrings[key] ?? key;
    return kEnStrings[key] ?? key;
  }

  /// Templated lookup with `{name}` placeholders, e.g.
  /// `tp('vsYesterday', 'vs {amount} yesterday', {'amount': 'TSh 10k'})`.
  ///
  /// Falls back to the English template when the Swahili one is missing,
  /// then substitutes every placeholder. Unmatched placeholders are left
  /// as-is so a typo shows up as `{typo}` instead of silently dropping text.
  static String tp(String key, String enTemplate, Map<String, String> params) {
    final template = t(key, enTemplate);
    var out = template;
    params.forEach((name, value) {
      out = out.replaceAll('{$name}', value);
    });
    return out;
  }

  @visibleForTesting
  static void useForTests(String next) => code.value = next;
}
