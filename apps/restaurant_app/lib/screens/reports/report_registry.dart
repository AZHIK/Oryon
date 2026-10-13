/// The 20 business reports, in menu order.
///
/// The Reports screen lists these entries; tapping one opens
/// [ReportDetailScreen] for that id. Ids are stable route segments
/// (`/reports/<id>`) — renaming a title never breaks a deep link.
library;

import 'package:flutter/material.dart';

/// Stable route id for one report.
@immutable
class ReportMeta {
  const ReportMeta({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

/// All reports, in the order the menu lists them.
const List<ReportMeta> allReports = [
  ReportMeta(
    id: 'profit-loss',
    title: 'Profit / Loss Report',
    subtitle: 'Revenue, costs, expenses and net profit',
    icon: Icons.account_balance_outlined,
  ),
  ReportMeta(
    id: 'product-purchases',
    title: 'Product Purchase Report',
    subtitle: 'What was bought, from whom, at what cost',
    icon: Icons.shopping_cart_outlined,
  ),
  ReportMeta(
    id: 'service-staff',
    title: 'Service Staff Report',
    subtitle: 'Sales performance per service staff member',
    icon: Icons.room_service_outlined,
  ),
  ReportMeta(
    id: 'sales-rep',
    title: 'Sales Representative Report',
    subtitle: 'Sales performance per sales representative',
    icon: Icons.badge_outlined,
  ),
  ReportMeta(
    id: 'register',
    title: 'Register Report',
    subtitle: 'Daily takings for shift close and reconciliation',
    icon: Icons.point_of_sale_outlined,
  ),
  ReportMeta(
    id: 'expense',
    title: 'Expense Report',
    subtitle: 'Ad-hoc spend broken down by category',
    icon: Icons.receipt_long_outlined,
  ),
  ReportMeta(
    id: 'sell-payments',
    title: 'Sell Payment Report',
    subtitle: 'Sales revenue grouped by payment method',
    icon: Icons.payments_outlined,
  ),
  ReportMeta(
    id: 'product-sell',
    title: 'Product Sell Report',
    subtitle: 'Quantity and revenue per product sold',
    icon: Icons.sell_outlined,
  ),
  ReportMeta(
    id: 'items',
    title: 'Items Report',
    subtitle: 'Catalog items with stock on hand',
    icon: Icons.inventory_2_outlined,
  ),
  ReportMeta(
    id: 'purchase-sale',
    title: 'Purchase & Sale',
    subtitle: 'Purchases side by side with sales',
    icon: Icons.compare_arrows_outlined,
  ),
  ReportMeta(
    id: 'trending',
    title: 'Trending Products',
    subtitle: 'Best sellers ranked by quantity',
    icon: Icons.trending_up_outlined,
  ),
  ReportMeta(
    id: 'stock-adjustments',
    title: 'Stock Adjustment Report',
    subtitle: 'Manual stock corrections in the window',
    icon: Icons.tune_outlined,
  ),
  ReportMeta(
    id: 'lots',
    title: 'Lot Report',
    subtitle: 'Received batches traced by lot',
    icon: Icons.batch_prediction_outlined,
  ),
  ReportMeta(
    id: 'expiry',
    title: 'Stock Expiry Report',
    subtitle: 'Lots expiring inside the window',
    icon: Icons.event_busy_outlined,
  ),
  ReportMeta(
    id: 'stock',
    title: 'Stock Report',
    subtitle: 'Current stock value by category',
    icon: Icons.warehouse_outlined,
  ),
  ReportMeta(
    id: 'customer-groups',
    title: 'Customer Groups Report',
    subtitle: 'Customers and spend bucketed by group',
    icon: Icons.group_outlined,
  ),
  ReportMeta(
    id: 'supplier-customer',
    title: 'Supplier & Customer Report',
    subtitle: 'Supplier purchases beside customer spend',
    icon: Icons.handshake_outlined,
  ),
  ReportMeta(
    id: 'tax',
    title: 'Tax Report',
    subtitle: 'Tax collected per day',
    icon: Icons.receipt_outlined,
  ),
  ReportMeta(
    id: 'activity',
    title: 'Activity Log',
    subtitle: 'Every stock movement, newest first',
    icon: Icons.history_outlined,
  ),
];

/// Looks up a report by its route id, or null for an unknown segment.
ReportMeta? reportById(String id) {
  for (final report in allReports) {
    if (report.id == id) return report;
  }
  return null;
}
