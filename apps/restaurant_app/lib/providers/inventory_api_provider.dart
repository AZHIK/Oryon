/// Inventory Service wiring: the shared Dio client, the read-side catalog
/// sync pipeline, and the write-side API service — the inventory-specific
/// analogue of `identityServiceDioProvider`/`store_api_provider_real.dart`.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/api_log_interceptor.dart';
import '../auth/token_refresh_interceptor.dart';
import '../auth/token_storage.dart';
import '../config/api_config.dart';
import '../constants/app_durations.dart';
import '../services/inventory_api_service.dart';
import '../services/purchase_api_service.dart';
import '../services/supplier_api_service.dart';
import '../sync/catalog_sync_service.dart';
import '../sync/categories_catalog_api.dart';
import '../sync/categories_sync_service.dart';
import '../sync/http_categories_catalog_api.dart';
import '../sync/http_inventory_catalog_api.dart';
import '../sync/http_suppliers_catalog_api.dart';
import '../sync/http_units_catalog_api.dart';
import '../sync/inventory_catalog_api.dart';
import '../sync/purchasing_sync_service.dart';
import '../sync/suppliers_catalog_api.dart';
import '../sync/units_catalog_api.dart';
import '../sync/units_sync_service.dart';
import 'database_providers.dart';
import 'permissions_cache_tick_provider.dart';
import 'permissions_provider.dart';

/// Dio client for Inventory Service calls.
///
/// Token refresh is always an Identity Service concern even though this
/// client's own `baseUrl` points at Inventory Service — `TokenRefreshInterceptor`
/// is given Identity Service's base URL so a 401 here still refreshes
/// against the service that actually issues tokens, exactly like
/// `identityServiceDioProvider`.
final inventoryServiceDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.inventoryServiceBaseUrl,
    connectTimeout: AppDurations.connectTimeout,
    receiveTimeout: AppDurations.receiveTimeout,
    sendTimeout: AppDurations.sendTimeout,
  ));

  dio.interceptors.add(TokenRefreshInterceptor(
    tokenStorage: TokenStorage(),
    baseUrl: ApiConfig.identityServiceBaseUrl,
    profileRepo: ref.watch(localProfileRepositoryProvider),
    onPermissionsSynced: () => ref.read(permissionsCacheTickProvider.notifier).state++,
  ));

  if (kDebugMode) {
    dio.interceptors.add(const ApiLogInterceptor());
  }

  return dio;
});

/// The one real client for the read-side catalog/stock pull.
final inventoryCatalogApiProvider = Provider<InventoryCatalogApi>((ref) {
  final businessId = ref.watch(currentBusinessIdProvider);
  if (businessId == null) throw StateError('No active business context');
  return HttpInventoryCatalogApi(
    dio: ref.watch(inventoryServiceDioProvider),
    businessId: businessId,
  );
});

/// Pulls the catalog/stock levels into the local cache. Depends on
/// [inventoryCatalogApiProvider], so only read once a business context
/// exists (callers already know this from `currentBusinessIdProvider`).
final catalogSyncServiceProvider = Provider<CatalogSyncService>((ref) {
  return CatalogSyncService(
    db: ref.watch(appDatabaseProvider),
    api: ref.watch(inventoryCatalogApiProvider),
  );
});

/// The one real client for item CRUD and stock operations (adjust/waste/
/// transfer).
final inventoryApiServiceProvider = Provider<InventoryApiService>(
  (ref) => InventoryApiService(dio: ref.watch(inventoryServiceDioProvider)),
);

/// The one real client for the read-side supplier directory pull.
final suppliersCatalogApiProvider = Provider<SuppliersCatalogApi>((ref) {
  final businessId = ref.watch(currentBusinessIdProvider);
  if (businessId == null) throw StateError('No active business context');
  return HttpSuppliersCatalogApi(
    dio: ref.watch(inventoryServiceDioProvider),
    businessId: businessId,
  );
});

/// Pulls the supplier directory into the local cache. Depends on
/// [suppliersCatalogApiProvider], so only read once a business context
/// exists.
final purchasingSyncServiceProvider = Provider<PurchasingSyncService>((ref) {
  return PurchasingSyncService(
    db: ref.watch(appDatabaseProvider),
    suppliersApi: ref.watch(suppliersCatalogApiProvider),
  );
});

/// The one real client for supplier CRUD.
final supplierApiServiceProvider = Provider<SupplierApiService>(
  (ref) => SupplierApiService(dio: ref.watch(inventoryServiceDioProvider)),
);

/// The one real client for the purchases module (multi-line POs, GRNs,
/// returns, invoices, payments). Online-only: no cache, no outbox.
final purchaseApiServiceProvider = Provider<PurchaseApiService>(
  (ref) => PurchaseApiService(dio: ref.watch(inventoryServiceDioProvider)),
);

/// The one real client for the read-side category taxonomy pull. Unlike
/// [suppliersCatalogApiProvider], this needs no business context — categories
/// are global (see `app/models/categories.py`) — so it can be read even
/// before a business context exists.
final categoriesCatalogApiProvider = Provider<CategoriesCatalogApi>(
  (ref) => HttpCategoriesCatalogApi(dio: ref.watch(inventoryServiceDioProvider)),
);

/// Pulls the category taxonomy into the local cache.
final categoriesSyncServiceProvider = Provider<CategoriesSyncService>(
  (ref) => CategoriesSyncService(
    db: ref.watch(appDatabaseProvider),
    api: ref.watch(categoriesCatalogApiProvider),
  ),
);

/// The one real client for the read-side unit taxonomy pull. Unlike
/// [suppliersCatalogApiProvider], this needs no business context — units
/// are global (see `app/models/units.py`) — so it can be read even before a
/// business context exists.
final unitsCatalogApiProvider = Provider<UnitsCatalogApi>(
  (ref) => HttpUnitsCatalogApi(dio: ref.watch(inventoryServiceDioProvider)),
);

/// Pulls the unit taxonomy into the local cache.
final unitsSyncServiceProvider = Provider<UnitsSyncService>(
  (ref) => UnitsSyncService(
    db: ref.watch(appDatabaseProvider),
    api: ref.watch(unitsCatalogApiProvider),
  ),
);
