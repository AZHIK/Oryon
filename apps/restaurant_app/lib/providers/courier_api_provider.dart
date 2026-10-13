/// Courier wiring: the direct CRUD API client backed by POS Service.
///
/// Couriers live in pos-service alongside customers, so this reuses
/// `posServiceDioProvider` — the same Dio (auth + logging interceptors) as
/// every other POS read/write path.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/courier_api_service.dart';
import 'pos_api_provider.dart';

/// The one real client for courier list/create/update/delete.
final courierApiServiceProvider = Provider<CourierApiService>(
  (ref) => CourierApiService(dio: ref.watch(posServiceDioProvider)),
);
