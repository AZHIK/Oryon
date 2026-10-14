/// HTTP implementation of the finance sync API using Dio.
///
/// Calls the real POS Service `/businesses/{business_id}/other-expenses/sync`,
/// `/other-incomes/sync`, and `/finance/attachments` endpoints. Auth is
/// handled by the Dio client's own interceptor, same as `HttpSyncApi`.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../constants/api_paths.dart';
import 'finance_sync_api.dart';
import 'finance_sync_dtos.dart';
import 'http_sync_api.dart' show HttpException;

/// HTTP client for syncing finance entries and receipts to POS Service.
class HttpFinanceSyncApi extends FinanceSyncApi {
  final Dio _dio;
  final String _businessId;

  HttpFinanceSyncApi({required this._dio, required this._businessId});

  @override
  Future<FinanceSyncBatchResult> syncExpenses(
    List<OtherExpenseDto> batch,
  ) async {
    try {
      final response = await _dio.post(
        PosApiPaths.expensesSync(_businessId),
        data: {'expenses': batch.map((e) => e.toJson()).toList()},
      );
      return _resultsFromResponse(response.data);
    } on DioException catch (e) {
      throw HttpException(
        'Expense sync failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<FinanceSyncBatchResult> syncIncomes(
    List<OtherIncomeDto> batch,
  ) async {
    try {
      final response = await _dio.post(
        PosApiPaths.incomesSync(_businessId),
        data: {'incomes': batch.map((i) => i.toJson()).toList()},
      );
      return _resultsFromResponse(response.data);
    } on DioException catch (e) {
      throw HttpException(
        'Income sync failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  @override
  Future<String> uploadReceipt({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: MediaType.parse(contentType),
        ),
      });
      final response = await _dio.post(
        PosApiPaths.attachments(_businessId),
        data: formData,
      );
      return response.data['id'] as String;
    } on DioException catch (e) {
      throw HttpException(
        'Receipt upload failed: ${e.message}',
        e.response?.statusCode,
      );
    }
  }

  FinanceSyncBatchResult _resultsFromResponse(dynamic data) {
    final results = (data['results'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((r) => FinanceSyncRowResult(
              clientEntryId: r['client_entry_id'] as String,
              status: r['status'] as String,
              reason: r['reason'] as String?,
            ))
        .toList();
    return FinanceSyncBatchResult(results: results);
  }
}
