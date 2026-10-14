import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_durations.dart';
import '../constants/app_limits.dart';
import '../database/app_database.dart';
import '../l10n/l10n.dart';
import '../models/cart.dart';
import '../models/order.dart';
import '../models/order_totals.dart';
import '../models/table_query.dart';
import '../services/pos_api_service.dart';
import '../sync/customer_sync_service.dart';
import '../sync/order_mapper.dart';
import '../sync/pending_sale_writer.dart';
import '../sync/sales_sync_service.dart';
import '../sync/sync_service.dart';
import '../utils/cogs.dart';
import 'customer_api_provider.dart';
import 'database_providers.dart';
import 'inventory_provider.dart';
import 'permissions_provider.dart';
import 'pos_api_provider.dart';
import 'production_provider.dart';
import 'sync_status_provider.dart';
import 'table_query_provider.dart';

/// Sortable column keys. Constants rather than raw strings at the call sites,
/// so the column config and the sort switch cannot drift apart.
abstract final class SalesSort {
  static const orderId = 'orderId';
  static const date = 'date';
  static const items = 'items';
  static const total = 'total';
  static const payment = 'payment';
  static const status = 'status';
  static const fulfillment = 'fulfillment';
}

/// Date windows offered by the header selector and the filter panel.
enum SalesDateRange {
  today('todayRange', 'Today'),
  week('weekRange', 'This week'),
  month('monthRange', 'This month'),
  all('allTimeRange', 'All time'),
  custom('customRange', 'Custom');

  const SalesDateRange(this.labelKey, this.labelDefault);
  final String labelKey;
  final String labelDefault;

  String get label => L10n.t(labelKey, labelDefault);
}

// ---------------------------------------------------------------------------
// Raw data
// ---------------------------------------------------------------------------

/// Source of completed sales, backed by POS Service once a store context
/// exists.
///
/// The UI always reads from the local cache — `build()` never blocks on the
/// network. A live fetch runs in the background on every read to keep that
/// cache current; if it fails the screen just keeps showing whatever was
/// last cached — same stale-while-revalidate contract as `InventoryNotifier`.
///
/// With no store context at all (no session yet), this returns an empty
/// list — there is no sales history until a store is selected.
class OrdersNotifier extends AsyncNotifier<List<Order>> {
  SalesSyncService get _sync => ref.read(salesSyncServiceProvider);
  PosApiService get _api => ref.read(posApiServiceProvider);

  String get _businessId {
    final id = ref.read(currentBusinessIdProvider);
    if (id == null) throw StateError('No active business context');
    return id;
  }

  @override
  Future<List<Order>> build() async {
    final storeId = ref.watch(currentStoreIdProvider);
    if (storeId == null) return const [];

    var disposed = false;
    ref.onDispose(() => disposed = true);
    unawaited(_refreshFromApi(storeId, isDisposed: () => disposed));

    return _loadFromCache(storeId);
  }

  Future<void> _refreshFromApi(String storeId, {required bool Function() isDisposed}) async {
    try {
      await _sync.syncSales(storeId: storeId);
      if (!isDisposed()) {
        state = AsyncData(await _loadFromCache(storeId));
      }
    } catch (_) {
      // No permission, offline, or a transient failure — the cached read
      // from `build()` is what the UI already shows; nothing more to do.
    }
  }

