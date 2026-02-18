# GrabGo Vendor Mobile App — UI/UX Plan Update

## Summary
- This adds a full UI/UX blueprint to the existing vendor app proposal.
- The app is mobile-first (Flutter), multi-service, multi-branch, and operations-first.
- Phase 1 UI focuses on execution speed: orders, inventory, store controls, chat, and basic KPIs.
- Phase 2 UI adds growth and finance depth: promos, advanced analytics, settlements, exports, automation.

## Locked UX Decisions
- Navigation: operations-first 5 tabs.
- Post-login default: live orders queue.
- Phase 1 feature boundary: operational core only.
- Orders IA: unified queue with smart filters.
- Catalog IA: fast item CRUD forms.
- Home IA: action inbox + key KPIs.

## App Structure
- Auth stack: `Splash`, `Sign In`, `Forgot Password`, `Verify OTP` (if enabled), `Session Restore`.
- Global context layer: `Store Switcher` available across app.
- Main tabs: `Home`, `Orders`, `Catalog`, `Chats`, `More`.
- Global overlays: `Notification Drawer`, `Quick Actions Sheet`, `Connectivity Banner`, `Critical Alert Banner`.

## Page Inventory and Criticality

| Route/Screen | Purpose | Criticality | Phase |
|---|---|---|---|
| `Splash` | Restore session and preload store context | Critical | P1 |
| `Sign In` | Unified vendor login | Critical | P1 |
| `Forgot Password` | Password recovery | Critical | P1 |
| `Store Selector` | Switch branch/service context | Critical | P1 |
| `Home` | Action inbox + compact KPI cards | Critical | P1 |
| `Home > Alerts` | View all urgent tasks | Critical | P1 |
| `Orders` | Unified order queue with filters | Critical | P1 |
| `Orders > Detail` | Full order context and timeline | Critical | P1 |
| `Orders > Status Action Sheet` | Accept/reject/preparing/ready/handover | Critical | P1 |
| `Orders > Pickup Code Verify` | OTP verification for pickup | Critical | P1 |
| `Orders > Prescription Review` | Approve/reject pharmacy prescription-required orders | Critical | P1 |
| `Catalog` | Item list with search/filter | Critical | P1 |
| `Catalog > Add Item` | Create item | Critical | P1 |
| `Catalog > Edit Item` | Update item fields/media | Critical | P1 |
| `Catalog > Stock Adjust` | Quick stock increment/decrement | Critical | P1 |
| `Catalog > Availability Toggle` | Mark item available/unavailable | Critical | P1 |
| `Chats` | Conversation inbox | Critical | P1 |
| `Chats > Thread` | Real-time order-linked chat | Critical | P1 |
| `More` | Secondary settings and tools index | Critical | P1 |
| `More > Store Operations` | Open/close store, accepting orders, prep defaults | Critical | P1 |
| `More > Staff` | Invite/manage owner/manager/operator/cashier roles | Critical | P1 |
| `More > Profile & Security` | Account profile, password, logout | Critical | P1 |
| `More > Basic Analytics` | Today/7d/30d operational metrics | Critical | P1 |
| `More > Notifications` | Notification preferences and history | Important, not blocking launch | P1 |
| `Promotions` | Campaigns/coupons/boosts | Non-critical | P2 |
| `Advanced Analytics` | Funnel/cohort/deep trends | Non-critical | P2 |
| `Settlements & Payouts` | Finance detail, exports | Non-critical | P2 |
| `Bulk Import` | CSV/large inventory import | Non-critical | P2 |
| `Automation Rules` | Auto-accept and smart operational rules | Non-critical | P2 |

## Critical Feature Definition (Phase 1)
- Must-have: login/session, store switching, order queue, order status actions, pickup OTP, prescription manual review, catalog CRUD, stock control, store open/close controls, chat, basic KPI cards.
- Should-have: notifications center, role-specific shortcuts, quick search for orders/items.
- Deferred: campaigns, advanced finance, deep analytics, bulk upload, automation engine.

## Screen-Level UX Behavior

## Home
- Top area: current store chip + switcher.
- Primary block: urgent action cards sorted by SLA risk.
- Secondary block: KPI cards (`new orders`, `in progress`, `avg prep time`, `cancel rate`).
- One-tap shortcuts: `Accept next`, `Mark ready`, `Low stock`.

## Orders
- Default list: all services unified.
- Sticky filter row: service type, status, fulfillment mode, SLA risk, search.
- Each card shows: order type, elapsed time, customer, item count, payout proxy, state badge.
- Detail screen includes: timeline, item list, notes, customer/rider contact, service-specific controls.
- Guardrails: invalid transitions disabled with explicit reason text.

## Catalog
- Fast list-first flow with inline actions.
- Create/edit form adapts fields by service type.
- Batch quick actions: availability toggle and stock update for selected items.
- Pharmacy item forms include prescription-required flag and compliance hint copy.

## Chats
- Inbox grouped by order and urgency.
- Thread supports quick-reply chips and attachment previews.
- Action shortcuts inside thread: open linked order, call counterpart, mark issue.

## More
- Store Operations, Staff, Profile/Security, Basic Analytics, Notifications.
- Staff pages enforce role permissions with clear disabled-state messaging.

## Styling and Visual System
- Base brand: keep GrabGo orange action identity.
- Service accents: food `#FE6132`, grocery `#4CAF50`, pharmacy `#009688`, grabmart `#9C27B0` used as badges/chips/indicators only.
- Typography: keep existing `Lato` system for consistency with customer/rider apps.
- Density: high-information cards with strong hierarchy, not marketing-heavy layouts.
- Motion: functional transitions only (queue updates, status change confirmation, tab transitions).
- Accessibility: WCAG-friendly contrast, tap targets >= 44px, clear state labels, color + icon redundancy.

## Public Interfaces and Types (UI Contract Additions)
- No new backend domains beyond the prior backend plan; this UI binds to those vendor endpoints.
- Add frontend route contracts:
  - `VendorRoute.home`, `VendorRoute.orders`, `VendorRoute.orderDetail`, `VendorRoute.catalog`, `VendorRoute.catalogEdit`, `VendorRoute.chats`, `VendorRoute.staff`, `VendorRoute.storeOps`.
- Add frontend state types:
  - `StoreContext`, `OrderQueueFilter`, `OrderActionPermission`, `CatalogItemDraft`, `PrescriptionReviewDecision`, `StaffPermissionMatrix`.
- Add permission map:
  - `owner`, `manager`, `operator`, `cashier` action matrix used by UI gates.

## Test Cases and Scenarios
- Owner logs in, switches between food and pharmacy branches, processes both order types.
- Staff with limited role can update stock but cannot manage staff or store-level settings.
- Pharmacy order requiring prescription cannot move to preparing before manual review.
- Pickup order must complete OTP verification before final pickup status.
- Unified queue filters correctly across service type/status/SLA.
- Chat thread links correctly back to order detail.
- Offline/reconnect flow preserves draft actions and refreshes safely.
- Critical alerts surface within 3 seconds of push/socket event while app foregrounded.

## Assumptions and Defaults
- Single app binary serves all vendor roles and all service categories.
- Same design token foundation from `grab_go_shared` is reused, then extended with vendor-specific components.
- Operational speed is prioritized over visual decoration in Phase 1.
- Any feature not listed as Critical is not allowed to block launch readiness.
