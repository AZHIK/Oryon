import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/session.dart';
import '../providers/session_provider.dart';
import '../screens/auth/complete_profile_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/otp_login_screen.dart';
import '../screens/auth/pin_unlock_screen.dart';
import '../screens/auth/profile_picker_screen.dart';
import '../screens/auth/set_pin_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/customers/customers_screen_gated.dart';
import '../screens/customers/customer_detail_screen_gated.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/order_detail/order_detail_screen.dart';
import '../screens/inventory/inventory_groceries_screen_gated.dart';
import '../screens/inventory/inventory_menu_items_screen_gated.dart';
import '../screens/insights/ai_insights_screen.dart';
import '../screens/inventory/grocery_detail_screen.dart';
import '../screens/inventory/menu_item_detail_screen.dart';
import '../screens/inventory/production_module_screen_gated.dart';
import '../screens/purchases/purchase_detail_screen_gated.dart';
import '../screens/purchasing/purchasing_screen.dart';
import '../screens/purchasing/requisition_export_screen.dart';
import '../screens/purchasing/requisition_order_screen.dart';
import '../screens/reports/report_detail_screen.dart';
import '../screens/reports/reports_screen_gated.dart';
import '../screens/suppliers/suppliers_screen_gated.dart';
import '../screens/pos/pos_screen.dart';
import '../screens/sales/couriers_screen.dart';
import '../screens/sales/sales_screen.dart';
import '../screens/settings/account_settings_screen.dart';
import '../screens/settings/app_preferences_screen.dart';
import '../screens/settings/business_profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/store_management_screen.dart';
import '../screens/settings/store_settings_screen.dart';
import '../screens/settings/whatsapp_settings_screen.dart';
import '../screens/staff/roles_screen.dart';
import '../screens/staff/staff_detail_screen.dart';
import '../screens/staff/staff_screen.dart';
import '../screens/finance/other_expenses_screen_gated.dart';
import '../screens/finance/other_incomes_screen_gated.dart';
import '../widgets/responsive_scaffold.dart';

/// Route paths and names in one place, so navigation calls never spell a
/// string literal twice.
abstract final class AppRoute {
  /// The splash, and the app's entry point. It renders a brand moment and then
  /// the guard sends the user wherever [SessionState.entryRoute] says.
  static const splashPath = '/';
  static const splashName = 'splash';

  /// Everything under here is reachable signed out; everything else is not.
  static const authPrefix = '/auth';

  static const profilesPath = '$authPrefix/profiles';
  static const profilesName = 'authProfiles';

  static const loginPath = '$authPrefix/login';
  static const loginName = 'authLogin';

  static const completeProfilePath = '$authPrefix/complete-profile';
  static const completeProfileName = 'authCompleteProfile';

  static const setPinPath = '$authPrefix/set-pin';
  static const setPinName = 'authSetPin';

  /// `?mode=change` re-runs Set PIN from Account Settings rather than as
  /// first-time setup — same screen, different copy and different exit.
  static const setPinModeParam = 'mode';
  static const setPinChangeMode = 'change';

  static String setPin({bool change = false}) =>
      change ? '$setPinPath?$setPinModeParam=$setPinChangeMode' : setPinPath;

  static const unlockPath = '$authPrefix/unlock';
  static const unlockName = 'authUnlock';

  static const onboardingPath = '$authPrefix/onboarding';
  static const onboardingName = 'authOnboarding';

  static const dashboardPath = '/dashboard';
  static const dashboardName = 'dashboard';

  static const posPath = '/pos';
  static const posName = 'pos';

  static const salesPath = '/sales';
  static const salesName = 'sales';

  /// Nested under sales so the shell's Sales tab stays selected on detail.
  static const orderDetailPath = ':orderId';
  static const orderDetailName = 'orderDetail';

  static String orderDetail(String orderId) => '$salesPath/$orderId';

  static const customersPath = '/customers';
  static const customersName = 'customers';

  /// Nested under customers so the shell's Customers tab stays selected.
  static const customerDetailPath = ':customerId';
  static const customerDetailName = 'customerDetail';

