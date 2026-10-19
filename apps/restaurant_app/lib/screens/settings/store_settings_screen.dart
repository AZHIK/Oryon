import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/order.dart';
import '../../constants/app_limits.dart';
import '../../constants/app_strings.dart';
import '../../models/store_settings.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/settings_provider.dart';
import '../../router/app_router.dart';
import '../../providers/store_api_provider_real.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../../widgets/detail_page/detail_page_scaffold.dart';
import '../../widgets/field_pair.dart';
import '../../widgets/labeled_form_field.dart';
import '../../widgets/receipt/coupon_dialog.dart';
import '../../widgets/receipt/receipt_dialog.dart';

/// Widget keys for the store settings form.
abstract final class StoreSettingsKeys {
  static const taxRate = Key('storeSettings.taxRate');
  static const serviceCharge = Key('storeSettings.serviceCharge');
  static const taxInclusive = Key('storeSettings.taxInclusive');
  static const currency = Key('storeSettings.currency');
  static const orderType = Key('storeSettings.orderType');
  static const receiptPrefix = Key('storeSettings.receiptPrefix');
  static const autoPrint = Key('storeSettings.autoPrint');
  static const printMode = Key('storeSettings.printMode');
  static const previewReceipt = Key('storeSettings.previewReceipt');
  static const previewCoupon = Key('storeSettings.previewCoupon');
  static const save = Key('storeSettings.save');

  static Key day(int index) => Key('storeSettings.day.$index');
  static Key openTime(int index) => Key('storeSettings.open.$index');
  static Key closeTime(int index) => Key('storeSettings.close.$index');
}

