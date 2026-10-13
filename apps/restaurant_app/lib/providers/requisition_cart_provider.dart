/// Session-only requisition cart + submitted-order state.
///
/// DECISION (confirmed): dismissing the cart dialog mid-build does NOT
/// persist a server draft — the cart lives in this in-memory notifier for
/// the session only. Closing the dialog (swipe / outside / close / Esc)
/// preserves every line; the cart clears on submit or logout.
///
/// Two assignment paths write the SAME `supplierId` field on each line:
/// per-item (supplier badge tap) and bulk (assign-to-all bar). Bulk defaults
/// to `unassigned-only`; the explicit "override all" toggle sets
/// [overwriteAll] and replaces existing per-item choices.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_strings.dart';
import '../models/requisition.dart';
import '../models/supplier.dart';
import '../services/requisition_api_service.dart';
import 'inventory_api_provider.dart';
import 'permissions_provider.dart';
import 'suppliers_provider.dart';

/// One bulk-assign action for the sticky action bar.
enum BulkScope { unassignedOnly, all }

class RequisitionCartState {
  const RequisitionCartState({
    this.lines = const [],
    this.notes,
    this.expectedAt,
    this.submitting = false,
    this.error,
    this.lastSubmitted,
  });

  final List<RequisitionCartLine> lines;
  final String? notes;
  final DateTime? expectedAt;
  final bool submitting;
  final String? error;
  final SubmittedRequisition? lastSubmitted;

  int get unassignedCount => lines.where((l) => !l.hasSupplier).length;
  bool get canSubmit => lines.isNotEmpty && unassignedCount == 0 && !submitting;

  /// Shown inline when the submit CTA is tapped while disabled.
  String? get submitBlocker {
    if (lines.isEmpty) return AppStrings.reqAddOneItem;
    if (unassignedCount > 0) {
      return AppStrings.reqItemsNeedSupplier(unassignedCount);
    }
    return null;
  }

  RequisitionCartState copyWith({
    List<RequisitionCartLine>? lines,
    String? notes,
    DateTime? expectedAt,
    bool? submitting,
    String? error,
    SubmittedRequisition? lastSubmitted,
    bool clearError = false,
    bool clearExpectedAt = false,
  }) {
    return RequisitionCartState(
      lines: lines ?? this.lines,
      notes: notes ?? this.notes,
      expectedAt:
          clearExpectedAt ? null : (expectedAt ?? this.expectedAt),
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
      lastSubmitted: lastSubmitted ?? this.lastSubmitted,
    );
  }
}

class RequisitionCartNotifier extends Notifier<RequisitionCartState> {
  @override
  RequisitionCartState build() => const RequisitionCartState();

  /// Adds an item; the same item twice merges quantities (split across
  /// suppliers happens via per-line supplier override, not duplicate rows).
  ///
  /// Pass the item's preferred supplier ([supplierId]/[supplierName]) to
  /// pre-assign the new line — the user can still change it per line or via
  /// bulk-assign. A re-add never overwrites an existing assignment, but it
  /// does fill in a still-unassigned line (e.g. the directory finished
  /// loading between the two taps).
  void addItem({
    required String itemId,
    required String itemName,
    required String unit,
    required double qty,
    String? supplierId,
    String? supplierName,
    String? assignmentSource,
  }) {
    final existing = state.lines.indexWhere((l) => l.itemId == itemId);
    if (existing >= 0) {
      final line = state.lines[existing];
      final fillSupplier =
          line.supplierId == null && supplierId != null;
      _setLines([
        for (var i = 0; i < state.lines.length; i++)
          if (i == existing)
            line.copyWith(
              qty: line.qty + qty,
              supplierId: fillSupplier ? supplierId : null,
              supplierName: fillSupplier ? supplierName : null,
              assignmentSource: fillSupplier ? assignmentSource : null,
            )
          else
            state.lines[i],
      ]);
    } else {
      _setLines([
        ...state.lines,
        RequisitionCartLine(
          itemId: itemId,
          itemName: itemName,
          unit: unit,
          qty: qty,
          supplierId: supplierId,
          supplierName: supplierName,
          assignmentSource: assignmentSource,
        ),
      ]);
    }
  }

  void setQty(String itemId, double qty) {
    if (qty <= 0) {
      removeLine(itemId);
      return;
    }
    _setLines([
      for (final l in state.lines)
        if (l.itemId == itemId) l.copyWith(qty: qty) else l,
    ]);
  }

  void removeLine(String itemId) {
    _setLines(state.lines.where((l) => l.itemId != itemId).toList());
  }

