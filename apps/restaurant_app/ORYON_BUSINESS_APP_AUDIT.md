# ORYON Business App - UI Completeness Audit Report
**Date**: August 25, 2026 | **Status**: Pre-Backend Integration | **Scope**: Flutter Mobile/Desktop App

---

## SECTION 1: FEATURE-BY-FEATURE AUDIT

### 1. DASHBOARD / HOME
**Screen File**: [dashboard_screen.dart](lib/screens/dashboard/dashboard_screen.dart)  
**Model**: [dashboard_metrics_provider.dart](lib/providers/dashboard_metrics_provider.dart)

| Requirement | Status | Details |
|---|---|---|
| Today's revenue summary | ✅ **Present** | KPI card with `sales.current` and comparison to previous period via `sales.change` (KpiValue model). Displayed in _KpiRow |
| Comparison to previous period | ✅ **Present** | Trend indicators show % change. Uses `KpiValue.change` (fraction). Visible in KPI cards |
| Active orders counter by status | ⚠️ **Partially Present** | Shows order count in KPI row, but **status breakdown (new/preparing/ready/completed) is NOT visible**. Order model has `OrderStatus` enum but dashboard doesn't display by-status counts |
| Low-stock alert banner | ✅ **Present** | `LowStockAlertBanner` component (line 72-78). Taps through to inventory screen. Driven by `metrics.lowStockItems` |
| AI recommendation/insight card | ✅ **Present** | `InsightHighlights()` widget shown on desktop (line 86). Full `AiInsightsScreen` at `/insights` route |
| Visual trend indicator (chart/sparkline) | ✅ **Present** | `RevenueTrendChart` component. Line chart with daily revenue data. Uses `revenueSeries: List<RevenuePoint>` |

---

### 2. ORDERS MANAGEMENT
**Primary Screen**: [sales_screen.dart](lib/screens/sales/sales_screen.dart)  
**Detail Screen**: [order_detail_screen.dart](lib/screens/order_detail/order_detail_screen.dart)  
**POS Screen**: [pos_screen.dart](lib/screens/pos/pos_screen.dart)  
**Model**: [order.dart](lib/models/order.dart)

