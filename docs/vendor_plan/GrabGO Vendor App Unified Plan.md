# GrabGo Vendor Mobile App — Unified Master Plan (Single Source of Truth)

## Brief Summary
Build one **Flutter mobile vendor app** for all GrabGo services (food, grocery, pharmacy, grabmart), with unified vendor identity, multi-branch support, owner/staff roles, operations-first UX, and Phase 1 launch focused on reliable daily execution.  
This plan combines product scope, backend architecture, API contracts, UI/UX, onboarding, testing, and rollout into one implementation-ready spec.

## Locked Decisions
| Area | Final Decision |
|---|---|
| Platform | Mobile app (Flutter), Android + iOS at launch |
| Service Coverage | Food + Grocery + Pharmacy + GrabMart in one app |
| Release Strategy | 2-phase rollout |
| Identity | Unified vendor account |
| Branching | Multi-branch at launch |
| Staffing | Owner + staff roles |
| Messaging | Vendor chat included in Phase 1 |
| Pharmacy Compliance | Manual prescription verification before accept |
| App Shell | 5 tabs: Home, Orders, Catalog, Chats, More |
| Default Landing | Live orders queue after login |
| V1 Priority | Operational core only |
| Orders UX | Unified queue + smart filters |
| Catalog UX | Fast item CRUD |
| Home UX | Action inbox + key KPIs |
| Visual Direction | Brand-consistent + service accents |
| Onboarding | Guided wizard, mandatory shell once, optional steps skippable |
| Training | Interactive demo order in onboarding |
| Missing Features Added to P1 | Substitution/partial fulfillment, issue center, outage controls, audit timeline UI |

## Phase Scope (Critical vs Deferred)

### Phase 1 (Launch-Critical)
1. Unified auth/session and store membership access.
2. Multi-branch store switcher across all services.
3. Live order operations: accept/reject/preparing/ready/handover/pickup OTP.
4. Pharmacy manual prescription review gate.
5. Catalog + inventory CRUD for all service types.
6. Store operating controls: open/close, accepting orders, outage pause, auto-resume.
7. Staff management: invite/manage roles.
8. Vendor chat inbox and order-linked threads.
9. Home action inbox + basic KPIs.
10. Onboarding wizard + demo order + persistent checklist.
11. Item substitution/partial fulfillment flow.
12. Vendor issue/escalation center.
13. Order audit timeline visibility.

### Phase 2 (Deferred)
1. Promotions/campaigns.
2. Advanced analytics and trend dashboards.
3. Settlement/payout center and exports.
4. Scheduled/pre-orders.
5. Printer/KDS integrations.
6. Automation rules (auto-accept, smart ops rules).

## Backend Plan

## 1) Data Model Changes (Prisma)
### Enums to add
1. `UserRole`: add `vendor`.
2. `VendorStoreType`: `restaurant`, `grocery`, `pharmacy`, `grabmart`.
3. `VendorStaffRole`: `owner`, `manager`, `operator`, `cashier`.
4. `MembershipStatus`: `invited`, `active`, `suspended`, `removed`.
5. `PrescriptionReviewStatus`: `not_required`, `pending`, `approved`, `rejected`.
6. `OrderIssueType`: `item_unavailable`, `customer_unreachable`, `rider_delay`, `payment_problem`, `other`.
7. `OrderIssueStatus`: `open`, `acknowledged`, `resolved`, `escalated`.
8. `StorePauseReason`: `kitchen_overload`, `stock_restock`, `technical_issue`, `staff_shortage`, `other`.
9. `ItemChangeType`: `replace`, `remove`, `cancel`.
10. `ItemChangeDecision`: `pending_customer`, `approved_customer`, `rejected_customer`, `expired`.

### Models to add
1. `VendorStoreMembership(userId, storeType, storeId, staffRole, status, isPrimary, createdAt, updatedAt)` with unique `(userId, storeType, storeId)`.
2. `VendorInvite(inviterUserId, email, storeType, storeId, staffRole, token, expiresAt, status)`.
3. `OrderPrescription(orderId, customerId, imageUrls, note, reviewStatus, reviewedByUserId, reviewedAt, rejectReason)`.
4. `OrderIssue(orderId, createdByUserId, storeType, storeId, issueType, status, description, escalatedAt, resolvedAt)`.
5. `StoreOutageWindow(storeType, storeId, reason, note, startsAt, endsAt, autoResume, createdByUserId, isActive)`.
6. `OrderItemChangeProposal(orderId, orderItemId, type, proposedItemId, note, priceDelta, decision, expiresAt, decidedAt, decidedByUserId)`.
7. `VendorOnboardingState(userId, stepsJson, completedAt, demoCompletedAt, updatedAt)` or equivalent user fields.

### Existing model extensions
1. `Order`: add `prescriptionRequired`, `prescriptionReviewStatus`.
2. `User`: add vendor onboarding completion/progress fields.

## 2) Auth and Authorization
1. Keep JWT auth based on `User` table only.
2. Vendor runtime access requires `role=vendor` (or temporary legacy compatibility) plus active membership.
3. Add middleware:
   - `requireVendorAuth`
   - `requireStoreMembership(storeType, storeId, minRole)`
   - `canPerformOrderAction(orderId, actorUserId)`