  Future<List<Order>> _loadFromCache(String storeId) async {
    final db = ref.read(appDatabaseProvider);

    final sales = await (db.select(db.cachedSales)
          ..where((row) => row.storeId.equals(storeId))
          ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)]))
        .get();

    final saleIds = sales.map((sale) => sale.id).toSet();
    final lineRows = saleIds.isEmpty
        ? const <CachedSaleLineItem>[]
        : await (db.select(db.cachedSaleLineItems)
              ..where((row) => row.saleId.isIn(saleIds)))
            .get();
    final linesBySaleId = <String, List<CachedSaleLineItem>>{};
    for (final line in lineRows) {
      linesBySaleId.putIfAbsent(line.saleId, () => []).add(line);
    }

    final items = await (db.select(db.cachedItems)
          ..where((row) => row.businessLocationId.equals(storeId)))
        .get();
    final itemsById = {for (final item in items) item.id: item};

    // Recovers each locally-placed order's original "ORD-0042" ticket
    // number — see `order_mapper.dart`'s `localOrderId` doc comment.
    final pending = await (db.select(db.pendingSales)
          ..where((row) => row.storeId.equals(storeId)))
        .get();
    final localOrderIdByClientSaleId = {
      for (final row in pending)
        if (row.localOrderId != null) row.clientSaleId: row.localOrderId!,
    };

    return [
      for (final sale in sales)
        orderFromCachedRow(
          sale: sale,
          lines: linesBySaleId[sale.id] ?? const [],
          itemsById: itemsById,
          localOrderId: localOrderIdByClientSaleId[sale.clientSaleId],
        ),
    ];
  }

  /// Re-runs the background sync and waits for it — for the Sales screen's
  /// refresh button, where the user expects it to reflect real completion
  /// rather than an instant, still-stale return. Requires a store context.
  Future<void> refresh() async {
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) throw StateError('No active store context');
    state = const AsyncLoading<List<Order>>().copyWithPrevious(state);
    await _sync.syncSales(storeId: storeId);
    state = AsyncData(await _loadFromCache(storeId));
  }

  /// Converts the open cart into a sale and returns it, so the caller can
  /// navigate straight to its detail route.
  ///
  /// [paymentType] overrides the tender recorded on the cart, for the quick
  /// charge dialog that takes payment without visiting the payment screen.
  ///
  /// The order is added to local state immediately so the UI never waits on
  /// the network; with a store context, writing it to the sync outbox and
  /// kicking off a sync happen in the background afterward, same
  /// local-update-now/sync-later shape as `InventoryNotifier.upsert()`.
  /// Without a store context the order stays local-only until one exists.
  Order placeOrder({
    required Cart cart,
    PaymentType? paymentType,
    OrderType orderType = OrderType.dineIn,
    String? tableLabel,
    String serverName = 'House',
    String? customerId,
  }) {
    final current = state.valueOrNull ?? const <Order>[];
    final order = Order.fromCart(
      id: nextOrderId(current),
      cart: cart,
      paymentType: paymentType,
      placedAt: DateTime.now(),
      orderType: orderType,
      tableLabel: tableLabel,
      serverName: serverName,
      customerId: customerId,
      unitCosts: _saleTimeUnitCosts(cart),
    );
    state = AsyncData([order, ...current]);

    final storeId = ref.read(currentStoreIdProvider);
    if (storeId != null) {
      final db = ref.read(appDatabaseProvider);
      final syncService = ref.read(syncServiceProvider);
      final customerSyncService = ref.read(customerSyncServiceProvider);
      unawaited(_writeAndSync(db, order, storeId, syncService, customerSyncService));
    }

    return order;
  }

  /// Per-unit production cost snapshot for each cart line, taken at sale
  /// time from live recipe costs (see `lib/utils/cogs.dart`).
  ///
  /// Every line is frozen — including zero-cost unknowns (no recipe and
  /// nothing on file). A frozen zero flagged estimated downstream beats a
  /// null that silently reprices at today's recipe cost: history must not
  /// move when groceries are repriced. Null is reserved for legacy rows
  /// synced before snapshots existed.
  Map<String, double> _saleTimeUnitCosts(Cart cart) {
    final recipes = ref.read(recipesCatalogListProvider);
    final items = ref.read(inventoryItemsListProvider);
    final index = CogsIndex(
      recipeCost: {
        for (final r in recipes)
          if (r.sellableItemId != null)
            r.sellableItemId!: r.costPerUnit,
      },
      recipeComplete: {
        for (final r in recipes)
          if (r.sellableItemId != null)
            r.sellableItemId!: r.costComplete,
      },
      fallbackCost: {
        for (final i in items)
          if (i.catalogItemId != null)
            i.catalogItemId!: Decimal.parse(i.unitCost.toString()),
      },
    );
    final costs = <String, double>{};
    for (final line in cart.items) {
      final unit = index.unitCostFor(line.item.id);
      costs[line.item.id] = double.parse(unit.cost.toString());
    }
    return costs;
  }

  Future<void> _writeAndSync(
    AppDatabase db,
    Order order,
    String storeId,
    SyncService syncService,
    CustomerSyncService customerSyncService,
  ) async {
    final written = await PendingSaleWriter(db).writeIfMappable(order, storeId: storeId);
    if (!written) return;
    // Customers MUST drain before sales: a sale carrying a customer_id
    // whose row hasn't reached the server yet fails its FK insert
    // server-side and has to retry — draining in order avoids that extra
    // round trip (see `CustomerSyncService`'s doc comment).
    await customerSyncService.syncNow();
    unawaited(syncService.syncNow());
  }

  Future<void> refund(String orderId, {required String reason}) =>
      _voidOrRefund(orderId, OrderStatus.refunded, reason: reason);

  Future<void> voidOrder(String orderId, {required String reason}) =>
      _voidOrRefund(orderId, OrderStatus.voided, reason: reason);

  /// Voids or refunds a sale through the real `void-or-refund` endpoint when
  /// it has already synced (`serverSaleId` is set) and there's a store
  /// context; otherwise falls back to a local-only status flip — an order
  /// whose outbox write hasn't synced yet, same "no `catalogItemId` yet →
  /// local-only" shape as `InventoryNotifier`'s write methods.
  Future<void> _voidOrRefund(
    String orderId,
    OrderStatus newStatus, {
    required String reason,
  }) async {
    final order = _byId(orderId);
    final storeId = ref.read(currentStoreIdProvider);

    if (order == null || storeId == null || order.serverSaleId == null) {
      _setStatus(orderId, newStatus);
      return;
    }

    await _api.voidOrRefund(
      businessId: _businessId,
      saleId: order.serverSaleId!,
      clientActionId: const Uuid().v4(),
      newStatus: orderStatusToBackend(newStatus),
      reason: reason,
    );
    await refresh();
  }

  void markPaid(String orderId) => _setStatus(orderId, OrderStatus.paid);

  void setFulfillmentStatus(String orderId, FulfillmentStatus status) {
    state = AsyncData([
      for (final order in state.valueOrNull ?? const <Order>[])
        if (order.id == orderId)
          order.copyWith(fulfillmentStatus: status)
        else
          order,
    ]);
  }

  void setOrderCourier(String orderId, String courierId) {
    state = AsyncData([
      for (final order in state.valueOrNull ?? const <Order>[])
        if (order.id == orderId)
          order.copyWith(courierId: courierId)
        else
          order,
    ]);
  }

  /// Pulls the latest sales from the backend — the Sales screen's refresh
  /// button.
  Future<void> checkForNewOrders() => refresh();

  Order? _byId(String id) {
    for (final order in state.valueOrNull ?? const <Order>[]) {
      if (order.id == id) return order;
    }
    return null;
  }

  void _setStatus(String orderId, OrderStatus status) {
    state = AsyncData([
      for (final order in state.valueOrNull ?? const <Order>[])
        if (order.id == orderId) order.copyWith(status: status) else order,
    ]);
  }
}