| Requirement | Status | Details |
|---|---|---|
| Order list/board with status stages | ⚠️ **Partially Present** | Sales screen shows tabular list of all orders. Status shown as badge (new/paid/refunded/voided/pending) but **NO visual kanban/board view** with status swimlanes (New → Preparing → Ready → Out for Delivery → Completed). Currently only list view. |
| Order detail view | ✅ **Present** | Full detail screen available. Shows: order lines with items, customer info (table/name if applicable), payment status, order type (dine-in/takeaway/delivery), totals. Screen: OrderDetailScreen |
| Customer info display | ✅ **Present** | Order detail includes: serverName, tableLabel, orderType. **No dedicated customer profile/history yet** (see #6 below) |
| Payment status visible | ✅ **Present** | PaymentType enum (cash/card/qris/mobile/giftCard), OrderStatus shown, payment panel with amount tendered & change |
| Delivery method indicator | ✅ **Present** | OrderType enum: dineIn / takeaway / delivery. Shown on order card and detail |
| Update/change order status | ⚠️ **Partially Present** | Order model has `copyWith()` but **no UI to change status from detail screen**. Would require backend hook |
| Real-time/refreshable order feed | ❌ **Missing** | No "new order" indicator/pulse. No refresh mechanism. Relies on page reload or navigation |
| Order history / past orders | ✅ **Present** | Sales screen filters by date range and displays full ledger. Date range selector at top of screen |

---

### 3. MENU MANAGEMENT
**Related Screens**: [pos_screen.dart](lib/screens/pos/pos_screen.dart), [item_detail_screen.dart](lib/screens/inventory/item_detail_screen.dart)  
**Model**: [menu_item.dart](lib/models/menu_item.dart)

| Requirement | Status | Details |
|---|---|---|
| List/grid view of menu items | ✅ **Present** | POS screen displays menu grid with category filtering. Cards show emoji/image, name, price, availability indicator |
| Add new menu item form | 🔌 **Needs Backend** | Dialog exists (`ItemFormDialog`) in POS context. Form captures: name, description, price, category, emoji, image. **Currently a local form only** — needs backend save endpoint |
| Edit existing menu item | 🔌 **Needs Backend** | `copyWith()` method on MenuItem. UI exists in ItemFormDialog but save is **not hooked to backend** |
| Delete menu item | ❌ **Missing** | No delete action in UI for menu items. MenuItem model has no `isArchived` field to soft-delete |
| Availability toggle | ✅ **Present** | MenuItem has `isAvailable` boolean. Reflected in POS grid (grayed out if unavailable). **No toggle UI to change availability** — would need backend hook |
| Best seller / underperforming indicator | ✅ **Present** | MenuItem has `isPopular` boolean. Dashboard shows "Top Items" ranked list with emoji and revenue. Not exposed on menu grid itself in POS |
| Menu item ↔ inventory link | ⚠️ **Partially Present** | MenuCategory is separate from InventoryCategory. Menu items and inventory tracked separately. **No mechanism to deduct inventory on sale** — would require backend reconciliation |

---

### 4. STOCK / INVENTORY
**Screen**: [inventory_screen.dart](lib/screens/inventory/inventory_screen.dart)  
**Detail**: [item_detail_screen.dart](lib/screens/inventory/item_detail_screen.dart)  
**Model**: [inventory_item.dart](lib/models/inventory_item.dart)

| Requirement | Status | Details |
|---|---|---|
| Current stock level list | ✅ **Present** | Inventory screen is a data table with columns: SKU, name, quantity, reorder level, unit cost, status badge, total value |
| Visual stock status (color-coded) | ✅ **Present** | `StockStatus` enum with colors: inStock (green/positive), lowStock (yellow/warning), outOfStock (red/danger). Shown in status badge |
| Request restock from supplier | ❌ **Missing** | No "Request Restock" button or workflow. Supplier interaction not implemented |
| Supplier request history/tracker | ❌ **Missing** | No supplier request management screen or status tracking |
| Manual stock adjustment | ✅ **Present** | `StockAdjustDialog` available. Allows adding/removing quantity with reason note. Local only — needs backend save |
| Waste/spoilage logging | ✅ **Present** | `WasteLogDialog` component. Records waste movements with reason. Tracked in StockMovementType enum. Local mock data only |
| Item detail view | ✅ **Present** | ItemDetailScreen shows full history of stock movements (StockMovement ledger) with timestamps, actors, deltas, running balance |

---

### 5. AI / BUSINESS ANALYTICS MODULE
**Screen**: [ai_insights_screen.dart](lib/screens/insights/ai_insights_screen.dart)  
**Model**: [ai_insight.dart](lib/models/ai_insight.dart)  
**Provider**: [ai_insights_provider.dart](lib/providers/ai_insights_provider.dart)

| Requirement | Status | Details |
|---|---|---|
| Revenue trend chart | ✅ **Present** | Dashboard & Insights screen show revenue line chart. Daily aggregation. No date-range toggle yet |
| Product performance ranking | ✅ **Present** | Dashboard shows "Top Items" ranked list. Insight categories include sales-based rankings |
| Peak sales period view | ❌ **Missing** | No hour-of-day or day-of-week heatmap. No "busiest time" analysis displayed |
| Stock movement summary | ✅ **Present** | Item detail screens show stock ledger (all movements). Dashboard shows inventory value. **No summary by movement type** (restock vs waste vs sale breakdown) |
| Waste/profitability pattern | ⚠️ **Partially Present** | Waste log exists. No dedicated profit analysis screen. Profitability would need cost-of-goods data linked to sales |
| Demand forecast display | ❌ **Missing** | No forecast model implemented. No "expected busy period" prediction |
| Actionable recommendation list | ✅ **Present** | AI Insights screen displays `AiInsight` cards with title, body, evidence (label/value pairs), and actionable links (actionLabel, actionRoute) |
| Alert/notification feed | ⚠️ **Partially Present** | Insights shown on dashboard and dedicated screen, but **no persistent notification center** or bell icon. Alerts are not a separate feed |

---

### 6. CUSTOMER MANAGEMENT
**Screen File**: ❌ **Missing**  
**Model**: ❌ **No dedicated customer model**

| Requirement | Status | Details |
|---|---|---|
| Customer list view | ❌ **Missing** | No customer management screen. No customer database |
| Individual customer order history | ⚠️ **Partially Present** | Order model has `serverName` field but no `customerId`. Orders filtered by date range but not by customer |
| Repeat customer / loyalty indicator | ❌ **Missing** | No customer entity, no loyalty tracking |

**Note**: Orders are currently stateless POS tickets, not linked to persistent customer profiles.

---

### 7. SUPPLIER INTERACTION (Business side)
**Screens**: ❌ **Missing**

| Requirement | Status | Details |
|---|---|---|
| View available suppliers/products | ❌ **Missing** | No supplier directory or marketplace preview |
| Send/track supplier restock requests | ❌ **Missing** | No restock request workflow |
| Supplier response/confirmation status | ❌ **Missing** | No request tracking |

**Current State**: InventoryItem has `supplier` (string) field but no supplier entity or interaction screen.

---

### 8. RIDER / DELIVERY COORDINATION
**Status**: ❌ **Missing**

| Requirement | Status | Details |
|---|---|---|
| Assign/view rider for order | ❌ **Missing** | Order model has `orderType: delivery` but no `riderId` or rider assignment screen |
| Delivery status tracking | ❌ **Missing** | OrderStatus is about payment (paid/refunded), not delivery state (out/delivered) |
| Communication with rider (chat/call/status) | ❌ **Missing** | No rider communication UI |

**Current State**: Order type distinguishes delivery orders, but no rider integration.

---

### 9. NOTIFICATIONS & ALERTS
**Status**: ⚠️ **Partially Present**

| Requirement | Status | Details |
|---|---|---|
| Notification center / bell icon | ❌ **Missing** | No persistent notification panel or notification history |
| Push/in-app alerts for: | | |
| — New order | ❌ **Missing** | No new order indicator/pulse in app |
| — Low stock | ⚠️ **Partial** | Alert banner on dashboard when `metrics.hasLowStock` but not a persistent notification |
| — AI recommendation | ⚠️ **Partial** | Insights displayed on dashboard but no notification event |
| — Delivery update | ❌ **Missing** | No delivery status tracking |
| Read/unread state handling | ❌ **Missing** | No notification state model |

---

### 10. ACCOUNT / SETTINGS
**Screens**: [business_profile_screen.dart](lib/screens/settings/business_profile_screen.dart), [account_settings_screen.dart](lib/screens/settings/account_settings_screen.dart), [store_settings_screen.dart](lib/screens/settings/store_settings_screen.dart)  
**Model**: [business_profile.dart](lib/models/business_profile.dart)

| Requirement | Status | Details |
|---|---|---|
| Business profile | ✅ **Present** | Editable form: name, legal name, type, email, phone, website, address, tax ID, receipt footer, brand color, logo upload |
| Staff account management | ✅ **Present** | Staff screen shows list with invite, detail view, role management. `StaffMember` model with status (active/inactive/pendingInvite) |
| Multi-user support | ✅ **Present** | Staff and roles system in place. Role-based permissions defined. Staff roles can be created and assigned |
| Subscription/plan tier view | ❌ **Missing** | No plan/tier information. No premium feature gates tied to subscription |
| Payment/billing settings | ❌ **Missing** | No payment method management or billing history |

---

### 11. AUTH & ONBOARDING
**Screens**: [otp_login_screen.dart](lib/screens/auth/otp_login_screen.dart), [set_pin_screen.dart](lib/screens/auth/set_pin_screen.dart), [onboarding_screen.dart](lib/screens/auth/onboarding_screen.dart), [profile_picker_screen.dart](lib/screens/auth/profile_picker_screen.dart)

| Requirement | Status | Details |
|---|---|---|
| Sign up flow | ⚠️ **Partially Present** | Onboarding screen exists but focused on business setup (menu, stock), not account creation. **No sign-up form for new business account** |
| Login flow | ✅ **Present** | OTP-based login (phone + 6-digit code). PIN unlock for returning sessions |
| Business onboarding | ✅ **Present** | Setup wizard for menu items and initial stock. Walks through adding products |
| Password reset / account recovery | ❌ **Missing** | No password reset or account recovery flow (relies on OTP re-entry) |

---

### 12. GENERAL / CROSS-CUTTING
**Status**: ✅ **Mostly Present**

| Requirement | Status | Details |
|---|---|---|
| Loading states | ✅ **Present** | Providers use AsyncValue pattern (loading/data/error). Skeletons/loaders on screens using data tables |
| Empty states | ✅ **Present** | Data page scaffold handles empty list rendering. No data fallback UI yet in all screens |
| Error states | ✅ **Present** | AsyncValue error handling in providers. Error display on detail screens (OrderDetailScreen._NotFound) |
| Consistent navigation | ✅ **Present** | Bottom tab navigation shell with Dashboard, POS, Sales, Inventory, Insights, Staff, Finance, Settings. Consistent across app |

---

## SECTION 2: CRITICAL MISSING FEATURES (RANKED BY MVP PRIORITY)

### **TIER 1 — BLOCKS CORE BUSINESS FUNCTION** (Fix before backend integration)

1. **Order Status Management** (Current: ⚠️ Display only | Needed: ✅ Editable)
   - Can view order status but cannot change it from PAID → READY or similar
   - Requires: Backend endpoint to update order status + UI button on order detail
   - **Business Impact**: Cannot manage kitchen workflow; POS is output-only

2. **Order Real-Time Feed** (Current: ❌ Missing)
   - No new order indicator; staff unaware of incoming orders
   - Requires: WebSocket or polling mechanism for new orders + visual indicator/bell
   - **Business Impact**: Orders sit invisible until someone manually refreshes

3. **Menu Item ↔ Inventory Reconciliation** (Current: ⚠️ Separate systems)
   - Menu and inventory are completely decoupled
   - When an item sells, stock is NOT automatically decremented
   - Requires: Backend logic to link menu items to inventory + post-sale stock update
   - **Business Impact**: Inventory counts become stale; no cost-of-goods tracking

4. **Customer Management System** (Current: ❌ Missing)
   - No customer entity; orders are anonymous POS tickets
   - Cannot track repeat customers, order history per customer, or loyalty
   - Requires: Customer model + lookup/creation screen + order ↔ customer link
   - **Business Impact**: No customer insights or repeat business tracking

### **TIER 2 — SIGNIFICANT GAPS** (Should be in Phase 1)

5. **Supplier Integration** (Current: ❌ Missing entirely)
   - No way to request restock, track supplier responses
   - Inventory item has supplier name (text) but no supplier entity or request workflow
   - Requires: Supplier model + request management screen + supplier feedback/status
   - **Business Impact**: Restocking is manual/offline; no procurement visibility

6. **Rider / Delivery Coordination** (Current: ❌ Missing entirely)
   - Delivery is an order type, but no rider assignment or tracking
   - No way to communicate delivery status to customer or assign orders to riders
   - Requires: Rider entity + assignment UI + status tracking + customer notification
   - **Business Impact**: Delivery orders cannot be fulfilled from app

7. **Persistent Notification System** (Current: ⚠️ Partial)
   - Alerts are embedded in screens (dashboard) but no notification center
   - No notification history, read/unread state, or persistent notifications
   - Requires: Notification model + center screen + push notification integration
   - **Business Impact**: Staff misses critical alerts (low stock, new order, AI warnings)

### **TIER 3 — MVP NICE-TO-HAVE** (Post-launch iteration)

8. **Kanban Order Board** (Current: ⚠️ List only)
   - Orders shown as table, not visual swimlanes (New → Preparing → Ready → Delivered)
   - Requires: Board view with drag-drop status updates
   - **Business Impact**: Kitchen workflow less visual but functional with current list

9. **Demand Forecasting** (Current: ❌ Missing)
   - No ML model or predictive display for busy periods
   - Requires: Backend ML + forecast rendering
   - **Business Impact**: Nice insight but not blocking operations

10. **Peak Sales Period Heatmap** (Current: ❌ Missing)
    - No hour-of-day or day-of-week analysis
    - Requires: Data aggregation + heatmap widget
    - **Business Impact**: Nice-to-have analytics; operations work without it

11. **Subscription / Premium Tiers** (Current: ❌ Missing)
    - No plan selection or feature gates
    - Requires: Plan model + gating logic
    - **Business Impact**: Post-MVP monetization layer

---

## SECTION 3: BACKEND INTEGRATION CHECKLIST

### **Data Entities Required** (with field specs)

#### **1. Order** (Extended)
```
OrderRow {
  id: String,
  items: [OrderLine] {
    itemId: String,
    name: String,
    emoji: String,
    unitPrice: Double,
    quantity: Int,
    note?: String,
  },
  placedAt: DateTime,
  paymentType: Enum[cash|card|qris|mobile|giftCard],
  status: Enum[paid|refunded|voided|pending],
  
  // MISSING — REQUIRED FOR DELIVERY
  deliveryStatus?: Enum[pending|assigned|enRoute|delivered|failed],
  riderId?: String,
  customerId?: String,  // Currently missing
  
  taxRate: Double,
  orderType: Enum[dineIn|takeaway|delivery],
  discountRate: Double,
  tableLabel?: String,
  serverName: String,
  amountTendered?: Double,
}
```

#### **2. Customer** (NEW — Required)
```
Customer {
  id: String,
  name: String,
  email?: String,
  phone?: String,
  addressLine1?: String,
  addressLine2?: String,
  city?: String,
  postcode?: String,
  country?: String,
  businessId: String,
  createdAt: DateTime,
  lastOrderAt?: DateTime,
  totalOrders: Int,
  totalSpent: Double,
}
```

#### **3. MenuItem** (Extended)
```
MenuItem {
  id: String,
  name: String,
  description: String,
  price: Double,
  categoryId: String,
  emoji: String,
  imageUrl?: String,
  isAvailable: Boolean,
  isPopular: Boolean,
  prepMinutes: Int,
  
  // MISSING — REQUIRED FOR INVENTORY LINK
  linkedInventoryItemId?: String,  // Foreign key to InventoryItem
}
```

#### **4. InventoryItem** (Extended)
```
InventoryItem {
  id: String,
  sku: String,
  name: String,
  categoryId: String,
  emoji: String,
  stock: Int,
  reorderLevel: Int,
  unitCost: Double,
  unit: String,  // "ea", "kg", "L", etc.
  supplier: String,
  description: String,
  lastCountedAt?: DateTime,
  trackStock: Boolean,
  isArchived: Boolean,
  
  // MISSING — REQUIRED FOR SUPPLIER WORKFLOW
  supplierId?: String,
  restockRequestId?: String,  // Current restock request, if any
}
```

#### **5. Supplier** (NEW — Required)
```
Supplier {
  id: String,
  businessId: String,
  name: String,
  email: String,
  phone: String,
  website?: String,
  addressLine1: String,
  addressLine2?: String,
  city: String,
  postcode: String,
  country: String,
  leadTimeHours: Int,  // Expected delivery lead time
  minOrderValue: Double,
  createdAt: DateTime,
}
```

#### **6. RestockRequest** (NEW — Required)
```
RestockRequest {
  id: String,
  businessId: String,
  supplierId: String,
  itemId: String,
  requestedQuantity: Int,
  estimatedCost: Double,
  status: Enum[pending|confirmed|dispatched|delivered|cancelled],
  requestedAt: DateTime,
  confirmedAt?: DateTime,
  deliveredAt?: DateTime,
  notes: String,
}
```

#### **7. Rider** (NEW — Required for Delivery)
```
Rider {
  id: String,
  businessId: String,
  name: String,
  phone: String,
  email?: String,
  status: Enum[available|onTrip|offline],
  currentOrderId?: String,
  locationLat?: Double,
  locationLng?: Double,
  updatedAt: DateTime,
}
```

#### **8. Notification** (NEW — Required)
```
Notification {
  id: String,
  businessId: String,
  staffId: String,
  type: Enum[newOrder|lowStock|AIInsight|deliveryUpdate],
  title: String,
  body: String,
  relatedEntityId?: String,  // Order ID, Inventory Item ID, etc.
  isRead: Boolean,
  createdAt: DateTime,
}
```

#### **9. StaffRole** (Needs permission fields)
```
BusinessRole {
  id: String,
  businessId: String,
  name: String,
  permissions: [String],  // e.g., ["order.view", "order.update", "inventory.edit"]
  createdAt: DateTime,
}
```

---

## SECTION 4: BACKEND ENDPOINTS REQUIRED

### **Critical Path Endpoints** (Must-Have for MVP)

**Orders**
- `GET /api/orders` — List orders with filters (date, status, type)
- `GET /api/orders/:id` — Get single order detail
- `PATCH /api/orders/:id` — Update order status, payment, rider assignment
- `POST /api/orders` — Create new order from POS
- `GET /api/orders?customerId=:id` — Orders for a customer

**Customers** (NEW)
- `POST /api/customers` — Create/register new customer
- `GET /api/customers` — List customers
- `GET /api/customers/:id` — Customer detail + order history
- `PATCH /api/customers/:id` — Update customer info

**Menu Items**
- `GET /api/menu-items` — List all items
- `POST /api/menu-items` — Create menu item
- `PATCH /api/menu-items/:id` — Update item (name, price, availability)
- `DELETE /api/menu-items/:id` — Soft-delete item

**Inventory**
- `GET /api/inventory` — List inventory items
- `GET /api/inventory/:id` — Item detail with stock ledger
- `PATCH /api/inventory/:id/stock` — Update stock (adjust, waste, transfer)
- `GET /api/inventory/:id/movements` — Stock movement history
- `POST /api/inventory/:id/waste-log` — Log waste/spoilage

**Suppliers** (NEW)
- `GET /api/suppliers` — List suppliers
- `POST /api/suppliers` — Add supplier
- `POST /api/restock-requests` — Request restock from supplier
- `GET /api/restock-requests` — List pending restock requests
- `PATCH /api/restock-requests/:id` — Update request status (e.g., supplier confirms)

**Riders** (NEW)
- `GET /api/riders` — List available riders
- `PATCH /api/orders/:id/assign-rider` — Assign rider to delivery order
- `PATCH /api/riders/:id/status` — Update rider status/location

**Notifications** (NEW)
- `GET /api/notifications` — List notifications for logged-in staff
- `PATCH /api/notifications/:id/read` — Mark as read
- `GET /api/notifications?unreadOnly=true` — Unread count

**Business / Settings**
- `GET /api/business/profile` — Get business profile
- `PATCH /api/business/profile` — Update business profile (name, logo, address, etc.)
- `GET /api/business/settings` — Get store settings (tax, currency, hours)
- `PATCH /api/business/settings` — Update settings

**Analytics / Insights** (If generating server-side)
- `GET /api/analytics/revenue?period=daily|weekly|monthly` — Revenue trend
- `GET /api/analytics/top-items?days=7|30` — Top selling items
- `GET /api/insights` — AI-generated insights (peak hours, waste patterns, recommendations)

---

## SECTION 5: SCOPE CREEP ALERTS (Features NOT in Concept Note)

### **What's in the app but NOT in the MVP brief:**

1. **Finance/Expenses Module** (`/finance/expenses`, `/finance/incomes`)
   - Full expense and income tracking with categorization
   - Not mentioned in concept note
   - ⚠️ **Verdict**: May be out-of-scope; clarify if needed for P1 or defer to P2

2. **Staff Roles & Permissions System**
   - Complete role management with permission strings
   - Granular access control (order.view, inventory.edit, etc.)
   - ✅ **Verdict**: Good to have; supports multi-user business model

3. **Store Management & Locations**
   - Multi-location support in settings
   - ✅ **Verdict**: Reasonable for future scaling

4. **Chat / Communication Dialog** (`chat_dialog.dart`)
   - General chat widget
   - Not clear what it's for (rider comms? internal? customer?)
   - ⚠️ **Verdict**: Clarify if needed; might be for staff/rider comms

5. **Table Query / Seating Allocation**
   - Table-based dine-in seating system
   - ✅ **Verdict**: Makes sense for restaurant POS

6. **Payment Session & Card Terminal Integration**
   - POS payment terminal integration (card, QRIS)
   - ✅ **Verdict**: Core to POS function

---

## SECTION 6: UI QUALITY & COMPLETENESS SUMMARY

### **What Works Well:**
- ✅ Comprehensive data models for core entities
- ✅ Clean, modular screen structure (detail pages, data tables, dialogs)
- ✅ Consistent design system & theming
- ✅ Responsive layout (mobile, tablet, desktop)
- ✅ Solid state management (Riverpod providers)
- ✅ Test coverage for key screens and dialogs
- ✅ Export and filtering for data pages
- ✅ Onboarding and auth flows complete

### **What Needs Attention Before Backend:**
1. **Wire up menu ↔ inventory relationship** — Critical for consistency
2. **Add order status update UI** — Required for kitchen workflow
3. **Create customer entity & screens** — Missing major business domain
4. **Add notification center** — Alerts are scattered, not persistent
5. **Create supplier management flow** — Currently text-only
6. **Implement order real-time polling/WebSocket** — No new order visibility

---

## SECTION 7: RECOMMENDED BACKEND INTEGRATION ORDER

### **Phase 1A — Core Order-to-Payment Flow** (Week 1-2)
1. Hook Orders list & detail screens to backend
2. Implement order status update endpoint & UI
3. Wire menu item creation/update/delete
4. Connect inventory stock adjustments

### **Phase 1B — Inventory & Supplier** (Week 2-3)
1. Implement inventory restock request workflow
2. Add supplier management screens
3. Link menu items → inventory for auto-deduction

### **Phase 2 — Customers & Notifications** (Week 3-4)
1. Implement customer registration & lookup
2. Add customer order history linking
3. Build notification system (database + UI center)

### **Phase 2+ — Riders & Advanced** (Week 4+)
1. Rider assignment and tracking
2. Real-time order status WebSocket
3. Demand forecasting and advanced analytics

---

## APPENDIX: FILE STRUCTURE REFERENCE

```
lib/
├── screens/
│   ├── dashboard/
│   │   └── dashboard_screen.dart          ← KPIs, low stock, revenue chart
│   ├── pos/
│   │   └── pos_screen.dart                ← Menu grid, cart, checkout
│   ├── sales/
│   │   └── sales_screen.dart              ← Order ledger/list
│   ├── order_detail/
│   │   └── order_detail_screen.dart       ← Order detail (needs status edit)
│   ├── inventory/
│   │   ├── inventory_screen.dart          ← Stock list & management
│   │   ├── item_detail_screen.dart        ← Stock movement history
│   │   ├── stock_adjust_dialog.dart       ← Manual adjustment
│   │   └── waste_log_dialog.dart          ← Waste logging
│   ├── insights/
│   │   └── ai_insights_screen.dart        ← AI recommendations & analytics
│   ├── staff/
│   │   ├── staff_screen.dart              ← Staff list
│   │   ├── roles_screen.dart              ← Role management
│   │   └── staff_detail_screen.dart
│   ├── settings/
│   │   ├── business_profile_screen.dart   ← Business info
│   │   ├── store_settings_screen.dart     ← Tax, currency, hours
│   │   └── account_settings_screen.dart   ← User account
│   ├── auth/
│   │   ├── otp_login_screen.dart          ← Phone + OTP login
│   │   ├── set_pin_screen.dart            ← PIN security
│   │   └── onboarding_screen.dart         ← Initial setup
│   └── finance/
│       ├── other_expenses_screen.dart     ← Ad-hoc expenses
│       └── other_incomes_screen.dart      ← Ad-hoc income
├── models/
│   ├── order.dart                         ← Order, OrderLine, OrderStatus, OrderType
│   ├── menu_item.dart                     ← MenuItem, MenuCategory
│   ├── inventory_item.dart                ← InventoryItem, StockStatus
│   ├── stock_movement.dart                ← StockMovement, StockMovementType
│   ├── business_profile.dart              ← BusinessProfile, BusinessType
│   ├── staff_member.dart                  ← StaffMember, StaffStatus
│   ├── ai_insight.dart                    ← AiInsight, InsightPriority, InsightCategory
│   └── ... (payment, cart, session, etc.)
├── providers/
│   ├── orders_provider.dart               ← Order list & filtering
│   ├── inventory_provider.dart            ← Inventory list & filtering
│   ├── menu_providers.dart                ← Menu items & categories
│   ├── dashboard_metrics_provider.dart    ← KPIs & charts
│   ├── ai_insights_provider.dart          ← AI insight generation
│   ├── staff_provider.dart                ← Staff & roles
│   ├── settings_provider.dart             ← Business & store settings
│   └── ...
└── widgets/
    ├── dashboard/
    │   ├── low_stock_alert_banner.dart
    │   ├── revenue_trend_chart.dart
    │   ├── insight_highlights.dart
    │   └── ...
    ├── data_page/                         ← Reusable table, filters, exports
    ├── pos/                               ← POS-specific (cart, checkout)
    └── ...
```

---

**Report Compiled By**: Claude Code | **Next Action**: Share findings with backend team & prioritize API design