4. Enforce ownership checks on every vendor mutation endpoint.
5. Deprecate store-table password auth flows as runtime source of truth.

## 3) Vendor API Surface (Public Interface)
### Core identity/context
1. `GET /api/vendor/me`
2. `GET /api/vendor/stores`
3. `GET /api/vendor/staff`
4. `POST /api/vendor/staff/invite`
5. `PATCH /api/vendor/staff/:membershipId`
6. `DELETE /api/vendor/staff/:membershipId`

### Orders
1. `GET /api/vendor/orders`
2. `GET /api/vendor/orders/:orderId`
3. `POST /api/vendor/orders/:orderId/actions/accept`
4. `POST /api/vendor/orders/:orderId/actions/reject`
5. `POST /api/vendor/orders/:orderId/actions/preparing`
6. `POST /api/vendor/orders/:orderId/actions/ready`
7. `POST /api/vendor/orders/:orderId/actions/handover`
8. `POST /api/vendor/orders/:orderId/actions/verify-pickup-code`
9. `POST /api/vendor/orders/:orderId/actions/prescription-review`
10. `GET /api/vendor/orders/:orderId/audit`

### Substitution / partial fulfillment
1. `POST /api/vendor/orders/:orderId/items/:orderItemId/propose-change`
2. `POST /api/vendor/orders/:orderId/items/:orderItemId/confirm-change`
3. `POST /api/vendor/orders/:orderId/items/:orderItemId/cancel-change`

### Issue center
1. `POST /api/vendor/orders/:orderId/issues`
2. `GET /api/vendor/orders/:orderId/issues`
3. `PATCH /api/vendor/orders/:orderId/issues/:issueId`

### Catalog
1. `GET /api/vendor/catalog/items`
2. `POST /api/vendor/catalog/items`
3. `PUT /api/vendor/catalog/items/:itemId`
4. `DELETE /api/vendor/catalog/items/:itemId`
5. `PATCH /api/vendor/catalog/items/:itemId/availability`
6. `PATCH /api/vendor/catalog/items/:itemId/stock`
7. `GET /api/vendor/catalog/categories`
8. `POST /api/vendor/catalog/categories`
9. `PUT /api/vendor/catalog/categories/:categoryId`

### Store operations
1. `PATCH /api/vendor/stores/:storeType/:storeId/operating-state`
2. `POST /api/vendor/stores/:storeType/:storeId/pause`
3. `POST /api/vendor/stores/:storeType/:storeId/resume`
4. `GET /api/vendor/stores/:storeType/:storeId/pause-status`

### Analytics
1. `GET /api/vendor/analytics/overview`
2. `GET /api/vendor/analytics/items`
3. `GET /api/vendor/analytics/service-breakdown`

### Onboarding
1. `GET /api/vendor/onboarding`
2. `PUT /api/vendor/onboarding`
3. `POST /api/vendor/onboarding/demo/complete`

## 4) Backend Hardening Required Before Mobile Integration
1. Fix inconsistent restaurant order lookup logic in existing orders route.
2. Enforce actor/store ownership checks on status transitions.
3. Add role checks for food mutations and all catalog mutations.
4. Ensure pause state blocks new incoming orders for paused store.
5. Keep existing customer/rider endpoints backward-compatible.

## 5) Realtime and Notifications
1. Extend chat participant model to include vendor in order-linked threads.
2. Add vendor push events:
   - `vendor_new_order`
   - `vendor_order_at_risk`
   - `vendor_issue_update`
   - `vendor_pause_expiring`
   - `vendor_chat_message`
3. Add socket channels scoped by vendor user and active store context.

## Vendor Mobile App (Flutter) Plan

## 1) Package and Foundation
1. Create `packages/grab_go_vendor`.
2. Reuse `grab_go_shared` themes/components/services.
3. Stack: `provider`, `go_router`, `chopper`, `firebase_messaging`, `socket_io_client`.

## 2) Navigation Architecture
1. App launch: `Splash -> Auth -> Onboarding -> Main Tabs`.
2. Main tabs: `Home`, `Orders`, `Catalog`, `Chats`, `More`.
3. Global store switcher persistent in app shell.
4. Post-login default: live orders queue.

## 3) Full Screen Map
### Auth + setup
1. Splash
2. Sign In
3. Forgot Password
4. Session Recovery

### Onboarding
1. Welcome
2. Store Context Setup
3. Permissions
4. Role Quick Guide
5. Demo Order Simulation
6. Quick Actions Setup
7. Completion + Checklist handoff

### Main
1. Home (action inbox + KPIs)
2. Orders list (unified queue)
3. Order detail
4. Order action sheet
5. Pickup OTP verification
6. Prescription review
7. Item change proposal
8. Issue report sheet
9. Issue timeline
10. Order audit timeline
11. Catalog list
12. Add item
13. Edit item
14. Stock adjust
15. Category management
16. Chats inbox
17. Chat thread
18. More hub
19. Store operations
20. Outage pause/resume
21. Staff list
22. Staff invite/manage
23. Profile & security
24. Basic analytics
25. Notification settings
26. Help + onboarding replay

