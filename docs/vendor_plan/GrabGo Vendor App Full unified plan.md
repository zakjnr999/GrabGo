# GrabGo Vendor Mobile App — Full Unified Plan (Single Scope, No Phases)

## Summary
This is the complete end-to-end plan to build one vendor mobile app for all GrabGo services (food, grocery, pharmacy, grabmart), with unified vendor identity, multi-branch operations, staff roles, full operational tooling, growth tooling, finance tooling, onboarding, and integrations in one scope.

## Goal and Success Criteria
1. Vendors can run daily operations for any GrabGo service from one mobile app account.
2. Owners can manage multiple branches and staff permissions safely.
3. Orders can be processed with substitution handling, issue escalation, prescription checks, and full auditability.
4. Vendors can manage catalog, availability, store outage windows, promotions, scheduled orders, and settlement visibility.
5. Customer and rider experiences remain compatible with new vendor capabilities.
6. System is secure, role-gated, observable, and test-covered.

## Product Scope (Full)
1. Unified vendor authentication and session management.
2. Multi-branch and multi-service store switching.
3. Owner/staff role management (owner, manager, operator, cashier).
4. Live order queue with full lifecycle controls.
5. Pickup OTP verification flow.
6. Pharmacy prescription manual review flow.
7. Item substitution and partial fulfillment flow.
8. Vendor issue center and support escalation flow.
9. Store pause/outage controls with reason and auto-resume.
10. Full catalog and category management across service types.
11. Inventory and stock management with quick/bulk actions.
12. Vendor chat (order-linked) with customer/rider participants.
13. Home action inbox and analytics dashboards.
14. Promotions and campaign tools.
15. Scheduled/pre-order management.
16. Payout/settlement center and report export.
17. Printer/KDS integration.
18. Onboarding wizard, demo order training, and persistent checklist.
19. Audit timeline for all order and operator actions.
20. Notification center and vendor-specific push/socket events.

## UX and Page Architecture
1. Launch stack: `Splash`, `Sign In`, `Forgot Password`, `Session Recovery`.
2. Onboarding stack: `Welcome`, `Store Context`, `Permissions`, `Role Guide`, `Demo Order`, `Quick Actions`, `Completion`.
3. Main tabs: `Home`, `Orders`, `Catalog`, `Chats`, `More`.
4. Home pages: `Action Inbox`, `KPI Cards`, `Checklist`, `Alerts`.
5. Orders pages: `Unified Queue`, `Order Detail`, `Status Actions`, `Pickup OTP`, `Prescription Review`, `Item Change Proposal`, `Issue Report`, `Issue Timeline`, `Audit Timeline`.
6. Catalog pages: `Item List`, `Add Item`, `Edit Item`, `Stock Adjust`, `Availability Toggle`, `Category List`, `Category Editor`.
7. Chats pages: `Chat Inbox`, `Order Thread`, `Media/Attachment View`.
8. Operations pages: `Store State`, `Pause/Resume`, `Service Toggles`, `Prep/Delivery Settings`.
9. Staff pages: `Staff List`, `Invite Staff`, `Role/Status Edit`.
10. Analytics pages: `Overview`, `Orders Analytics`, `Item Analytics`, `Service Breakdown`, `SLA Performance`.
11. Growth pages: `Promotions`, `Campaign Builder`, `Promo Performance`.
12. Scheduling pages: `Scheduled Orders`, `Time Slot Capacity`, `Cutoff Rules`.
13. Finance pages: `Settlements`, `Payout History`, `Statements`, `Export Center`.
14. Integrations pages: `Printer Setup`, `KDS Setup`, `Test Print`.
15. Support pages: `Help`, `Escalations`, `Policy`, `Onboarding Replay`.

## Design System
1. Base brand color remains GrabGo orange `#FE6132`.
2. Service accents: food `#FE6132`, grocery `#4CAF50`, pharmacy `#009688`, grabmart `#9C27B0`.
3. Typography remains `Lato` for ecosystem consistency.
4. UI style is operations-first: dense, high-clarity, low-friction interactions.
5. Accessibility requirements: strong contrast, non-color status cues, readable state labels, large tap targets.
6. Motion requirements: meaningful and minimal transitions for state change clarity.

## Backend Architecture and Contracts

## Data Model Changes
1. Extend `UserRole` with `vendor`.
2. Add enums for `VendorStoreType`, `VendorStaffRole`, `MembershipStatus`, `PrescriptionReviewStatus`, `OrderIssueType`, `OrderIssueStatus`, `StorePauseReason`, `ItemChangeType`, `ItemChangeDecision`.
3. Add `VendorStoreMembership`.
4. Add `VendorInvite`.
5. Add `OrderPrescription`.
6. Add `OrderIssue`.
7. Add `StoreOutageWindow`.
8. Add `OrderItemChangeProposal`.
9. Add vendor onboarding progress state fields/table.
10. Extend `Order` with prescription and change-management status fields.

