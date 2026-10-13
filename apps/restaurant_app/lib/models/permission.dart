import 'package:flutter/material.dart';

/// One thing a role can be allowed to do.
///
/// Identified by a stable dotted string rather than an enum value, because a
/// real backend hands these over as strings and a custom role saved today has
/// to still resolve after the catalogue grows tomorrow.
@immutable
class Permission {
  const Permission({
    required this.id,
    required this.label,
    required this.description,
  });

  /// e.g. `inventory.adjust`. Stored on the role.
  final String id;

  final String label;

  /// One line under the toggle in the role form, so the person granting a
  /// permission does not have to infer its blast radius from four words.
  final String description;
}

/// A related set of permissions, rendered as one collapsible section.
@immutable
class PermissionGroup {
  const PermissionGroup({
    required this.id,
    required this.label,
    required this.icon,
    required this.permissions,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<Permission> permissions;

  List<String> get permissionIds => [for (final p in permissions) p.id];
}

/// The permission catalogue.
///
/// The single source of truth for what a role *can* grant. The role form
/// renders it, the roles table counts against it, and the invite dialog reads
/// labels out of it — none of them hold a list of their own.
///
/// Every id here is a real `PermissionCode` value from the identity-service
/// backend (`app/core/permission_codes.py`) — this used to be an invented
/// catalogue that only accidentally overlapped the backend on 3 of 18
/// entries; every id below either matches a code an endpoint actually
/// enforces today, or one added specifically so this editor has something
/// real to assign (POS/Inventory extras, Sales & Reports, Settings — all
/// unenforced until a future service checks them, same as the backend's own
/// `procurement.*`/`ai.*` codes being defined ahead of their service).
///
/// The Staff Management group deliberately does *not* invent parallel
/// `staff.invite`/`staff.roles`-style ids: the real staff/role endpoints
/// check `user_business_roles.*`/`business_roles.*` specifically, so this
/// group uses those directly — a toggle that doesn't match what the backend
/// actually checks would grant nothing.
abstract final class AppPermissions {
  /// Permissions that let a staff member work a till. A role holding this
  /// gets the sales performance block on their detail screen.
  static const posAccess = 'pos.write';
  static const posView = 'pos.view';
  static const posDiscount = 'pos.discount';
  static const posRefund = 'pos.refund';

  static const inventoryView = 'inventory.view';
  static const inventoryAdjust = 'inventory.adjust';
  static const inventoryItemsCreate = 'inventory.items.create';
  static const inventoryItemsUpdate = 'inventory.items.update';
  static const inventoryItemsDeactivate = 'inventory.items.deactivate';
  static const inventoryWasteRecord = 'inventory.waste.record';
  static const inventoryTransfer = 'inventory.transfer';
  static const productionCreate = 'production.create';
  static const productionView = 'production.view';
  static const recipesView = 'recipes.view';
  static const recipesCreate = 'recipes.create';
  static const recipesUpdate = 'recipes.update';
  static const recipesDelete = 'recipes.delete';

  static const salesView = 'sales.view';
  static const salesExport = 'sales.export';
  static const reportsView = 'reports.view';
  static const reportsExport = 'reports.export';

  static const customersView = 'customers.view';
  static const customersCreate = 'customers.create';
  static const customersUpdate = 'customers.update';
  static const customersDelete = 'customers.delete';
  static const procurementView = 'procurement.view';
  static const procurementCreate = 'procurement.create';
  static const procurementApprove = 'procurement.approve';
  static const procurementReceive = 'procurement.receive';
  static const suppliersView = 'suppliers.view';
  static const suppliersCreate = 'suppliers.create';
  static const suppliersUpdate = 'suppliers.update';
  static const suppliersDelete = 'suppliers.delete';
  static const couriersView = 'couriers.view';
  static const couriersCreate = 'couriers.create';
  static const couriersUpdate = 'couriers.update';
  static const couriersDelete = 'couriers.delete';
  static const financeView = 'finance.view';
  static const financeExpensesCreate = 'finance.expenses.create';
  static const financeExpensesUpdate = 'finance.expenses.update';
  static const financeExpensesDelete = 'finance.expenses.delete';
  static const financeIncomesCreate = 'finance.incomes.create';
  static const financeIncomesUpdate = 'finance.incomes.update';
  static const financeIncomesDelete = 'finance.incomes.delete';
  static const financeAttachmentsUpload = 'finance.attachments.upload';
  static const insightsView = 'insights.view';

  static const rolesView = 'business_roles.view';
  static const rolesCreate = 'business_roles.create';
  static const rolesUpdate = 'business_roles.update';
  static const rolesDelete = 'business_roles.delete';
  static const rolesManagePermissions = 'business_roles.manage_permissions';
  static const staffView = 'user_business_roles.view';
  static const staffAssign = 'user_business_roles.assign';
  static const staffRevoke = 'user_business_roles.revoke';

  static const settingsStore = 'settings.store';
  static const settingsTax = 'settings.tax';
  static const settingsDevices = 'settings.devices';
  static const settingsBilling = 'settings.billing';

  static const storesView = 'stores.view';
  static const storesCreate = 'stores.create';
  static const storesUpdate = 'stores.update';
  static const storesDelete = 'stores.delete';
  static const storesSwitch = 'stores.switch';

  static const groups = <PermissionGroup>[
    PermissionGroup(
      id: 'pos',
      label: 'Point of Sale',
      icon: Icons.point_of_sale_outlined,
      permissions: [
        Permission(
          id: posAccess,
          label: 'Open the till',
          description: 'Take orders and process payments',
        ),
        Permission(
          id: posDiscount,
          label: 'Apply discounts',
          description: 'Reduce a ticket total before payment',
        ),
        Permission(
          id: posRefund,
          label: 'Process refunds',
          description: 'Return money against a completed sale',
        ),
      ],
    ),
    PermissionGroup(
      id: 'inventory',
      label: 'Inventory',
      icon: Icons.inventory_2_outlined,
      permissions: [
        Permission(
          id: inventoryView,
          label: 'View items',
          description: 'See stock levels and item details',
        ),
        Permission(
          id: inventoryItemsCreate,
          label: 'Add items',
          description: 'Create new items in the catalog',
        ),
        Permission(
          id: inventoryItemsUpdate,
          label: 'Edit items',
          description: "Change an item's name, category, costs or thresholds",
        ),
        Permission(
          id: inventoryAdjust,
          label: 'Adjust stock',
          description: 'Record recounts and manual corrections',
        ),
        Permission(
          id: inventoryWasteRecord,
          label: 'Log waste',
          description: 'Record spoiled or wasted stock',
        ),
        Permission(
          id: inventoryTransfer,
          label: 'Transfer stock',
          description: 'Move stock between store locations',
        ),
        Permission(
          id: productionCreate,
          label: 'Record production',
          description: 'Consume ingredients and stock finished dishes',
        ),
        Permission(
          id: productionView,
          label: 'View production history',
          description: 'See recorded production runs and consumption',
        ),
        Permission(
          id: recipesView,
          label: 'View recipes',
          description: 'See bills of materials for menu items',
        ),
        Permission(
          id: recipesCreate,
          label: 'Add recipes',
          description: 'Define bills of materials for menu items',
        ),
        Permission(
          id: recipesUpdate,
          label: 'Edit recipes',
          description: 'Change recipe ingredients or rename recipes',
        ),
        Permission(
          id: recipesDelete,
          label: 'Delete recipes',
          description: 'Remove bills of materials from menu items',
        ),
        Permission(
          id: inventoryItemsDeactivate,
          label: 'Delete items',
          description: 'Remove an item from active inventory',
        ),
      ],
    ),
    PermissionGroup(
      id: 'sales',
      label: 'Sales & Reports',
      icon: Icons.receipt_long_outlined,
      permissions: [
        Permission(
          id: salesView,
          label: 'View sales',
          description: 'Browse the order ledger and receipts',
        ),
        Permission(
          id: salesExport,
          label: 'Export sales data',
          description: 'Download the ledger as PDF or Excel',
        ),
        Permission(
          id: reportsView,
          label: 'View reports',
          description: 'Takings, item mix and staff performance',
        ),
        Permission(
          id: reportsExport,
          label: 'Export reports',
          description: 'Download report tables as PDF or Excel',
        ),
      ],
    ),
    PermissionGroup(
      id: 'operations',
      label: 'Operations',
      icon: Icons.dashboard_customize_outlined,
      permissions: [
        Permission(
          id: customersView,
          label: 'View customers',
          description: 'Browse the customer list, profiles, and order history',
        ),
        Permission(
          id: customersCreate,
          label: 'Add customers',
          description: 'Create a new customer record, including from the checkout flow',
        ),
        Permission(
          id: customersUpdate,
          label: 'Edit customers',
          description: "Change a customer's name, phone, email, or address",
        ),
        Permission(
          id: customersDelete,
          label: 'Delete customers',
          description: 'Remove a customer record',
        ),
        Permission(
          id: procurementView,
          label: 'View purchases',
          description: 'Browse multi-line purchase orders, receipts and invoices',
        ),
        Permission(
          id: procurementCreate,
          label: 'Create purchases',
          description: 'Draft, submit and cancel multi-line purchase orders',
        ),
        Permission(
          id: procurementApprove,
          label: 'Approve purchases',
          description: 'Approve purchase orders and record invoices and payments',
        ),
        Permission(
          id: procurementReceive,
          label: 'Receive purchases',
          description: 'Record goods receipts and purchase returns against orders',
        ),
        Permission(
          id: suppliersView,
          label: 'View suppliers',
          description: 'Browse the supplier list',
        ),
        Permission(
          id: suppliersCreate,
          label: 'Add suppliers',
          description: 'Create a new supplier record, including from the order cart',
        ),
        Permission(
          id: suppliersUpdate,
          label: 'Edit suppliers',
          description: "Change a supplier's name or contact details",
        ),
        Permission(
          id: suppliersDelete,
          label: 'Delete suppliers',
          description: 'Remove a supplier record',
        ),
        Permission(
          id: couriersView,
          label: 'View couriers',
          description: 'Track delivery couriers and their assignments',
        ),
        Permission(
          id: couriersCreate,
          label: 'Add couriers',
          description: 'Register a new delivery courier',
        ),
        Permission(
          id: couriersUpdate,
          label: 'Edit couriers',
          description: "Change a courier's details or availability",
        ),
        Permission(
          id: couriersDelete,
          label: 'Delete couriers',
          description: 'Remove a courier record',
        ),
        Permission(
          id: financeView,
          label: 'View finance',
          description: 'See revenue, payouts and financial summaries',
        ),
        Permission(
          id: financeExpensesCreate,
          label: 'Add expenses',
          description: 'Record a new ad-hoc expense entry',
        ),
        Permission(
          id: financeExpensesUpdate,
          label: 'Edit expenses',
          description: 'Change an existing expense entry',
        ),
        Permission(
          id: financeExpensesDelete,
          label: 'Delete expenses',
          description: 'Remove an expense entry',
        ),
        Permission(
          id: financeIncomesCreate,
          label: 'Add other income',
          description: 'Record a new ad-hoc income entry',
        ),
        Permission(
          id: financeIncomesUpdate,
          label: 'Edit other income',
          description: 'Change an existing income entry',
        ),
        Permission(
          id: financeIncomesDelete,
          label: 'Delete other income',
          description: 'Remove an income entry',
        ),
        Permission(
          id: financeAttachmentsUpload,
          label: 'Attach receipts',
          description: 'Upload a receipt photo to an expense or income entry',
        ),
        Permission(
          id: insightsView,
          label: 'View insights',
          description: 'Browse AI-generated business insights',
        ),
      ],
    ),
    PermissionGroup(
      id: 'staff',
      label: 'Staff Management',
      icon: Icons.groups_outlined,
      permissions: [
        Permission(
          id: staffView,
          label: 'View staff',
          description: 'See the team list and member profiles',
        ),
        Permission(
          id: staffAssign,
          label: 'Invite & assign staff',
          description: 'Send an invite and assign a role',
        ),
        Permission(
          id: staffRevoke,
          label: 'Remove staff roles',
          description: 'Revoke a role assignment from a member',
        ),
        Permission(
          id: rolesView,
          label: 'View roles',
          description: 'See custom roles and what they can do',
        ),
        Permission(
          id: rolesCreate,
          label: 'Create roles',
          description: 'Define a new custom role',
        ),
        Permission(
          id: rolesUpdate,
          label: 'Edit roles',
          description: 'Rename or redescribe an existing role',
        ),
        Permission(
          id: rolesDelete,
          label: 'Delete roles',
          description: 'Remove a custom role with no staff assigned',
        ),
        Permission(
          id: rolesManagePermissions,
          label: 'Manage role permissions',
          description: "Change what a role's toggles grant",
        ),
      ],
    ),
    PermissionGroup(
      id: 'stores',
      label: 'Stores',
      icon: Icons.storefront_outlined,
      permissions: [
        Permission(
          id: storesView,
          label: 'View stores',
          description: 'See every location in the business',
        ),
        Permission(
          id: storesCreate,
          label: 'Add stores',
          description: 'Register a new location',
        ),
        Permission(
          id: storesUpdate,
          label: 'Edit stores',
          description: "Change a location's details",
        ),
        Permission(
          id: storesDelete,
          label: 'Delete stores',
          description: 'Remove a location with no history',
        ),
        Permission(
          id: storesSwitch,
          label: 'Switch stores',
          description: 'Move this terminal to another location',
        ),
      ],
    ),
    PermissionGroup(
      id: 'settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      permissions: [
        Permission(
          id: settingsStore,
          label: 'Store profile',
          description: 'Name, address and opening hours',
        ),
        Permission(
          id: settingsTax,
          label: 'Tax & pricing rules',
          description: 'Tax rates and service charges',
        ),
        Permission(
          id: settingsDevices,
          label: 'Devices & printers',
          description: 'Pair terminals and receipt printers',
        ),
        Permission(
          id: settingsBilling,
          label: 'Billing & subscription',
          description: 'Payment method and plan changes',
        ),
      ],
    ),
  ];

  /// Every permission, flattened. Used for "12 of 18" style counts.
  static List<Permission> get all => [
    for (final group in groups) ...group.permissions,
  ];

  static int get count => all.length;

  static Permission? byId(String id) {
    for (final group in groups) {
      for (final permission in group.permissions) {
        if (permission.id == id) return permission;
      }
    }
    return null;
  }

  static String labelFor(String id) => byId(id)?.label ?? id;

  /// Ids that actually exist in the catalogue, in catalogue order.
  ///
  /// A stored role can name a permission that has since been retired; filtering
  /// through this keeps a stale id from being counted or rendered.
  static List<String> resolve(Set<String> ids) => [
    for (final permission in all)
      if (ids.contains(permission.id)) permission.id,
  ];
}
