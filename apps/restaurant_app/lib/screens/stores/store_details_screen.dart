import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dio/dio.dart';

import '../../models/store_location.dart';
import '../../constants/app_strings.dart';
import '../../providers/store_api_provider_real.dart';
import '../../providers/store_locations_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/api_errors.dart';
import '../../widgets/data_page/data_page_scaffold.dart';
import '../settings/store_settings_screen.dart' show SettingSwitchTile;

/// Detailed view of a single store with tabs for settings and staff.
///
/// Shows store information, operating hours, staff assignments, and settings
/// all in one comprehensive management interface.
class StoreDetailsScreen extends ConsumerWidget {
  const StoreDetailsScreen({
    super.key,
    required this.storeId,
    required this.businessId,
  });

  final String storeId;
  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(
      storeLocationsProvider.select(
        (stores) => stores.firstWhere(
          (s) => s.id == storeId,
          orElse: () => StoreLocation(
            id: storeId,
            name: 'Unknown Store',
          ),
        ),
      ),
    );

    return DefaultTabController(
      length: 3,
      child: DataPageScaffold(
        title: store.name,
        subtitle: store.address.isEmpty ? 'No address set' : store.address,
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.canPop()
                ? context.pop()
                : context.goNamed(
                    AppRoute.settingsName,
                  ),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(AppStrings.back),
          ),
        ],
        bottom: TabBar(
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Settings'),
            Tab(text: 'Staff'),
          ],
          indicatorSize: TabBarIndicatorSize.tab,
        ),
        child: TabBarView(
          children: [
            _OverviewTab(store: store, businessId: businessId),
            _SettingsTab(store: store, businessId: businessId),
            _StaffTab(store: store, businessId: businessId),
          ],
        ),
      ),
    );
  }
}