## Vendor API Namespace
1. Identity and context: `/api/vendor/me`, `/api/vendor/stores`.
2. Staff: `/api/vendor/staff`, `/api/vendor/staff/invite`, `/api/vendor/staff/:membershipId`.
3. Orders: `/api/vendor/orders`, `/api/vendor/orders/:orderId`, `/api/vendor/orders/:orderId/actions/*`.
4. Pickup verification: `/api/vendor/orders/:orderId/actions/verify-pickup-code`.
5. Prescription decision: `/api/vendor/orders/:orderId/actions/prescription-review`.
6. Item change flow: `/api/vendor/orders/:orderId/items/:orderItemId/*`.
7. Issue center: `/api/vendor/orders/:orderId/issues*`.
8. Audit trail: `/api/vendor/orders/:orderId/audit`.
9. Catalog items/categories: `/api/vendor/catalog/*`.
10. Store operations and outage: `/api/vendor/stores/:storeType/:storeId/*`.
11. Analytics: `/api/vendor/analytics/*`.
12. Promotions: `/api/vendor/promotions/*`.
13. Scheduling: `/api/vendor/scheduling/*`.
14. Settlements and exports: `/api/vendor/settlements/*`.
15. Integrations: `/api/vendor/integrations/printer/*`, `/api/vendor/integrations/kds/*`.
16. Onboarding: `/api/vendor/onboarding*`.

## Security and Authorization
1. JWT auth is `User`-table based only.
2. Every vendor mutation requires active store membership and role check.
3. Ownership enforcement across all order/catalog/store actions.
4. Action-level permission matrix enforced server-side and mirrored client-side.
5. Full audit event write on every critical mutation.

## Realtime and Notifications
1. Vendor joins role/store scoped socket rooms.
2. New events: `vendor_new_order`, `vendor_sla_risk`, `vendor_issue_update`, `vendor_substitution_response`, `vendor_pause_expiry`, `vendor_chat_message`.
3. Notification preferences and quiet-hour controls included.

## Customer and Rider Compatibility Changes
1. Customer app adds substitution approval/rejection experience.
2. Customer order timeline includes vendor issues, item changes, prescription status.
3. Rider app supports vendor-inclusive order thread and updated handover states.
4. Existing customer/rider order APIs remain backward-compatible while vendor APIs are added.

## Mobile Technical Architecture
1. Create `packages/grab_go_vendor`.
2. Use `provider` for state orchestration with domain providers.
3. Use `go_router` for route graph and guarded navigation.
4. Use `chopper` clients against `/api/vendor/*`.
5. Use shared services for cache, secure storage, push, socket, chat, and theming.
6. Maintain store-context singleton state used by every domain module.

## Order and Ops Rules (Business Logic Defaults)
1. Unified queue across all services with smart filters.
2. Prescription-required orders cannot proceed without vendor decision.
3. Substitution response timeout default is 5 minutes.
4. Pause/outage blocks new intake but does not block active-order processing.
5. Auto-resume supports predefined durations and custom timestamp.
6. Every reject/cancel/escalation requires reason code.

## Edge Cases and Failure Modes
1. Network loss during action mutation uses optimistic lock + retry guard.
2. Concurrent staff actions use version checks and conflict messaging.
3. Substitution timeout applies deterministic fallback policy.
4. Auto-resume with expired timer recovers from scheduler delay safely.
5. Chat message send retry and delivery state shown in UI.
6. Branch switch preserves tab state but refreshes scoped data atomically.

## Test Plan and Acceptance

## Backend test suites
1. Membership/role authorization matrix.
2. Order lifecycle transitions and forbidden transitions.
3. Prescription review gates.
4. Substitution and partial fulfillment correctness.
5. Issue lifecycle and escalation.
6. Pause/outage order intake behavior.
7. Audit completeness and integrity.
8. Settlement, scheduling, and promotion endpoint correctness.
9. Integration tests for vendor+customer+rider shared flows.

## Mobile test suites
1. Onboarding mandatory shell and checklist persistence.
2. Store switch consistency across modules.
3. Order action flow correctness per role.
4. Catalog CRUD and stock updates.
5. Substitution and issue center UX flows.
6. Pause/resume controls and status banners.
7. Chat and realtime event handling.
8. Finance, scheduling, and promotion screens data integrity.
9. Offline/reconnect behavior.

## Acceptance scenarios
1. Owner manages two branches across two service types in one session.
2. Cashier cannot access restricted owner settings.
3. Pharmacy order requires manual review before progress.
4. Substitution accepted by customer updates totals and status.
5. Issue escalated and resolved with timeline trace.
6. Store paused with auto-resume successfully.
7. Settlement and export views reflect backend data accurately.
8. Printer/KDS test signal succeeds and queues real orders.

## Rollout and Operations
1. Feature flags for all major domains even though full scope is included.
2. Pilot with selected vendors, then progressive expansion.
3. Observability dashboards for latency, failure rates, denial rates, and event delivery.
4. Alerting on auth failures, transition errors, substitution failures, outage misconfigurations.

## Implementation Sequence (Single Journey Order)
1. Schema and migration foundation.
2. Auth and membership middleware.
3. Vendor core APIs (orders, catalog, store ops, staff).
4. Substitution, issue center, prescription, outage logic.
5. Promotions, scheduling, settlements, integrations APIs.
6. Realtime and notification expansion.
7. OpenAPI update and API contract tests.
8. Vendor app shell and navigation.
9. Orders and catalog modules.
10. Chat, staff, store ops, onboarding modules.
11. Analytics, promotions, scheduling, finance, integrations modules.
12. Customer and rider compatibility work.
13. End-to-end QA, pilot release, production rollout.

## Assumptions and Defaults
1. Existing brand/theme foundation in shared package is reused.
2. Unified vendor identity becomes canonical and store-table passwords are not runtime auth source.
3. Currency/market defaults remain current project defaults unless explicitly changed.
4. ESC/POS-compatible printer integration is default for initial hardware support.
5. Scheduled order capacity defaults are configured per store and editable by owner/manager.
6. No unresolved product decisions remain for implementation start.
