/// HTTP implementation of the finance catalog (read-side) API using Dio.
///
/// Calls the real POS Service `/businesses/{business_id}/other-expenses` and
/// `/other-incomes` list endpoints. Mirrors `HttpPosCatalogApi`'s paging
/// loop — the backend caps a page at 100 rows, so a full pull must page
/// through until a short page comes back.
library;

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../constants/api_paths.dart';
import '../constants/app_limits.dart';
import 'finance_catalog_api.dart';

const _pageSize = AppLimits.catalogFetchPageSize;

/// HTTP client for fetching the finance ledgers from POS Service via Dio.
class HttpFinanceCatalogApi extends FinanceCatalogApi {
  final Dio _dio;
  final String _businessId;

  HttpFinanceCatalogApi({required this._dio, required this._businessId});

  @override
  Future<List<OtherExpenseServerDto>> fetchExpenses({
    required String storeId,
  }) async {
    try {
      final expenses = <OtherExpenseServerDto>[];
      var offset = 0;
      while (true) {
        final response = await _dio.get(
          PosApiPaths.expenses(_businessId),
          queryParameters: {
            'store_id': storeId,
            'limit': _pageSize,
            'offset': offset,
            'include_deleted': true,
          },
        );
        final page = (response.data['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expenses.addAll(page.map(_expenseFromJson));
        if (page.length < _pageSize) break;
        offset += _pageSize;
      }
      return expenses;
    } on DioException catch (e) {
      throw FinanceFetchException(
        'Expenses fetch failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<List<OtherIncomeServerDto>> fetchIncomes({
    required String storeId,
  }) async {
    try {
      final incomes = <OtherIncomeServerDto>[];
      var offset = 0;
      while (true) {
        final response = await _dio.get(
          PosApiPaths.incomes(_businessId),
          queryParameters: {
            'store_id': storeId,
            'limit': _pageSize,
            'offset': offset,
            'include_deleted': true,
          },
        );
        final page = (response.data['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        incomes.addAll(page.map(_incomeFromJson));
        if (page.length < _pageSize) break;
        offset += _pageSize;
      }
      return incomes;
    } on DioException catch (e) {
      throw FinanceFetchException(
        'Incomes fetch failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  OtherExpenseServerDto _expenseFromJson(Map<String, dynamic> e) =>
      OtherExpenseServerDto(
        id: e['id'] as String,
        businessId: e['business_id'] as String,
        storeId: e['store_id'] as String,
        clientExpenseId: e['client_expense_id'] as String,
        category: e['category'] as String,
        amount: Decimal.parse(e['amount'].toString()),
        description: e['description'] as String,
        payee: e['payee'] as String?,
        note: e['note'] as String?,
        paymentMethod: e['payment_method'] as String,
        receiptAttachmentId: e['receipt_attachment_id'] as String?,
        actorId: e['actor_id'] as String?,
        occurredAt: DateTime.parse(e['occurred_at'] as String),
        syncedAt: DateTime.parse(e['synced_at'] as String),
        updatedAt: DateTime.parse(e['updated_at'] as String),
        isDeleted: e['is_deleted'] as bool,
        createdAt: DateTime.parse(e['created_at'] as String),
      );

  OtherIncomeServerDto _incomeFromJson(Map<String, dynamic> i) =>
      OtherIncomeServerDto(
        id: i['id'] as String,
        businessId: i['business_id'] as String,
        storeId: i['store_id'] as String,
        clientIncomeId: i['client_income_id'] as String,
        category: i['category'] as String,
        amount: Decimal.parse(i['amount'].toString()),
        description: i['description'] as String,
        source: i['source'] as String?,
        note: i['note'] as String?,
        paymentMethod: i['payment_method'] as String,
        receiptAttachmentId: i['receipt_attachment_id'] as String?,
        actorId: i['actor_id'] as String?,
        occurredAt: DateTime.parse(i['occurred_at'] as String),
        syncedAt: DateTime.parse(i['synced_at'] as String),
        updatedAt: DateTime.parse(i['updated_at'] as String),
        isDeleted: i['is_deleted'] as bool,
        createdAt: DateTime.parse(i['created_at'] as String),
      );
}

/// Finance fetch error for debugging.
class FinanceFetchException implements Exception {
  final String message;
  final int? statusCode;

  FinanceFetchException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'FinanceFetchException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}
