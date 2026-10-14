import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/business_profile.dart';
import '../models/order.dart';
import '../models/store_settings.dart';
import '../theme/app_theme.dart';
import 'business_api_provider.dart';
import 'database_providers.dart';
import 'staff_provider.dart';

/// App-wide theme mode.
///
/// In-memory for now; persisting it later means overriding this provider with
/// one backed by shared_preferences and nothing else has to change.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void set(ThemeMode mode) => state = mode;

  /// Cycles system → light → dark, for the app bar toggle.
  void cycle() {
    state = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ---------------------------------------------------------------------------
// Business identity
// ---------------------------------------------------------------------------

class BusinessProfileNotifier extends Notifier<BusinessProfile?> {
  @override
  BusinessProfile? build() {
    final currentBusiness = ref.watch(currentBusinessProvider);

    return currentBusiness.when(
      data: (business) {
        if (business != null) return BusinessProfile.fromDto(business);
        return null;
      },
      loading: () => null,
      error: (_, _) => null,
    );
  }

  void save(BusinessProfile profile) => state = profile;
}

final businessProfileProvider =
    NotifierProvider<BusinessProfileNotifier, BusinessProfile?>(
      BusinessProfileNotifier.new,
    );

/// Store identity shown in the nav header.
///
/// Prefers the live business profile, but that is permission-gated
/// (`businesses.view`) — ordinary staff (e.g. Kitchen Staff) never have it,
/// so for them this falls back to the device's locked business name, which
/// login writes from the onboarding-status response. Display-only: the name
/// is already on receipts and known to staff, so no permission is needed to
/// show it.
final storeNameProvider = Provider<String>(
  (ref) {
    final profile = ref.watch(businessProfileProvider);
    final liveName = profile?.name.trim();
    if (liveName != null && liveName.isNotEmpty) return liveName;
    return ref.watch(_deviceBusinessNameProvider).valueOrNull ??
        'Restaurant';
  },
);

/// This device's locked business name, read from local `DeviceConfig`.
/// Written at login/provisioning time, so it is available offline and
/// regardless of the caller's role permissions.
final _deviceBusinessNameProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(localProfileRepositoryProvider);
  final device = await repo.currentDevice();
  final name = device?.businessName as String?;
  final trimmed = name?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
});

/// The thank-you line printed at the bottom of every receipt.
///
/// Exposed separately so the receipt renderer depends on the one string it
/// prints rather than on the whole profile — and so no receipt ever ships with
/// a hardcoded message again.
final receiptFooterProvider = Provider<String>(
  (ref) {
    final profile = ref.watch(businessProfileProvider);
    return profile?.formattedAddress ?? '';
  },
);

/// The business's accent colour, for receipts and customer-facing surfaces.
final brandColorProvider = Provider<Color>(
  (ref) {
    final profile = ref.watch(businessProfileProvider);
    return profile?.brandColor ?? AppTheme.seed;
  },
);

// ---------------------------------------------------------------------------
// Store operation
// ---------------------------------------------------------------------------

/// How this store trades: tax, currency, receipt numbering, opening hours.
///
/// Every field here has a consumer somewhere else in the app, which is the
/// test a setting has to pass before it earns a place on the screen.
class StoreSettingsNotifier extends Notifier<StoreSettings> {
  @override
  StoreSettings build() => const StoreSettings();

  void save(StoreSettings settings) => state = settings;

  void setDay(int index, DayHours day) => state = state.withDay(index, day);

  void setCurrency(Currency currency) =>
      state = state.copyWith(currency: currency);
}

final storeSettingsProvider =
    NotifierProvider<StoreSettingsNotifier, StoreSettings>(
      StoreSettingsNotifier.new,
    );

/// The tax rate new tickets are opened at.
///
/// Selected out of [storeSettingsProvider] rather than read whole, so the cart
/// is not rebuilt when someone edits the receipt prefix.
final taxRateProvider = Provider<double>(
  (ref) => ref.watch(storeSettingsProvider.select((s) => s.taxRate)),
);

/// Whether menu prices already carry their tax.
final taxInclusiveProvider = Provider<bool>(
  (ref) => ref.watch(storeSettingsProvider.select((s) => s.taxInclusive)),
);

final serviceChargeRateProvider = Provider<double>(
  (ref) => ref.watch(storeSettingsProvider.select((s) => s.serviceChargeRate)),
);

/// The currency every amount in the app is formatted in.
///
/// Read once at the root of the widget tree, where it configures [Fmt] before
/// anything below it formats a number.
final currencyProvider = Provider<Currency>(
  (ref) => ref.watch(storeSettingsProvider.select((s) => s.currency)),
);

/// What a fresh ticket's order type starts as.
final defaultOrderTypeProvider = Provider<OrderType>(
  (ref) => ref.watch(storeSettingsProvider.select((s) => s.defaultOrderType)),
);

/// Prefix on printed receipt numbers, e.g. "INV-".
final receiptPrefixProvider = Provider<String>(
  (ref) => ref.watch(storeSettingsProvider.select((s) => s.receiptPrefix)),
);

final autoPrintReceiptProvider = Provider<bool>(
  (ref) => ref.watch(storeSettingsProvider.select((s) => s.autoPrintReceipt)),
);

/// Default of what the till prints after a charge (receipt vs coupon),
/// chosen by the owner in Store Settings.
final checkoutPrintModeProvider = Provider<CheckoutPrintMode>(
  (ref) => ref.watch(storeSettingsProvider.select((s) => s.checkoutPrintMode)),
);

/// Per-sale print choice in the take-payment dialog: charge + receipt or
/// charge + coupon.
///
/// Seeded from [checkoutPrintModeProvider] every time the dialog opens (see
/// `chargeOpenOrder`), then freely switchable by the cashier for that sale
/// only — it never writes back to Store Settings.
final checkoutPrintChoiceProvider = StateProvider<CheckoutPrintMode>(
  (ref) => ref.watch(checkoutPrintModeProvider),
);

/// Note and coin values offered as one-tap top-ups when taking cash.
///
/// Store configuration rather than constants in the widget, and *amounts*
/// rather than pre-baked labels: a venue on a currency with no 5 note, or one
/// whose smallest bill is 10.000, changes this list and every quick-amount
/// control follows. The labels are formatted through [Fmt.money], so the
/// currency itself is still decided in exactly one place.
final cashQuickAmountsProvider = Provider<List<double>>(
  (ref) => switch (ref.watch(
    storeSettingsProvider.select((s) => s.currency),
  )) {
    // Whole-unit cash economies: useful notes, not pocket change.
    Currency.tzs => const [1000, 2000, 5000, 10000],
    Currency.idr => const [10000, 20000, 50000, 100000],
    _ => const [5, 10, 20, 50],
  },
);

/// Signed-in staff member, used as the default server on new orders.
///
/// Resolves to whoever is actually signed in at this terminal (via
/// [currentUserNameProvider]) — never a fixed name — trimmed to the first
/// name only ("Ava Mensah" renders as "Ava").
final currentStaffProvider = Provider<String>((ref) {
  final full = ref.watch(currentUserNameProvider).trim();
  final space = full.indexOf(' ');
  return space == -1 ? full : full.substring(0, space);
});
