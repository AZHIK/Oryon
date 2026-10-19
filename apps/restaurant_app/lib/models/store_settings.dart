import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import 'order.dart';

/// The currencies a venue can be configured in.
///
/// Locale and symbol travel together because [NumberFormat] needs both: a
/// symbol without its locale puts the group separators in the wrong places, and
/// a locale without its symbol prints the wrong currency entirely.
enum Currency {
  // `en_TZ` rather than `sw_TZ`: identical grouping ("TSh4,800"), but the
  // compact form stays "TSh12K" instead of intl's Swahili "TSh elfu 12",
  // which reads backwards on a summary tile.
  tzs('TZS', 'TSh', 'en_TZ', 'Tanzanian shilling'),
  usd('USD', r'$', 'en_US', 'US dollar'),
  eur('EUR', '€', 'de_DE', 'Euro'),
  gbp('GBP', '£', 'en_GB', 'Pound sterling'),
  idr('IDR', 'Rp', 'id_ID', 'Indonesian rupiah'),
  sgd('SGD', r'S$', 'en_SG', 'Singapore dollar'),
  aud('AUD', r'A$', 'en_AU', 'Australian dollar');

  const Currency(this.code, this.symbol, this.locale, this.description);

  final String code;
  final String symbol;
  final String locale;
  final String description;

  /// Rupiah and shilling prices are quoted in whole units — "Rp 48.000" and
  /// "TSh 4,800" are not prices anyone writes with cents — where the rest of
  /// these carry two decimals.
  int get decimalDigits => this == Currency.idr || this == Currency.tzs ? 0 : 2;

  String get label => '$code · $symbol';
}

/// A single day's trading hours.
///
/// [open] and [close] are kept even while [isOpen] is false, so toggling a day
/// shut for a public holiday and back on again does not lose the times someone
/// already set.
@immutable
class DayHours {
  const DayHours({
    required this.isOpen,
    this.open = const TimeOfDay(hour: 9, minute: 0),
    this.close = const TimeOfDay(hour: 22, minute: 0),
  });

  final bool isOpen;
  final TimeOfDay open;
  final TimeOfDay close;

  /// True where the shift runs past midnight — a bar closing at 02:00 is a
  /// normal Friday, not a mistake, so it is described rather than rejected.
  bool get isOvernight =>
      _minutes(close) <= _minutes(open) && isOpen;

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  DayHours copyWith({bool? isOpen, TimeOfDay? open, TimeOfDay? close}) =>
      DayHours(
        isOpen: isOpen ?? this.isOpen,
        open: open ?? this.open,
        close: close ?? this.close,
      );

  @override
  bool operator ==(Object other) =>
      other is DayHours &&
      other.isOpen == isOpen &&
      other.open == open &&
      other.close == close;

  @override
  int get hashCode => Object.hash(isOpen, open, close);
}

/// Weekday labels for the operating-hours list, Monday first — a trading week
/// starts on Monday everywhere this app is likely to be installed.
/// Centralized in [AppStrings] (weekdayNames/weekdayShortNames) so a future
/// localization pass translates them once.
const kWeekdayNames = AppStrings.weekdayNames;

const kWeekdayShortNames = AppStrings.weekdayShortNames;

/// What the till prints after a charge settles: the itemised receipt or a
/// short coupon (e.g. a kitchen/claim ticket). The store owner picks the
/// default in Store Settings; the cashier can still switch it per sale in the
/// take-payment dialog.
enum CheckoutPrintMode {
  receipt('receipt', 'Receipt', Icons.receipt_long_rounded),
  coupon('coupon', 'Coupon', Icons.confirmation_number_outlined);

  const CheckoutPrintMode(this.storageKey, this.labelDefault, this.icon);
  final String storageKey;
  final String labelDefault;
  final IconData icon;

  String get label => labelDefault;

  static CheckoutPrintMode fromStorageKey(String? key) =>
      values.firstWhere(
        (mode) => mode.storageKey == key,
        orElse: () => CheckoutPrintMode.receipt,
      );
}

/// How this terminal *behaves* — as distinct from [BusinessProfile], which is
/// who the business *is*.
///
/// The split matters because the two are edited by different people at
/// different times: a tax rate change is an accounting decision, a logo change
/// is a marketing one. Everything here has a consumer elsewhere in the app —
/// the tax rate opens every ticket, the default order type pre-selects the POS
/// panel, the currency formats every amount on screen.
@immutable
class StoreSettings {
  const StoreSettings({
    this.taxEnabled = false,
    this.taxRate = 0,
    this.taxInclusive = false,
    this.serviceChargeRate = 0,
    this.currency = Currency.tzs,
    this.defaultOrderType = OrderType.dineIn,
    this.receiptPrefix = 'INV-',
    this.autoPrintReceipt = true,
    this.checkoutPrintMode = CheckoutPrintMode.receipt,
    // Always seven entries, Monday first. Not asserted: the constructor is
    // const, and a const evaluation cannot read a list's length.
    this.hours = defaultHours,
  });

