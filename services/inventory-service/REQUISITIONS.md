# Requisition flow — unified order cart → per-supplier POs → WhatsApp payloads

> 2026-10-13 — POs are now **qty-only** (no cost on the PO or in the
> supplier payload). Actual cost enters on `GoodsReceiptLine.unit_cost` at
> receipt time and flows into weighted-average costing. The `SupplierItem`
> catalogue and `RequisitionLine` price snapshots remain as buyer-side
> reference only.
>
> 2026-10-13 — POs are now **two-step**: create (`unfulfilled`) → receive
> (each line: qty received + actual unit cost). `fulfilled` once every line
> is fully received, else still `unfulfilled` (more GRNs may follow);
> `cancelled` only before anything is received. The submit/approve
> handshake, returns, invoices/payments, supplier statement, and the
> requisition mark-sent/mark-confirmed + Cloud API per-PO send are removed.
> Requisition POs are created `unfulfilled` (directly receivable); rollup
> is Fulfilled / Cancelled / Unfulfilled. Migration `s2t3u4v5w6x7` shrinks
> the status enum and drops the returns/payables tables.

Staff build ONE order (a **Requisition**) with items from multiple suppliers in a
dialog-based cart, then submit. The backend splits it into SEPARATE purchase
orders — one per supplier — and prepares a ready-to-send WhatsApp payload per PO.
No WhatsApp API is called in this pass; staff send manually via a `wa.me` deep link.

## Confirmed decisions (do not re-litigate silently)

| # | Question | Decision |
|---|----------|----------|
| 1 | Bulk-assign overwrite | Default **unassigned-only**; explicit **"override all" toggle** replaces existing per-item picks |
| 2 | `po_number` scheme | **Global sequential per business** (`PO-0001`, existing `uq_purchaseorder_business_po_number`) |
| 3 | Append-to-draft rule | **Same requisition only** — append to an `unfulfilled` PO from the same requisition+supplier, else create new |
| 4 | Stack | FastAPI + SQLModel + Postgres/Alembic (`inventory-service`); Flutter + Riverpod app. **Additive only** — see mapping notes below |
| 5 | Delivery date | **Per requisition** (single `expected_at`, copied to each PO) |
| 6 | Cart dismiss | **Client-side session only** — no server draft; dialog close preserves in-memory cart |

### Existing-schema mapping (Q4 adjustments)

- `Supplier.phone` is the legacy number field. Added nullable `whatsapp_number`
  (+ `contact_person`, `is_active`). Payload resolution: `whatsapp_number` → else
  `phone` → else skip payload (PO still created, UI shows "Add WhatsApp number").
  `is_active=False` = temporarily not ordering; `is_deleted=True` = retired.
- There was **no `SupplierItem` table** (`Item.supplier_id` holds one supplier).
  Added `supplieritem` (price, moq, lead_time_days, is_preferred) — `Item.supplier_id`
  untouched. Missing catalogue row ⇒ `price_unconfirmed=true`, never a block.
- `PurchaseOrder.status` is `unfulfilled` (open, receivable) / `fulfilled`
  (terminal, quantities met) / `cancelled` (only before any receipt).
- Flutter: `Supplier.whatsappNumber` falls back to `phone` via `sendNumber`.
  The Drift `cached_suppliers` table does **not** yet carry the new columns
  (TODO below) — cached rows resolve through `phone` until it does.

## Backend (`services/inventory-service`)

Migration `n2b3c4d5e6f7` (revises `m1a2b3c4d5e6`): new `requisition`,
`requisitionline`, `supplieritem`, `suppliermessage` (+ 4 native enums);
`supplier` += `whatsapp_number/contact_person/is_active`;
`purchaseorder` += nullable `requisition_id` FK + `idempotency_key`, enum +=
`payload_ready/sent/confirmed/partially_fulfilled/fulfilled`;
`purchaseorderline` += `price_unconfirmed` (default false).

- `POST /businesses/{bid}/requisitions` — submit cart → split → payloads.
  Rejects lines with no `supplier_id` (422 naming the items); allows
  `price_unconfirmed` (flagged, not blocked); duplicate `(supplier,item)` pairs
  merge by summing qty; same item under two suppliers ⇒ two POs. One commit —
  all-or-nothing. Idempotent on `idempotency_key` (re-submit returns the graph).
