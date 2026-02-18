# GrabGo Vendor Plan Coverage Checklist

Last updated: 2026-02-18

Status legend:

- `DONE`: Implemented and wired.
- `PARTIAL`: Initial UI or flow exists, but core behavior is not complete.
- `NOT_STARTED`: Not implemented yet.
- `BACKEND_BLOCKED`: Requires backend work before frontend can be completed.

## Mobile App (P1 Critical Scope)

| Planned Item                                                | Status      | Current Evidence                                                            | Gap                                                                |
| ----------------------------------------------------------- | ----------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Splash                                                      | DONE        | `packages/grab_go_vendor/lib/core/view/splash_screen.dart`                  | No session-restore decision logic yet.                             |
| Sign In                                                     | DONE        | `packages/grab_go_vendor/lib/features/auth/view/login.dart`                 | Real API auth not connected yet.                                   |
| Forgot Password                                             | DONE        | `packages/grab_go_vendor/lib/features/auth/view/forgot_password.dart`       | Real API integration pending.                                      |
| Register + vendor documents                                 | DONE        | `packages/grab_go_vendor/lib/features/auth/view/register.dart`              | Backend submit endpoint pending.                                   |
| OTP verification (auth)                                     | DONE        | `packages/grab_go_vendor/lib/features/auth/view/otp_verification.dart`      | Backend verify/resend pending.                                     |
| Onboarding wizard                                           | PARTIAL     | `packages/grab_go_vendor/lib/features/onboarding/view/onboarding_main.dart` | 3-slide intro exists; full 7-step guided flow missing.             |
| Mandatory onboarding shell + skippable optional steps       | NOT_STARTED | —                                                                           | No persisted onboarding state or step gating yet.                  |
| Interactive demo order in onboarding                        | NOT_STARTED | —                                                                           | Not implemented.                                                   |
| Persistent onboarding checklist card                        | PARTIAL     | `packages/grab_go_vendor/lib/features/home/view/home_tab.dart`              | Static checklist only; no persisted progress.                      |
| Main shell with 5 tabs (Home, Orders, Catalog, Chats, More) | DONE        | `packages/grab_go_vendor/lib/shared/widgets/bottom_navigation.dart`         | —                                                                  |
| Post-login default = Orders queue                           | DONE        | `packages/grab_go_vendor/lib/shared/viewmodel/bottom_nav_provider.dart`     | —                                                                  |
| Global store switcher persistent in shell                   | PARTIAL     | Store chip only in `home_tab.dart`                                          | No shared store context provider or switcher control in app shell. |
| Home action inbox + KPIs                                    | PARTIAL     | `packages/grab_go_vendor/lib/features/home/view/home_tab.dart`              | Static data; no real feed, urgency sort, unresolved issues.        |
| Orders unified queue + smart filters                        | PARTIAL     | `packages/grab_go_vendor/lib/features/home/view/orders_tab.dart`            | Static list/chips only; no backend filters/state machine.          |
| Order detail                                                | NOT_STARTED | —                                                                           | Missing route/screen.                                              |
| Order action sheet (accept/reject/preparing/ready/handover) | NOT_STARTED | —                                                                           | Missing route/sheet + role/action guardrails.                      |
| Pickup OTP verification (order handover)                    | NOT_STARTED | —                                                                           | Auth OTP exists, pickup OTP flow does not.                         |
| Pharmacy prescription review                                | NOT_STARTED | —                                                                           | Missing screen + action path.                                      |
| Item substitution / partial fulfillment                     | NOT_STARTED | —                                                                           | Missing UI and state flow.                                         |
| Issue center (report, timeline, escalation)                 | NOT_STARTED | —                                                                           | Missing UI and state flow.                                         |
| Order audit timeline                                        | NOT_STARTED | —                                                                           | Missing screen and model mapping.                                  |
| Catalog list/search/filter                                  | PARTIAL     | `packages/grab_go_vendor/lib/features/home/view/catalog_tab.dart`           | Static demo data only.                                             |
| Catalog add/edit item                                       | NOT_STARTED | —                                                                           | Missing screens/forms/routes.                                      |
| Stock adjust                                                | NOT_STARTED | —                                                                           | Missing screen/workflow.                                           |
| Availability toggle                                         | NOT_STARTED | —                                                                           | Missing workflow.                                                  |
| Category management                                         | NOT_STARTED | —                                                                           | Missing screens.                                                   |
| Chat inbox                                                  | PARTIAL     | `packages/grab_go_vendor/lib/features/home/view/chats_tab.dart`             | Static demo threads only.                                          |
| Chat thread (order-linked realtime)                         | NOT_STARTED | —                                                                           | Missing thread route + websocket wiring.                           |
| More hub                                                    | PARTIAL     | `packages/grab_go_vendor/lib/features/home/view/more_tab.dart`              | Static menu only.                                                  |
| Store operations (open/close/accepting orders)              | NOT_STARTED | —                                                                           | Missing screen/controls.                                           |
| Outage pause/resume + reason + auto-resume                  | NOT_STARTED | —                                                                           | Missing screen/flow/banner.                                        |
| Staff list + invite/manage                                  | NOT_STARTED | —                                                                           | Missing screens and permission matrix UI.                          |
| Profile & security                                          | NOT_STARTED | —                                                                           | Missing screens.                                                   |
| Basic analytics                                             | NOT_STARTED | —                                                                           | Missing screen/charts.                                             |
| Notification settings                                       | NOT_STARTED | —                                                                           | Missing screen.                                                    |
| Help + onboarding replay                                    | NOT_STARTED | —                                                                           | Missing screen/entry point.                                        |
| Empty/zero/error state library                              | NOT_STARTED | —                                                                           | Not standardized across tabs/modules.                              |
| Permission recovery UX                                      | NOT_STARTED | —                                                                           | Missing deep-link settings UX.                                     |
| Role-based action visibility                                | NOT_STARTED | —                                                                           | Permission matrix not wired in UI.                                 |
| Offline/reconnect UX + queued actions                       | NOT_STARTED | —                                                                           | Missing connectivity banner and action queue.                      |
| Critical action confirmations                               | NOT_STARTED | —                                                                           | No confirm dialogs for reject/cancel/close-store yet.              |

