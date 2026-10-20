/// HTTP client for Identity Service business-RBAC endpoints (roles, role
/// permissions, staff assignment).
///
/// Built on the shared [identityServiceDioProvider] Dio instance — its
/// `TokenRefreshInterceptor` attaches the current bearer token and handles
/// silent refresh-on-401 automatically, so methods here don't thread a
/// token through every call the way `IdentityServiceApi`'s auth methods
/// still do.
library;

import 'package:dio/dio.dart';
import '../constants/api_paths.dart';
import 'identity_service_api.dart' show AuthException;
import 'staff_rbac_dtos.dart';

class StaffRbacApi {
  final Dio _dio;

  StaffRbacApi({required this._dio});

  /// POST /businesses/{businessId}/roles
  Future<BusinessRoleDto> createRole({
    required String businessId,
    required CreateRoleInput input,
  }) async {
    try {
      final response = await _dio.post(
        IdentityApiPaths.roles(businessId),
        data: input.toJson(),
      );
      return BusinessRoleDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException.fromDio('Role creation failed', e);
    }
  }

  /// PATCH /businesses/{businessId}/roles/{roleId}
  Future<BusinessRoleDto> updateRole({
    required String businessId,
    required String roleId,
    required UpdateRoleInput input,
  }) async {
    try {
      final response = await _dio.patch(
        IdentityApiPaths.role(businessId, roleId),
        data: input.toJson(),
      );
      return BusinessRoleDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException.fromDio('Role update failed', e);
    }
  }

  /// DELETE /businesses/{businessId}/roles/{roleId}
  Future<void> deleteRole({required String businessId, required String roleId}) async {
    try {
      await _dio.delete(IdentityApiPaths.role(businessId, roleId));
    } on DioException catch (e) {
      throw AuthException.fromDio('Role deletion failed', e);
    }
  }

  /// GET /businesses/{businessId}/roles
  Future<List<BusinessRoleDto>> listRoles({required String businessId}) async {
    try {
      final response = await _dio.get(IdentityApiPaths.roles(businessId));
      return (response.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(BusinessRoleDto.fromJson)
          .toList();
    } on DioException catch (e) {
      throw AuthException.fromDio('Role list failed', e);
    }
  }

  /// GET /businesses/{businessId}/roles/{roleId}/permissions
  Future<List<RolePermissionDto>> listRolePermissions({
    required String businessId,
    required String roleId,
  }) async {
    try {
      final response = await _dio.get(
        IdentityApiPaths.rolePermissions(businessId, roleId),
      );
      return (response.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(RolePermissionDto.fromJson)
          .toList();
    } on DioException catch (e) {
      throw AuthException.fromDio('Role permissions fetch failed', e);
    }
  }

  /// POST /businesses/{businessId}/roles/{roleId}/permissions
  Future<void> assignRolePermission({
    required String businessId,
    required String roleId,
    required String permissionCode,
  }) async {
    try {
      await _dio.post(
        IdentityApiPaths.rolePermissions(businessId, roleId),
        data: {'permission_code': permissionCode},
      );
    } on DioException catch (e) {
      throw AuthException.fromDio('Permission assignment failed', e);
    }
  }

  /// DELETE /businesses/{businessId}/roles/{roleId}/permissions/{code}
  Future<void> removeRolePermission({
    required String businessId,
    required String roleId,
    required String permissionCode,
  }) async {
    try {
      await _dio.delete(
        IdentityApiPaths.rolePermission(businessId, roleId, permissionCode),
      );
    } on DioException catch (e) {
      throw AuthException.fromDio('Permission removal failed', e);
    }
  }

  /// POST /businesses/{businessId}/staff — invite by phone or email, or
  /// assign an additional role to an existing staff member by user id.
  Future<void> assignStaff({
    required String businessId,
    required AssignStaffInput input,
  }) async {
    try {
      await _dio.post(
        IdentityApiPaths.staff(businessId),
        data: input.toJson(),
      );
    } on DioException catch (e) {
      throw AuthException.fromDio('Staff assignment failed', e);
    }
  }

  /// GET /businesses/{businessId}/staff
  Future<List<StaffMemberDto>> listStaff({required String businessId}) async {
    try {
      final response = await _dio.get(IdentityApiPaths.staff(businessId));
      return (response.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(StaffMemberDto.fromJson)
          .toList();
    } on DioException catch (e) {
      throw AuthException.fromDio('Staff list failed', e);
    }
  }

  /// DELETE /businesses/{businessId}/staff/{userId}/roles/{roleId}
  Future<void> revokeStaffRole({
    required String businessId,
    required String userId,
    required String roleId,
  }) async {
    try {
      await _dio.delete(
        IdentityApiPaths.staffRole(businessId, userId, roleId),
      );
    } on DioException catch (e) {
      throw AuthException.fromDio('Role revoke failed', e);
    }
  }
}
