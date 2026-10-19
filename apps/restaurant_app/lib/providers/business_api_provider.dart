import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_dtos.dart';
import '../services/business_api_service.dart';
import 'auth_provider.dart';
import 'permissions_provider.dart';

/// Provides access to the business API service.
final businessApiProvider = Provider<BusinessApiService>((ref) {
  final dio = ref.watch(identityServiceDioProvider);
  return BusinessApiService(dio: dio);
});

/// Fetches the current business data from the backend.
///
/// This is an async provider that loads the full business details including
/// all fields from the backend (logo, license_document_url, status, etc).
/// Uses the JWT's activeBusinessId as the authoritative source.
///
/// Returns null if user lacks permission to view business data.
final currentBusinessProvider = FutureProvider<BusinessReadDto?>((ref) async {
  try {
    final businessId = ref.watch(currentBusinessIdProvider);
    if (businessId == null) return null;

    // Check if user has permission to view business.
    final canViewBusiness = ref.watch(hasPermissionProvider('businesses.view'));
    if (!canViewBusiness) return null;

    final businessApi = ref.watch(businessApiProvider);
    return await businessApi.getBusiness(businessId: businessId);
  } catch (e) {
    // Return null on error; UI should handle this
    return null;
  }
});

/// Refreshes the current business data.
///
/// Call this to manually refresh business data after updates.
Future<void> refreshCurrentBusiness(WidgetRef ref) =>
    ref.refresh(currentBusinessProvider.future);

/// Mutations for the current business, following the same
/// call-API-then-refresh pattern as RolesNotifier/StaffNotifier.
class BusinessProfileNotifier {
  BusinessProfileNotifier(this.ref);
  final Ref ref;

  Future<BusinessReadDto> update(String businessId, BusinessUpdateInput input) async {
    final api = ref.read(businessApiProvider);
    final updated = await api.updateBusiness(businessId: businessId, input: input);
    ref.invalidate(currentBusinessProvider);
    return updated;
  }
}

final businessProfileNotifierProvider = Provider<BusinessProfileNotifier>(
  (ref) => BusinessProfileNotifier(ref),
);
