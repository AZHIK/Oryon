import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_dtos.dart';
import '../services/store_api_service.dart';
import 'auth_provider.dart';
import 'session_provider.dart';

/// Provides access to the store API service.
final storeApiServiceProvider = Provider<StoreApiService>((ref) {
  final dio = ref.watch(identityServiceDioProvider);
  return StoreApiService(dio: dio);
});

/// Fetches all stores for the current business from the backend.
///
/// This is an async provider that loads the full store details from the backend.
/// Skips fetching during onboarding to avoid token context issues.
final storesProvider = FutureProvider<List<StoreReadDto>>((ref) async {
  try {
    final session = ref.watch(sessionProvider);
    final auth = ref.watch(authProvider);

    // Don't fetch during onboarding — context switch is still settling in.
    if (!session.hasCompletedOnboarding) return [];
    if (auth.selectedBusinessId == null) return [];

    final storeApi = ref.watch(storeApiServiceProvider);
    return await storeApi.listStores(businessId: auth.selectedBusinessId!);
  } catch (e) {
    // Return empty list on error; UI should handle this
    return [];
  }
});

/// Fetches details for a specific store.
///
/// Parameters:
/// - [businessId]: The business ID
/// - [storeId]: The store ID to fetch
final storeDetailProvider = FutureProvider.family<StoreReadDto?, String>(
  (ref, storeId) async {
    try {
      final auth = ref.watch(authProvider);
      if (auth.selectedBusinessId == null) return null;

      final storeApi = ref.watch(storeApiServiceProvider);
      return await storeApi.getStore(
        businessId: auth.selectedBusinessId!,
        storeId: storeId,
      );
    } catch (e) {
      return null;
    }
  },
);

/// Fetches store settings for a specific store.
///
/// Parameters:
/// - [businessId]: The business ID
/// - [storeId]: The store ID
final storeSettingProvider = FutureProvider.family<StoreSettingReadDto?, String>(
  (ref, storeId) async {
    try {
      final auth = ref.watch(authProvider);
      if (auth.selectedBusinessId == null) return null;

      final storeApi = ref.watch(storeApiServiceProvider);
      return await storeApi.getStoreSettings(
        businessId: auth.selectedBusinessId!,
        storeId: storeId,
      );
    } catch (e) {
      return null;
    }
  },
);

/// Refreshes all stores data.
///
/// Call this to manually refresh store data after updates.
Future<void> refreshStores(WidgetRef ref) =>
    ref.refresh(storesProvider.future);

/// Refreshes a specific store's details.
///
/// Call this to manually refresh a store's details after updates.
Future<void> refreshStoreDetail(WidgetRef ref, String storeId) =>
    ref.refresh(storeDetailProvider(storeId).future);

/// Refreshes a specific store's settings.
///
/// Call this to manually refresh store settings after updates.
Future<void> refreshStoreSetting(WidgetRef ref, String storeId) =>
    ref.refresh(storeSettingProvider(storeId).future);
