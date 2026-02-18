# GrabGo Vendor Mobile App (Multi-Service) — Decision-Complete Proposal

## Summary
- Build a new Flutter mobile app package for vendors covering food, grocery, pharmacy, and grabmart in one app.
- Use a unified vendor identity with multi-branch support, owner+staff roles, and Android+iOS launch together.
- Ship in 2 phases: Phase 1 core operations for all services (including chat), Phase 2 advanced analytics/promotions/automation.
- Backend must add a vendor access layer and secure order/catalog operations by store ownership before app implementation.

## Locked Product Decisions
- Release model: 2-phase rollout.
- Identity model: unified vendor account.
- Styling direction: brand-consistent with service accents.
- Staffing: owner + staff roles.
- Platforms: Android + iOS together.
- Messaging: include chat in Phase 1.
- Branching: multi-branch at launch.
- Pharmacy compliance: manual prescription verification before acceptance.

## Verified Current-State Findings (from codebase)
- Backend already supports multi-service ordering in `backend/routes/orders.js`, but vendor-safe ownership controls are incomplete.
- Food has mutation endpoints (`POST/PUT /api/foods`) but no strict vendor ownership checks in current handlers.
- Grocery/pharmacy/grabmart routes are mostly customer discovery/read endpoints; no vendor CRUD/ops endpoints exist.
- Auth middleware (`backend/middleware/auth.js`) is `User`-table JWT based; vendor store tables have separate email/password fields, creating identity inconsistency.
- `UserRole` enum currently has `customer|restaurant|rider|admin`; no unified `vendor` role.
- Chat model is customer-rider centric (`backend/models/Chat.js`), so vendor chat requires schema/service updates.
- API docs are drifted (notably statuses paths in `backend/docs/openapi.yaml` vs `backend/routes/statuses.js`).
- Flutter mobile baseline is strong in customer/rider/shared packages; no current `packages/grab_go_vendor` exists.

## Implementation Scope

## Phase 1 (Launch Scope)
- Vendor auth/session with unified account.
- Multi-store switcher across all service types.
- Live order operations: accept/reject/preparing/ready/handover/pickup-code verification.
- Pharmacy manual prescription review gate.
- Catalog and inventory CRUD for all service types.
- Store operations toggles: `isOpen`, `isAcceptingOrders`, prep time, delivery settings.
- Staff management: invite, role assignment, suspension.
- Vendor chat for order conversations.
- Push notifications for new orders, SLA alerts, chat.
- Basic analytics: today/7d/30d sales, cancellation rate, prep SLA, top items.
- Brand-consistent UI system with service accenting.

## Phase 2 (Post-Launch)
- Advanced analytics and cohort insights.
- Promotions/campaign management.
- Auto-accept rules, prep-time automation, low-stock automations.
- Finance modules: settlement details, payout tracking, exports.
- Enhanced compliance automation (OCR/validation workflows).

## Backend Architecture Plan

## 1) Data Model and Types (Prisma)
Add:
- `enum UserRole` add `vendor`.
- `enum VendorStoreType { restaurant, grocery, pharmacy, grabmart }`.
- `enum VendorStaffRole { owner, manager, operator, cashier }`.
- `enum MembershipStatus { invited, active, suspended, removed }`.
- `enum PrescriptionReviewStatus { not_required, pending, approved, rejected }`.

Create:
- `model VendorStoreMembership` with `userId`, `storeType`, `storeId`, `staffRole`, `status`, `isPrimary`, timestamps, unique `(userId, storeType, storeId)`, index `(storeType, storeId)`.
- `model VendorInvite` with inviter, invitee email, store context, role, token, expiry, status.
- `model OrderPrescription` with `orderId`, `customerId`, `imageUrls[]`, `note`, `reviewStatus`, `reviewedByUserId`, `reviewedAt`, `rejectReason`.

Extend `Order`:
- `prescriptionReviewStatus` default `not_required`.
- `prescriptionRequired` boolean default `false`.

## 2) Auth and Access Strategy
- Standardize vendor auth through `/api/users` JWT flow only (User table).
- Deprecate store-table password-based identity usage for runtime auth.
- Add middleware `authorizeVendorStoreAccess(storeType, storeId, minStaffRole)` for every vendor mutation.
- Keep legacy `restaurant` role compatibility, but all new vendor features require `vendor` role + membership.

## 3) API Surface (Public Interfaces)
Add namespaced vendor APIs:

1. `GET /api/vendor/me`
- Returns vendor profile, memberships, effective permissions.

2. `GET /api/vendor/stores`
- Filters: `storeType`, `status`.
- Returns all accessible stores across service types.

3. `GET /api/vendor/orders`
- Required: `storeType`, `storeId`.
- Filters: `status`, `fulfillmentMode`, `from`, `to`, `page`, `limit`.

4. `POST /api/vendor/orders/:orderId/actions/accept`
5. `POST /api/vendor/orders/:orderId/actions/reject`
6. `POST /api/vendor/orders/:orderId/actions/ready`
7. `POST /api/vendor/orders/:orderId/actions/handover`
8. `POST /api/vendor/orders/:orderId/actions/verify-pickup-code`
9. `POST /api/vendor/orders/:orderId/actions/prescription-review`
- Body: `{ decision: "approved"|"rejected", note?: string }`.

10. `GET /api/vendor/catalog/items`
- Required: `storeType`, `storeId`.
- Filters: `query`, `categoryId`, `availability`, `page`, `limit`.

