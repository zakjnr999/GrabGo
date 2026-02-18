# UI/UX Addendum — Onboarding + Missing Design Essentials

## Summary
- Yes, we were missing onboarding, and it should be in Phase 1.
- I’m adding a guided first-run onboarding wizard plus a persistent completion checklist.
- I’m also adding core UX safeguards we should not ship without (empty/error states, permission recovery, role-gated UI, offline behavior, SLA urgency language).

## Critical Additions (Phase 1)
- `Onboarding Navigator` before main tabs.
- `Mandatory first-run shell` with skippable optional steps.
- `Interactive demo order` simulation in onboarding.
- `Persistent onboarding checklist` card on `Home` until all optional items are done.
- `Empty/zero/error state library` for Home, Orders, Catalog, Chats.
- `Permission recovery UX` for notifications/location with deep-link to settings.
- `Role-based action visibility` (owner/manager/operator/cashier) at component level.
- `Offline and reconnect UX` with queued intent and retry states.
- `Critical action confirmations` for reject/cancel/close-store operations.

## Onboarding Screen Flow
1. `Welcome`
- Brand intro, role-aware copy, estimated completion time.

2. `Store Context Setup`
- Select default branch/store and service context.
- Confirm switching behavior across multi-branch access.

3. `Permissions`
- Notification permission prompt.
- Optional location/background permissions if needed by role/use-case.
- “Do later” allowed; tracked in checklist.

4. `Role Quick Guide`
- Shows what this role can and cannot do.
- Explains order SLA badges and escalation cues.

5. `Interactive Demo Order`
- Simulated flow: accept -> preparing -> ready -> handover/pickup verification.
- No real backend order mutation.
- Completion tracked; step can be skipped and resumed later.

6. `Quick Actions Setup`
- Choose 3 pinned shortcuts for Home (for example: Accept Next, Mark Ready, Low Stock).

7. `Done + Checklist`
- Enters app at live Orders queue.
- Remaining optional items shown as checklist in Home.

## Navigation Update
- Launch stack: `Splash` -> `Auth` -> `Onboarding` -> `Main Tabs`.
- Main tabs remain: `Home`, `Orders`, `Catalog`, `Chats`, `More`.
- Re-entry path: `More > Help > Onboarding & Training`.

## Critical vs Non-Critical UX (Updated)
- Critical in P1: onboarding wizard, demo order, checklist, role guardrails, failure/empty states, permission recovery.
- Non-critical (P2): richer animation tutorials, gamified training, multi-language onboarding variants, advanced personalization of onboarding paths.

## Public Interfaces / Types to Add
- Backend fields (user-level):
  - `vendorOnboardingCompletedAt`
  - `vendorOnboardingSteps` (JSON progress map)
  - `vendorDemoOrderCompletedAt`
- Backend endpoints:
  - `GET /api/vendor/onboarding`
  - `PUT /api/vendor/onboarding`
  - `POST /api/vendor/onboarding/demo/complete`
- Frontend types:
  - `OnboardingStepId`
  - `OnboardingProgress`
  - `QuickActionPreset`
  - `DemoOrderState`

## Test Scenarios
1. First login always enters onboarding shell.
2. Optional onboarding steps can be skipped and resumed later.
3. Orders tab is default entry after onboarding completion.
4. Demo order does not touch real order APIs.
5. Checklist state persists across logout/login and device restart.
6. Staff role sees only permitted actions during onboarding and main app.
7. Permission denial path shows recovery prompt and app remains usable.
8. Offline during onboarding sync retries without blocking app entry.

## Assumptions and Defaults
- Onboarding is account-level (not device-only).
- Demo order is simulated locally; only completion state syncs to backend.
- Onboarding content is role-aware and service-aware but shares one flow shell.