  static String customerDetail(String customerId) =>
      '$customersPath/$customerId';

  static const reportsPath = '/reports';
  static const reportsName = 'reports';

  /// One report's detail, nested under [reportsPath] so the shell's
  /// Reports tab stays selected — same pattern as `:itemId` under
  /// `/inventory` and `:customerId` under `/customers`.
  static const reportDetailPath = ':reportId';
  static const reportDetailName = 'reportDetail';

  static String reportDetail(String reportId) => '$reportsPath/$reportId';

  static const insightsPath = '/insights';
  static const insightsName = 'insights';

  static const inventoryPath = '/inventory';
  static const groceriesName = 'inventoryGroceries';

  static String groceries() => inventoryPath;

  static const menuItemsPath = '/menu-items';
  static const menuItemsName = 'inventoryMenuItems';

  static String menuItems() => menuItemsPath;

  /// Detail screens nest under their own list, so the shell highlights the
  /// right Stock entry — groceries under Groceries, menu items under Menu
  /// Items. Each detail redirects a mistyped line to its sibling, so an old
  /// `/inventory/<id>` bookmark for a menu item still lands correctly.
  static const groceryDetailPath = ':itemId';
  static const groceryDetailName = 'groceryDetail';

  static String groceryDetail(String itemId) => '$inventoryPath/$itemId';

  static const menuItemDetailPath = ':itemId';
  static const menuItemDetailName = 'menuItemDetail';

  static String menuItemDetail(String itemId) => '$menuItemsPath/$itemId';

  /// The detail route for an item of [itemType] (`raw_material` goes to
  /// Groceries, everything else to Menu Items). Used by callers that only
  /// hold an id and resolve the type first.
  static String itemDetailFor({
    required String itemType,
    required String itemId,
  }) => itemType == 'raw_material'
      ? groceryDetail(itemId)
      : menuItemDetail(itemId);

  static const staffPath = '/staff';
  static const staffName = 'staff';

  /// Declared before [staffDetailPath] in the route table: `/staff/roles` has
  /// to match the literal segment, not be swallowed as a staff id.
  static const rolesPath = 'roles';
  static const rolesName = 'staffRoles';

  static String roles() => '$staffPath/$rolesPath';

  static const staffDetailPath = ':staffId';
  static const staffDetailName = 'staffDetail';

  static String staffDetail(String staffId) => '$staffPath/$staffId';

  static const financePath = '/finance';
  static const financeName = 'finance';

  static const financeExpensesPath = 'expenses';
  static const financeExpensesName = 'financeExpenses';

  static String financeExpenses() => '$financePath/$financeExpensesPath';

  static const financeIncomesPath = 'incomes';
  static const financeIncomesName = 'financeIncomes';

  static String financeIncomes() => '$financePath/$financeIncomesPath';

  static const settingsPath = '/settings';
  static const settingsName = 'settings';

  /// All nested under settings so the shell's Settings tab stays selected on
  /// every one of them.
  static const businessProfilePath = 'business-profile';
  static const businessProfileName = 'businessProfile';

  static String businessProfile() => '$settingsPath/$businessProfilePath';

  static const storeSettingsPath = 'store-settings';
  static const storeSettingsName = 'storeSettings';

  static String storeSettings() => '$settingsPath/$storeSettingsPath';

  static const storeManagementPath = 'store-management';
  static const storeManagementName = 'storeManagement';

  static String storeManagement() => '$settingsPath/$storeManagementPath';

  static const appPreferencesPath = 'app-preferences';
  static const appPreferencesName = 'appPreferences';

  static String appPreferences() => '$settingsPath/$appPreferencesPath';

  static const accountPath = 'account';
  static const accountName = 'account';

  static String account() => '$settingsPath/$accountPath';

  static const whatsappPath = 'whatsapp';
  static const whatsappName = 'whatsapp';

  static String whatsapp() => '$settingsPath/$whatsappPath';

  /// Top-level route outside the shell, reached via the bell icon in the app bar.
  static const notificationsPath = '/notifications';
  static const notificationsName = 'notifications';

