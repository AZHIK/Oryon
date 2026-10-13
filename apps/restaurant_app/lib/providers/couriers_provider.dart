import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/courier.dart';
import 'courier_api_provider.dart';
import 'permissions_provider.dart';

/// Source of truth for couriers, backed by POS Service once a business
/// context exists.
///
/// Unlike the old in-memory stub (which started empty and never fetched),
/// this pulls `GET /businesses/{id}/couriers` on build and after every
/// mutation — the same stale-while-revalidate shape as `CustomersNotifier`,
/// minus the offline outbox: couriers are low-volume master data, so
/// creates/edits/deletes go straight to the server and surface a clear
/// error offline instead of queuing silently.
class CouriersNotifier extends AsyncNotifier<List<Courier>> {
  @override
  Future<List<Courier>> build() async {
    final businessId = ref.watch(currentBusinessIdProvider);
    if (businessId == null) return const [];
    try {
      return await ref.watch(courierApiServiceProvider).fetchCouriers(
        businessId: businessId,
      );
    } catch (_) {
      // Offline or unauthorized — the screen renders the empty/error state
      // and a manual refresh retries.
      return const [];
    }
  }

  /// Re-pulls the ledger — for pull-to-refresh and post-mutation refresh.
  Future<void> refresh() async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    state = const AsyncLoading<List<Courier>>().copyWithPrevious(state);
    try {
      state = AsyncData(
        await ref.read(courierApiServiceProvider).fetchCouriers(
          businessId: businessId,
        ),
      );
    } catch (e, st) {
      state = AsyncError<List<Courier>>(e, st).copyWithPrevious(state);
    }
  }

  /// Creates a courier server-side, then refreshes the list.
  Future<Courier> create({
    required String name,
    required String phone,
    String? vehicle,
    bool isActive = true,
  }) async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) throw StateError('No active business context');
    final saved = await ref
        .read(courierApiServiceProvider)
        .createCourier(
          businessId: businessId,
          name: name,
          phone: phone,
          vehicle: vehicle,
          isActive: isActive,
        );
    await refresh();
    return saved;
  }

  /// Edits [existing] server-side, then refreshes the list.
  Future<Courier> edit(
    Courier existing, {
    String? name,
    String? phone,
    String? vehicle,
    bool? isActive,
  }) async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) throw StateError('No active business context');
    final saved = await ref
        .read(courierApiServiceProvider)
        .updateCourier(
          businessId: businessId,
          courierId: existing.id,
          name: name,
          phone: phone,
          vehicle: vehicle,
          isActive: isActive,
        );
    await refresh();
    return saved;
  }

  /// Flips availability without opening the form.
  Future<void> setActive(Courier courier, bool isActive) async {
    await edit(courier, isActive: isActive);
  }

  /// Deletes a courier server-side, then refreshes the list.
  Future<void> remove(String id) async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) throw StateError('No active business context');
    await ref
        .read(courierApiServiceProvider)
        .deleteCourier(businessId: businessId, courierId: id);
    await refresh();
  }
}

final couriersProvider =
    AsyncNotifierProvider<CouriersNotifier, List<Courier>>(CouriersNotifier.new);

/// The list, unwrapped — mirrors `customersListProvider`.
final couriersListProvider = Provider<List<Courier>>(
  (ref) => ref.watch(couriersProvider).valueOrNull ?? const [],
);

/// Active couriers available for assignment.
final activeCouriersProvider = Provider<List<Courier>>((ref) {
  return ref
      .watch(couriersListProvider)
      .where((c) => c.status == CourierStatus.active)
      .toList();
});

/// Lookup by id.
final courierByIdProvider = Provider.family<Courier?, String>((ref, id) {
  for (final courier in ref.watch(couriersListProvider)) {
    if (courier.id == id) return courier;
  }
  return null;
});