- `POST /businesses/{bid}/requisitions/{id}/bulk-assign`
  (`scope: all_items|unassigned_items_only`, `overwrite: bool`) — idempotent,
  re-resolves prices from `supplieritem`.
- `POST …/requisitions/{id}/regenerate-payloads` — rebuild after line edits.
- `POST /businesses/{bid}/supplier-items` — catalogue upsert.
- Receiving happens on the PO itself (`POST …/purchases/orders/{id}/receive`
  with per-line qty + actual unit cost); cancel (`POST …/cancel`) only
  before anything is received. No submit/approve, no invoices/payments,
  no mark-sent/mark-confirmed.

### Bulk-assign overwrite rules

`unassigned_items_only` touches only supplier-less lines. `all_items` is still
safe by default: lines with a supplier are skipped unless `overwrite=true`
(the "Override items that already have a supplier" toggle). Both write the same
`RequisitionLine.supplier_id`; `supplier_assignment_source` records
`manual_per_item` vs `bulk_all` for display only.

### PO split logic

Group lines by `supplier_id` → per group, reuse an `unfulfilled` PO of
**this requisition+supplier** if present, else `PO-<next global seq>` →
write qty-only `PurchaseOrderLine`s (unit denormalized from item; catalogue
prices stay on the `RequisitionLine` snapshot, never copied to the PO) →
`SupplierMessage(status='ready')` per PO unless the supplier has no number.

### Status rollup (pure, `rollup_requisition_status`)

All `fulfilled` → **Fulfilled** · all `cancelled` → **Cancelled** · else
**Unfulfilled**. Never stored; derived per read.

### Payload schema (per PO, `SupplierMessage.payload`)

`po_id, supplier{name, whatsapp_number}, message_type='purchase_order',
text_preview` (qty-only lines, e.g. `- Flour: 5.000 kg`),
`structured_data{po_number, restaurant_name, order_date,
delivery_requested_date, items[{name, qty, unit}], notes}`,
`deep_link = https://wa.me/<digits>?text=<url-encoded text_preview>`.
Status enums include `sent/delivered/read`
for forward-compat; nothing auto-advances past `ready` — only staff taps do.

## Frontend (`apps/restaurant_app`)

- `requisition_cart_dialog.dart` — the cart. Bottom sheet (mobile) / centered
  640px modal (tablet/desktop) via `Breakpoints` (`tablet: 600, desktop: 1024,
  maxContentWidth: 1600`). Pinned header + sticky bulk bar + pinned footer;
  list scrolls independently. `RequisitionCartButton` (with count badge) is the
  persistent trigger, wired next to "New order" on the Purchases tab.
- `widgets/dialogs/supplier_picker_dialog.dart` — nested picker used for both
  scopes. Bottom sheet (mobile) / 440px dialog with autofocus search (larger).
  Same component, same field, different scope.
- `requisition_order_screen.dart` — Option 2 UX: date, rollup chip, line count;
  supplier cards (badge, lines, item count, send button). 1-col mobile →
  2/3-col grid ≥ tablet widths (`LayoutBuilder` + `Breakpoints.of`, layout-only).
  `launchUrl(externalApplication)`: native app on mobile, Web/app prompt on
  desktop. No PO numbers here.
- `requisition_export_screen.dart` — secondary route (`…/requisition/:id/export`):
  real PO numbers, timestamps, `SelectableText` previews, Copy + Share/print,
  price-TBC lines marked. Print-friendly single column, capped at
  `maxContentWidth`.
- Touch targets ≥44px on mobile/tablet; hover never required. Dialog routes give
  focus trap + Esc + focus return; picker search autofouses on non-mobile.
- Routes: `AppRoute.requisitionDetail(id)` (`/purchasing/requisition/:id`),
  `AppRoute.requisitionExport(id)` (`…/export`). i18n: all strings via
  `AppStrings.req*` (+ en/sw maps).

## Tests

