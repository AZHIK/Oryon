/// Request/response models for the Identity Service business-RBAC endpoints
/// (business roles, role permissions, staff assignment).
///
/// Shapes verified directly against `app/schemas/business_rbac.py`:
/// `is_protected` flags, with permissions fetched separately.
library;

/// A custom role scoped to one business, as returned by the role endpoints.
class BusinessRoleDto {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final bool isProtected;
  final DateTime createdAt;
  final DateTime updatedAt;

  BusinessRoleDto({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    required this.isProtected,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusinessRoleDto.fromJson(Map<String, dynamic> json) {
    return BusinessRoleDto(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isProtected: json['is_protected'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Request body for POST /businesses/{id}/roles.
class CreateRoleInput {
  final String name;
  final String? description;

  CreateRoleInput({required this.name, this.description});

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
      };
}

/// Request body for PATCH /businesses/{id}/roles/{roleId}.
class UpdateRoleInput {
  final String? name;
  final String? description;

  UpdateRoleInput({this.name, this.description});

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      };
}

/// One permission code assigned to a role, as returned by
/// GET /businesses/{id}/roles/{roleId}/permissions.
class RolePermissionDto {
  final String businessRoleId;
  final String permissionCode;

  RolePermissionDto({required this.businessRoleId, required this.permissionCode});

  factory RolePermissionDto.fromJson(Map<String, dynamic> json) {
    return RolePermissionDto(
      businessRoleId: json['business_role_id'] as String,
      permissionCode: json['permission_code'] as String,
    );
  }
}

/// Request body for POST /businesses/{id}/staff.
///
/// Identify the person by [phone] or [email] (server looks them up and
/// creates a pending invite if neither matches), or by [userId] for an
/// existing member getting another role.
class AssignStaffInput {
  final String businessRoleId;
  final String? phone;
  final String? email;
  final String? userId;
  final String? fullName;

  AssignStaffInput({
    required this.businessRoleId,
    this.phone,
    this.email,
    this.userId,
    this.fullName,
  });

  Map<String, dynamic> toJson() => {
        'business_role_id': businessRoleId,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (userId != null) 'user_id': userId,
        if (fullName != null) 'full_name': fullName,
      };
}

/// One role a staff member holds, within a [StaffMemberDto].
class StaffRoleSummaryDto {
  final String businessRoleId;
  final String name;

  /// Set only for store-scoped assignments (`UserStoreRole` on the backend).
  final String? storeId;
  final String? storeName;

  StaffRoleSummaryDto({
    required this.businessRoleId,
    required this.name,
    this.storeId,
    this.storeName,
  });

  factory StaffRoleSummaryDto.fromJson(Map<String, dynamic> json) {
    return StaffRoleSummaryDto(
      businessRoleId: json['business_role_id'] as String,
      name: json['name'] as String,
      storeId: json['store_id'] as String?,
      storeName: json['store_name'] as String?,
    );
  }
}

/// One staff member and every role they hold at a business, as returned by
/// GET /businesses/{id}/staff.
class StaffMemberDto {
  final String userId;

  /// Null for staff invited by email who have not added a phone yet.
  final String? phone;
  final String fullName;
  final String? email;
  final String status; // "active" | "invited" | "suspended" | "locked"
  final List<StaffRoleSummaryDto> roles;

  StaffMemberDto({
    required this.userId,
    required this.phone,
    required this.fullName,
    this.email,
    required this.status,
    required this.roles,
  });

  factory StaffMemberDto.fromJson(Map<String, dynamic> json) {
    return StaffMemberDto(
      userId: json['user_id'] as String,
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      status: json['status'] as String,
      roles: (json['roles'] as List<dynamic>)
          .map((r) => StaffRoleSummaryDto.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}