/// Overview tab showing store basic information.
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({
    required this.store,
    required this.businessId,
  });

  final StoreLocation store;
  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store Information',
                    style: context.text.titleMedium,
                  ),
                  const SizedBox(height: Insets.md),
                  _InfoRow(label: 'Name', value: store.name),
                  _InfoRow(label: 'Address', value: store.address ?? '—'),
                  _InfoRow(label: 'Phone', value: (store.phone?.isNotEmpty ?? false) ? store.phone! : '—'),
                  _InfoRow(label: 'Status', value: store.isActive ? 'Active' : 'Inactive'),
                  _InfoRow(label: 'Staff', value: '${store.staffCount}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings tab for configuring store-specific settings (sourced from StoreSetting backend table).
class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab({
    required this.store,
    required this.businessId,
  });

  final StoreLocation store;
  final String businessId;

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  late TextEditingController _latitude;
  late TextEditingController _longitude;
  late TextEditingController _email;
  late TextEditingController _phone;
  late TextEditingController _amount;
  late TextEditingController _maxPaymentTime;
  late TextEditingController _logoUrl;

  late String _currency;
  late bool _offerRetail;
  late bool _offerWholesale;
  late bool _displayInclusive;
  late bool _active;

  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _latitude = TextEditingController(text: widget.store.latitude?.toString() ?? '');
    _longitude = TextEditingController(text: widget.store.longitude?.toString() ?? '');
    _email = TextEditingController(text: widget.store.email ?? '');
    _phone = TextEditingController(text: widget.store.phone ?? '');
    _amount = TextEditingController(text: widget.store.amount?.toString() ?? '');
    _maxPaymentTime = TextEditingController(text: widget.store.maxPaymentTimeMinutes?.toString() ?? '');
    _logoUrl = TextEditingController(text: widget.store.logo ?? '');

    _currency = widget.store.preferredCurrency;
    _offerRetail = widget.store.offerRetail;
    _offerWholesale = widget.store.offerWholesale;
    _displayInclusive = widget.store.displayPricesInclusiveOfTax;
    _active = widget.store.active;
  }

  @override
  void dispose() {
    for (final ctrl in [_latitude, _longitude, _email, _phone, _amount, _maxPaymentTime, _logoUrl]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final storeApi = ref.read(storeApiServiceProvider);
      await storeApi.updateStoreSettings(
        businessId: widget.businessId,
        storeId: widget.store.id,
        latitude: double.tryParse(_latitude.text.trim()),
        longitude: double.tryParse(_longitude.text.trim()),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        preferredCurrency: _currency,
        displayPricesInclusiveOfTax: _displayInclusive,
        offerRetail: _offerRetail,
        offerWholesale: _offerWholesale,
        amount: double.tryParse(_amount.text.trim()),
        maxPaymentTimeMinutes: int.tryParse(_maxPaymentTime.text.trim()),
        active: _active,
        logo: _logoUrl.text.trim().isEmpty ? null : _logoUrl.text.trim(),
      );

      await refreshStoreSetting(ref, widget.store.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.storeDetailsSaved)),
        );
      }
    } on DioException catch (e) {
      setState(() {
        _errorMessage = errorDetail(
          e.response?.data,
          fallback: 'Failed to save settings',
        );
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            Card(
              color: context.colors.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: context.colors.onErrorContainer),
                ),
              ),
            ),
            const SizedBox(height: Insets.lg),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppStrings.storeDetailsTitle, style: context.text.titleMedium),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(_saving ? 'Saving...' : 'Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  // Location section
                  Text(AppStrings.storeLocationSection, style: context.text.labelLarge),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latitude,
                          keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: InputDecoration(
                            label: Text(AppStrings.latitudeLabel),
                            hintText: 'e.g., -6.7924',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: TextField(
                          controller: _longitude,
                          keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: InputDecoration(
                            label: Text(AppStrings.longitudeLabel),
                            hintText: 'e.g., 39.2083',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  // Contact section
                  Text(AppStrings.storeContactSection, style: context.text.labelLarge),
                  const SizedBox(height: Insets.md),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      label: Text(AppStrings.storeEmailLabel),
                      hintText: 'contact@store.com',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      label: Text(AppStrings.storePhoneLabel),
                      hintText: '+255 7XX XXX XXX',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  // Sales channels section
                  Text(AppStrings.storeSalesChannelsSection, style: context.text.labelLarge),
                  const SizedBox(height: Insets.md),
                  SettingSwitchTile(
                    title: 'Offer retail',
                    subtitle: 'Allow retail sales at this location',
                    value: _offerRetail,
                    onChanged: (v) => setState(() => _offerRetail = v),
                  ),
                  SettingSwitchTile(
                    title: 'Offer wholesale',
                    subtitle: 'Allow wholesale sales at this location',
                    value: _offerWholesale,
                    onChanged: (v) => setState(() => _offerWholesale = v),
                  ),
                  const SizedBox(height: Insets.lg),
                  // Pricing section
                  Text(AppStrings.storePricingSection, style: context.text.labelLarge),
                  const SizedBox(height: Insets.md),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    items: [
                      DropdownMenuItem(value: 'TZS', child: Text(AppStrings.tzShilling)),
                      DropdownMenuItem(value: 'USD', child: Text(AppStrings.usDollar)),
                      DropdownMenuItem(value: 'EUR', child: Text(AppStrings.euroLabel)),
                    ],
                    onChanged: (v) => setState(() => _currency = v ?? 'TZS'),
                    decoration: InputDecoration(
                      label: Text(AppStrings.storeCurrencyLabel),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  SettingSwitchTile(
                    title: 'Display prices inclusive of tax',
                    subtitle: 'Show prices with tax included',
                    value: _displayInclusive,
                    onChanged: (v) => setState(() => _displayInclusive = v),
                  ),
                  const SizedBox(height: Insets.lg),
                  // Credit/tab section
                  Text(AppStrings.storeCreditTabsSection, style: context.text.labelLarge),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amount,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            label: Text(AppStrings.creditLimitLabel),
                            hintText: '10000',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: TextField(
                          controller: _maxPaymentTime,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            label: Text(AppStrings.maxPaymentTimeLabel),
                            hintText: '1440',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  // Operational section
                  Text(AppStrings.storeOperationalSection, style: context.text.labelLarge),
                  const SizedBox(height: Insets.md),
                  SettingSwitchTile(
                    title: 'Currently trading',
                    subtitle: 'Distinct from lifecycle status',
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                  const SizedBox(height: Insets.lg),
                  // Logo section
                  Text(AppStrings.storeLogoSection, style: context.text.labelLarge),
                  const SizedBox(height: Insets.md),
                  TextField(
                    controller: _logoUrl,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                        label: Text(AppStrings.logoUrlLabel),
                      hintText: 'https://...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.storeHoursReceiptsSection, style: context.text.titleMedium),
                  const SizedBox(height: Insets.md),
                  ListTile(
                    title: Text(AppStrings.hoursOfOperation),
                    subtitle: Text(AppStrings.comingSoon),
                    trailing: const Icon(Icons.lock_rounded, size: 18),
                  ),
                  const Divider(),
                  ListTile(
                    title: Text(AppStrings.receiptSettings),
                    subtitle: Text(AppStrings.comingSoon),
                    trailing: const Icon(Icons.lock_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Staff tab for managing store-specific staff assignments.
class _StaffTab extends ConsumerWidget {
  const _StaffTab({
    required this.store,
    required this.businessId,
  });

  final StoreLocation store;
  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Store Staff (${store.staffCount})',
                        style: context.text.titleMedium,
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppStrings.addStaffComingSoon)),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(AppStrings.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  Text(
                    'Staff assignments and roles for this location',
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple info row for displaying key-value pairs.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: context.text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
