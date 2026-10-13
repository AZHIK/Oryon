/// Backend endpoint paths, grouped by the Dio client that serves them.
///
/// The hosts live in `ApiConfig`; these are the paths *below* the service
/// root (which already ends in `/api/v1`). One builder per endpoint means a
/// renamed route is a one-line fix instead of a grep across twenty call
/// sites — and a typo'd path fails in exactly one place.
///
/// Local GoRouter paths (`/auth/login`, `/reports`, …) are UI routes, not
/// backend endpoints, and stay with the router.
library;

abstract final class IdentityApiPaths {
  static const otpRequest = '/auth/otp/request';
  static const otpVerify = '/auth/otp/verify';
  static const onboardingStatus = '/users/me/onboarding-status';
  static const updateMe = '/users/me';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const switchContext = '/auth/context/switch';
  static const switchStore = '/auth/context/switch-store';
  static const businesses = '/businesses';

  static String business(String businessId) => '/businesses/$businessId';

  /// Public (unauthenticated) existence probe — see `business_exists`.
  static String businessExists(String businessId) =>
      '/businesses/$businessId/exists';
  static String businessStores(String businessId) =>
      '/businesses/$businessId/stores';
  static String store(String businessId, String storeId) =>
      '/businesses/$businessId/stores/$storeId';
  static String storeSettings(String businessId, String storeId) =>
      '/businesses/$businessId/stores/$storeId/settings';
  static String storeStaff(String businessId, String storeId) =>
      '/businesses/$businessId/stores/$storeId/staff';
  static String storeStaffRole(
    String businessId,
    String storeId,
    String userId,
    String roleId,
  ) => '/businesses/$businessId/stores/$storeId/staff/$userId/roles/$roleId';

  static String roles(String businessId) => '/businesses/$businessId/roles';
  static String role(String businessId, String roleId) =>
      '/businesses/$businessId/roles/$roleId';
  static String rolePermissions(String businessId, String roleId) =>
      '/businesses/$businessId/roles/$roleId/permissions';
  static String rolePermission(
    String businessId,
    String roleId,
    String permissionCode,
  ) => '/businesses/$businessId/roles/$roleId/permissions/$permissionCode';
  static String staff(String businessId) => '/businesses/$businessId/staff';
  static String staffRole(String businessId, String userId, String roleId) =>
      '/businesses/$businessId/staff/$userId/roles/$roleId';

  /// Auth endpoints that must skip the token-refresh retry.
  static const publicAuthPaths = [
    '/auth/otp/verify',
    '/auth/login/password',
    '/auth/platform/login',
    // The refresh call itself: its own 401 means the session is dead, and
    // retrying it through the refresher would resend the same dead token
    // (nesting one refresh inside another) instead of surfacing the death.
    '/auth/refresh',
  ];
}

abstract final class InventoryApiPaths {
  static String items(String businessId) => '/businesses/$businessId/items';
  static String item(String businessId, String itemId) =>
      '/businesses/$businessId/items/$itemId';
  static String itemImage(String businessId, String itemId) =>
      '/businesses/$businessId/items/$itemId/image';
  static String itemAdjust(String businessId, String itemId) =>
      '/businesses/$businessId/items/$itemId/adjust';
  static String itemWaste(String businessId, String itemId) =>
      '/businesses/$businessId/items/$itemId/waste';
  static String transfer(String businessId) =>
      '/businesses/$businessId/transfer';
  static String recipes(String businessId) => '/businesses/$businessId/recipes';
  static String recipe(String businessId, String recipeId) =>
      '/businesses/$businessId/recipes/$recipeId';
  static String produce(String businessId, String recipeId) =>
      '/businesses/$businessId/recipes/$recipeId/produce';
  static String planProduction(String businessId, String recipeId) =>
      '/businesses/$businessId/recipes/$recipeId/plan';
  static String runs(String businessId) => '/businesses/$businessId/runs';
  static String run(String businessId, String runId) =>
      '/businesses/$businessId/runs/$runId';
  static String runAction(String businessId, String runId, String action) =>
      '/businesses/$businessId/runs/$runId/$action';
  static String productionEvents(String businessId) =>
      '/businesses/$businessId/production-events';
  static String productionEvent(String businessId, String eventId) =>
      '/businesses/$businessId/production-events/$eventId';
  static String wasteSummary(String businessId) =>
      '/businesses/$businessId/waste-summary';
  static String productionSummary(String businessId) =>
      '/businesses/$businessId/production-summary';
  static String stockValuation(String businessId) =>
      '/businesses/$businessId/stock-valuation';
  static String stock(String businessId) => '/businesses/$businessId/stock';
  static String productPurchases(String businessId) =>
      '/businesses/$businessId/product-purchases';
  static String stockAdjustments(String businessId) =>
      '/businesses/$businessId/stock-adjustments';
  static String lotReport(String businessId) =>
      '/businesses/$businessId/lot-report';
  static String expiryReport(String businessId) =>
      '/businesses/$businessId/expiry-report';
  static String costHistory(String businessId) =>
      '/businesses/$businessId/cost-history';
  static String supplierPurchases(String businessId) =>
      '/businesses/$businessId/supplier-purchases';
  static String activityLog(String businessId) =>
      '/businesses/$businessId/activity-log';
  static String suppliers(String businessId) =>
      '/businesses/$businessId/suppliers';
  static String supplier(String businessId, String supplierId) =>
      '/businesses/$businessId/suppliers/$supplierId';
  static String purchaseOrders(String businessId) =>
      '/businesses/$businessId/purchases/orders';
  static String purchaseOrder(String businessId, String orderId) =>
      '/businesses/$businessId/purchases/orders/$orderId';
  static String purchaseOrderAction(
    String businessId,
    String orderId,
    String action,
  ) => '/businesses/$businessId/purchases/orders/$orderId/$action';