  /// Per-item assignment — overrides that line only.
  void assignSupplierToLine({
    required String itemId,
    required String supplierId,
    required String supplierName,
  }) {
    _setLines([
      for (final l in state.lines)
        if (l.itemId == itemId)
          l.copyWith(
            supplierId: supplierId,
            supplierName: supplierName,
            assignmentSource: 'manual_per_item',
          )
        else
          l,
    ]);
  }

  void clearLineSupplier(String itemId) {
    _setLines([
      for (final l in state.lines)
        if (l.itemId == itemId) l.copyWith(clearSupplier: true) else l,
    ]);
  }

  /// Bulk assignment — same field, convenience layer. [scope] defaults to
  /// unassigned-only; pass [overwriteAll] (the explicit toggle) to replace
  /// existing per-item choices too.
  void bulkAssign({
    required String supplierId,
    required String supplierName,
    BulkScope scope = BulkScope.unassignedOnly,
    bool overwriteAll = false,
  }) {
    _setLines([
      for (final l in state.lines)
        if (l.supplierId == null ||
            (scope == BulkScope.all && overwriteAll))
          l.copyWith(
            supplierId: supplierId,
            supplierName: supplierName,
            assignmentSource: 'bulk_all',
          )
        else
          l,
    ]);
  }

  void setNotes(String? notes) =>
      state = state.copyWith(notes: notes, clearError: true);

  void setExpectedAt(DateTime? date) => state = state.copyWith(
        expectedAt: date,
        clearExpectedAt: date == null,
        clearError: true,
      );

  void clearError() => state = state.copyWith(clearError: true);

  void clearCart() => state = const RequisitionCartState(
      lastSubmitted: null);

  void _setLines(List<RequisitionCartLine> lines) {
    state = state.copyWith(lines: lines, clearError: true);
  }

  /// Submits the cart: one requisition → one PO per supplier. Generates a
  /// fresh idempotency key per submit so double-tap can't duplicate.
  Future<SubmittedRequisition> submit() async {
    final blocker = state.submitBlocker;
    if (blocker != null) throw RequisitionApiException(blocker);
    final businessId = ref.read(currentBusinessIdProvider);
    final storeId = ref.read(currentStoreIdProvider);
    if (businessId == null || storeId == null) {
      throw RequisitionApiException(AppStrings.reqNoBusiness);
    }
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final response = await ref.read(requisitionApiServiceProvider).submit(
            businessId: businessId,
            storeId: storeId,
            lines: [
              for (final l in state.lines)
                {
                  'item_id': l.itemId,
                  'qty': l.qty.toString(),
                  'supplier_id': l.supplierId,
                },
            ],
            idempotencyKey: const Uuid().v4(),
            notes: state.notes,
            expectedAt: state.expectedAt,
          );
      final suppliers = {
        for (final s in ref.read(suppliersListProvider)) s.id: s.name,
      };
      // Backfill names the backend doesn't know (offline-added suppliers).
      for (final l in state.lines) {
        suppliers.putIfAbsent(
            l.supplierId ?? '', () => l.supplierName ?? 'Supplier');
      }
      final submitted = submittedFromResponse(response, suppliers);
      state = RequisitionCartState(lastSubmitted: submitted);
      return submitted;
    } catch (e) {
      state = state.copyWith(
        submitting: false,
        error: e is RequisitionApiException ? e.message : e.toString(),
      );
      rethrow;
    }
  }
}

final requisitionCartProvider =
    NotifierProvider<RequisitionCartNotifier, RequisitionCartState>(
        RequisitionCartNotifier.new);

/// Finds an item's preferred supplier ([InventoryItem.preferredSupplierId],
/// synced from the backend's `item.supplier_id`) in [directory]. Returns
/// null when the item has none, or it isn't in the directory
/// (deleted/renamed server-side, or the directory hasn't loaded) — the cart
/// line then stays unassigned for manual or bulk assignment.
///
/// Real records only: callers pass [suppliersListProvider], which holds the
/// synced directory once a business context exists. A line stays unassigned
/// unless the directory actually contains the preferred supplier.
Supplier? findPreferredSupplier(
    List<Supplier> directory, String? preferredSupplierId) {
  if (preferredSupplierId == null || preferredSupplierId.isEmpty) return null;
  for (final supplier in directory) {
    if (supplier.id == preferredSupplierId) return supplier;
  }
  return null;
}

final requisitionApiServiceProvider = Provider<RequisitionApiService>(
  (ref) =>
      RequisitionApiService(dio: ref.watch(inventoryServiceDioProvider)),
);
