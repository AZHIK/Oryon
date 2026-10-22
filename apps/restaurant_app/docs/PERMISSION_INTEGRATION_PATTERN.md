# Permission Enforcement Integration Pattern Guide

This guide explains how to add permission enforcement to any screen in the Oryon app. Use this pattern for POS, Inventory, Staff, Sales, Settings, and all other feature screens.

---

## Quick Summary

Three integration points, three lines of code each:

1. **Screen-level gate** — Block entire screen without permission
2. **Button-level gates** — Disable action buttons
3. **Feature-level gates** — Hide/show features conditionally

---

## Pattern 1: Screen-Level Gate (Protection)

**Use this to block access to entire screens.**

### Step 1: Create gated wrapper screen

```dart
// lib/screens/inventory/inventory_screen_gated.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/permission.dart';
import '../../widgets/permission_gated_widget.dart';
import 'inventory_screen.dart';

class InventoryScreenGated extends ConsumerWidget {
  const InventoryScreenGated({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGatedScreen(
      requiredPermission: AppPermissions.inventoryView,  // User needs this
      child: const InventoryScreen(),                     // Show this if allowed
      onDenied: (reason) => Scaffold(                      // Show this if denied
        appBar: AppBar(title: const Text('Inventory')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text('Access Denied: $reason'),
            ],
          ),
        ),
      ),
      onUnknown: (reason) => Scaffold(                     // Show this if offline
        appBar: AppBar(title: const Text('Inventory')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('Offline: Feature may be unavailable'),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Step 2: Update router to use gated version

In your `AppRouter` or wherever you define routes:

```dart
// Before
GoRoute(
  path: '/inventory',
  builder: (context, state) => const InventoryScreen(),
),

