/// Direct CRUD API for delivery couriers.
///
/// Couriers are low-volume master data (unlike offline-first sales or finance
/// outbox rows), so this is a thin synchronous wrapper around POS Service
/// `POST/GET/PATCH/DELETE /businesses/{id}/couriers` — the same direct-write
/// role `CustomerApiService` plays for already-synced customers.
library;

import 'package:dio/dio.dart';

import '../constants/api_paths.dart';
import '../models/courier.dart';

/// Thrown when POS Service rejects a courier mutation (duplicate phone,
/// not found, validation) or the list fetch fails.
class CourierApiException implements Exception {
  final String message;
  final int? statusCode;

  CourierApiException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'CourierApiException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

class CourierApiService {
  const CourierApiService({required this._dio});

  final Dio _dio;

  Future<List<Courier>> fetchCouriers({required String businessId}) async {
    try {
      final couriers = <Courier>[];
      var offset = 0;
      const pageSize = 100;
      while (true) {
        final response = await _dio.get(
          PosApiPaths.couriers(businessId),
          queryParameters: {'limit': pageSize, 'offset': offset},
        );
        final page = (response.data['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        couriers.addAll(page.map(Courier.fromJson));
        if (page.length < pageSize) break;
        offset += pageSize;
      }
      return couriers;
    } on DioException catch (e) {
      throw _toException(e, 'Could not load couriers');
    }
  }

  Future<Courier> createCourier({
    required String businessId,
    required String name,
    required String phone,
    String? vehicle,
    bool isActive = true,
  }) async {
    try {
      final response = await _dio.post(
        PosApiPaths.couriers(businessId),
        data: {
          'name': name,
          'phone': phone,
          if (vehicle != null) 'vehicle': vehicle,
          'is_active': isActive,
        },
      );
      return Courier.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toException(e, 'Could not add courier');
    }
  }

  Future<Courier> updateCourier({
    required String businessId,
    required String courierId,
    String? name,
    String? phone,
    String? vehicle,
    bool? isActive,
  }) async {
    try {
      final response = await _dio.patch(
        PosApiPaths.courier(businessId, courierId),
        data: {
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
          if (vehicle != null) 'vehicle': vehicle,
          if (isActive != null) 'is_active': isActive,
        },
      );
      return Courier.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toException(e, 'Could not save courier');
    }
  }

  Future<void> deleteCourier({
    required String businessId,
    required String courierId,
  }) async {
    try {
      await _dio.delete(PosApiPaths.courier(businessId, courierId));
    } on DioException catch (e) {
      throw _toException(e, 'Could not delete courier');
    }
  }

  CourierApiException _toException(DioException e, String fallback) {
    final detail = e.response?.data is Map
        ? (e.response?.data as Map)['detail']
        : null;
    return CourierApiException(
      detail?.toString() ?? e.message ?? fallback,
      e.response?.statusCode,
    );
  }
}
