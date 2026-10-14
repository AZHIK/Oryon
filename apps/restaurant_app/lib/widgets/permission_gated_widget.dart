/// Widget wrapper for permission-gated UI elements.
///
/// Shows/hides/disables content based on permission checks.
/// Handles offline state (Unknown cache) gracefully.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/permission_enforcement.dart';
import '../constants/app_strings.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';

/// Wraps a widget with permission gating.
///
/// If user has permission: shows the child widget normally
/// If user lacks permission: shows a disabled/hidden version
/// If offline (no cache): shows "offline mode" version
///
/// Usage:
/// ```dart
/// PermissionGatedWidget(
///   requiredPermission: AppPermissions.inventoryItemsUpdate,
///   child: EditInventoryButton(),
///   onDenied: (reason) => Text('Cannot edit: $reason'),
/// )
/// ```
class PermissionGatedWidget extends ConsumerWidget {
  const PermissionGatedWidget({super.key,
    required this.requiredPermission,
    required this.child,
    this.onDenied,
    this.onUnknown,
  });

  final String requiredPermission;
  final Widget child;
  final Widget Function(String reason)? onDenied;
  final Widget Function(String reason)? onUnknown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkFuture = ref.watch(canPerformActionProvider(requiredPermission));

    return checkFuture.when(
      data: (hasPermission) {
        if (hasPermission) {
          return child;
        }
        return onDenied?.call(AppStrings.lackingPermission) ??
            _defaultDeniedWidget();
      },
      loading: () => _loadingWidget(),
      error: (error, _) {
        // If error is PermissionUnknownException, show offline version
        if (error is PermissionUnknownException) {
          return onUnknown?.call(error.message) ?? _defaultUnknownWidget();
        }
        return _errorWidget(error.toString());
      },
    );
  }

  static Widget _defaultDeniedWidget() {
    return Builder(
      builder: (context) => Opacity(
        opacity: 0.5,
        child: Tooltip(
          message: AppStrings.lackingPermission,
          child: Container(
            color: context.colors.onSurfaceVariant.withValues(alpha: 0.2),
            child: Text(
              AppStrings.noPermission,
              style: context.text.labelLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _defaultUnknownWidget() {
    return Builder(
      builder: (context) => Tooltip(
        message: AppStrings.offlinePermissionsTooltip,
        child: Container(
          color: context.semantic.warning.withValues(alpha: 0.1),
          padding: const EdgeInsets.all(8),
          child: Text(
            AppStrings.offlineMode,
            style: context.text.labelLarge?.copyWith(
              color: context.semantic.warning,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _loadingWidget() {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  static Widget _errorWidget(String message) {
    return Builder(
      builder: (context) => Tooltip(
        message: message,
        child: Container(
          color: context.semantic.danger.withValues(alpha: 0.1),
          child: Text(
            AppStrings.errorTitle,
            style: context.text.labelLarge?.copyWith(
              color: context.semantic.danger,
            ),
          ),
        ),
      ),
    );
  }
}

/// Button wrapper that disables if user lacks permission.
///
/// Usage:
/// ```dart
/// PermissionGatedButton(
///   requiredPermission: AppPermissions.posDiscount,
///   onPressed: () => applyDiscount(),
///   child: Text('Apply Discount'),
/// )
/// ```
class PermissionGatedButton extends ConsumerWidget {
  const PermissionGatedButton({super.key,
    required this.requiredPermission,
    required this.onPressed,
    required this.child,
  });

  final String requiredPermission;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkFuture = ref.watch(canPerformActionProvider(requiredPermission));

    return checkFuture.when(
      data: (hasPermission) {
        return Tooltip(
          message: hasPermission ? '' : AppStrings.lackingPermission,
          child: FilledButton(
            onPressed: hasPermission ? onPressed : null,
            child: child,
          ),
        );
      },
      loading: () => const FilledButton(
        onPressed: null,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, _) {
        // If offline, show disabled state
        if (error is PermissionUnknownException) {
          return Tooltip(
            message: AppStrings.offlineCheckUnavailable,
            child: FilledButton(
              onPressed: null,
              child: child,
            ),
          );
        }
        return FilledButton(
          onPressed: null,
          child: child,
        );
      },
    );
  }
}

/// Screen wrapper that checks permission before allowing access.
///
/// Usage:
/// ```dart
/// PermissionGatedScreen(
///   requiredPermission: AppPermissions.inventoryItemsUpdate,
///   child: EditInventoryScreen(),
///   onDenied: (reason) => PermissionDeniedScreen(reason),
/// )
/// ```
class PermissionGatedScreen extends ConsumerWidget {
  const PermissionGatedScreen({super.key,
    required this.requiredPermission,
    required this.child,
    this.title,
    this.feature,
    this.onDenied,
    this.onUnknown,
  });

  final String requiredPermission;
  final Widget child;

  /// Feature name for the fallback screens (`'Reports'` renders
  /// `'Reports Access Denied'`). Custom [onDenied]/[onUnknown] builders
  /// still win when provided — this only standardizes the screens that
  /// repeated the same denied/offline layout eleven times over.
  final String? title;

  /// Denied-headline base when it differs from [title] (e.g. appbar
  /// `'Other expenses'` but `'Finance Access Denied'`). Defaults to [title].
  final String? feature;

  final Widget Function(String reason)? onDenied;
  final Widget Function(String reason)? onUnknown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkFuture = ref.watch(canPerformActionProvider(requiredPermission));

    return checkFuture.when(
      data: (hasPermission) {
        if (hasPermission) {
          return child;
        }
        return onDenied?.call(AppStrings.lackingScreenPermission) ??
            _deniedScreen(title, feature ?? title);
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) {
        if (error is PermissionUnknownException) {
          return onUnknown?.call(error.message) ?? _unknownScreen(title);
        }
        return _errorScreen(error.toString());
      },
    );
  }

  static Widget _deniedScreen(String? title, String? feature) {
    if (title == null || feature == null) {
      return const _LegacyDeniedScreen();
    }
    return Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: context.colors.onSurfaceVariant,
                ),
                const SizedBox(height: Insets.lg),
                Text(
                  AppStrings.accessDeniedFor(feature),
                  style: context.text.headlineSmall,
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  AppStrings.lackingScreenPermission,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _unknownScreen(String? title) {
    if (title == null) {
      return const _LegacyUnknownScreen();
    }
    return Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 48,
                  color: context.semantic.warning,
                ),
                const SizedBox(height: Insets.lg),
                Text(
                  AppStrings.offlineMode,
                  style: context.text.headlineSmall,
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  AppStrings.offlineSubtitle,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _errorScreen(String message) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.errorTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Text(
            '${AppStrings.permissionCheckFailed}: $message',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Pre-title fallback: the generic denied screen for callers that don't
/// name their feature.
class _LegacyDeniedScreen extends StatelessWidget {
  const _LegacyDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.accessDenied)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(Insets.lg),
          child: Text(
            AppStrings.permissionDeniedHint,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Pre-title fallback: the generic offline screen.
class _LegacyUnknownScreen extends StatelessWidget {
  const _LegacyUnknownScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.offlineMode)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(Insets.lg),
          child: Text(
            AppStrings.offlinePermissionsHint,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