/// How this store trades: what it charges, what it prints, when it is open.
///
/// The counterpart to Business Profile — that screen is identity, this one is
/// behaviour. Every control here has a consumer somewhere else in the app, so
/// nothing on it is a stored preference that does nothing.
///
/// One column of sections at every width: these are short, self-contained
/// blocks that read top to bottom, and a second column would only put the
/// opening hours somewhere the eye has to hunt for them.
class StoreSettingsScreen extends ConsumerStatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  ConsumerState<StoreSettingsScreen> createState() =>
      _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends ConsumerState<StoreSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _taxRate = TextEditingController();
  final _serviceCharge = TextEditingController();
  final _receiptPrefix = TextEditingController();

  /// The whole draft lives here until Save: opening hours and toggles are
  /// edited in place, and a half-applied set of trading rules is not a state
  /// the till should ever run under.
  late StoreSettings _draft;
  bool _seeded = false;
  bool _dirty = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;

    _draft = ref.read(storeSettingsProvider);
    // Stored as fractions, edited as percentages.
    _taxRate.text = _asPercent(_draft.taxRate);
    _serviceCharge.text = _asPercent(_draft.serviceChargeRate);
    _receiptPrefix.text = _draft.receiptPrefix;
  }

  @override
  void dispose() {
    _taxRate.dispose();
    _serviceCharge.dispose();
    _receiptPrefix.dispose();
    super.dispose();
  }

  static String _asPercent(double fraction) =>
      (fraction * 100).toStringAsFixed(2);

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  /// Applies [change] to the draft and marks the form dirty in one step, so no
  /// control can update state and forget to enable Save.
  void _edit(StoreSettings Function(StoreSettings) change) {
    setState(() {
      _draft = change(_draft);
      _dirty = true;
    });
  }

  double _percentToFraction(String raw) {
    final parsed = double.tryParse(raw.trim());
    if (parsed == null) return 0;
    return (parsed / 100).clamp(0, 1);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final saved = _draft.copyWith(
      taxRate: _percentToFraction(_taxRate.text),
      serviceChargeRate: _percentToFraction(_serviceCharge.text),
      receiptPrefix: _receiptPrefix.text.trim(),
    );
    ref.read(storeSettingsProvider.notifier).save(saved);

    // Push the tax switch to the server so synced sales charge the same
    // tax the till shows. Local save always wins for this terminal;
    // a failed push (offline, no permission) just leaves the server
    // value unchanged and says so.
    _pushTaxToServer(saved);

    setState(() => _dirty = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(content: Text(AppStrings.storeSettingsSaved)),
    );
  }

  Future<void> _pushTaxToServer(StoreSettings saved) async {
    final businessId = ref.read(currentBusinessIdProvider);
    final storeId = ref.read(currentStoreIdProvider);
    if (businessId == null || storeId == null) return;
    try {
      await ref.read(storeApiServiceProvider).updateStoreSettings(
            businessId: businessId,
            storeId: storeId,
            taxEnabled: saved.taxEnabled,
            taxRate: saved.taxEnabled ? saved.taxRate : 0,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Saved on this device. Tax change will reach the server when online.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: _touch,
      child: DetailPageScaffold(
        maxContentWidth: 820,
        header: DetailPageHeader(
          title: AppStrings.storeSettingsTitle,
          subtitle: AppStrings.storeSettingsSubtitle,
          onBack: () => context.canPop()
              ? context.pop()
              : context.goNamed(AppRoute.settingsName),
          actions: [
            FilledButton.icon(
              key: StoreSettingsKeys.save,
              onPressed: _dirty ? _save : null,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(AppStrings.saveChangesAction),
            ),
          ],
        ),
        children: [
          _TaxPanel(
            taxRate: _taxRate,
            serviceCharge: _serviceCharge,
            draft: _draft,
            onTaxEnabledChanged: (value) =>
                _edit((d) => d.copyWith(taxEnabled: value)),
            onInclusiveChanged: (value) =>
                _edit((d) => d.copyWith(taxInclusive: value)),
            onCurrencyChanged: (value) =>
                _edit((d) => d.copyWith(currency: value)),
          ),
          _OrderPanel(
            receiptPrefix: _receiptPrefix,
            draft: _draft,
            onOrderTypeChanged: (value) =>
                _edit((d) => d.copyWith(defaultOrderType: value)),
            onAutoPrintChanged: (value) =>
                _edit((d) => d.copyWith(autoPrintReceipt: value)),
            onPrintModeChanged: (value) =>
                _edit((d) => d.copyWith(checkoutPrintMode: value)),
            onPreviewReceipt: () =>
                showSampleReceiptPreviewDialog(context, ref),
            onPreviewCoupon: () =>
                showSampleCouponPreviewDialog(context, ref),
          ),
          _HoursPanel(
            settings: _draft,
            onDayChanged: (index, day) => _edit((d) => d.withDay(index, day)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tax & pricing
// ---------------------------------------------------------------------------

class _TaxPanel extends StatelessWidget {
  const _TaxPanel({
    required this.taxRate,
    required this.serviceCharge,
    required this.draft,
    required this.onTaxEnabledChanged,
    required this.onInclusiveChanged,
    required this.onCurrencyChanged,
  });

  final TextEditingController taxRate;
  final TextEditingController serviceCharge;
  final StoreSettings draft;
  final ValueChanged<bool> onTaxEnabledChanged;
  final ValueChanged<bool> onInclusiveChanged;
  final ValueChanged<Currency> onCurrencyChanged;

  static final _rateFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}\.?\d{0,2}')),
  ];

  String? _validateRate(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return AppStrings.enterNumberError;
    if (parsed < 0 || parsed > 100) return AppStrings.percentRangeError;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final taxOff = !draft.taxEnabled;
    return DetailPanel(
      title: AppStrings.taxPricingPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingSwitchTile(
            switchKey: const Key('storeSettings.taxEnabled'),
            title: 'Charge tax',
            subtitle: draft.taxEnabled
                ? 'Tax is added at checkout and shown everywhere'
                : 'Off — no tax is charged or shown anywhere',
            value: draft.taxEnabled,
            onChanged: onTaxEnabledChanged,
          ),
          const SizedBox(height: Insets.lg),
          FieldPair(
            left: LabeledFormField(
              label: AppStrings.taxRateField,
              helper: taxOff ? 'Turn tax on to set a rate' : AppStrings.newTicketHelper,
              child: TextFormField(
                key: StoreSettingsKeys.taxRate,
                controller: taxRate,
                enabled: !taxOff,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: _rateFormatters,
                decoration: InputDecoration(
                  hintText: AppStrings.taxExample,
                  suffixText: AppStrings.percentSuffix,
                ),
                validator: _validateRate,
              ),
            ),
            right: LabeledFormField(
              label: AppStrings.serviceChargeField,
              helper: AppStrings.serviceChargeHelper,
              child: TextFormField(
                key: StoreSettingsKeys.serviceCharge,
                controller: serviceCharge,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: _rateFormatters,
                decoration: InputDecoration(
                  hintText: AppStrings.quantityHint,
                  suffixText: AppStrings.percentSuffix,
                ),
                validator: _validateRate,
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),
          Opacity(
            opacity: taxOff ? 0.4 : 1,
            child: IgnorePointer(
              ignoring: taxOff,
              child: SettingSwitchTile(
                switchKey: StoreSettingsKeys.taxInclusive,
                title: AppStrings.pricesIncludeTax,
                subtitle: draft.taxInclusive
                    ? AppStrings.taxInclusivePrices
                    : AppStrings.taxAddedAtCheckout,
                value: draft.taxInclusive,
                onChanged: onInclusiveChanged,
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),
          LabeledFormField(
            label: AppStrings.currencyField,
            helper: AppStrings.currencyShownHelper,
            child: DropdownButtonFormField<Currency>(
              key: StoreSettingsKeys.currency,
              initialValue: draft.currency,
              isExpanded: true,
              items: [
                for (final currency in Currency.values)
                  DropdownMenuItem(
                    value: currency,
                  child: Text(
                    AppStrings.currencyOption(
                      currency.description,
                      currency.label,
                    ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onCurrencyChanged(value);
              },
            ),
          ),
          const SizedBox(height: Insets.md),
          _SampleAmount(currency: draft.currency),
        ],
      ),
    );
  }
}

/// What a price will look like once the chosen currency is applied.
///
/// Formatted independently of [Fmt] so it can preview a currency that has not
/// been saved yet — picking one from the dropdown shows the change before
/// committing it, which is the whole question someone opens this field to ask.
class _SampleAmount extends StatelessWidget {
  const _SampleAmount({required this.currency});

  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final sample = currency.decimalDigits == 0 ? 48000.0 : 48.0;

    return Row(
      children: [
        Icon(
          Icons.sell_outlined,
          size: 15,
          color: context.colors.onSurfaceVariant,
        ),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Text(
            AppStrings.currencyPreview(Fmt.moneyIn(currency, sample)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Order & receipt
// ---------------------------------------------------------------------------

class _OrderPanel extends StatelessWidget {
  const _OrderPanel({
    required this.receiptPrefix,
    required this.draft,
    required this.onOrderTypeChanged,
    required this.onAutoPrintChanged,
    required this.onPrintModeChanged,
    required this.onPreviewReceipt,
    required this.onPreviewCoupon,
  });

  final TextEditingController receiptPrefix;
  final StoreSettings draft;
  final ValueChanged<OrderType> onOrderTypeChanged;
  final ValueChanged<bool> onAutoPrintChanged;
  final ValueChanged<CheckoutPrintMode> onPrintModeChanged;
  final VoidCallback onPreviewReceipt;
  final VoidCallback onPreviewCoupon;

  @override
  Widget build(BuildContext context) {
    return DetailPanel(
      title: AppStrings.orderReceiptPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FieldPair(
            left: LabeledFormField(
              label: AppStrings.defaultOrderTypeField,
              helper: AppStrings.preselectedPosHelper,
              child: DropdownButtonFormField<OrderType>(
                key: StoreSettingsKeys.orderType,
                initialValue: draft.defaultOrderType,
                isExpanded: true,
                items: [
                  for (final type in OrderType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(type.icon, size: 17),
                          const SizedBox(width: Insets.sm),
                          Flexible(
                            child: Text(
                              type.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onOrderTypeChanged(value);
                },
              ),
            ),
            right: LabeledFormField(
              label: AppStrings.receiptPrefixField,
              helper: AppStrings.receiptPrefixExample,
              child: TextFormField(
                key: StoreSettingsKeys.receiptPrefix,
                controller: receiptPrefix,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: AppStrings.receiptPrefixHint,
                ),
                validator: (value) => (value ?? '').trim().length >
                        AppLimits.receiptPrefixLength
                    ? AppStrings.receiptPrefixLengthError
                    : null,
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),
          SettingSwitchTile(
            switchKey: StoreSettingsKeys.autoPrint,
            title: AppStrings.autoPrintReceipt,
            subtitle: draft.autoPrintReceipt
                ? AppStrings.autoPrintOn
                : AppStrings.autoPrintOff,
            value: draft.autoPrintReceipt,
            onChanged: onAutoPrintChanged,
          ),
          const SizedBox(height: Insets.lg),
          LabeledFormField(
            label: AppStrings.defaultPrintModeField,
            helper: AppStrings.defaultPrintModeHelper,
            child: DropdownButtonFormField<CheckoutPrintMode>(
              key: StoreSettingsKeys.printMode,
              initialValue: draft.checkoutPrintMode,
              isExpanded: true,
              items: [
                for (final mode in CheckoutPrintMode.values)
                  DropdownMenuItem(
                    value: mode,
                    child: Row(
                      children: [
                        Icon(mode.icon, size: 17),
                        const SizedBox(width: Insets.sm),
                        Flexible(
                          child: Text(
                            mode.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onPrintModeChanged(value);
              },
            ),
          ),
          const SizedBox(height: Insets.lg),
          OutlinedButton.icon(
            key: StoreSettingsKeys.previewReceipt,
            onPressed: onPreviewReceipt,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: Text(AppStrings.previewReceiptAction),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            AppStrings.previewReceiptBlurb,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Insets.md),
          OutlinedButton.icon(
            key: StoreSettingsKeys.previewCoupon,
            onPressed: onPreviewCoupon,
            icon: const Icon(Icons.confirmation_number_outlined, size: 18),
            label: Text(AppStrings.previewCouponAction),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            AppStrings.previewCouponBlurb,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Operating hours
// ---------------------------------------------------------------------------

class _HoursPanel extends StatelessWidget {
  const _HoursPanel({required this.settings, required this.onDayChanged});

  final StoreSettings settings;
  final void Function(int index, DayHours day) onDayChanged;

  @override
  Widget build(BuildContext context) {
    final hours = settings.hours;

    return DetailPanel(
      title: AppStrings.operatingHours,
      // The exception is what is worth stating: "Closed Mon" tells the reader
      // something a count of open days does not.
      trailing: Text(
        settings.hoursSummary,
        textAlign: TextAlign.end,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.lg,
        Insets.lg,
        Insets.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < hours.length; i++) ...[
            if (i > 0) const Divider(height: Insets.lg),
            _DayRow(
              index: i,
              day: hours[i],
              onChanged: (day) => onDayChanged(i, day),
            ),
          ],
        ],
      ),
    );
  }
}

/// One weekday: a toggle, and the two time pickers that only exist when the
/// day is actually open.
///
/// A closed day collapses to the label and the toggle. Showing greyed-out time
/// pickers for six closed days would be six rows of controls that cannot be
/// used, which is worse than a row that simply says "Closed".
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.index,
    required this.day,
    required this.onChanged,
  });

  final int index;
  final DayHours day;
  final ValueChanged<DayHours> onChanged;

  /// Below this the label, the toggle and two time pickers stop fitting on one
  /// line, and the pickers move to a second row under them.
  static const double _inlineMin = 460;

  Future<void> _pick(
    BuildContext context, {
    required bool isOpening,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpening ? day.open : day.close,
      helpText: isOpening ? AppStrings.opensAt : AppStrings.closesAt,
    );
    if (picked == null) return;

    onChanged(
      isOpening ? day.copyWith(open: picked) : day.copyWith(close: picked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final label = Text(
      kWeekdayNames[index],
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.text.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: day.isOpen ? colors.onSurface : colors.onSurfaceVariant,
      ),
    );

    final toggle = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
          Text(
          day.isOpen ? AppStrings.openValue : AppStrings.closedValue,
          style: context.text.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: Insets.sm),
        Switch(
          key: StoreSettingsKeys.day(index),
          value: day.isOpen,
          onChanged: (value) => onChanged(day.copyWith(isOpen: value)),
        ),
      ],
    );

    // A Wrap rather than a Row: two time chips and the arrow between them need
    // roughly 190px, and the sweep drags this panel down to a 176px column.
    // Wrapping puts the closing time on its own line instead of painting past
    // the panel's edge.
    final times = Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _TimeChip(
          key: StoreSettingsKeys.openTime(index),
          time: day.open,
          onTap: () => _pick(context, isOpening: true),
        ),
        Icon(
          Icons.arrow_forward_rounded,
          size: 15,
          color: colors.onSurfaceVariant,
        ),
        _TimeChip(
          key: StoreSettingsKeys.closeTime(index),
          time: day.close,
          onTap: () => _pick(context, isOpening: false),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final inline = constraints.maxWidth >= _inlineMin;

        if (!day.isOpen) {
          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: Insets.sm),
              toggle,
            ],
          );
        }

        if (inline) {
          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: Insets.sm),
              times,
              const SizedBox(width: Insets.lg),
              toggle,
            ],
          );
        }

        // Phone layout: the day and its toggle share the first line, and the
        // pickers get a line of their own rather than being crushed between
        // them.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: label),
                const SizedBox(width: Insets.sm),
                toggle,
              ],
            ),
            const SizedBox(height: Insets.sm),
            times,
            if (day.isOvernight)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: Text(
                  AppStrings.closesNextMorning,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({super.key, required this.time, required this.onTap});

  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        side: BorderSide(color: context.semantic.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          child: Text(
            time.format(context),
            maxLines: 1,
            style: context.text.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

/// A bordered switch row with a one-line explanation beneath the label.
///
/// The shape every boolean setting in this app takes — used here, and by App
/// Preferences for its notification toggles, so the two screens cannot drift
/// into two different-looking switches.
class SettingSwitchTile extends StatelessWidget {
  const SettingSwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.switchKey,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Key placed on the switch itself, so a test taps the control rather than
  /// the card around it.
  final Key? switchKey;

  /// An extra affordance between the text and the switch — App Preferences
  /// puts its "Saved" confirmation here.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: context.semantic.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.md,
            Insets.md,
            Insets.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Flexible, not a plain child: the trailing slot is decoration
              // and must give way before the row paints past its card. The
              // label and the switch are what the row is for.
              if (trailing != null) ...[
                const SizedBox(width: Insets.sm),
                Flexible(child: trailing!),
              ],
              const SizedBox(width: Insets.sm),
              Switch(key: switchKey, value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