// After
GoRoute(
  path: '/inventory',
  builder: (context, state) => const InventoryScreenGated(),  // Use gated version
),
```

### What This Does

- ✅ User without `inventory.view` → sees "Access Denied" screen
- ✅ User with permission → sees full Inventory screen
- ✅ Offline user → sees "Offline: Feature may be unavailable"

---

## Pattern 2: Button-Level Gate (Actions)

**Use this to disable specific action buttons.**

### Option A: Simple Button Disabling

```dart
// Inside your screen (e.g., InventoryScreen)
class InventoryScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          // Regular button - always visible
          FilledButton(
            onPressed: () => viewItem(),
            child: const Text('View Item'),
          ),

          // Edit button - disabled without permission
          PermissionGatedButton(
            requiredPermission: AppPermissions.inventoryEdit,
            onPressed: () => editItem(),
            child: const Text('Edit Item'),
          ),

          // Adjust stock - disabled without permission
          PermissionGatedButton(
            requiredPermission: AppPermissions.inventoryAdjust,
            onPressed: () => adjustStock(),
            child: const Text('Adjust Stock'),
          ),
        ],
      ),
    );
  }
}
```

### Option B: Conditional Rendering

For finer control, show/hide buttons based on permission:

```dart
class InventoryScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(canPerformActionProvider(AppPermissions.inventoryEdit));

    return Scaffold(
      body: Column(
        children: [
          // Show edit button only if user has permission
          if (canEdit.value ?? false)
            FilledButton(
              onPressed: () => editItem(),
              child: const Text('Edit Item'),
            ),

          // Show delete button only if user has permission
          if (ref.watch(canPerformActionProvider(AppPermissions.inventoryDelete)).value ?? false)
            OutlinedButton(
              onPressed: () => deleteItem(),
              child: const Text('Delete Item'),
            ),
        ],
      ),
    );
  }
}
```

### What This Does

- ✅ `PermissionGatedButton` — button is visible but disabled without permission
- ✅ Shows tooltip explaining why button is disabled
- ✅ User can still see the button (better UX than hiding)

---

## Pattern 3: Feature-Level Gate (Sections)

**Use this to hide/show entire feature sections.**

### Panel/Widget Gating

```dart
class POSScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          // Always show: basic POS interface
          const POSItemList(),

          // Show only if user has discount permission
          PermissionGatedWidget(
            requiredPermission: AppPermissions.posDiscount,
            child: const DiscountPanel(),
            onDenied: (_) => const SizedBox.shrink(),  // Hide if no permission
          ),

          // Show only if user has refund permission
          PermissionGatedWidget(
            requiredPermission: AppPermissions.posRefund,
            child: const RefundPanel(),
            onDenied: (_) => const SizedBox.shrink(),  // Hide if no permission
          ),

          // Offline: show warning if any feature unavailable
          PermissionGatedWidget(
            requiredPermission: AppPermissions.posDiscount,
            child: const SizedBox.shrink(),  // No content needed
            onUnknown: (_) => Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange[100],
              child: const Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline: Discount may not be available',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### What This Does

- ✅ Discount panel hidden if user lacks `pos.discount` permission
- ✅ Refund panel hidden if user lacks `pos.refund` permission
- ✅ Offline users see warning message instead of blank space

---

## Permission Constants Reference

Use these pre-defined permissions. Add more as needed in `lib/models/permission.dart`:

```dart
class AppPermissions {
  // POS Permissions
  static const String posAccess = 'pos.write';          // Access POS
  static const String posDiscount = 'pos.discount';     // Apply discount
  static const String posRefund = 'pos.refund';         // Process refund

  // Inventory Permissions
  static const String inventoryView = 'inventory.view';     // View items
  static const String inventoryEdit = 'inventory.edit';     // Edit items
  static const String inventoryAdjust = 'inventory.adjust'; // Adjust stock
  static const String inventoryDelete = 'inventory.delete'; // Delete items

  // Staff Permissions
  static const String staffView = 'staff.view';     // View staff list
  static const String staffAssign = 'staff.assign'; // Assign roles
  static const String staffRevoke = 'staff.revoke'; // Remove staff

  // Sales Permissions
  static const String salesView = 'sales.view';     // View sales
  static const String salesExport = 'sales.export'; // Export data

  // Reports Permissions
  static const String reportsView = 'reports.view';

  // Settings Permissions
  static const String settingsStore = 'settings.store';   // Store settings
  static const String settingsTax = 'settings.tax';       // Tax settings
  static const String settingsDevices = 'settings.devices'; // Device settings
}
```

---

## Integration Checklist

For each screen you integrate, follow this checklist:

- [ ] Identify required read permission (e.g., `inventory.view`)
- [ ] Identify required write permissions (e.g., `inventory.edit`)
- [ ] Create `*_screen_gated.dart` wrapper with screen-level gate
- [ ] Update router to use gated version
- [ ] Wrap edit/delete buttons with `PermissionGatedButton`
- [ ] Wrap optional feature sections with `PermissionGatedWidget`
- [ ] Test: verify denied users see appropriate message
- [ ] Test: verify offline users see "Offline" message
- [ ] Test: verify allowed users can access all features

---

## Complete Example: Inventory Screen Integration

### File Structure

```
lib/screens/inventory/
├── inventory_screen.dart          (existing - core screen)
└── inventory_screen_gated.dart    (NEW - permission wrapper)
```

### Step 1: Create wrapper (`inventory_screen_gated.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/permission.dart';
import '../../widgets/permission_gated_widget.dart';
import 'inventory_screen.dart';

class InventoryScreenGated extends ConsumerWidget {
  const InventoryScreenGated({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGatedScreen(
      requiredPermission: AppPermissions.inventoryView,
      child: const InventoryScreen(),
      onDenied: (reason) => _buildDeniedScreen(reason),
      onUnknown: (reason) => _buildOfflineScreen(reason),
    );
  }

  Widget _buildDeniedScreen(String reason) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Access Denied', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(reason, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineScreen(String reason) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('Offline Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Some features may be unavailable.'),
          ],
        ),
      ),
    );
  }
}
```

### Step 2: Update router (`lib/router/app_router.dart`)

Find the inventory route and update it:

```dart
GoRoute(
  path: '/inventory',
  builder: (context, state) => const InventoryScreenGated(),  // Changed
),
```

### Step 3: Add button gates (`inventory_screen.dart`)

In the existing screen, wrap buttons:

```dart
class InventoryScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Column(
        children: [
          // Edit button - gated
          PermissionGatedButton(
            requiredPermission: AppPermissions.inventoryEdit,
            onPressed: () => _editItem(context),
            child: const Text('Edit Item'),
          ),

          // Delete button - gated
          PermissionGatedButton(
            requiredPermission: AppPermissions.inventoryDelete,
            onPressed: () => _deleteItem(context),
            child: const Text('Delete Item'),
          ),
        ],
      ),
    );
  }
}
```

---

## Safe-by-Default Behavior

The system is built to fail safely:

| Scenario | Result | User Sees |
|----------|--------|-----------|
| User has permission | ✅ Allowed | Feature works |
| User lacks permission | ❌ Denied | Button disabled + tooltip |
| Offline with cache | ✅ Allowed | Feature works (cached) |
| Offline without cache | ❓ Unknown | "Offline mode" message |
| Permission check fails | ❓ Unknown | "Offline mode" message |

**The golden rule: Missing information → block, don't grant.**

---

## Testing Your Integration

### Test Denied Access

```bash
# Simulate: user without inventory.edit permission
# Expected: Edit button is disabled, shows tooltip "You lack permission: inventory.edit"
flutter test
```

### Test Offline Mode

```bash
# Simulate: offline without cached permissions
# Expected: Screen shows "Offline: Feature may be unavailable"
```

### Test Allowed Access

```bash
# Simulate: user with all inventory permissions
# Expected: All buttons enabled, features visible
```

---

## Common Patterns by Feature

### POS Features

```dart
// Apply discount (requires separate permission)
PermissionGatedButton(
  requiredPermission: AppPermissions.posDiscount,
  onPressed: () => applyDiscount(),
  child: const Text('Apply Discount'),
)

