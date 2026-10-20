/// A hand-rolled fake for the identity-service backend, used only in tests.
///
/// [AuthNotifier]/[IdentityServiceApi]/[StaffRbacApi] talk to a real backend
/// in the running app (see `identityServiceDioProvider`), so widget tests
/// that exercise auth, onboarding or staff/roles need something to answer
/// those calls without a live server. Implementing Dio's [HttpClientAdapter]
/// directly avoids pulling in a mocking package for what is a bounded set of
/// canned JSON responses shaped like the real ones.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// The only code [FakeIdentityAdapter] accepts as correct.
const fakeOtpCode = '111111';

/// Builds an unsigned (test-only) JWT with the given claims — the app never
/// verifies the signature client-side (see `jwt_decoder.dart`), only decodes
/// the payload, so this is enough to round-trip `sub`/`active_business_id`/
/// `permissions`.
String fakeJwt(Map<String, dynamic> claims) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({
        'alg': 'none',
      })}.${segment(claims)}.fake-signature';
}

/// A fake JWT for a user already scoped to [businessId] with [permissions]
/// (defaults to `['*']`, an owner-equivalent token) — for tests that skip
/// the real OTP flow via a directly-overridden `sessionProvider` state, and
/// so also need `authProvider`'s in-memory token seeded by hand (see
/// `pumpSession`'s `authAccessToken` in `auth_flow_test.dart`).
String fakeScopedToken({
  String userId = 'fake-user-id',
  String? businessId,
  List<String> permissions = const ['*'],
}) {
  final now = DateTime.now().toUtc();
  return fakeJwt({
    'sub': userId,
    'exp': now.add(const Duration(minutes: 15)).millisecondsSinceEpoch ~/ 1000,
    'user_category': 'business_user',
    'active_business_id': businessId,
    'permissions': permissions,
    'roles': businessId == null ? <String>[] : ['owner'],
  });
}

/// The locations `GET .../stores` serves, shared with the store-staff assign
/// handler so recorded assignments carry the real store name — like the
/// backend's `Store` join does.
List<Map<String, dynamic>> _fakeStores(String businessId) {
  final now = DateTime.now().toUtc().toIso8601String();
  Map<String, dynamic> store(String id, String name, bool primary, String type) => {
    'id': id,
    'business_id': businessId,
    'name': name,
    'token': 'tok-$id',
    'location_type': type,
    'status': 'active',
    'country_code': 'TZ',
    'city': null,
    'address': null,
    'timezone': 'Africa/Dar_es_Salaam',
    'is_primary': primary,
    'created_at': now,
    'updated_at': now,
  };
  return [
    store('store-1', 'Main Location', true, 'head_office'),
    store('store-2', 'Branch Two', false, 'restaurant_branch'),
  ];
}

class FakeIdentityBackendState {
  FakeIdentityBackendState();

  /// The name returned by onboarding-status — non-empty by default so tests
  /// that aren't specifically about the "complete your profile" step don't
  /// get routed there. Set to '' to exercise that path.
  String fullName = 'Test User';
  String? email;
  String? phone;
  bool needsOnboarding = true;
  String? businessId;
  String? businessName;

  /// Populated by `POST /businesses`, mirroring the real backend's
  /// role-template seeding (one protected owner role, four operational
  /// ones) — enough for a team-step role picker to have real choices.
  final List<Map<String, dynamic>> roles = [];

  /// One entry per staff member: `{user_id, phone, full_name, email,
  /// status, roles: [{business_role_id, name}]}` — matches `StaffMemberRead`.
  final List<Map<String, dynamic>> staff = [];

  int _seq = 0;
  String _nextId(String prefix) => '$prefix-${++_seq}';

  Map<String, dynamic>? _staffByPhone(String phone) =>
      staff.where((s) => s['phone'] == phone).firstOrNull;
}

class FakeIdentityAdapter implements HttpClientAdapter {
  FakeIdentityAdapter(this.state);

  final FakeIdentityBackendState state;

  @override
  void close({bool force = false}) {}

