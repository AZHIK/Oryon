import 'package:dio/dio.dart';

import '../auth/auth_dtos.dart';
import '../constants/api_paths.dart';

/// API client for store management operations.
///
/// Handles CRUD operations for stores including:
/// - Listing stores
/// - Reading store details
/// - Updating store information and settings
/// - Deleting stores
/// - Managing store staff assignments
///
/// All operations are business-scoped and require authentication.
class StoreApiService {
  const StoreApiService({required this._dio});

  final Dio _dio;

  /// List all stores for a business.
  ///
  /// Returns a list of [StoreReadDto] objects. Requires an active
  /// business context in the authentication token.
  Future<List<StoreReadDto>> listStores({
    required String businessId,
  }) async {
    try {
      final response = await _dio.get(IdentityApiPaths.businessStores(businessId));
      final data = response.data as List<dynamic>;
      return data
          .map((store) => StoreReadDto.fromJson(store as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get details for a specific store.
  Future<StoreReadDto> getStore({
    required String businessId,
    required String storeId,
  }) async {
    try {
      final response = await _dio.get(
        IdentityApiPaths.store(businessId, storeId),
      );
      return StoreReadDto.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new store.
  ///
  /// Requires [STORES_CREATE] permission.
  ///
  /// Parameters:
  /// - [businessId]: The business this store belongs to
  /// - [name]: Store name
  /// - [locationType]: Type of location (head_office, restaurant_branch, kitchen, warehouse, farm, depot)
  /// - [address]: Physical address
  /// - [city]: City or locality
  /// - [countryCode]: ISO 3166-1 alpha-2 country code
  /// - [timezone]: IANA timezone identifier
  /// - [isPrimary]: Whether this is the primary/flagship store
  /// - [status]: 'active' or 'inactive'
  Future<StoreReadDto> createStore({
    required String businessId,
    required String name,
    required String locationType,
    String? address,
    String? city,
    String? countryCode,
    String? timezone,
    bool? isPrimary,
    String? status,
  }) async {
    try {
      final payload = {
        'name': name,
        'location_type': locationType,
        'address': ?address,
        'city': ?city,
        'country_code': ?countryCode,
        'timezone': ?timezone,
        'is_primary': ?isPrimary,
        'status': ?status,
      };

      final response = await _dio.post(
        IdentityApiPaths.businessStores(businessId),
        data: payload,
      );
      return StoreReadDto.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Update store information.
  ///
  /// Requires [STORES_UPDATE] permission.
  ///
  /// Only provided fields are updated (partial update).
  Future<StoreReadDto> updateStore({
    required String businessId,
    required String storeId,
    String? name,
    String? address,
    String? city,
    String? timezone,
    bool? isPrimary,
    String? status,
    String? locationType,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': ?name,
        'address': ?address,
        'city': ?city,
        'timezone': ?timezone,
        'is_primary': ?isPrimary,
        'status': ?status,
        'location_type': ?locationType,
      };

      final response = await _dio.patch(
        IdentityApiPaths.store(businessId, storeId),
        data: payload,
      );
      return StoreReadDto.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a store.
  ///
  /// Requires [STORES_DELETE] permission.
  ///
  /// Returns true if deletion was successful.
  Future<bool> deleteStore({
    required String businessId,
    required String storeId,
  }) async {
    try {
      await _dio.delete(IdentityApiPaths.store(businessId, storeId));
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Get store settings.
  ///
  /// Returns the [StoreSettingReadDto] for a specific store.
  Future<StoreSettingReadDto> getStoreSettings({
    required String businessId,
    required String storeId,
  }) async {
    try {
      final response = await _dio.get(
        IdentityApiPaths.storeSettings(businessId, storeId),
      );
      return StoreSettingReadDto.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Update store settings.
  ///
  /// Requires [STORES_UPDATE] permission.
  ///
  /// Only provided fields are updated (partial update).
  Future<StoreSettingReadDto> updateStoreSettings({
    required String businessId,
    required String storeId,
    bool? active,
    String? address,
    double? latitude,
    double? longitude,
    String? email,
    String? phone,
    String? preferredCurrency,
    double? amount,
    int? maxPaymentTimeMinutes,
    String? logo,
    bool? offerRetail,
    bool? offerWholesale,
    bool? displayPricesInclusiveOfTax,
    bool? taxEnabled,
    double? taxRate,
  }) async {
    try {
      final payload = <String, dynamic>{
        'active': ?active,
        'address': ?address,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'email': ?email,
        'phone': ?phone,
        'preferred_currency': ?preferredCurrency,
        'amount': ?amount,
        'max_payment_time_minutes': ?maxPaymentTimeMinutes,
        'logo': ?logo,
        'offer_retail': ?offerRetail,
        'offer_wholesale': ?offerWholesale,
        'display_prices_inclusive_of_tax': ?displayPricesInclusiveOfTax,
        'tax_enabled': ?taxEnabled,
        'tax_rate': ?taxRate,
      };

      final response = await _dio.patch(
        IdentityApiPaths.storeSettings(businessId, storeId),
        data: payload,
      );
      return StoreSettingReadDto.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Assign staff to a store.
  ///
  /// Requires [USER_STORE_ROLES_ASSIGN] permission.
  ///
  /// Parameters:
  /// - [businessId]: The business this store belongs to
  /// - [storeId]: The store to assign staff to
  /// - [businessRoleId]: The role to assign to the staff member
  /// - [userId]: UUID of the user to assign (optional if creating new)
  /// - [phone]: Phone number of user (one of phone/email required if userId
  ///   is not provided)
  /// - [email]: Email of user (one of phone/email required if userId is not
  ///   provided)
  /// - [fullName]: Optional display name; only applied when the invite
  ///   creates a new pending user or fills a blank name
  Future<void> assignStaffToStore({
    required String businessId,
    required String storeId,
    required String businessRoleId,
    String? userId,
    String? phone,
    String? email,
    String? fullName,
  }) async {
    try {
      final payload = {
        'business_role_id': businessRoleId,
        'user_id': ?userId,
        'phone': ?phone,
        'email': ?email,
        'full_name': ?fullName,
      };

      await _dio.post(
        IdentityApiPaths.storeStaff(businessId, storeId),
        data: payload,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// List staff assigned to a store.
  ///
  /// Requires [USER_STORE_ROLES_VIEW] permission.
  ///
  /// Returns a list of staff members assigned to the store with their roles.
  Future<List<Map<String, dynamic>>> listStoreStaff({
    required String businessId,
    required String storeId,
  }) async {
    try {
      final response = await _dio.get(
        IdentityApiPaths.storeStaff(businessId, storeId),
      );
      return List<Map<String, dynamic>>.from(response.data as List<dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Revoke a staff member's role at a store.
  ///
  /// Requires [USER_STORE_ROLES_REVOKE] permission.
  Future<void> revokeStaffFromStore({
    required String businessId,
    required String storeId,
    required String userId,
    required String roleId,
  }) async {
    try {
      await _dio.delete(
        IdentityApiPaths.storeStaffRole(businessId, storeId, userId, roleId),
      );
    } catch (e) {
      rethrow;
    }
  }
}