final ordersProvider = AsyncNotifierProvider<OrdersNotifier, List<Order>>(
  OrdersNotifier.new,
);

/// The list, unwrapped for widgets/providers that only ever want to render
/// what's currently known without handling loading/error states themselves
/// — mirrors `inventoryItemsListProvider`.
final ordersListProvider = Provider<List<Order>>(
  (ref) => ref.watch(ordersProvider).valueOrNull ?? const [],
);

/// Continues the ORD-#### sequence from the highest existing id.
///
/// Top-level so the POS panel can preview the next ticket number without
/// re-deriving the rule and risking a mismatch with the sale it creates.
String nextOrderId(List<Order> orders) {
  var highest = 0;
  for (final order in orders) {
    final n = int.tryParse(order.id.split('-').last);
    if (n != null && n > highest) highest = n;
  }
  return 'ORD-${(highest + 1).toString().padLeft(AppLimits.orderNumberWidth, '0')}';
}

// ---------------------------------------------------------------------------
// Search / sort / pagination
// ---------------------------------------------------------------------------

final salesQueryProvider = NotifierProvider<TableQueryNotifier, TableQuery>(
  () => TableQueryNotifier(
    // Newest first is what a manager wants on opening the ledger.
    const TableQuery(
      sortField: SalesSort.date,
      ascending: false,
      pageSize: AppLimits.tablePageSizeDense,
    ),
  ),
);

