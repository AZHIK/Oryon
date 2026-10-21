/// Debug logging for API traffic that stays quiet around binary payloads.
///
/// A plain `LogInterceptor(requestBody: true, responseBody: true)` prints
/// every response body verbatim — fine while every payload was JSON, but a
/// single product-photo download then dumps megabytes of byte values
/// (`223, 197, 113, …` with `255, 0` JPEG stuffing pairs) into the
/// terminal. This interceptor logs the same method/URL/headers/status for
/// every call, JSON bodies with credential fields redacted, and a one-line
/// `<binary …>` / `<multipart …>` summary for photos and uploads.
///
/// It is only installed in debug builds (SEC-05). Redaction is still applied
/// in debug so a screen-shared terminal or a pasted log cannot leak passwords,
/// OTPs, or refresh tokens.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiLogInterceptor extends Interceptor {
  const ApiLogInterceptor();

  static const _redacted = '<redacted>';

  /// Matched case-insensitively against map keys. Errs on the side of
  /// over-redacting: a missed token is far worse than a missing debug value.
  static const _sensitiveKeyFragments = <String>{
    'password',
    'passcode',
    'token',
    'secret',
    'authorization',
    'cookie',
    'otp',
    'code',
    'pin',
    'api_key',
    'apikey',
    'credential',
  };

  static bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return _sensitiveKeyFragments.any(lower.contains);
  }

  static Object? _redact(Object? value) {
    if (value is Map) {
      return <Object?, Object?>{
        for (final entry in value.entries)
          entry.key: _isSensitiveKey(entry.key.toString())
              ? _redacted
              : _redact(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_redact).toList(growable: false);
    }
    return value;
  }

  static bool _isBinaryBody(Object? data) =>
      data is FormData || data is List<int> || data is Uint8List;

  static void _logBody(Object? data) {
    if (data is FormData) {
      debugPrint(
        '<multipart ${data.files.length} file(s), '
        '${data.fields.length} field(s)>',
      );
      return;
    }
    if (_isBinaryBody(data)) {
      debugPrint('<binary ${(data as List).length} bytes>');
      return;
    }
    if (data is Map || data is Iterable) {
      debugPrint(_redact(data).toString());
      return;
    }
    if (data is String) {
      // Never echo arbitrary text: error pages and OTP/confirmation payloads
      // have shown up as plain strings in the past.
      debugPrint('<text ${data.length} chars>');
      return;
    }
    debugPrint(data.toString());
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('--> ${options.method} ${options.uri}');
    _logBody(options.data);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('<-- ${response.statusCode} ${response.requestOptions.uri}');
    _logBody(response.data);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // One short line: backend `detail` when present, else the status, else
    // the transport cause — never Dio's multi-line status-code lecture.
    final status = err.response?.statusCode;
    final data = err.response?.data;
    final detail = data is Map && data['detail'] is String
        ? data['detail'] as String
        : null;
    final cause =
        detail ??
        (status != null
            ? 'HTTP $status'
            : '${err.type}${err.error == null ? '' : ': ${err.error}'}');
    debugPrint('<-- ERROR $cause ${err.requestOptions.uri}');
    handler.next(err);
  }
}