  /// Purchasing module (multi-line purchase orders).
  static const purchasingPath = '/purchasing';
  static const purchasingName = 'purchasing';

  /// Legacy deep-link target — reorders were removed, so old
  /// bookmarks/deep links land on purchasing instead.
  static const legacyReordersPath = '/reorders';

  static String purchaseDetail(String orderId) => '$purchasingPath/$orderId';
  static const purchaseDetailPath = ':orderId';
  static const purchaseDetailName = 'purchaseDetail';

  /// Unified requisition order (Option 2 UX: grouped supplier cards, no PO
  /// numbers) + its secondary export view (real PO numbers, printable).
  static String requisitionDetail(String requisitionId) =>
      '$purchasingPath/requisition/$requisitionId';
  static const requisitionDetailPath = 'requisition/:requisitionId';
  static const requisitionDetailName = 'requisitionDetail';

  static String requisitionExport(String requisitionId) =>
      '$purchasingPath/requisition/$requisitionId/export';
  static const requisitionExportPath = 'export';
  static const requisitionExportName = 'requisitionExport';

  static const productionPath = '/production';
  static const productionName = 'production';

  static const suppliersPath = '/suppliers';
  static const suppliersName = 'suppliers';

  static const couriersPath = '/couriers';
  static const couriersName = 'couriers';
}