  ResponseBody _json(Object? body, int statusCode) {
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final method = options.method;
    final data = options.data;
    final body = data is Map ? data : <String, dynamic>{};

    if (method == 'POST' && path.endsWith('/auth/otp/request')) {
      return _json(null, 204);
    }

    if (method == 'POST' && path.endsWith('/auth/otp/email/request')) {
      state.email = body['email'] as String?;
      return _json(null, 204);
    }

    if (method == 'POST' && path.endsWith('/auth/otp/email/verify')) {
      if (body['code'] != fakeOtpCode) {
        return _json({'detail': 'Invalid or expired code'}, 401);
      }
      state.email = body['email'] as String?;
      return _json({
        'access_token': fakeScopedToken(permissions: const []),
        'refresh_token': 'fake-refresh-token',
        'token_type': 'bearer',
      }, 200);
    }

    if (method == 'POST' && path.endsWith('/auth/otp/verify')) {
      if (body['code'] != fakeOtpCode) {
        return _json({'detail': 'Invalid or expired code'}, 401);
      }
      return _json({
        'access_token': fakeScopedToken(permissions: const []),
        'refresh_token': 'fake-refresh-token',
        'token_type': 'bearer',
      }, 200);
    }

    if (method == 'GET' && path.endsWith('/users/me/onboarding-status')) {
      return _json({
        'needs_onboarding': state.needsOnboarding,
        'business_id': state.businessId,
        'business_name': state.businessName,
        'full_name': state.fullName,
        'email': state.email,
      }, 200);
    }

    if (method == 'PATCH' && path.endsWith('/users/me')) {
      state.fullName = body['full_name'] as String? ?? state.fullName;
      // Mirrors the backend: an omitted email leaves the login address alone.
      if (body.containsKey('email')) {
        state.email = body['email'] as String?;
      }
      if (body.containsKey('phone')) {
        state.phone = body['phone'] as String?;
      }
      return _json({'full_name': state.fullName, 'email': state.email}, 200);
    }

    if (method == 'POST' && path.endsWith('/businesses')) {
      final id = state.businessId ?? _createBusinessId();
      state.businessId = id;
      state.businessName = body['name'] as String? ?? 'Test Business';
      state.needsOnboarding = false;
      _seedRoleTemplates(id);
      final ownerRole = state.roles.firstWhere((r) => r['is_protected'] == true);
      return _json({
        'business': {
          'id': id,
          'business_id': id,
          'name': state.businessName,
          'business_type': body['business_type'],
          'organization_id': null,
          'tax_id': body['tax_id'],
          'registration_number': body['registration_number'],
          'email': body['email'],
          'phone': body['phone'],
          'address': body['address'],
          'status': 'active',
          'logo': null,
          'license_document_url': body['license_document_url'],
          'cuisine_type': body['cuisine_type'],
          'country_code': body['country_code'] ?? 'TZ',
          'city': body['city'],
          'timezone': body['timezone'] ?? 'Africa/Dar_es_Salaam',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        'roles_created': [for (final r in state.roles) r['name']],
        'owner_role_name': ownerRole['name'],
        'note': 'Call POST /auth/context/switch with this business_id.',
      }, 201);
    }

    if (method == 'POST' && path.endsWith('/auth/context/switch')) {
      final businessId = body['business_id'] as String? ?? state.businessId;
      return _json({
        'access_token': fakeScopedToken(businessId: businessId),
        'refresh_token': 'fake-refresh-token-2',
        'token_type': 'bearer',
      }, 200);
    }

    if (method == 'POST' && path.endsWith('/auth/context/switch-store')) {
      return _json({
        'access_token': fakeScopedToken(businessId: state.businessId),
        'refresh_token': 'fake-refresh-token-3',
        'token_type': 'bearer',
      }, 200);
    }

    final storeSettingsMatch =
        RegExp(r'/businesses/([^/]+)/stores/([^/]+)/settings$').firstMatch(path);
    if (method == 'GET' && storeSettingsMatch != null) {
      final storeId = storeSettingsMatch.group(2)!;
      return _json({
        'id': 'setting-$storeId',
        'store_id': storeId,
        'active': true,
        'preferred_currency': 'USD',
        'offer_retail': true,
        'offer_wholesale': false,
        'display_prices_inclusive_of_tax': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, 200);
    }

    final storesMatch = RegExp(r'/businesses/([^/]+)/stores$').firstMatch(path);
    if (method == 'GET' && storesMatch != null) {
      return _json(_fakeStores(storesMatch.group(1)!), 200);
    }

    final rolesListMatch = RegExp(r'/businesses/([^/]+)/roles$').firstMatch(path);
    if (method == 'GET' && rolesListMatch != null) {
      return _json(state.roles, 200);
    }
    if (method == 'POST' && rolesListMatch != null) {
      final role = _newRole(name: body['name'] as String, description: body['description'] as String?);
      state.roles.add(role);
      return _json(role, 201);
    }

    final roleMatch = RegExp(r'/businesses/([^/]+)/roles/([^/]+)$').firstMatch(path);
    if (roleMatch != null) {
      final roleId = roleMatch.group(2)!;
      final role = state.roles.where((r) => r['id'] == roleId).firstOrNull;
      if (role == null) return _json({'detail': 'Business role not found'}, 404);
      if (method == 'PATCH') {
        if (role['is_protected'] == true) {
          return _json({'detail': 'Protected roles cannot be modified'}, 403);
        }
        if (body['name'] != null) role['name'] = body['name'];
        if (body['description'] != null) role['description'] = body['description'];
        return _json(role, 200);
      }
      if (method == 'DELETE') {
        if (role['is_protected'] == true) {
          return _json({'detail': 'Protected roles cannot be deleted'}, 403);
        }
        state.roles.removeWhere((r) => r['id'] == roleId);
        return _json(null, 204);
      }
    }

    final rolePermsMatch =
        RegExp(r'/businesses/([^/]+)/roles/([^/]+)/permissions$').firstMatch(path);
    if (rolePermsMatch != null) {
      final roleId = rolePermsMatch.group(2)!;
      final role = state.roles.where((r) => r['id'] == roleId).firstOrNull;
      if (role == null) return _json({'detail': 'Business role not found'}, 404);
      final codes = role['permission_codes'] as List<String>;
      if (method == 'GET') {
        return _json([
          for (final code in codes) {'business_role_id': roleId, 'permission_code': code},
        ], 200);
      }
      if (method == 'POST') {
        final code = body['permission_code'] as String;
        if (!codes.contains(code)) codes.add(code);
        return _json({'detail': 'Permission assigned to role'}, 201);
      }
    }
    final removePermMatch =
        RegExp(r'/businesses/([^/]+)/roles/([^/]+)/permissions/([^/]+)$').firstMatch(path);
    if (method == 'DELETE' && removePermMatch != null) {
      final roleId = removePermMatch.group(2)!;
      final code = removePermMatch.group(3)!;
      final role = state.roles.where((r) => r['id'] == roleId).firstOrNull;
      if (role == null) return _json({'detail': 'Business role not found'}, 404);
      final codes = role['permission_codes'] as List<String>;
      if (!codes.remove(code)) {
        return _json({'detail': 'Permission not assigned to role'}, 404);
      }
      return _json(null, 204);
    }

    final staffListMatch = RegExp(r'/businesses/([^/]+)/staff$').firstMatch(path);
    if (method == 'GET' && staffListMatch != null) {
      // Store-scoped assignments ride along on the business roster, like the
      // real `list_staff` merge — the roster is one list, not two.
      return _json([
        for (final member in state.staff)
          {
            ...member,
            'roles': [
              ...(member['roles'] as List? ?? const []),
              ...((member['store_roles'] as List?) ?? const []),
            ],
          },
      ], 200);
    }
    if (method == 'POST' && staffListMatch != null) {
      final roleId = body['business_role_id'] as String;
      final role = state.roles.where((r) => r['id'] == roleId).firstOrNull;
      if (role == null) return _json({'detail': 'Business role not found'}, 404);

      final phone = body['phone'] as String?;
      final email = body['email'] as String?;
      final fullName = (body['full_name'] as String?)?.trim() ?? '';
      var member = phone != null
          ? state._staffByPhone(phone)
          : email == null
          ? null
          : state.staff
                .where((m) => m['email'] == email)
                .firstOrNull;
      if (member == null) {
        member = {
          'user_id': state._nextId('user'),
          'phone': phone,
          'full_name': fullName,
          'email': email,
          'status': 'invited',
          'roles': <Map<String, dynamic>>[],
        };
        state.staff.add(member);
      } else if ((member['full_name'] as String? ?? '').isEmpty && fullName.isNotEmpty) {
        member['full_name'] = fullName;
      }
      final existingRoles = member['roles'] as List<Map<String, dynamic>>;
      if (existingRoles.any((r) => r['business_role_id'] == roleId)) {
        return _json(
          {'detail': 'This user already has this role assignment at this business.'},
          409,
        );
      }
      existingRoles.add({'business_role_id': roleId, 'name': role['name']});
      return _json({'detail': 'Staff role assigned'}, 201);
    }

    final storeStaffMatch =
        RegExp(r'/businesses/([^/]+)/stores/([^/]+)/staff$').firstMatch(path);
    if (method == 'POST' && storeStaffMatch != null) {
      final storeId = storeStaffMatch.group(2)!;
      final roleId = body['business_role_id'] as String;
      final role = state.roles.where((r) => r['id'] == roleId).firstOrNull;
      if (role == null) return _json({'detail': 'Business role not found'}, 404);

      final phone = body['phone'] as String?;
      final email = body['email'] as String?;
      final fullName = (body['full_name'] as String?)?.trim() ?? '';
      var member = phone != null
          ? state._staffByPhone(phone)
          : email == null
          ? null
          : state.staff
                .where((m) => m['email'] == email)
                .firstOrNull;
      if (member == null) {
        member = {
          'user_id': state._nextId('user'),
          'phone': phone,
          'full_name': fullName,
          'email': email,
          'status': 'invited',
          'roles': <Map<String, dynamic>>[],
          'store_roles': <Map<String, dynamic>>[],
        };
        state.staff.add(member);
      } else if ((member['full_name'] as String? ?? '').isEmpty && fullName.isNotEmpty) {
        member['full_name'] = fullName;
      }
      final storeRoles =
          (member['store_roles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      member['store_roles'] = storeRoles;
      if (storeRoles.any(
        (r) => r['business_role_id'] == roleId && r['store_id'] == storeId,
      )) {
        return _json(
          {'detail': 'This user already has this role assignment at this store.'},
          409,
        );
      }
      final businessId = storeStaffMatch.group(1)!;
      final storeName = _fakeStores(
        businessId,
      ).where((s) => s['id'] == storeId).firstOrNull?['name'] as String?;
      storeRoles.add({
        'business_role_id': roleId,
        'name': role['name'],
        'store_id': storeId,
        'store_name': storeName,
      });
      return _json({'detail': 'Store staff role assigned'}, 201);
    }

    final revokeMatch =
        RegExp(r'/businesses/([^/]+)/staff/([^/]+)/roles/([^/]+)$').firstMatch(path);
    if (method == 'DELETE' && revokeMatch != null) {
      final userId = revokeMatch.group(2)!;
      final roleId = revokeMatch.group(3)!;
      final member = state.staff.where((s) => s['user_id'] == userId).firstOrNull;
      if (member == null) return _json({'detail': 'Staff role assignment not found'}, 404);
      final roles = member['roles'] as List<Map<String, dynamic>>;
      final before = roles.length;
      roles.removeWhere((r) => r['business_role_id'] == roleId);
      if (roles.length == before) {
        return _json({'detail': 'Staff role assignment not found'}, 404);
      }
      return _json(null, 204);
    }

    return _json({'detail': 'Not found (fake backend): $method $path'}, 404);
  }

  String _createBusinessId() => state._nextId('biz');

  Map<String, dynamic> _newRole({
    required String name,
    String? description,
    bool isProtected = false,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'id': state._nextId('role'),
      'business_id': state.businessId,
      'name': name,
      'description': description,
      'is_protected': isProtected,
      'created_at': now,
      'updated_at': now,
      // Not part of the real BusinessRoleRead shape — internal bookkeeping
      // for the fake's own /roles/{id}/permissions responses.
      'permission_codes': <String>[],
    };
  }

  /// Mirrors the real backend's role-template seeding for a restaurant
  /// business: one protected owner role plus four operational ones.
  void _seedRoleTemplates(String businessId) {
    state.roles
      ..clear()
      ..addAll([
        _newRole(name: 'restaurant_owner', description: 'Full operational control', isProtected: true)
          ..['permission_codes'] = <String>['*'],
        _newRole(name: 'Manager', description: 'Runs the floor day to day'),
        _newRole(name: 'Cashier', description: 'Takes orders and payments'),
        _newRole(name: 'Kitchen Staff', description: 'Prep and stock counts'),
        _newRole(name: 'Stock Controller', description: 'Purchasing and stock accuracy'),
      ]);
  }
}
