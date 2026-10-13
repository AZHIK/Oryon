/// Source of purchase orders, fetched live from Inventory Service.
///
/// Strictly online-only — unlike `ReordersNotifier` there is NO Drift
/// read cache and no stale-while-revalidate: every read is a direct API
/// call, and every write is a direct API call followed by a re-fetch. When
/// offline the state is an error/empty and the UI shows the offline
/// placeholder instead of the list (see `PurchasesScreen`). There is no
/// outbox and no background sync: without a
/// business context the list is simply empty.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/purchase_order.dart';
import '../services/purchase_api_service.dart';
import 'inventory_api_provider.dart';
import 'permissions_provider.dart';

class PurchasesNotifier extends AsyncNotifier<List<PurchaseOrder>> {
  @override
  Future<List<PurchaseOrder>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    if (businessId == null) return const [];
    return _fetch(businessId);
  }

  Future<List<PurchaseOrder>> _fetch(String businessId) async {
    final dtos = await ref
        .read(purchaseApiServiceProvider)
        .fetchOrders(businessId: businessId);
    final orders = dtos.map(PurchaseOrder.fromDto).toList();
    orders.sort((a, b) => b.orderedAt.compareTo(a.orderedAt));
    return orders;
  }

  /// Re-fetches from the API — for pull-to-refresh and post-write updates.
  /// Throws offline/backend errors to the caller (the screen shows them).
  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading<List<PurchaseOrder>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _fetch(businessId));
  }

  /// Full detail (lines and receipts) for one order.
  Future<PurchaseOrder> fetchDetail(String orderId) async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) throw StateError('No active business context');
    final dto = await ref
        .read(purchaseApiServiceProvider)
        .fetchOrder(businessId: businessId, orderId: orderId);
    return PurchaseOrder.fromDto(dto);
  }

  /// Creates an order (unfulfilled), then refreshes the list.
  Future<PurchaseOrder> create({
    required String supplierId,
    required List<PurchaseOrderLineInput> lines,
    String? notes,
    DateTime? expectedAt,
  }) async {
    final businessId = ref.read(currentBusinessIdProvider);
    final storeId = ref.read(currentStoreIdProvider);
    if (businessId == null || storeId == null) {
      throw StateError('Purchases need an active store context');
    }
    final created = await ref.read(purchaseApiServiceProvider).createOrder(
          businessId: businessId,
          storeId: storeId,
          supplierId: supplierId,
          lines: lines,
          notes: notes,
          expectedAt: expectedAt,
        );
    await refresh();
    return PurchaseOrder.fromDto(created);
  }

  Future<void> _act(
    String orderId,
    Future<PurchaseOrderDto> Function() call,
  ) async {
    await call();
    await refresh();
  }

  /// Cancels an unfulfilled order with no receipts, then refreshes.
  Future<void> cancel(String orderId) async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) throw StateError('No active business context');
    final api = ref.read(purchaseApiServiceProvider);
    await _act(
      orderId,
      () => api.cancelOrder(businessId: businessId, orderId: orderId),
    );
  }

  /// Records a goods receipt (partial quantities allowed), then refreshes.
  Future<GoodsReceiptDto> receive({
    required String orderId,
    required List<GoodsReceiptLineInput> lines,
    String? notes,
  }) async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) throw StateError('No active business context');
    final grn = await ref.read(purchaseApiServiceProvider).receiveOrder(
          businessId: businessId,
          orderId: orderId,
          lines: lines,
          notes: notes,
        );
    await refresh();
    return grn;
  }
}

final purchasesProvider =
    AsyncNotifierProvider<PurchasesNotifier, List<PurchaseOrder>>(
        PurchasesNotifier.new);

/// The list, unwrapped.
final purchasesListProvider = Provider<List<PurchaseOrder>>(
  (ref) => ref.watch(purchasesProvider).valueOrNull ?? const [],
);

/// Open orders (unfulfilled), newest first.
final openPurchasesProvider = Provider<List<PurchaseOrder>>((ref) {
  return ref
      .watch(purchasesListProvider)
      .where((o) => o.status.isOpen)
      .toList();
});

/// Lookup a single order from the list state.
final purchaseByIdProvider =
    Provider.family<PurchaseOrder?, String>((ref, orderId) {
  return ref
      .watch(purchasesListProvider)
      .where((o) => o.id == orderId)
      .firstOrNull;
});
