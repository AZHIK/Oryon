/// Direct (non-outbox) write API for already-synced finance entries, plus
/// receipt download.
///
/// Mirrors `pos_api_service.dart`'s role for void/refund: editing or
/// deleting an entry that already has a server id requires connectivity —
/// there's no offline-first queue for it (a second outbox for mutations of
/// already-synced rows is real complexity for a rare case; see
/// `OtherExpensesNotifier`'s doc comment on why offline edits of a synced
/// row are refused instead).
library;

import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../constants/api_paths.dart';

/// Thrown when POS Service rejects a finance entry mutation (not found,
/// already deleted, validation).
class FinanceApiException implements Exception {
  final String message;
  final int? statusCode;

  FinanceApiException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'FinanceApiException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

class FinanceApiService {
  const FinanceApiService({required this._dio});

  final Dio _dio;

  Future<void> updateExpense({
    required String businessId,
    required String expenseId,
    String? category,
    Decimal? amount,
    String? description,
    String? paymentMethod,
    String? payee,
    String? note,
    DateTime? occurredAt,
  }) async {
    try {
      await _dio.patch(
        PosApiPaths.expense(businessId, expenseId),
        data: {
          'category': ?category,
          if (amount != null) 'amount': amount.toString(),
          'description': ?description,
          'payment_method': ?paymentMethod,
          'payee': ?payee,
          'note': ?note,
          if (occurredAt != null)
            'occurred_at': occurredAt.toUtc().toIso8601String(),
        },
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<void> deleteExpense({
    required String businessId,
    required String expenseId,
  }) async {
    try {
      await _dio.delete(PosApiPaths.expense(businessId, expenseId));
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<void> updateIncome({
    required String businessId,
    required String incomeId,
    String? category,
    Decimal? amount,
    String? description,
    String? paymentMethod,
    String? source,
    String? note,
    DateTime? occurredAt,
  }) async {
    try {
      await _dio.patch(
        PosApiPaths.income(businessId, incomeId),
        data: {
          'category': ?category,
          if (amount != null) 'amount': amount.toString(),
          'description': ?description,
          'payment_method': ?paymentMethod,
          'source': ?source,
          'note': ?note,
          if (occurredAt != null)
            'occurred_at': occurredAt.toUtc().toIso8601String(),
        },
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<void> deleteIncome({
    required String businessId,
    required String incomeId,
  }) async {
    try {
      await _dio.delete(PosApiPaths.income(businessId, incomeId));
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// Fetches a receipt's raw bytes for viewing (e.g. one pulled from a
  /// synced entry created on another device, where only `remoteId` is known).
  Future<Uint8List> fetchReceipt({
    required String businessId,
    required String attachmentId,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        PosApiPaths.attachment(businessId, attachmentId),
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  FinanceApiException _toException(DioException e) {
    final detail = e.response?.data is Map
        ? (e.response?.data as Map)['detail']
        : null;
    return FinanceApiException(
      detail?.toString() ?? e.message ?? 'Request failed',
      e.response?.statusCode,
    );
  }
}
