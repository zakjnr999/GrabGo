# Parcel API Contract (MVP)

This document freezes the Parcel backend API contract used by frontend clients.

## Base

- Base route: `/api/parcel`
- Auth: Bearer JWT required for all routes except `GET /config`
- Currency: `GHS`

## Response Envelope

### Success

```json
{
  "success": true,
  "message": "Human readable message",
  "data": {}
}
```

### Error

```json
{
  "success": false,
  "message": "Error summary",
  "code": "MACHINE_READABLE_CODE",
  "errors": [
    { "field": "field.path", "message": "Validation message" }
  ]
}
```

## Policy & Payment Contract

- Insurance is disabled in MVP (`insuranceEnabled=false`).
- Liability is capped by:
  - `declaredValueGhs`
  - configured cap (`maxDeclaredValueGhs` / `liabilityCapGhs`)
- Frontend should display liability disclaimer and terms acceptance before order creation.

### Payment Method Input Contract

- Accepted API request values:
  - `card`
  - `paystack`
  - legacy alias: `online`
- Canonical API meaning:
  - `card` => prepaid card flow
  - `paystack` => online provider flow
- Storage mapping (internal Prisma enum compatibility):
  - `card` -> `card`
  - `paystack` / `online` -> `online`

### Production Config Keys

- `PARCEL_MAX_DECLARED_VALUE_GHS` (primary)
- `MAX_DECLARED_VALUE` (fallback alias; used only when parcel-specific key is not set)
- `PARCEL_LIABILITY_CAP_GHS`
- `PARCEL_LIABILITY_FORMULA`
- `PARCEL_LIABILITY_DISCLAIMER`
- `PARCEL_TERMS_VERSION`
- `PARCEL_ONLINE_PAYMENT_PROVIDER` (MVP supports `paystack`)
- `PARCEL_RETURN_FEE_ENABLED`

## Endpoints

### `GET /config`

Returns parcel feature and policy metadata:

- `enabled`
- `scheduledEnabled`
- `returnToSenderEnabled`
- `insuranceEnabled`
- `noInsuranceEnabled`
- `maxDeclaredValueGhs`
- `liabilityCapGhs`
- `liabilityFormula`
- `liabilityDisclaimer`
- `termsVersion`
- `scheduleToleranceMinutes`
- `paymentMethods`:
  - `apiAccepted`
  - `acceptedInputValues`
  - `storageValues`
  - `aliases`
  - `onlinePaymentProvider`

### `POST /quote`

Input (minimum required):

- `pickup` (address + coordinates + contact)
- `dropoff` (address + coordinates + contact)
- `declaredValueGhs` (or `declaredValue`)
- `weightKg`
- `sizeTier`
- `paymentMethod` (`card` | `paystack` | `online`)

Returns:

- `quote` (distance, ETA, subtotal, fees, tax, total, breakdown)
- `returnPolicy` (return fee estimate and breakdown)
- `riderEarnings` (original trip, return trip, total potential)
- `policy` (liability + insurance + terms + payment method contract)

### `POST /orders`

Additional required fields:

- `acceptParcelTerms=true`
- `prohibitedItemsAccepted=true`
- valid `termsVersion` matching config

Returns created parcel order record.

### `GET /orders`

Query:

- `limit` (default 30, max 100)
- `cursor` (optional pagination cursor)

Returns parcel order list scoped by role.

### `GET /orders/:parcelId`

Returns parcel order details with latest events.

### `POST /orders/:parcelId/paystack/initialize`

Initializes payment for parcel order and returns:

- `authorizationUrl`
- `reference`
- `accessCode`
- `paymentAmount`

### `POST /orders/:parcelId/confirm-payment`

Optional body:

- `reference`
- `provider` (must match configured online provider; default `paystack`)

Returns payment confirmation status.

### `POST /orders/:parcelId/cancel`

Body:

- `reason` (optional)

Cancels parcel only from allowed pre-dispatch states.

### `POST /orders/:parcelId/delivery-code/resend`

Resends recipient delivery verification code with cooldown limits.

### `POST /orders/:parcelId/return-to-sender`

Rider-only route. Initiates return flow and computes:

- `returnChargeAmount`
- `returnTripFee`
- `returnTripEarning`
- `totalRiderEarning = originalTripEarning + returnTripEarning`

### `POST /orders/:parcelId/confirm-returned`

Rider-only route. Confirms terminal `returned_to_sender` state.
