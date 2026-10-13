/// One report's detail screen: live figures plus the usual exports.
///
/// Opened from [ReportsScreen] via `/reports/<id>`. The body is the same
/// section widget the aggregate endpoints back — and every section carries
/// the standard PDF/Excel export buttons (gated on `reports.export`),
/// driven by the exact columns and rows on screen, so the file always says
/// what the screen said.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/permission.dart';
import '../../providers/reports_provider.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/permission_gated_widget.dart';
import 'report_registry.dart';
import 'reports_screen.dart';

/// Detail for the report with route id [reportId].
class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({required this.reportId, super.key});

  final String reportId;

  /// Refreshes only this report's providers — opening a detail screen must
  /// never refetch the other nineteen.
  Future<void> _refresh(WidgetRef ref) {
    switch (reportId) {
      case 'profit-loss':
        return Future.wait([
          ref.read(financeSummaryProvider.notifier).refresh(),
          ref.read(itemMixProvider.notifier).refresh(),
          ref.read(productPurchasesProvider.notifier).refresh(),
          ref.read(wasteSummaryProvider.notifier).refresh(),
          ref.read(stockValuationProvider.notifier).refresh(),
        ]);
      case 'product-purchases':
        return ref.read(productPurchasesProvider.notifier).refresh();
      case 'service-staff':
      case 'sales-rep':
        return ref.read(staffPerformanceProvider.notifier).refresh();
      case 'register':
        return ref.read(dailyTakingsProvider.notifier).refresh();
      case 'expense':
        return ref.read(financeSummaryProvider.notifier).refresh();
      case 'sell-payments':
        return ref.read(sellPaymentsProvider.notifier).refresh();
      case 'product-sell':
        return ref.read(itemMixProvider.notifier).refresh();
      case 'purchase-sale':
        return Future.wait([
          ref.read(productPurchasesProvider.notifier).refresh(),
          ref.read(dailyTakingsProvider.notifier).refresh(),
        ]);
      case 'trending':
        return ref.read(trendingProductsProvider.notifier).refresh();
      case 'stock-adjustments':
        return ref.read(stockAdjustmentsProvider.notifier).refresh();
      case 'lots':
        return ref.read(lotReportProvider.notifier).refresh();
      case 'expiry':
        return ref.read(expiryReportProvider.notifier).refresh();
      case 'stock':
        return ref.read(stockValuationProvider.notifier).refresh();
      case 'customer-groups':
        return ref.read(customerGroupsProvider.notifier).refresh();
      case 'supplier-customer':
        return Future.wait([
          ref.read(supplierPurchasesProvider.notifier).refresh(),
          ref.read(customerSpendProvider.notifier).refresh(),
        ]);
      case 'tax':
        return ref.read(taxReportProvider.notifier).refresh();
      case 'activity':
        return ref.read(activityLogProvider.notifier).refresh();
      default:
        return Future.value();
    }
  }

  /// The section widget backing this report. `TakingsSection`,
  /// `FinanceSection`, `WasteSection`, `ProductionSection` and
  /// `ValuationSection` stay reachable through the reports they compose
  /// (register, expense, purchase-sale, stock), so the menu lists each
  /// drawer entry exactly once.
  Widget _body() {
    switch (reportId) {
      case 'profit-loss':
        return const ProfitLossSection();
      case 'product-purchases':
        return const ProductPurchasesSection();
      case 'service-staff':
        return const StaffSection();
      case 'sales-rep':
        return const SalesRepSection();
      case 'register':
        return const RegisterSection();
      case 'expense':
        return const ExpenseSection();
      case 'sell-payments':
        return const SellPaymentsSection();
      case 'product-sell':
        return const ItemMixSection();
      case 'items':
        return const ItemsSection();
      case 'purchase-sale':
        return const PurchaseSaleSection();
      case 'trending':
        return const TrendingSection();
      case 'stock-adjustments':
        return const StockAdjustmentsSection();
      case 'lots':
        return const LotSection();
      case 'expiry':
        return const ExpirySection();
      case 'stock':
        return const StockReportSection();
      case 'customer-groups':
        return const CustomerGroupsSection();
      case 'supplier-customer':
        return const SupplierCustomerSection();
      case 'tax':
        return const TaxSection();
      case 'activity':
        return const ActivityLogSection();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = reportById(reportId);
    if (meta == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report')),
        body: const Center(child: Text('Unknown report')),
      );
    }
    return PermissionGatedScreen(
      requiredPermission: AppPermissions.reportsView,
      title: meta.title,
      child: Scaffold(
        appBar: AppBar(
          title: Text(meta.title),
          elevation: 0,
          actions: const [ReportsDateAction()],
        ),
        body: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.all(Insets.lg),
            children: [
              const ReportsDateChip(),
              _body(),
            ],
          ),
        ),
      ),
    );
  }
}