## Backend (Required for Vendor Plan)

| Planned Item                                                              | Status      | Current Evidence                                                        | Gap                                                 |
| ------------------------------------------------------------------------- | ----------- | ----------------------------------------------------------------------- | --------------------------------------------------- |
| `UserRole.vendor` in Prisma                                               | NOT_STARTED | `backend/prisma/schema.prisma` has `customer, restaurant, rider, admin` | Add role and migrate.                               |
| Vendor membership models/enums (`VendorStoreMembership`, roles, statuses) | NOT_STARTED | Not present in Prisma schema                                            | Add schema + migration + seed path.                 |
| Vendor namespace APIs `/api/vendor/*`                                     | NOT_STARTED | No `backend/routes/vendor*.js`                                          | Create vendor route modules and mount in app.       |
| Vendor auth/membership middleware                                         | NOT_STARTED | No `requireVendorAuth` / membership middleware                          | Implement middleware and endpoint enforcement.      |
| Vendor order action endpoints                                             | NOT_STARTED | Only generic order routes exist                                         | Add vendor-owned order action endpoints and checks. |
| Prescription review endpoint                                              | NOT_STARTED | No `/api/vendor/orders/:id/actions/prescription-review`                 | Implement and gate transitions.                     |
| Substitution/partial fulfillment endpoints                                | NOT_STARTED | Not found                                                               | Implement flow and timeout policy.                  |
| Issue center endpoints                                                    | NOT_STARTED | Not found                                                               | Add create/list/update issue APIs.                  |
| Order audit endpoint for vendor                                           | NOT_STARTED | Not found in vendor namespace                                           | Add `/api/vendor/orders/:id/audit`.                 |
| Vendor catalog CRUD namespace                                             | NOT_STARTED | No `/api/vendor/catalog/*`                                              | Implement service-aware CRUD with ownership checks. |
| Store outage/pause endpoints                                              | NOT_STARTED | No `/api/vendor/stores/*/pause-status` etc.                             | Implement with reason and auto-resume support.      |
| Vendor onboarding state endpoints                                         | NOT_STARTED | No `/api/vendor/onboarding*`                                            | Add onboarding progress persistence APIs.           |
| Vendor socket/push event set                                              | NOT_STARTED | No vendor event names found                                             | Add channels/events and notification mapping.       |
| Chat participant extension for vendor                                     | PARTIAL     | Existing chat routes/models are customer/rider oriented                 | Extend participant model + authorization.           |

## Cross-App Compatibility Items

| Planned Item                                                            | Status      | Gap                                             |
| ----------------------------------------------------------------------- | ----------- | ----------------------------------------------- |
| Customer substitution approve/reject UX                                 | NOT_STARTED | Needed for vendor substitution flow completion. |
| Customer timeline includes prescription/item-change/vendor-issue events | NOT_STARTED | No compatibility additions yet.                 |
| Rider vendor-inclusive order thread updates                             | NOT_STARTED | No compatibility updates yet.                   |

## Phase 2 Items (Intentionally Deferred)

These are intentionally deferred and do not block current P1 delivery:

- Promotions/campaign tools
- Advanced analytics
- Settlements/payout exports
- Scheduled/pre-orders
- Printer/KDS integrations
- Automation rules