// ---------------------------------------------------------------------------
// Filters
// ---------------------------------------------------------------------------

/// The Sales filter state: a date window plus payment and status multi-selects.
///
/// An empty set means "no constraint", so "nothing ticked" and "everything
/// ticked" behave the same for the user.
@immutable
class SalesFilters {
  const SalesFilters({
    this.range = SalesDateRange.today,
    this.customRange,
    this.payments = const {},
    this.statuses = const {},
  });

  final SalesDateRange range;

  /// Only meaningful when [range] is [SalesDateRange.custom].
  final DateTimeRange? customRange;

  final Set<PaymentType> payments;
  final Set<OrderStatus> statuses;

  /// The date window has its own always-visible control in the page header,
  /// so it is deliberately not counted here — the badge reports only what the
  /// Filter panel hides.
  int get activeCount => payments.length + statuses.length;

  /// Resolves [range] against [now]. Null means "no date constraint".
  DateTimeRange? window(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    return switch (range) {
      SalesDateRange.today => DateTimeRange(
        start: today,
        end: today.add(AppDurations.singleDay),
      ),
      // Calendar week starting Monday, not a rolling seven days — "this week"
      // means the week you are in.
      SalesDateRange.week => DateTimeRange(
        start: today.subtract(Duration(days: today.weekday - 1)),
        end: today.add(AppDurations.singleDay),
      ),
      SalesDateRange.month => DateTimeRange(
        start: DateTime(now.year, now.month),
        end: today.add(AppDurations.singleDay),
      ),
      SalesDateRange.all => null,
      SalesDateRange.custom => customRange == null
          ? null
          : DateTimeRange(
              start: customRange!.start,
              // The picker returns a start-of-day end date; include that day.
              end: DateTime(
                customRange!.end.year,
                customRange!.end.month,
                customRange!.end.day,
              ).add(AppDurations.singleDay),
            ),
    };
  }

  bool matches(Order order, DateTime now) {
    if (payments.isNotEmpty && !payments.contains(order.paymentType)) {
      return false;
    }
    if (statuses.isNotEmpty && !statuses.contains(order.status)) return false;

    final window = this.window(now);
    if (window == null) return true;
    return !order.placedAt.isBefore(window.start) &&
        order.placedAt.isBefore(window.end);
  }

  SalesFilters copyWith({
    SalesDateRange? range,
    DateTimeRange? customRange,
    Set<PaymentType>? payments,
    Set<OrderStatus>? statuses,
  }) {
    return SalesFilters(
      range: range ?? this.range,
      customRange: customRange ?? this.customRange,
      payments: payments ?? this.payments,
      statuses: statuses ?? this.statuses,
    );
  }
}

class SalesFiltersNotifier extends Notifier<SalesFilters> {
  @override
  SalesFilters build() => const SalesFilters();

  void setRange(SalesDateRange range) {
    state = state.copyWith(range: range);
    _resetPage();
  }

  void setCustomRange(DateTimeRange range) {
    state = state.copyWith(range: SalesDateRange.custom, customRange: range);
    _resetPage();
  }

  void togglePayment(PaymentType payment) {
    final next = Set<PaymentType>.of(state.payments);
    next.contains(payment) ? next.remove(payment) : next.add(payment);
    state = state.copyWith(payments: next);
    _resetPage();
  }

  void toggleStatus(OrderStatus status) {
    final next = Set<OrderStatus>.of(state.statuses);
    next.contains(status) ? next.remove(status) : next.add(status);
    state = state.copyWith(statuses: next);
    _resetPage();
  }

  /// Clears the panel's filters but keeps the date window, which the user set
  /// through a separate, still-visible control.
  void clear() {
    state = SalesFilters(range: state.range, customRange: state.customRange);
    _resetPage();
  }