11. `POST /api/vendor/catalog/items`
12. `PUT /api/vendor/catalog/items/:itemId`
13. `DELETE /api/vendor/catalog/items/:itemId`
14. `PATCH /api/vendor/catalog/items/:itemId/availability`

15. `PATCH /api/vendor/stores/:storeType/:storeId/operating-state`
- Body supports `isOpen`, `isAcceptingOrders`, prep settings.

16. `GET /api/vendor/analytics/overview`
- Required: `storeType`, `storeId`, `range`.

17. `GET /api/vendor/staff`
18. `POST /api/vendor/staff/invite`
19. `PATCH /api/vendor/staff/:membershipId`
20. `DELETE /api/vendor/staff/:membershipId`

Chat updates:
- Extend existing `/api/chats` to support vendor as participant and order-scoped multi-party threads.
- Keep existing route shape to avoid mobile client fragmentation; add role-aware participant filtering internally.

## 4) Critical Backend Hardening Before Mobile Build
- Fix `GET /api/orders` restaurant lookup logic that references nonexistent relation shape.
- Enforce ownership and role checks on all order status updates.
- Enforce ownership checks on food mutations and all future catalog mutations.
- Remove/lock unsafe direct status updates where actor/store validation is missing.
- Update OpenAPI spec to match real routes before integration testing.

## Vendor Mobile App Plan (Flutter)

## Package and foundation
- Create `packages/grab_go_vendor`.
- Reuse `grab_go_shared` theme/components/services.
- Use same stack as customer/rider: `provider`, `go_router`, `chopper`, `firebase_messaging`, `socket_io_client`.

## App modules
1. Auth and session.
2. Store switcher (multi-branch, multi-service).
3. Dashboard (KPIs + attention queue).
4. Orders (inbox, detail, action sheets, SLA timers).
5. Prescription review queue (pharmacy).
6. Catalog management (service-aware forms).
7. Inventory and stock alerts.
8. Chat inbox and thread.
9. Staff management.
10. Settings and profile.

## Navigation and state
- Root tabs: `Home`, `Orders`, `Catalog`, `Chats`, `More`.
- Global selected store context required for every module.
- Shared provider model: `SessionProvider`, `StoreContextProvider`, `OrderProvider`, `CatalogProvider`, `ChatProvider`, `AnalyticsProvider`, `StaffProvider`.

## Required Changes in Customer and Rider Apps

## Customer app
- Pharmacy checkout: require prescription upload when cart has `requiresPrescription` items.
- Order timeline: include prescription review state and vendor decision events.
- Chat UI: include vendor participant in order chat thread behavior.

## Rider app
- Order detail: show vendor-ready state and handover checkpoints consistently.
- Chat participation in order threads where vendor messaging is enabled.
- Keep rider operational flow unchanged except for thread participation and richer status metadata.

## Styling System (Brand-Consistent + Service Accents)
- Base brand: action orange `#FE6132`, neutral backgrounds from existing shared theme.
- Service accents: food `#FE6132`, grocery `#4CAF50`, pharmacy `#009688`, grabmart `#9C27B0`.
- Typography: keep `Lato` for consistency; use stronger weight hierarchy for data-dense operational views.
- Visual pattern: neutral surfaces + accent chips/badges per service; avoid full-screen color flooding.
- Motion: minimal functional transitions for state changes, queue refresh, and status transitions.
- Dark mode: support from shared theme tokens, but default design tuned for high-contrast daylight operations.

## Test Plan and Scenarios

## Backend tests
1. Vendor auth and membership resolution.
2. Store access control negative/positive cases across all service types.
3. Order action state machine by role and ownership.
4. Pharmacy prescription gating rules.
5. Catalog CRUD permissions and validation.
6. Chat participant authorization and message delivery.
7. Regression tests for customer/rider order flows.

## Mobile tests
1. Provider/unit tests for store switching and role permissions.
2. API contract tests using mocked responses for all vendor endpoints.
3. Widget tests for order actions, prescription review, catalog edit flows.
4. Integration tests for login, switch-store, accept-order, ready-order, chat send.

## Acceptance criteria
1. A single vendor user can manage multiple stores across multiple service types in one session.
2. Staff users can only perform actions allowed by assigned role.
3. Vendor cannot read or mutate orders/catalog outside their memberships.
4. Pharmacy required-prescription orders cannot proceed to preparation without vendor review.
5. Chat works in real time for order participants (customer, vendor, rider where applicable).
6. Push notifications reach vendor app for new orders and chat.
7. Android and iOS builds pass smoke tests and core flow tests.

## Rollout and Monitoring
- Feature flags: `vendor_app_enabled`, `vendor_chat_enabled`, `pharmacy_prescription_gate`.
- Soft launch with selected vendors, then expand by city/service.
- Dashboards: order acceptance latency, rejected-action rate, status transition failures, chat delivery success, API 5xx.
- Alerting thresholds on auth failures, permission denials spike, and order action error rates.

## Assumptions and Defaults
- Currency and market defaults remain current project defaults (GHS/Ghana) for Phase 1.
- No marketplace-level dynamic commission redesign in Phase 1.
- Existing customer and rider apps remain production-critical; vendor rollout must be backward-compatible.
- Store-table passwords are deprecated operationally; User-table auth is the source of truth after migration.
- All new vendor mutations are gated through membership-based authorization.