  /// Tax switch — off by default. When off, no tax is charged or shown
  /// anywhere (POS, sales, receipts, reports). When on, tickets charge
  /// subtotal * taxRate.
  final bool taxEnabled;

  /// Stored as a fraction (0.18), entered as a percentage. Keeping the
  /// fraction canonical means the checkout maths never divides by 100.
  /// Only used when [taxEnabled] is true.
  final double taxRate;

  /// Whether menu prices already include tax. Changes what a receipt says, not
  /// what the customer pays.
  final bool taxInclusive;

  final double serviceChargeRate;

  final Currency currency;

  /// Pre-selected on the POS order panel when a ticket is started.
  final OrderType defaultOrderType;

  /// Prepended to receipt numbers, e.g. "INV-" → "INV-1042".
  final String receiptPrefix;

  final bool autoPrintReceipt;

  /// Default of what prints after a charge: receipt or coupon. The
  /// take-payment dialog pre-selects this, and the cashier may override it
  /// per sale.
  final CheckoutPrintMode checkoutPrintMode;

  /// Monday-first, always seven entries.
  final List<DayHours> hours;

  /// A restaurant week: closed Monday, long weekend service.
  static const defaultHours = <DayHours>[
    DayHours(isOpen: false),
    DayHours(isOpen: true),
    DayHours(isOpen: true),
    DayHours(isOpen: true),
    DayHours(
      isOpen: true,
      open: TimeOfDay(hour: 11, minute: 0),
      close: TimeOfDay(hour: 23, minute: 30),
    ),
    DayHours(
      isOpen: true,
      open: TimeOfDay(hour: 10, minute: 0),
      close: TimeOfDay(hour: 23, minute: 30),
    ),
    DayHours(
      isOpen: true,
      open: TimeOfDay(hour: 10, minute: 0),
      close: TimeOfDay(hour: 21, minute: 0),
    ),
  ];

  /// "Closed Mondays" / "Open every day" — the one-line readout the settings
  /// index shows without opening the screen.
  String get hoursSummary {
    final closed = [
      for (var i = 0; i < hours.length; i++)
        if (!hours[i].isOpen) kWeekdayShortNames[i],
    ];
    if (closed.isEmpty) return AppStrings.openEveryDay;
    if (closed.length == 7) return AppStrings.closedAllWeek;
    return AppStrings.closedDays(closed.join(', '));
  }

  StoreSettings copyWith({
    bool? taxEnabled,
    double? taxRate,
    bool? taxInclusive,
    double? serviceChargeRate,
    Currency? currency,
    OrderType? defaultOrderType,
    String? receiptPrefix,
    bool? autoPrintReceipt,
    CheckoutPrintMode? checkoutPrintMode,
    List<DayHours>? hours,
  }) {
    return StoreSettings(
      taxEnabled: taxEnabled ?? this.taxEnabled,
      taxRate: taxRate ?? this.taxRate,
      taxInclusive: taxInclusive ?? this.taxInclusive,
      serviceChargeRate: serviceChargeRate ?? this.serviceChargeRate,
      currency: currency ?? this.currency,
      defaultOrderType: defaultOrderType ?? this.defaultOrderType,
      receiptPrefix: receiptPrefix ?? this.receiptPrefix,
      autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
      checkoutPrintMode: checkoutPrintMode ?? this.checkoutPrintMode,
      hours: hours ?? this.hours,
    );
  }

  /// Replaces one day without the caller having to rebuild the whole list.
  StoreSettings withDay(int index, DayHours day) => copyWith(
    hours: [
      for (var i = 0; i < hours.length; i++)
        if (i == index) day else hours[i],
    ],
  );

  @override
  bool operator ==(Object other) =>
      other is StoreSettings &&
      other.taxEnabled == taxEnabled &&
      other.taxRate == taxRate &&
      other.taxInclusive == taxInclusive &&
      other.serviceChargeRate == serviceChargeRate &&
      other.currency == currency &&
      other.defaultOrderType == defaultOrderType &&
      other.receiptPrefix == receiptPrefix &&
      other.autoPrintReceipt == autoPrintReceipt &&
      other.checkoutPrintMode == checkoutPrintMode &&
      _sameHours(other.hours, hours);

  @override
  int get hashCode => Object.hash(
    taxEnabled,
    taxRate,
    taxInclusive,
    serviceChargeRate,
    currency,
    defaultOrderType,
    receiptPrefix,
    autoPrintReceipt,
    checkoutPrintMode,
    Object.hashAll(hours),
  );

  static bool _sameHours(List<DayHours> a, List<DayHours> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
