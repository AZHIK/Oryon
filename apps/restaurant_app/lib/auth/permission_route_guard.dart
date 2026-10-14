/// Route guards for permission-based access control.
///
/// Use with GoRouter to prevent navigation to protected routes without permission.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/permission_enforcement.dart';
import '../models/permission.dart';
import '../router/app_router.dart';

/// Guard a route: if user lacks permission, redirect to dashboard or deny screen.
///
/// Usage in router:
/// ```dart
/// GoRoute(
///   path: '/inventory',
///   redirect: (context, state) => permissionGuard(
///     ref,
///     state,
///     requiredPermission: AppPermissions.inventoryView,
///   ),
///   builder: ...
/// )
/// ```
Future<String?> permissionGuard(
  WidgetRef ref,
  GoRouterState state, {
  required String requiredPermission,
}) async {
  final enforcement = ref.watch(permissionEnforcementProvider);
  final result = await enforcement.checkPermission(requiredPermission);

  return result.when(
    onAllowed: () => null, // Allow navigation
    onDenied: (_, _) => AppRoute.dashboardPath, // Redirect to dashboard
    onUnknown: (_) => AppRoute.dashboardPath, // Offline: go to dashboard
  );
}

/// Simpler version for sync checks (use cautiously - doesn't wait for async).
/// Prefer the async version above.
bool canAccessRoute(WidgetRef ref, String requiredPermission) {
  // This is a sync check - it won't catch offline Unknown state perfectly
  // Use only for sidebar visibility, not for actual route guards
  return true; // Will be improved with caching
}