// Process refund (requires separate permission)
PermissionGatedButton(
  requiredPermission: AppPermissions.posRefund,
  onPressed: () => processRefund(),
  child: const Text('Process Refund'),
)
```

### Inventory Features

```dart
// Edit inventory items
PermissionGatedButton(
  requiredPermission: AppPermissions.inventoryEdit,
  onPressed: () => editItem(),
  child: const Text('Edit Item'),
)

// Adjust stock levels
PermissionGatedButton(
  requiredPermission: AppPermissions.inventoryAdjust,
  onPressed: () => adjustStock(),
  child: const Text('Adjust Stock'),
)
```

### Staff Management

```dart
// Assign staff to roles
PermissionGatedButton(
  requiredPermission: AppPermissions.staffAssign,
  onPressed: () => assignStaff(),
  child: const Text('Assign Role'),
)

// Remove staff
PermissionGatedButton(
  requiredPermission: AppPermissions.staffRevoke,
  onPressed: () => removeStaff(),
  child: const Text('Remove Staff'),
)
```

---

## Troubleshooting

### Issue: Button always disabled

**Cause:** User doesn't have permission, or cache is empty (offline).

**Fix:** 
1. Check user's role/permissions in backend
2. Verify permission code matches `AppPermissions` constant
3. When offline, ensure cache was populated when online

### Issue: Screen shows "Access Denied" for everyone

**Cause:** Permission check is failing, returning Unknown.

**Fix:**
1. Check if JWT token contains valid permission claims
2. Check if CachedPermissions table has data
3. Check error logs for permission enforcement errors

### Issue: Offline mode shows warning but should allow

**Cause:** Safe-by-default blocks unknown permissions.

**Fix:** This is intentional. If cache is missing/stale, we block to be safe. Consider:
1. Pre-load permissions when user logs in (cache warmup)
2. Keep cache fresh with 24-hour TTL
3. Show offline message, but allow read-only operations if cached

---

## Summary

- **Screen-level:** Use `PermissionGatedScreen` to block entire screens
- **Button-level:** Use `PermissionGatedButton` to disable actions
- **Feature-level:** Use `PermissionGatedWidget` to hide/show sections

Apply these three patterns to every screen, and your app will have complete permission enforcement with safe offline behavior.

See examples:
- POS: `lib/screens/pos/pos_screen_gated.dart`
- Inventory: `lib/screens/inventory/inventory_screen_gated.dart` (coming)
- Staff: `lib/screens/staff/staff_screen_gated.dart` (coming)
