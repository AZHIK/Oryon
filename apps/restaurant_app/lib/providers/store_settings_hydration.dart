import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_dtos.dart';
import '../models/store_settings.dart';

/// Adopts a newly selected store's backend settings onto the terminal.
///
/// Tax switch + rate now have a backend home, so they roam with the store:
/// off stays off everywhere until switched on in Store Settings.
StoreSettings hydrateStoreSettings({
  required StoreSettings current,
  required StoreSettingReadDto dto,
}) {
  final code = dto.preferredCurrency.trim().toUpperCase();
  final currency = Currency.values.firstWhere(
    (c) => c.code.toUpperCase() == code,
    orElse: () => current.currency,
  );
  return current.copyWith(
    currency: currency,
    taxInclusive: dto.displayPricesInclusiveOfTax,
    taxEnabled: dto.taxEnabled,
    taxRate: dto.taxRate,
  );
}

/// True once the terminal's store token has been refreshed after an offline
/// switch — until then the till runs on cached data under the new store.
///
/// Set by the store-switch flow; cleared by a successful online token
/// exchange (switch or refresh-while-pending). Drives the pending-token
/// banner.
final storeTokenRefreshPendingProvider = StateProvider<bool>((ref) => false);