Backend (`tests/test_requisitions.py`): bulk scopes/overwrite/
`price_unconfirmed`/idempotent rerun; split grouping, missing-supplier 422
naming items + rollback, TBC flagging, same-item-two-suppliers, duplicate-submit,
bad-item rollback; qty-only payload/URL-encoding/missing-number/phone
fallback; rollup table; full journey (submit → receive → Fulfilled rollup,
gone mark-sent/mark-confirmed 404); no-number PO.
`tests/api/test_purchases.py`: create (unfulfilled, qty-only) → partial
receive (stays unfulfilled) → full receive (fulfilled + costing) → receive
guarded; cancel rules; removed routes 404; list/permissions.
Run: `DB_URL=…:5434/oryonfoods_inventory TEST_DB_URL=…:5434/oryonfoods_inventory_test
uv run --project . python -m pytest tests/test_requisitions.py tests/api/test_purchases.py -q`
(all green; store-scope enforcement is now covered by
`tests/api/test_store_scope.py`).

App (`test/requisition_cart_test.dart` 12 tests — cart state machine, submit,
`fromJson`/badges; `test/requisition_cart_dialog_test.dart` 6 tests — sheet vs
dialog per width, dismiss-preserves-cart, blocker copy, picker assign, Esc).
Run: `flutter test test/requisition_cart_test.dart test/requisition_cart_dialog_test.dart`.

## Cross-device QA checklist

- [ ] Cart: bottom sheet mobile (swipe dismiss, keyboard insets) vs centered
      640px modal tablet/desktop; header/footer pinned, list scrolls alone.
- [ ] Picker nested on all three widths; desktop search filters by typing.
- [ ] `wa.me` link: native app (mobile) vs Web/app prompt (desktop) — pre-filled.
- [ ] Desktop keyboard: Tab cycles inside dialog, Esc closes, focus returns.
- [ ] Touch targets ≥44px mobile/tablet; order grid 1→2→3 columns by width.
- [ ] Empty/error copy on all widths: no supplier, no WhatsApp number, payload
      skipped, TBC banner, offline notice, failed load + retry.

## WhatsApp Cloud API pass (implemented 2026-10-06)

The manual `wa.me` flow above stays as the fallback. When the business
connects its sender in the app (Settings → WhatsApp), POs send through
the WhatsApp Business Cloud API instead:

* `whatsappconnection` (migration `q9r0s1t2u3v4`, one row per business):
  `phone_number_id`, display number, access token (plaintext in this
  pass — same MVP tradeoff as `internal_service_token`; move to a secret
  manager before multi-tenant prod), server-generated webhook
  `verify_token`, live `status` (`connected`/`error`/`disconnected`).
* `PUT …/whatsapp/connection` stores + live-verifies credentials against
  Graph in one call; `GET` returns a masked preview; `DELETE` clears the
  token; `POST …/connection/test` re-checks. Auth: `procurement.view`
  (GET) / `procurement.create` (writes).
* `POST …/purchases/orders/{id}/send-whatsapp` — REMOVED (2026-10-13):
  staff send via the wa.me deep link only; no Cloud API per-PO send and no
  PO send lifecycle. Connection CRUD + webhooks above stay as-is.
* `GET /api/v1/whatsapp/webhook` verifies Meta's handshake against the
  per-business token (`?business_id=…&t=…`, global
  `WHATSAPP_WEBHOOK_VERIFY_TOKEN` fallback); `POST` applies
  `sent → delivered → read` / `failed` callbacks by `wamid` and stores
  inbound supplier replies (matched to the sender's latest PO by number,
  unmatched kept with `po_id=NULL`), flagging EN+SW confirmation
  keywords (`confirmation_detected`) for display.
* `SupplierMessage` gained `provider_message_id` + `last_error`;
  `messagestatus` gained `received` (inbound rows).
* Tests: `tests/test_whatsapp.py` (connection CRUD, masking, webhook
  verify/status/inbound, reply parser, gone send-whatsapp 404).
* App: Settings → WhatsApp screen (connect/test/disconnect + webhook
  URL + verify token with copy), live status row in the Settings index,
  and per-supplier-card wa.me send (manual deep link only).
* Env: `WHATSAPP_GRAPH_BASE_URL` (default `https://graph.facebook.com`),
  `WHATSAPP_GRAPH_VERSION` (`v21.0`), optional `WHATSAPP_APP_SECRET`
  (enables `X-Hub-Signature-256` checks), `PUBLIC_BASE_URL`.

Still open: template-message support for outside-the-window sends, and
`whatsapp_number` et al. on the Drift `cached_suppliers` table (+ mapper)
so the directory sync carries them. Never call the API from the submit
transaction (the send endpoint is the only caller).