  void _resetPage() => ref.read(salesQueryProvider.notifier).resetPage();
}

final salesFiltersProvider =
    NotifierProvider<SalesFiltersNotifier, SalesFilters>(
      SalesFiltersNotifier.new,
    );

// ---------------------------------------------------------------------------
// Derived views
// ---------------------------------------------------------------------------

/// Search + filters + sort in one place, so no filtering logic lives in the
/// widget tree and the exporters can reuse exactly what the table shows.
final filteredOrdersProvider = Provider<List<Order>>((ref) {
  final orders = ref.watch(ordersListProvider);
  final query = ref.watch(salesQueryProvider);
  final filters = ref.watch(salesFiltersProvider);
  final search = query.search.trim().toLowerCase();
  final now = DateTime.now();

  final rows = orders.where((order) {
    if (!filters.matches(order, now)) return false;
    if (search.isEmpty) return true;
    return order.id.toLowerCase().contains(search) ||
        order.serverName.toLowerCase().contains(search) ||
        (order.tableLabel?.toLowerCase().contains(search) ?? false) ||
        order.paymentType.label.toLowerCase().contains(search) ||
        order.lines.any((line) => line.name.toLowerCase().contains(search));
  }).toList();

  final direction = query.ascending ? 1 : -1;
  rows.sort((a, b) {
    final cmp = switch (query.sortField) {
      SalesSort.orderId => a.id.compareTo(b.id),
      SalesSort.items => a.itemCount.compareTo(b.itemCount),
      SalesSort.total => a.total.compareTo(b.total),
      SalesSort.payment => a.paymentType.label.compareTo(b.paymentType.label),
      SalesSort.status => a.status.label.compareTo(b.status.label),
      SalesSort.fulfillment => a.fulfillmentStatus.index.compareTo(b.fulfillmentStatus.index),
      _ => a.placedAt.compareTo(b.placedAt),
    };
    // Stable tiebreak keeps rows from shuffling between equal values.
    return cmp != 0 ? cmp * direction : a.id.compareTo(b.id);
  });

  return rows;
});

final salesSliceProvider = Provider<PageSlice<Order>>(
  (ref) => PageSlice.of(
    ref.watch(filteredOrdersProvider),
    ref.watch(salesQueryProvider),
  ),
);

final orderByIdProvider = Provider.family<Order?, String>((ref, id) {
  for (final order in ref.watch(ordersListProvider)) {
    if (order.id == id) return order;
  }
  return null;
});

/// Totals for a *completed* sale — the sale-detail counterpart to
/// `orderTotalsProvider`, which serves the open ticket. Both hand back the
/// same [OrderTotals] type, so the payment breakdown widget cannot tell (or
/// care) which end of the flow it is rendering.
final orderTotalsByIdProvider = Provider.family<OrderTotals, String>(
  (ref, id) => ref.watch(orderByIdProvider(id))?.totals ?? OrderTotals.zero,
);

/// Headline numbers for the sales summary strip.
@immutable
class SalesSummary {
  const SalesSummary({
    required this.revenue,
    required this.orderCount,
    required this.itemCount,
    required this.refundedCount,
  });

  final double revenue;
  final int orderCount;
  final int itemCount;
  final int refundedCount;

  double get averageOrderValue => orderCount == 0 ? 0 : revenue / orderCount;
}

/// Summarises exactly what the table is showing, so filtering to "Refunded"
/// changes the cards too — the alternative leaves three numbers on screen that
/// quietly describe a different set of rows.
final salesSummaryProvider = Provider<SalesSummary>((ref) {
  var revenue = 0.0;
  var orderCount = 0;
  var itemCount = 0;
  var refunded = 0;

  for (final order in ref.watch(filteredOrdersProvider)) {
    orderCount++;
    itemCount += order.itemCount;
    revenue += order.netRevenue;
    if (order.status == OrderStatus.refunded) refunded++;
  }

  return SalesSummary(
    revenue: revenue,
    orderCount: orderCount,
    itemCount: itemCount,
    refundedCount: refunded,
  );
});