  /// Unified multi-supplier requisition cart → per-supplier PO split.
  static String requisitions(String businessId) =>
      '/businesses/$businessId/requisitions';
  static String requisition(String businessId, String requisitionId) =>
      '/businesses/$businessId/requisitions/$requisitionId';
  static String requisitionBulkAssign(
    String businessId,
    String requisitionId,
  ) => '/businesses/$businessId/requisitions/$requisitionId/bulk-assign';
  static String requisitionPayloads(String businessId, String requisitionId) =>
      '/businesses/$businessId/requisitions/$requisitionId/regenerate-payloads';
  static String supplierItems(String businessId) =>
      '/businesses/$businessId/supplier-items';

  /// WhatsApp Business Cloud API connection.
  static String whatsappConnection(String businessId) =>
      '/businesses/$businessId/whatsapp/connection';
  static String whatsappConnectionTest(String businessId) =>
      '/businesses/$businessId/whatsapp/connection/test';

  /// Global taxonomy endpoints (no business scope).
  static const categories = '/categories';
  static const units = '/units';
}

abstract final class PosApiPaths {
  static String saleVoidRefund(String businessId, String saleId) =>
      '/businesses/$businessId/sales/$saleId/void-or-refund';
  static String salesSync(String businessId) =>
      '/businesses/$businessId/sales/sync';
  static String sales(String businessId) => '/businesses/$businessId/sales';
  static String sale(String businessId, String saleId) =>
      '/businesses/$businessId/sales/$saleId';
  static String dailyTakings(String businessId) =>
      '/businesses/$businessId/reports/daily-takings';
  static String itemMix(String businessId) =>
      '/businesses/$businessId/reports/item-mix';
  static String staffPerformance(String businessId) =>
      '/businesses/$businessId/reports/staff-performance';
  static String financeSummary(String businessId) =>
      '/businesses/$businessId/reports/finance-summary';
  static String sellPayments(String businessId) =>
      '/businesses/$businessId/reports/sell-payments';
  static String taxReport(String businessId) =>
      '/businesses/$businessId/reports/tax-report';
  static String registerSummary(String businessId) =>
      '/businesses/$businessId/reports/register-summary';
  static String expenseReport(String businessId) =>
      '/businesses/$businessId/reports/expense-report';
  static String profitLoss(String businessId) =>
      '/businesses/$businessId/reports/profit-loss';
  static String customerGroups(String businessId) =>
      '/businesses/$businessId/reports/customer-groups';
  static String customerSpend(String businessId) =>
      '/businesses/$businessId/reports/customer-spend';
  static String expense(String businessId, String expenseId) =>
      '/businesses/$businessId/other-expenses/$expenseId';
  static String expenses(String businessId) =>
      '/businesses/$businessId/other-expenses';
  static String expensesSync(String businessId) =>
      '/businesses/$businessId/other-expenses/sync';
  static String income(String businessId, String incomeId) =>
      '/businesses/$businessId/other-incomes/$incomeId';
  static String incomes(String businessId) =>
      '/businesses/$businessId/other-incomes';
  static String incomesSync(String businessId) =>
      '/businesses/$businessId/other-incomes/sync';
  static String attachments(String businessId) =>
      '/businesses/$businessId/finance/attachments';
  static String attachment(String businessId, String attachmentId) =>
      '/businesses/$businessId/finance/attachments/$attachmentId';
  static String customers(String businessId) =>
      '/businesses/$businessId/customers';
  static String customer(String businessId, String customerId) =>
      '/businesses/$businessId/customers/$customerId';
  static String customersSync(String businessId) =>
      '/businesses/$businessId/customers/sync';
  static String couriers(String businessId) =>
      '/businesses/$businessId/couriers';
  static String courier(String businessId, String courierId) =>
      '/businesses/$businessId/couriers/$courierId';
}