/// The app's router, exposed through Riverpod so it is created and disposed
/// with the rest of the app state rather than as a global.
final goRouterProvider = Provider<GoRouter>((ref) {
  // Owned by the router rather than the library. Module-level keys would be
  // shared by every router ever built, so a second ProviderScope — a test
  // pumping the app twice, or a second window — would collide on them.
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final dashboardNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'dashboard',
  );
  final posNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'pos');
  final salesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'sales');
  final customersNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'customers',
  );
  final purchasingNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'purchasing',
  );
  final productionNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'production',
  );
  final suppliersNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'suppliers',
  );
  final couriersNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'couriers',
  );
  final reportsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'reports');
  final insightsNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'insights',
  );
  final groceriesNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'groceries',
  );
  final menuItemsNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'menu-items',
  );
  final financeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'finance');
  final staffNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'staff');
  final settingsNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'settings',
  );

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    // The splash, always. What comes after it is the guard's decision, made
    // from session state rather than from wherever the app happened to launch.
    initialLocation: AppRoute.splashPath,
    debugLogDiagnostics: false,
    refreshListenable: ref.watch(sessionRefreshProvider),
    redirect: (context, state) => _guard(ref, state),
    routes: [
      // Outside the shell: an auth screen has no nav rail, no bottom bar and
      // nothing to switch to. They are the app's front door, not a tab in it.
      GoRoute(
        path: AppRoute.splashPath,
        name: AppRoute.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoute.profilesPath,
        name: AppRoute.profilesName,
        builder: (context, state) => const ProfilePickerScreen(),
      ),
      GoRoute(
        path: AppRoute.loginPath,
        name: AppRoute.loginName,
        builder: (context, state) => const OtpLoginScreen(),
      ),
      GoRoute(
        path: AppRoute.completeProfilePath,
        name: AppRoute.completeProfileName,
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: AppRoute.setPinPath,
        name: AppRoute.setPinName,
        builder: (context, state) => SetPinScreen(
          isChangingPin:
              state.uri.queryParameters[AppRoute.setPinModeParam] ==
              AppRoute.setPinChangeMode,
        ),
      ),
      GoRoute(
        path: AppRoute.unlockPath,
        name: AppRoute.unlockName,
        builder: (context, state) => const PinUnlockScreen(),
      ),
      GoRoute(
        path: AppRoute.onboardingPath,
        name: AppRoute.onboardingName,
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Top-level notifications screen (not under shell branches)
      GoRoute(
        path: AppRoute.notificationsPath,
        name: AppRoute.notificationsName,
        builder: (context, state) => const NotificationsScreen(),
      ),
      // Legacy single-item reorders lived here before they were removed —
      // send old bookmarks/deep links to the purchasing module.
      GoRoute(
        path: AppRoute.legacyReordersPath,
        redirect: (_, _) => AppRoute.purchasingPath,
      ),
      // The old tab routes from when Groceries and Menu Items shared one
      // Inventory branch — send old bookmarks to their standalone homes.
      GoRoute(
        path: '/inventory/groceries',
        redirect: (_, _) => AppRoute.inventoryPath,
      ),
      GoRoute(
        path: '/inventory/menu-items',
        redirect: (_, _) => AppRoute.menuItemsPath,
      ),
      // An IndexedStack shell: each branch keeps its own Navigator, so the
      // POS cart and the Sales scroll position both survive tab switches.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ResponsiveScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: dashboardNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.dashboardPath,
                name: AppRoute.dashboardName,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: posNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.posPath,
                name: AppRoute.posName,
                builder: (context, state) => const PosScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: salesNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.salesPath,
                name: AppRoute.salesName,
                builder: (context, state) => const SalesScreen(),
                routes: [
                  GoRoute(
                    path: AppRoute.orderDetailPath,
                    name: AppRoute.orderDetailName,
                    builder: (context, state) => OrderDetailScreen(
                      orderId: state.pathParameters['orderId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: customersNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.customersPath,
                name: AppRoute.customersName,
                builder: (context, state) => const CustomersScreenGated(),
                routes: [
                  GoRoute(
                    path: AppRoute.customerDetailPath,
                    name: AppRoute.customerDetailName,
                    builder: (context, state) => CustomerDetailScreenGated(
                      customerId: state.pathParameters['customerId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: purchasingNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.purchasingPath,
                name: AppRoute.purchasingName,
                builder: (context, state) => const PurchasingScreen(),
                routes: [
                  // Declared before `:orderId` so the literal `requisition`
                  // segment matches first — same ordering rule as
                  // `/staff/roles` versus `:staffId`.
                  GoRoute(
                    path: AppRoute.requisitionDetailPath,
                    name: AppRoute.requisitionDetailName,
                    builder: (context, state) => RequisitionOrderScreen(
                      requisitionId: state.pathParameters['requisitionId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: AppRoute.requisitionExportPath,
                        name: AppRoute.requisitionExportName,
                        builder: (context, state) => RequisitionExportScreen(
                          requisitionId: state.pathParameters['requisitionId']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: AppRoute.purchaseDetailPath,
                    name: AppRoute.purchaseDetailName,
                    builder: (context, state) => PurchaseDetailScreenGated(
                      orderId: state.pathParameters['orderId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: productionNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.productionPath,
                name: AppRoute.productionName,
                builder: (context, state) =>
                    const ProductionModuleScreenGated(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: suppliersNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.suppliersPath,
                name: AppRoute.suppliersName,
                builder: (context, state) => const SuppliersScreenGated(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: couriersNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.couriersPath,
                name: AppRoute.couriersName,
                builder: (context, state) => const CouriersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: financeNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.financePath,
                name: AppRoute.financeName,
                builder: (context, state) => const OtherExpensesScreenGated(),
                routes: [
                  GoRoute(
                    path: AppRoute.financeExpensesPath,
                    name: AppRoute.financeExpensesName,
                    builder: (context, state) =>
                        const OtherExpensesScreenGated(),
                  ),
                  GoRoute(
                    path: AppRoute.financeIncomesPath,
                    name: AppRoute.financeIncomesName,
                    builder: (context, state) =>
                        const OtherIncomesScreenGated(),
                  ),
                ],
              ),
            ],
          ),
          // Advertised by the rail but not part of this UI build. Real
          // branches, so each keeps its own Navigator and swapping in a real
          // screen is a one-line change here.
          StatefulShellBranch(
            navigatorKey: reportsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.reportsPath,
                name: AppRoute.reportsName,
                builder: (context, state) => const ReportsScreenGated(),
                routes: [
                  GoRoute(
                    path: AppRoute.reportDetailPath,
                    name: AppRoute.reportDetailName,
                    builder: (context, state) => ReportDetailScreen(
                      reportId: state.pathParameters['reportId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: insightsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.insightsPath,
                name: AppRoute.insightsName,
                builder: (context, state) => const AiInsightsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: groceriesNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.inventoryPath,
                name: AppRoute.groceriesName,
                builder: (context, state) =>
                    const InventoryGroceriesScreenGated(),
                routes: [
                  GoRoute(
                    path: AppRoute.groceryDetailPath,
                    name: AppRoute.groceryDetailName,
                    builder: (context, state) => GroceryDetailScreen(
                      itemId: state.pathParameters['itemId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: menuItemsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.menuItemsPath,
                name: AppRoute.menuItemsName,
                builder: (context, state) =>
                    const InventoryMenuItemsScreenGated(),
                routes: [
                  GoRoute(
                    path: AppRoute.menuItemDetailPath,
                    name: AppRoute.menuItemDetailName,
                    builder: (context, state) => MenuItemDetailScreen(
                      itemId: state.pathParameters['itemId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: staffNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.staffPath,
                name: AppRoute.staffName,
                builder: (context, state) => const StaffScreen(),
                routes: [
                  // Order matters: the literal `roles` segment is declared
                  // first so it is not captured by the `:staffId` pattern
                  // below it.
                  GoRoute(
                    path: AppRoute.rolesPath,
                    name: AppRoute.rolesName,
                    builder: (context, state) => const RolesScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.staffDetailPath,
                    name: AppRoute.staffDetailName,
                    builder: (context, state) => StaffDetailScreen(
                      staffId: state.pathParameters['staffId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: settingsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoute.settingsPath,
                name: AppRoute.settingsName,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: AppRoute.businessProfilePath,
                    name: AppRoute.businessProfileName,
                    builder: (context, state) => const BusinessProfileScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.storeSettingsPath,
                    name: AppRoute.storeSettingsName,
                    builder: (context, state) => const StoreSettingsScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.storeManagementPath,
                    name: AppRoute.storeManagementName,
                    builder: (context, state) => const StoreManagementScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.appPreferencesPath,
                    name: AppRoute.appPreferencesName,
                    builder: (context, state) => const AppPreferencesScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.accountPath,
                    name: AppRoute.accountName,
                    builder: (context, state) => const AccountSettingsScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.whatsappPath,
                    name: AppRoute.whatsappName,
                    builder: (context, state) => const WhatsAppSettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _RouteErrorScreen(error: state.error),
  );

  ref.onDispose(router.dispose);
  return router;
});

/// The app's only route guard.
///
/// Returns null to allow a navigation and a path to divert it. Two rules, in
/// this order:
///
///  1. The splash holds everything until it has had its moment, then hands off
///     to wherever [SessionState.entryRoute] points.
///  2. Anything outside `/auth` needs a signed-in, unlocked, onboarded session
///     and is bounced back to the right step of the flow when it does not have
///     one.
///
/// Auth routes themselves are deliberately *not* guarded in reverse: reaching
/// `/auth/unlock` while already unlocked is someone locking the till on
/// purpose at the end of a shift, and bouncing them to the Dashboard would
/// make that impossible.
String? _guard(Ref ref, GoRouterState state) {
  final session = ref.read(sessionProvider);
  final location = state.matchedLocation;

  if (location == AppRoute.splashPath) {
    return session.bootstrapped ? session.entryRoute : null;
  }

  if (location.startsWith(AppRoute.authPrefix)) return null;

  // Everything below here is inside the shell and needs a real session.
  if (!session.isLoggedIn) {
    return session.hasSavedProfiles
        ? AppRoute.profilesPath
        : AppRoute.loginPath;
  }
  if (!session.hasPin) return AppRoute.setPinPath;
  if (!session.isUnlocked) return AppRoute.unlockPath;
  if (!session.hasCompletedOnboarding) return AppRoute.onboardingPath;

  return null;
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.explore_off_rounded,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text('Page not found', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    error?.toString() ?? 'That route does not exist.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.goNamed(AppRoute.posName),
                    icon: const Icon(Icons.point_of_sale_rounded),
                    label: const Text('Back to POS'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