## UI/UX Behavior Specs

## 1) Home
1. Top: current store chip + switch.
2. Priority cards sorted by urgency: new orders, SLA risk, low stock, unresolved issues.
3. KPI row: new orders, in-progress, avg prep time, cancellation rate.
4. Checklist card shown until onboarding optional steps are done.

## 2) Orders
1. One unified queue across services.
2. Smart chips: service, status, fulfillment, SLA, search.
3. Card anatomy: time elapsed, service badge, item count, customer/rider context, action CTA.
4. Detail timeline includes status, issues, item changes, audit entries.
5. Invalid actions are disabled with explicit reason copy.

## 3) Catalog
1. Fast list-first editing.
2. Service-aware item forms.
3. Quick actions for stock and availability.
4. Multi-select for rapid availability toggles.

## 4) Chat
1. Order-linked threads as primary grouping.
2. Unread and at-risk conversation badges.
3. Shortcut from chat to order detail.

## 5) Outage controls
1. Pause modal requires reason.
2. Optional auto-resume timer.
3. Active outage banner visible in Home and Orders.

## 6) Onboarding
1. Mandatory shell once; optional steps skippable.
2. Demo order is simulated and cannot mutate real orders.
3. Incomplete optional tasks remain in Home checklist and More > Training.

## Design System
1. Base brand primary action color: `#FE6132`.
2. Service accents:
   - Food `#FE6132`
   - Grocery `#4CAF50`
   - Pharmacy `#009688`
   - GrabMart `#9C27B0`
3. Typography: `Lato` (existing ecosystem consistency).
4. UI style: operationally dense, high-contrast, action-prioritized.
5. Accessibility: clear status text, icon+color redundancy, minimum touch target sizes.

## Required Customer and Rider App Updates
1. Customer app:
   - Add substitution approval UX.
   - Show issue/status/item-change timeline events.
   - Vendor-inclusive order chat behavior.
2. Rider app:
   - Ensure vendor-inclusive chat thread compatibility.
   - Reflect vendor handover and issue-related order states where relevant.

## Execution Sequence (Follow Exactly)
1. **Workstream A**: Prisma schema + migrations + seeded permission roles.
2. **Workstream B**: vendor auth/membership middleware + route hardening.
3. **Workstream C**: vendor API endpoints for orders/catalog/staff/store ops.
4. **Workstream D**: substitution, issue center, outage controls, audit endpoints.
5. **Workstream E**: chat participant extension and vendor push/socket events.
6. **Workstream F**: OpenAPI sync and backend tests.
7. **Workstream G**: create `grab_go_vendor` app shell + routing + providers.
8. **Workstream H**: implement P1 screens and flows in priority order:
   - Orders core
   - Catalog core
   - Store operations
   - Staff
   - Chats
   - Home KPIs
   - Onboarding
9. **Workstream I**: customer/rider compatibility changes.
10. **Workstream J**: integration testing, pilot rollout flags, production release.

## Test Plan

## Backend tests
1. Membership authorization matrix by role and store.
2. Order lifecycle transition rules by actor.
3. Prescription review gating logic.
4. Substitution proposal and decision timeout behavior.
5. Issue creation/escalation/resolution.
6. Pause/outage blocking of new orders.
7. Audit timeline completeness.
8. Chat participant auth with vendor added.
9. Regression for customer/rider legacy endpoints.

## Mobile tests
1. Onboarding flow completion/skipping/resume.
2. Store switching correctness across services and branches.
3. Orders queue filtering and action correctness.
4. Catalog CRUD and stock updates.
5. Substitution and issue workflows.
6. Pause/resume controls.
7. Chat thread send/receive and order linking.
8. Offline/reconnect resilience.

## End-to-End acceptance scenarios
1. Owner processes cross-service orders in two branches within one session.
2. Staff member with restricted role cannot access forbidden actions.
3. Pharmacy order requiring prescription cannot move forward before review.
4. Substitution approved by customer updates order correctly.
5. Store pause prevents new intake and auto-resumes on timer.
6. All critical actions appear in order audit timeline.

## Rollout and Monitoring
1. Feature flags:
   - `vendor_app_enabled`
   - `vendor_chat_enabled`
   - `vendor_substitution_enabled`
   - `vendor_issue_center_enabled`
   - `vendor_pause_controls_enabled`
   - `vendor_onboarding_enabled`
2. Pilot rollout by selected stores first.
3. KPIs to monitor:
   - order acceptance latency
   - substitution success rate
   - cancellation rate
   - issue resolution time
   - chat delivery success
   - API 4xx/5xx error rates
4. Alerts:
   - spikes in permission denials
   - status transition failures
   - outage/pause misconfiguration
   - realtime message delivery drop

## Assumptions and Defaults
1. Current market settings remain (GHS/Ghana) in Phase 1.
2. Unified `User` identity becomes canonical for vendor runtime access.
3. Phase 1 prioritizes operational reliability over growth tooling.
4. Features outside the Phase 1 list cannot block launch.
5. All new vendor mutations must be membership-gated and audited.
