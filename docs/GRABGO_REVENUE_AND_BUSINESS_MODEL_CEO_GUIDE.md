# GrabGo Revenue & Business Model

## CEO Complete Guide — How GrabGo Earns Income

> **Document Version:** 2.0 — March 5, 2026
> **Audience:** CEO, C-Suite, Investors, Operations Leadership
> **Scope:** Every revenue stream, cost center, and growth opportunity in the GrabGo platform
>
> **v2.0 Changes:** Vendor commission system now fully implemented. Per-vendor configurable commission rates, vendor wallet, automatic settlement on delivery, full audit trail.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Revenue Streams — Where the Money Comes From](#2-revenue-streams--where-the-money-comes-from)
   - [A. Customer-Facing Fees (Per-Order)](#a-customer-facing-fees-per-order)
   - [B. Rider Platform Commission (Per-Delivery)](#b-rider-platform-commission-per-delivery)
   - [C. Parcel Delivery Revenue](#c-parcel-delivery-revenue)
   - [D. Rider Financial Services](#d-rider-financial-services)
   - [E. Vendor Commission System (NEW v2)](#e-vendor-commission-system-new-v2)
3. [Complete Money Flow — Per Order](#3-complete-money-flow--per-order)
4. [Revenue Projections & Unit Economics](#4-revenue-projections--unit-economics)
5. [Cost Centers — Where the Money Goes](#5-cost-centers--where-the-money-goes)
6. [The Delivery Fee Explained](#6-the-delivery-fee-explained)
7. [The Rider Earnings Explained](#7-the-rider-earnings-explained)
8. [Parcel Delivery — A Second Revenue Engine](#8-parcel-delivery--a-second-revenue-engine)
9. [Payment Infrastructure](#9-payment-infrastructure)
10. [Customer Acquisition Tools](#10-customer-acquisition-tools)
11. [Untapped Revenue Opportunities](#11-untapped-revenue-opportunities)
12. [Revenue Levers — What You Can Tune](#12-revenue-levers--what-you-can-tune)
13. [Competitive Positioning](#13-competitive-positioning)
14. [Risk Factors](#14-risk-factors)
15. [Strategic Roadmap](#15-strategic-roadmap)
16. [Complete Configuration Reference](#16-complete-configuration-reference)

---

## 1. Executive Summary

GrabGo is a multi-vertical delivery platform (food, groceries, pharmacy, general retail, parcels) that earns income through **six active revenue streams** and has infrastructure for **three additional untapped streams**.

### Revenue at a Glance

| #   | Revenue Stream               | Type                        | Status                  | Revenue Per Unit        |
| --- | ---------------------------- | --------------------------- | ----------------------- | ----------------------- |
| 1   | **Rider commission**         | 15% of every delivery       | ✅ Active               | ~GHS 2.25/delivery      |
| 2   | **Customer delivery fee**    | Vendor base + distance rate | ✅ Active               | GHS 5–20/order          |
| 3   | **Customer service fee**     | % of order subtotal         | ✅ Configurable         | Depends on rate set     |
| 4   | **Tax collection**           | % of subtotal               | ✅ Configurable         | Depends on rate set     |
| 5   | **Rain surge fee**           | Flat fee during rain        | ⚙️ Ready                | Configurable per event  |
| 6   | **Parcel fees**              | Multi-factor pricing        | ✅ Active               | GHS 10–30/parcel        |
| 7   | **Withdrawal fees**          | GHS 1–2 per instant cashout | ✅ Active               | GHS 1–2/withdrawal      |
| 8   | **Loan interest**            | 3–8% on cash advances       | ✅ Active               | GHS 1.50–80/loan        |
| 9   | **Vendor featured listings** | Manual promotion            | 🏗️ Built, not monetized |                         |
| 10  | **Vendor commission**        | % of food sales             | ✅ **Implemented (v2)** | Configurable per vendor |

### The Core Business Model (Simple Version)

1. **Customer** orders food → pays **subtotal + delivery fee + service fee + tax**
2. **Vendor** prepares food → pays **commission** on the subtotal (configurable per vendor, default 0%)
3. **Rider** delivers food → earns (GHS 5 base + GHS 2/km + tip) × 85%
4. **GrabGo keeps** → vendor commission + 15% rider commission + delivery fee margin + service fee + tax

---

## 2. Revenue Streams — Where the Money Comes From

### A. Customer-Facing Fees (Per-Order)

Every order a customer places generates up to **four fee components** for GrabGo:

#### 1. Delivery Fee

The customer pays a delivery fee composed of:

$$\text{deliveryFee} = \text{Vendor Base Fee} + (\text{Distance in km} \times \text{Rate per km})$$

Then clamped between a minimum and maximum:

$$\text{deliveryFee} = \text{clamp}(\text{deliveryFee},\ \text{MIN},\ \text{MAX})$$

| Parameter             | Env Variable               | Default                     |
| --------------------- | -------------------------- | --------------------------- |
| Vendor base fee       | Per-vendor in database     | Varies                      |
| Distance rate         | `DELIVERY_FEE_PER_KM`      | GHS 0 (needs configuration) |
| Minimum fee           | `DELIVERY_FEE_MIN`         | GHS 0 (needs configuration) |
| Maximum fee           | `DELIVERY_FEE_MAX`         | GHS 0 (needs configuration) |
| Max delivery distance | `DELIVERY_MAX_DISTANCE_KM` | 50 km                       |

> ⚠️ **CEO Action Required:** These defaults are set to 0, meaning they need to be configured in your environment variables before launch. See [§12 Revenue Levers](#12-revenue-levers--what-you-can-tune) for recommended values.

#### 2. Service Fee

A percentage of the order subtotal (food cost) charged to the customer:

$$\text{serviceFee} = \text{clamp}(\text{subtotal} \times \text{SERVICE\_FEE\_RATE},\ \text{MIN},\ \text{MAX})$$

| Parameter           | Env Variable       | Default                 |
| ------------------- | ------------------ | ----------------------- |
| Service fee rate    | `SERVICE_FEE_RATE` | 0 (needs configuration) |
| Minimum service fee | `SERVICE_FEE_MIN`  | GHS 0                   |
| Maximum service fee | `SERVICE_FEE_MAX`  | GHS 0                   |

**This is 100% GrabGo revenue.** None of it goes to the rider or vendor.

> **Industry benchmark:** Most delivery platforms charge 5–15% service fee. I recommend starting at **5%** with a min of GHS 1.00 and max of GHS 10.00.

#### 3. Tax

$$\text{tax} = \text{subtotal} \times \text{TAX\_RATE}$$

| Parameter | Env Variable | Default |
| --------- | ------------ | ------- |
| Tax rate  | `TAX_RATE`   | 0       |

> **Note:** Ghana's standard VAT is 15% (12.5% VAT + 2.5% NHIL). Consult your tax advisor on applicability to delivery platform services.

#### 4. Rain Surge Fee

A flat surcharge added during rainy weather, detected automatically via the **Tomorrow.io weather API**:

| Parameter            | Env Variable                 | Default |
| -------------------- | ---------------------------- | ------- |
| Rain surge enabled   | `RAIN_SURGE_ENABLED`         | false   |
| Surge amount         | `RAIN_SURGE_FEE`             | GHS 0   |
| Min rain intensity   | `RAIN_INTENSITY_THRESHOLD`   | 0       |
| Min rain probability | `RAIN_PROBABILITY_THRESHOLD` | 0       |

**How it works:** When a customer places an order, the system checks the weather at the vendor's location. If rain intensity or probability exceeds the threshold, the flat surge fee is added. This compensates riders for riding in rain and keeps supply available during bad weather.

> **Recommended:** Enable with GHS 2.00–3.00 surge fee to ensure riders stay online during rain.

#### Complete Customer Order Total

$$\text{total} = \text{subtotal} + \text{deliveryFee} + \text{serviceFee} + \text{tax} + \text{rainFee} - \text{creditsApplied}$$

---

### B. Rider Platform Commission (Per-Delivery)

**This is GrabGo's single largest and most reliable revenue stream.**

For every delivery completed, rider earnings are calculated as:

| Component                   | Value           | Example (5 km, no tip) |
| --------------------------- | --------------- | ---------------------- |
| Base fee                    | GHS 5.00        | GHS 5.00               |
| Distance fee                | GHS 2.00 per km | GHS 10.00              |
| Tip                         | 100% to rider   | GHS 0.00               |
| **Gross earnings**          |                 | **GHS 15.00**          |
| **GrabGo commission (15%)** |                 | **GHS 2.25**           |
| **Rider receives (85%)**    |                 | **GHS 12.75**          |

#### What GrabGo Keeps

| Source                         | Amount         | Frequency      |
| ------------------------------ | -------------- | -------------- |
| 15% of (base + distance + tip) | ~GHS 1.50–5.00 | Every delivery |

#### More Examples

| Delivery Distance | Tip    | Gross     | GrabGo Keeps (15%) | Rider Gets (85%) |
| ----------------- | ------ | --------- | ------------------ | ---------------- |
| 2 km              | GHS 0  | GHS 9.00  | **GHS 1.35**       | GHS 7.65         |
| 5 km              | GHS 0  | GHS 15.00 | **GHS 2.25**       | GHS 12.75        |
| 10 km             | GHS 0  | GHS 25.00 | **GHS 3.75**       | GHS 21.25        |
| 5 km              | GHS 5  | GHS 20.00 | **GHS 3.00**       | GHS 17.00        |
| 10 km             | GHS 10 | GHS 35.00 | **GHS 5.25**       | GHS 29.75        |

> **Note:** The rider commission constants (GHS 5.00 base, GHS 2.00/km, 15%) are currently hardcoded. Parcel delivery equivalents are environment-variable configurable. I recommend making food delivery constants configurable too for flexibility.

---

### C. Parcel Delivery Revenue

GrabGo's parcel system is a **separate, fully configurable revenue engine** with richer pricing:

#### Customer-Facing Parcel Pricing

$$\text{parcelSubtotal} = \text{baseFee} + (\text{km} \times \text{feePerKm}) + (\text{minutes} \times \text{feePerMin}) + \text{sizeSurcharge} + (\text{weightKg} \times \text{weightFee})$$
$$\text{parcelTotal} = \text{parcelSubtotal} + \text{serviceFee} + \text{tax} + \text{rainFee}$$

| Component        | Env Variable                   | Default     |
| ---------------- | ------------------------------ | ----------- |
| Base fee         | `PARCEL_BASE_FEE_GHS`          | GHS 8.00    |
| Per-km fee       | `PARCEL_FEE_PER_KM_GHS`        | GHS 2.20    |
| Per-minute fee   | `PARCEL_FEE_PER_MIN_GHS`       | GHS 0.15    |
| Service fee rate | `PARCEL_SERVICE_FEE_RATE`      | 3%          |
| Tax rate         | `PARCEL_TAX_RATE`              | 0%          |
| Weight fee       | `PARCEL_WEIGHT_FEE_PER_KG_GHS` | GHS 0.25/kg |

#### Parcel Size Surcharges

| Size                        | Surcharge |
| --------------------------- | --------- |
| Small (fits in hand)        | GHS 0     |
| Medium (backpack)           | GHS 2.00  |
| Large (needs both hands)    | GHS 5.00  |
| XLarge (needs vehicle rack) | GHS 8.00  |

#### Parcel Return-to-Sender Fees

If a recipient refuses delivery, the sender can be charged for the return trip:

| Component          | Env Variable                    | Default  |
| ------------------ | ------------------------------- | -------- |
| Return fee enabled | `PARCEL_RETURN_FEE_ENABLED`     | false    |
| Return base fee    | `PARCEL_RETURN_BASE_FEE_GHS`    | GHS 5.00 |
| Return per-km      | `PARCEL_RETURN_FEE_PER_KM_GHS`  | GHS 1.70 |
| Return per-min     | `PARCEL_RETURN_FEE_PER_MIN_GHS` | GHS 0.10 |

#### Parcel Rider Commission

Same 15% model as food delivery:

| Component           | Env Variable                      | Default  |
| ------------------- | --------------------------------- | -------- |
| Rider base fee      | `PARCEL_RIDER_BASE_FEE_GHS`       | GHS 5.00 |
| Rider per-km rate   | `PARCEL_RIDER_FEE_PER_KM_GHS`     | GHS 2.00 |
| Platform commission | `PARCEL_PLATFORM_COMMISSION_RATE` | 15%      |

#### Parcel Constraints

| Parameter          | Value               |
| ------------------ | ------------------- |
| Max declared value | GHS 500             |
| Liability cap      | GHS 500             |
| Max weight         | 30 kg               |
| Max dimension      | 200 cm              |
| Insurance          | Not available (MVP) |

#### Example Parcel Delivery — 8 km, Medium, 3 kg, 25 minutes

**Customer pays:**

- Subtotal = GHS 8.00 + (8 × 2.20) + (25 × 0.15) + 2.00 + (3 × 0.25) = GHS 32.10
- Service fee = GHS 32.10 × 3% = GHS 0.96
- **Total = GHS 33.06**

**Rider earns:**

- Gross = GHS 5.00 + (8 × 2.00) = GHS 21.00
- Commission = GHS 21.00 × 15% = GHS 3.15
- **Rider gets = GHS 17.85**

**GrabGo keeps:**

- Platform commission: GHS 3.15
- Service fee: GHS 0.96
- Pricing delta (customer subtotal − rider gross): GHS 32.10 − 21.00 = GHS 11.10
- **Total GrabGo revenue from this parcel: GHS 15.21**

> **Key insight:** Parcel deliveries are more profitable per-delivery than food orders because the customer pricing is multi-factor (distance + time + weight + size) while rider earnings are only distance-based. The gap widens on heavier, larger parcels.

---

### D. Rider Financial Services

#### Withdrawal Fees

| Partner Level | Free Withdrawals/Week | Fee After Free Quota |
| ------------- | --------------------- | -------------------- |
| L1 (Bronze)   | 0                     | GHS 2.00             |
| L2 (Silver)   | 1                     | GHS 2.00             |
| L3 (Gold)     | 3                     | GHS 1.50             |
| L4 (Platinum) | 5                     | GHS 1.00             |
| L5 (Diamond)  | Unlimited             | GHS 0.00             |

**Minimum withdrawal amount:** GHS 5.00

**Projected monthly revenue (conservative):**

- 500 riders, 60% at L1–L2, avg 2 withdrawals/week each
- 300 × 2 × GHS 2.00 × 4 weeks = **GHS 4,800/month**

#### Loan Interest

| Level | Max Loan  | Interest Rate | Example Interest Revenue |
| ----- | --------- | ------------- | ------------------------ |
| L2    | GHS 300   | 8%            | GHS 24.00 per loan       |
| L3    | GHS 500   | 6%            | GHS 30.00 per loan       |
| L4    | GHS 800   | 5%            | GHS 40.00 per loan       |
| L5    | GHS 1,000 | 3%            | GHS 30.00 per loan       |

**Minimum loan:** GHS 50 | **Terms:** 7, 14, or 30 days | **Max active loans:** 1 per rider

**Repayment:** Automatic daily deductions from wallet at 04:00 AM. If wallet balance is insufficient, deduction is partial or skipped — no negative balances.

**Projected monthly revenue (conservative):**

- 100 loans/month at avg GHS 31 interest = **GHS 3,100/month**

**Risk mitigation:** Only riders with 20+ deliveries and 3.5★+ rating qualify. L4/L5 riders are auto-approved. L2/L3 require manual approval.

---

### E. Vendor Commission System (NEW v2)

**✅ Now fully implemented.** GrabGo charges vendors a configurable commission on every completed order's food/item subtotal.

#### How It Works

1. **Each vendor has a `commissionRate` field** (e.g., 0.15 = 15%). Default is 0% (no commission).
2. **When an order is delivered**, the settlement system automatically:
   - Calculates commission: `vendorCommission = subtotal × commissionRate`
   - Calculates payout: `vendorPayout = subtotal − vendorCommission`
   - Records the commission and payout on the Order record
   - Credits the **VendorWallet** with the payout amount
   - Creates audit trail transactions (sale + commission deduction)
3. **The vendor sees their net payout** in their wallet — the commission is deducted transparently.

#### Per-Vendor Configuration

Each vendor type (Restaurant, GroceryStore, PharmacyStore, GrabMartStore) has its own `commissionRate` field. This means you can:

| Strategy                              | How to Set It                                                                       |
| ------------------------------------- | ----------------------------------------------------------------------------------- |
| **0% for all** (launch)               | Default — no changes needed                                                         |
| **10% for all vendors**               | Set `commissionRate = 0.10` on each vendor                                          |
| **8% for GrabGo Exclusive**           | Lower rate for vendors with `isGrabGoExclusive = true`                              |
| **15% standard, 10% for high-volume** | Set per-vendor based on their order volume                                          |
| **Global default override**           | Set `VENDOR_COMMISSION_RATE` env var (applies to vendors with `commissionRate = 0`) |

#### Example: GHS 50 Order at 15% Commission

| Line Item                     | Amount                    |
| ----------------------------- | ------------------------- |
| Customer pays (food subtotal) | GHS 50.00                 |
| Vendor commission (15%)       | −GHS 7.50 → GrabGo        |
| Vendor payout                 | GHS 42.50 → Vendor Wallet |

#### Vendor Wallet System

Every vendor gets a **VendorWallet** (created automatically on first order settlement):

| Field              | Purpose                                  |
| ------------------ | ---------------------------------------- |
| `balance`          | Current withdrawable balance             |
| `totalEarnings`    | Lifetime gross sales (before commission) |
| `totalCommission`  | Lifetime commission paid to GrabGo       |
| `totalWithdrawals` | Lifetime withdrawn amount                |

All transactions are recorded in the **VendorTransaction** table with types: `sale`, `commission`, `payout`, `adjustment`.

#### Safety Features

| Feature                   | What It Prevents                                                                                                                 |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| **Idempotent settlement** | Same order can't credit vendor wallet twice                                                                                      |
| **Atomic transaction**    | Commission + wallet credit happen inside one Prisma `$transaction`                                                               |
| **Rate locked on order**  | The `vendorCommissionRate` is stored on the Order at settlement time — changing a vendor's rate later doesn't affect past orders |
| **Audit trail**           | Every sale and commission deduction is a separate `VendorTransaction` record                                                     |

#### Additional Vendor Features (Also Available)

| Feature                    | Database Fields                               | Status   |
| -------------------------- | --------------------------------------------- | -------- |
| **Featured listings**      | `featured`, `featuredUntil`                   | ✅ Built |
| **Exclusive partnerships** | `isGrabGoExclusive`, `isGrabGoExclusiveUntil` | ✅ Built |
| **Priority ranking**       | `priorityScore`                               | ✅ Built |
| **Promotional banners**    | Full `PromotionalBanner` model                | ✅ Built |

---

## 3. Complete Money Flow — Per Order

### Example: Customer orders GHS 50 of food, 5 km delivery, no tip, no rain, no promo

Assuming configured rates: 5% service fee, delivery fee = vendor's GHS 3 base + 5 km × GHS 1/km = GHS 8

```
CUSTOMER PAYS:
├── Food subtotal                 GHS  50.00  → To Vendor (minus commission)
├── Delivery fee                  GHS   8.00  → To GrabGo (partially offsets rider payout)
├── Service fee (5%)              GHS   2.50  → 100% to GrabGo
├── Tax (if applicable)           GHS   0.00  → Passed through to government
└── TOTAL                         GHS  60.50

VENDOR SETTLEMENT (automatic on delivery):
├── Subtotal                      GHS  50.00
├── Commission (15%)             -GHS   7.50  → To GrabGo
└── VENDOR PAYOUT                 GHS  42.50  → Vendor Wallet

RIDER EARNS (separate calculation):
├── Base fee                      GHS   5.00
├── Distance (5 km × GHS 2)      GHS  10.00
├── Tip                           GHS   0.00
├── GROSS                         GHS  15.00
├── GrabGo commission (15%)      -GHS   2.25  → To GrabGo
└── NET TO RIDER                  GHS  12.75

GRABGO'S TOTAL REVENUE FROM THIS ORDER:
├── Vendor commission (15%)       GHS   7.50  ← NEW in v2
├── Rider commission (15%)        GHS   2.25
├── Service fee                   GHS   2.50
├── Delivery fee margin           GHS   8.00 - 12.75 = -GHS 4.75 (offset by above)
├── Tax retained                  GHS   0.00
└── NET GRABGO REVENUE            GHS   7.50 ✅ Profitable!
```

### The Vendor Commission Changes Everything

With the **v2 vendor commission system** now implemented, every order is profitable. The delivery fee gap (rider earns more than customer pays for delivery) is covered by the vendor commission + service fee.

**Sensitivity to commission rate:**

| Vendor Commission Rate | GrabGo Revenue (on GHS 50 order) | Status         |
| ---------------------- | -------------------------------- | -------------- |
| 0% (launch)            | GHS 0.00                         | ⚠️ Breakeven   |
| 10%                    | GHS 5.00                         | ✅ Profitable  |
| 15%                    | GHS 7.50                         | ✅ Strong      |
| 20%                    | GHS 10.00                        | ✅ Very strong |

> **CEO Action:** Commission rate is configurable per vendor. Set `VENDOR_COMMISSION_RATE` env var for the global default, or set `commissionRate` on individual vendors in the database. Start at 0% for launch, raise to 10–15% by month 3.

---

## 4. Revenue Projections & Unit Economics

### Scenario: 500 Daily Orders, 200 Active Riders

#### Per-Order Revenue Breakdown (Assuming Configured Rates)

| Revenue Source            | Per Order | Daily (×500) | Monthly (×15,000) |
| ------------------------- | --------- | ------------ | ----------------- |
| Rider commission (15%)    | GHS 2.25  | GHS 1,125    | **GHS 33,750**    |
| Service fee (5%)          | GHS 2.50  | GHS 1,250    | **GHS 37,500**    |
| Delivery fee margin (avg) | GHS 1.00  | GHS 500      | **GHS 15,000**    |
| **Subtotal (per-order)**  |           |              | **GHS 86,250**    |

#### Non-Order Revenue

| Revenue Source             | Monthly Estimate |
| -------------------------- | ---------------- |
| Withdrawal fees            | GHS 4,800        |
| Loan interest              | GHS 3,100        |
| Parcel deliveries (50/day) | GHS 22,500       |
| **Subtotal (non-order)**   | **GHS 30,400**   |

#### Cost Centers

| Cost                                | Monthly Estimate                            |
| ----------------------------------- | ------------------------------------------- |
| Incentive payouts (budget cap)      | −GHS 80,000 (max, likely GHS 30,000–50,000) |
| Welcome credits (new users)         | −GHS 2,500 (500 new users × GHS 5)          |
| Referral rewards                    | −GHS 5,000 (500 referrals × GHS 10)         |
| Server/infrastructure               | −GHS 2,000                                  |
| Payment processing (Paystack ~1.5%) | −GHS 13,500                                 |
| **Total costs**                     | **~GHS 53,000–103,000**                     |

#### Net Revenue Estimate

| Scenario                            | Monthly Net |
| ----------------------------------- | ----------- |
| Conservative (high incentive spend) | GHS 13,650  |
| Moderate                            | GHS 43,650  |
| With 15% vendor commission added    | GHS 156,150 |

> **The path to profitability is clear: vendor commission + controlled incentive spend.**

---

## 5. Cost Centers — Where the Money Goes

### 5.1 Rider Incentive System (Controllable)

The incentive system is the largest cost center, but it's fully budget-capped:

| Budget Window | Cap        | Controls                        |
| ------------- | ---------- | ------------------------------- |
| Daily         | GHS 5,000  | Max daily incentive approvals   |
| Weekly        | GHS 25,000 | Max weekly incentive approvals  |
| Monthly       | GHS 80,000 | Max monthly incentive approvals |

**What these pay for:**

- Quest rewards (daily/weekly delivery challenges)
- Streak bonuses (consecutive day rewards)
- Milestone badges (lifetime achievement one-time payouts)
- Peak hour bonuses (% bonus during rush hours)

All amounts are multiplied by the rider's partner level multiplier (1.0×–1.6×).

> **Start with GHS 1,000/day cap and increase based on ROI.** The system queues excess incentives as "pending" — they aren't lost, just delayed.

### 5.2 Customer Acquisition (Controllable)

| Instrument                 | Cost Per Use                      | Notes                                              |
| -------------------------- | --------------------------------- | -------------------------------------------------- |
| Welcome credits            | GHS 5.00 per new user             | Applied to first order                             |
| Referral reward (referrer) | GHS 10.00 per successful referral | Paid when referee completes first order of GHS 20+ |
| Referral milestone bonus   | GHS 5.00 per 5 referrals          | Extra bonus for active referrers                   |
| Promo codes                | Variable                          | Percentage, fixed, or free delivery discounts      |

**Referral credits expire in 90 days** — unclaimed credits are never paid out.

### 5.3 Payment Processing (Fixed)

**Paystack** is the payment gateway. Standard Paystack pricing in Ghana:

- Local cards: 1.95% (capped at GHS 100)
- Mobile money: 1% (uncapped)
- International cards: 3.9% + GHS 1

This is a pass-through cost that scales with order volume.

### 5.4 Infrastructure (Fixed)

Server hosting, database, Redis cache, weather API, CDN — relatively small fixed costs that scale slowly.

---

## 6. The Delivery Fee Explained

### Two Separate Calculations — This Is Critical to Understand

**The customer delivery fee and rider earnings are calculated independently.**

|                  | Customer Delivery Fee                | Rider Earnings              |
| ---------------- | ------------------------------------ | --------------------------- |
| **Base**         | Vendor's base fee (varies)           | GHS 5.00 (fixed)            |
| **Distance**     | `DELIVERY_FEE_PER_KM` (configurable) | GHS 2.00/km (hardcoded)     |
| **Additional**   | Rain surge, min/max clamp            | Tips                        |
| **Who keeps it** | Goes to GrabGo                       | 85% to rider, 15% to GrabGo |

**Why they're decoupled:** This gives GrabGo pricing flexibility. You can set customer delivery fees based on what the market will bear, independently from what you pay riders. On short deliveries, GrabGo profits on the gap. On long deliveries, GrabGo may subsidize the difference — but the service fee covers it.

### Delivery Fee Margin Analysis

| Distance | Customer Fee (vendor base GHS 5 + GHS 1.50/km) | Rider Gross | Rider Net (85%) | GrabGo Margin                 |
| -------- | ---------------------------------------------- | ----------- | --------------- | ----------------------------- |
| 1 km     | GHS 6.50                                       | GHS 7.00    | GHS 5.95        | **+GHS 0.55** (small profit)  |
| 3 km     | GHS 9.50                                       | GHS 11.00   | GHS 9.35        | **+GHS 0.15** (breakeven)     |
| 5 km     | GHS 12.50                                      | GHS 15.00   | GHS 12.75       | **−GHS 0.25** (small subsidy) |
| 10 km    | GHS 20.00                                      | GHS 25.00   | GHS 21.25       | **−GHS 1.25** (subsidy)       |

> **Insight:** Long-distance orders are subsidized by GrabGo's service fee revenue. If you want to avoid subsidizing, increase `DELIVERY_FEE_PER_KM` to GHS 2.00+ (matching the rider rate), or decrease `DELIVERY_MAX_DISTANCE_KM` to limit long-distance orders.

---

## 7. The Rider Earnings Explained

### How a Rider Earns Money on GrabGo

A rider's income comes from **four sources**:

| Source                 | Description                                          | Who Pays                       |
| ---------------------- | ---------------------------------------------------- | ------------------------------ |
| **Delivery earnings**  | GHS 5 base + GHS 2/km − 15% commission, per delivery | GrabGo (from platform revenue) |
| **Tips**               | 100% of customer tips                                | Customer (passed through)      |
| **Incentive bonuses**  | Quests, streaks, milestones, peak hour bonuses       | GrabGo (from incentive budget) |
| **Loan disbursements** | Cash advances (must be repaid with interest)         | GrabGo (repaid by rider)       |

### Rider Daily Earnings Potential

| Performance    | Deliveries | Avg Distance | Base Earnings | Incentives (est.) | Total          |
| -------------- | ---------- | ------------ | ------------- | ----------------- | -------------- |
| Casual         | 5          | 4 km         | GHS 55.25     | GHS 6.00          | **GHS 61.25**  |
| Active         | 10         | 5 km         | GHS 127.50    | GHS 23.00         | **GHS 150.50** |
| Power rider    | 15         | 5 km         | GHS 191.25    | GHS 50.00         | **GHS 241.25** |
| Peak (Diamond) | 20         | 6 km         | GHS 289.00    | GHS 100.00        | **GHS 389.00** |

> **These are competitive earnings for Ghana.** A power rider earning GHS 240+/day is making GHS 5,000+/month, which is well above the average salary. This is your selling point for rider recruitment.

---

## 8. Parcel Delivery — A Second Revenue Engine

### Why Parcels Are More Profitable Than Food

| Factor                      | Food Delivery                             | Parcel Delivery                                       |
| --------------------------- | ----------------------------------------- | ----------------------------------------------------- |
| Pricing model               | Simple (base + distance)                  | Multi-factor (base + distance + time + weight + size) |
| Service fee                 | Configurable % of food subtotal           | 3% of parcel subtotal                                 |
| Customer willingness to pay | Price-sensitive (comparing to eating out) | Less price-sensitive (need item moved)                |
| Time sensitivity            | Very high (food gets cold)                | Moderate                                              |
| Return trips                | Never                                     | Possible (extra revenue)                              |
| Average order value         | GHS 30–80                                 | GHS 15–50 (delivery fee itself)                       |

### Parcel Revenue Per Delivery (Example: 8 km, Medium, 3 kg)

| Component               | Amount        | Who Gets It                   |
| ----------------------- | ------------- | ----------------------------- |
| Customer pays (total)   | GHS 33.06     | —                             |
| Rider earns (net)       | GHS 17.85     | Rider                         |
| GrabGo commission (15%) | GHS 3.15      | GrabGo                        |
| Service fee (3%)        | GHS 0.96      | GrabGo                        |
| Pricing delta           | GHS 11.10     | GrabGo                        |
| **GrabGo total**        | **GHS 15.21** | **(46% of customer payment)** |

> **Compare to food:** GrabGo might earn GHS 4–5 on a food delivery. Parcel deliveries can yield **3× the margin** per delivery.

---

## 9. Payment Infrastructure

### Paystack Integration

GrabGo uses **Paystack** as its primary payment processor, supporting:

| Payment Method             | How It Works                                                 |
| -------------------------- | ------------------------------------------------------------ |
| **Card payments**          | Standard Paystack checkout flow                              |
| **Mobile Money**           | MTN MoMo, Vodafone Cash, AirtelTigo Money                    |
| **Cash on Delivery (COD)** | Partial prepay (delivery fee) via Paystack + cash on arrival |

### Cash on Delivery — Special Model

COD is a hybrid payment method designed for markets where digital payment adoption is growing:

| Parameter                     | Env Variable                       | Default |
| ----------------------------- | ---------------------------------- | ------- |
| COD enabled                   | `COD_ENABLED`                      | false   |
| Min previous delivered orders | `COD_MIN_PREPAID_DELIVERED_ORDERS` | 3       |
| Max order total for COD       | `COD_MAX_ORDER_TOTAL_GHS`          | GHS 250 |
| Max concurrent COD orders     | `COD_MAX_CONCURRENT_ORDERS`        | 1       |
| No-show disable threshold     | `COD_NO_SHOW_DISABLE_THRESHOLD`    | 1       |

**How COD works:**

1. Customer places order → pays delivery fee upfront via Paystack
2. Rider delivers food → collects cash for the food subtotal
3. Rider keeps the cash (deducted from their next payout)

**COD Guards (Fraud Prevention):**

- Customer must have 3+ previous successfully delivered (prepaid) orders
- Phone must be verified
- Max GHS 250 per COD order
- Only 1 concurrent COD order at a time
- 1 no-show disables COD permanently for that customer

> **Recommended:** Enable COD after launch once you have a baseline of payment data. It dramatically increases order conversion in Ghana where many customers prefer cash.

---

## 10. Customer Acquisition Tools

### Referral Program

| Mechanism                  | Amount                               | Condition                                   |
| -------------------------- | ------------------------------------ | ------------------------------------------- |
| Referrer reward            | GHS 10.00 credit                     | When referee completes first order ≥ GHS 20 |
| Referrer milestone bonus   | GHS 5.00 extra                       | Every 5 successful referrals                |
| Referee (new user) benefit | User gets the referral link/discount | First order                                 |
| Welcome credits            | GHS 5.00                             | All new users automatically                 |
| Credit expiry              | 90 days                              | Unused credits expire                       |

**Cost of acquisition via referral:** GHS 15.00 (GHS 10 referrer + GHS 5 welcome credit). This is very competitive — paid advertising often costs GHS 20–50 per acquired customer.

### Promo Code System

Three promo types are supported:

| Type            | How It Works        | Example                     |
| --------------- | ------------------- | --------------------------- |
| `percentage`    | % off subtotal      | "20OFF" = 20% off           |
| `fixed`         | Fixed GHS discount  | "SAVE5" = GHS 5 off         |
| `free_delivery` | Waives delivery fee | "FREEDEL" = no delivery fee |

Promo codes support: usage limits, expiry dates, minimum order amounts, max uses per user.

> **Advice:** Use `free_delivery` promos sparingly — they eliminate one of your revenue streams. Prefer `percentage` promos capped at a max discount (e.g., 20% off up to GHS 10 max).

---

## 11. Untapped Revenue Opportunities

### ✅ ~~Priority 1: Vendor Commission~~ — IMPLEMENTED (v2)

**Status:** ✅ Fully implemented. Per-vendor configurable commission with VendorWallet, automatic settlement, and audit trail.

**Industry Standard:**
| Platform | Vendor Commission |
|---|---|
| Uber Eats | 15–30% |
| DoorDash | 15–30% |
| Glovo (Africa) | 15–25% |
| Jumia Food | 15–20% |
| **GrabGo (configurable)** | **0–15% (per vendor)** |

**Revenue Impact:**

- 500 orders/day × GHS 50 avg food value × 15% commission = **GHS 3,750/day = GHS 112,500/month**
- This alone makes GrabGo profitable.

**Recommended Rollout:**

1. Launch with **0% commission** (`VENDOR_COMMISSION_RATE=0`) for the first 3 months
2. Introduce **10% commission** after establishing a customer base — set per-vendor or globally
3. Scale to **15%** once vendors see consistent order volume
4. Offer **reduced commission (8%)** for vendors with `isGrabGoExclusive = true`

**How to activate:** Set the `VENDOR_COMMISSION_RATE` env var (global default) or update each vendor's `commissionRate` field in the database.

### 🟡 Priority 2: Vendor Advertising / Featured Listings

**Status:** Infrastructure exists (`isFeatured`, `priorityScore`, `PromotionalBanner` model), but no self-serve system or pricing.

**Revenue Model Options:**
| Model | Description | Monthly Revenue Potential |
|---|---|---|
| Fixed monthly fee | GHS 200–500/month for "Featured" badge | 50 vendors × GHS 300 = GHS 15,000/month |
| Cost-per-impression | GHS 0.01–0.05 per listing view | Volume-dependent |
| Promotional banner slots | GHS 500–1,000/week per banner slot | GHS 2,000–4,000/month |
| Boost placement | Pay to rank higher in search results | Commission-based |

### 🟢 Priority 3: Subscription / Premium Plans

**Status:** Not implemented. Listed as future feature.

**Customer Subscription (e.g., "GrabGo Plus"):**
| Tier | Price | Benefits |
|---|---|---|
| GrabGo Plus | GHS 30/month | Free delivery on orders > GHS 30, 5% off service fee |
| GrabGo Premium | GHS 60/month | Free delivery on all orders, priority support, exclusive deals |

**Vendor Subscription (e.g., "GrabGo Pro"):**
| Tier | Price | Benefits |
|---|---|---|
| Basic | Free | Standard listing, standard commission |
| Pro | GHS 200/month | Featured listing, lower commission (10%), analytics dashboard |
| Enterprise | GHS 500/month | Top placement, 8% commission, dedicated account manager, promo tools |

### 🟢 Priority 4: Parcel Insurance

**Status:** The config explicitly says `insurance: false (MVP)`.

| Insurance Option | Price                  | Coverage      |
| ---------------- | ---------------------- | ------------- |
| Basic            | 2% of declared value   | Up to GHS 200 |
| Standard         | 3.5% of declared value | Up to GHS 500 |

Revenue is pure margin minus rare claims.

---

## 12. Revenue Levers — What You Can Tune

### Pre-Launch Configuration Checklist

These environment variables are set to 0/false by default and **must be configured before launch**:

| Variable              | Recommended Starting Value | Why                                        |
| --------------------- | -------------------------- | ------------------------------------------ |
| `DELIVERY_FEE_PER_KM` | **GHS 1.50**               | Covers most of rider distance cost         |
| `DELIVERY_FEE_MIN`    | **GHS 3.00**               | Floor prevents zero-fee orders             |
| `DELIVERY_FEE_MAX`    | **GHS 25.00**              | Cap prevents price shock on long distances |
| `SERVICE_FEE_RATE`    | **0.05 (5%)**              | Industry standard starting point           |
| `SERVICE_FEE_MIN`     | **GHS 1.00**               | Ensures minimum revenue per order          |
| `SERVICE_FEE_MAX`     | **GHS 15.00**              | Cap prevents sticker shock on large orders |
| `TAX_RATE`            | **Consult tax advisor**    | Ghana VAT applicability                    |
| `RAIN_SURGE_ENABLED`  | **true**                   | Critical for rainy season supply           |
| `RAIN_SURGE_FEE`      | **GHS 2.00**               | Modest enough to not deter orders          |
| `COD_ENABLED`         | **true (after 1 month)**   | Opens up cash-preferring customers         |
| `BUDGET_CAP_DAILY`    | **GHS 1,000**              | Start conservative, scale with data        |

### Revenue Sensitivity Analysis

What happens when you adjust key levers:

| Lever                                      | Change                 | Monthly Revenue Impact (500 orders/day) |
| ------------------------------------------ | ---------------------- | --------------------------------------- |
| Service fee 5% → 8%                        | +3% of subtotal        | +GHS 22,500/month                       |
| Delivery fee/km GHS 1.50 → GHS 2.00        | +GHS 0.50/km/order     | +GHS 11,250/month                       |
| Rider commission 15% → 18%                 | +3% of rider gross     | +GHS 6,750/month (⚠️ risks rider churn) |
| Add vendor commission at 15%               | New revenue stream     | +GHS 112,500/month                      |
| Incentive budget GHS 5,000 → GHS 3,000/day | −GHS 2,000/day savings | +GHS 60,000/month savings               |

---

## 13. Competitive Positioning

### GrabGo vs. Competitors in Ghana

| Factor                     | GrabGo                                                | Bolt Food     | Glovo          | Jumia Food |
| -------------------------- | ----------------------------------------------------- | ------------- | -------------- | ---------- |
| **Rider commission**       | 15% (rider keeps 85%)                                 | ~20–25%       | ~20–25%        | ~20%       |
| **Rider incentive system** | Full gamified system (levels, quests, streaks, loans) | Basic bonuses | Basic bonuses  | Minimal    |
| **Parcel delivery**        | ✅ Full multi-factor pricing                          | ❌            | ✅ Basic       | ❌         |
| **Cash on Delivery**       | ✅ With fraud guards                                  | Limited       | ✅             | ✅         |
| **Rider cash advances**    | ✅ 3–8% interest                                      | ❌            | ❌             | ❌         |
| **Weather-aware pricing**  | ✅ Real-time rain surge                               | ❌            | ❌             | ❌         |
| **Multi-vertical**         | Food + Grocery + Pharmacy + GrabMart + Parcels        | Food only     | Food + Parcels | Food only  |

### Your Competitive Advantages

1. **Lower rider commission = more riders** → more supply → better service → more customers
2. **Rider loyalty system = lower churn** → less recruitment spend → better rider quality
3. **Multi-vertical = higher order frequency** → customers use GrabGo for food, groceries, medicine, parcels
4. **Rider financial services = unique moat** → no competitor in Ghana offers cash advances to riders
5. **Weather-aware pricing = smarter operations** → maintain supply during rain when competitors struggle

---

## 14. Risk Factors

### Financial Risks

| Risk                                                  | Severity | Likelihood | Mitigation                                                                      |
| ----------------------------------------------------- | -------- | ---------- | ------------------------------------------------------------------------------- |
| **Negative unit economics without vendor commission** | High     | High       | Implement vendor commission by month 3                                          |
| **Incentive overspend**                               | Medium   | Low        | Hard budget caps (GHS 5,000/day max)                                            |
| **Loan defaults**                                     | Medium   | Medium     | 20+ delivery + 3.5★ eligibility requirement; max 1 active loan                  |
| **Payment processing costs eat margins**              | Low      | Certain    | Negotiate volume rates with Paystack; push mobile money (1% vs 1.95% for cards) |
| **Long-distance delivery subsidies**                  | Medium   | Medium     | Set `DELIVERY_FEE_PER_KM` ≥ rider rate; limit `DELIVERY_MAX_DISTANCE_KM`        |

### Operational Risks

| Risk                                  | Severity | Mitigation                                                                |
| ------------------------------------- | -------- | ------------------------------------------------------------------------- |
| **Not enough riders at launch**       | Critical | 15% commission is competitive; incentive system creates viral recruitment |
| **Not enough vendors**                | Critical | Launch with 0% vendor commission; offer GrabGo Exclusive perks            |
| **COD fraud (no-shows)**              | Medium   | 3-order prepaid history required; 1 no-show disables COD                  |
| **Rider gaming the incentive system** | Low      | Score engine uses 5 weighted factors; streaks require real deliveries     |

### Regulatory Risks

| Risk                                | Action                                                            |
| ----------------------------------- | ----------------------------------------------------------------- |
| **Tax compliance**                  | Configure `TAX_RATE` per tax advisor guidance                     |
| **Lending regulations**             | Confirm if rider cash advances constitute lending under Ghana law |
| **Data protection**                 | Ensure compliance with Ghana Data Protection Act                  |
| **Rider employment classification** | Monitor legal landscape for gig worker reclassification           |

---

## 15. Strategic Roadmap

### Phase 1: Pre-Launch (Now)

| Action                                                            | Priority     | Revenue Impact  |
| ----------------------------------------------------------------- | ------------ | --------------- |
| Configure all fee env variables (service fee, delivery fee, etc.) | 🔴 Critical  | Immediate       |
| Set incentive budget cap to GHS 1,000/day                         | 🔴 Critical  | Cost control    |
| Enable rider partner system in shadow mode                        | 🟡 Important | Data collection |
| Set up Paystack production keys                                   | 🔴 Critical  | Accept payments |

### Phase 2: Launch (Month 1–2)

| Action                               | Priority        | Revenue Impact               |
| ------------------------------------ | --------------- | ---------------------------- |
| Launch with 0% vendor commission     | 🔴 Critical     | Attracts vendors             |
| Enable rider incentives (low budget) | 🟡 Important    | Attracts/retains riders      |
| Enable COD after 2 weeks of data     | 🟡 Important    | +20–30% order conversion     |
| Launch referral program              | 🟡 Important    | Organic customer acquisition |
| Enable rain surge pricing            | 🟢 Nice to have | Maintains supply in rain     |

### Phase 3: Growth (Month 3–6)

| Action                                        | Priority        | Revenue Impact               |
| --------------------------------------------- | --------------- | ---------------------------- |
| Introduce 10% vendor commission               | 🔴 Critical     | +GHS 75,000/month            |
| Enable rider loan system                      | 🟡 Important    | +GHS 3,000/month + retention |
| Increase incentive budget as rider base grows | 🟡 Important    | Better retention             |
| Launch featured vendor listings (manual)      | 🟢 Nice to have | +GHS 5,000–15,000/month      |
| Introduce parcel insurance                    | 🟢 Nice to have | Pure margin revenue          |

### Phase 4: Maturity (Month 6–12)

| Action                                     | Priority        | Revenue Impact      |
| ------------------------------------------ | --------------- | ------------------- |
| Raise vendor commission to 15%             | 🟡 Important    | +GHS 37,500/month   |
| Launch customer subscription (GrabGo Plus) | 🟡 Important    | Recurring revenue   |
| Launch vendor subscription (GrabGo Pro)    | 🟡 Important    | Recurring revenue   |
| Build self-serve vendor advertising        | 🟢 Nice to have | Scalable ad revenue |
| Negotiate volume rates with Paystack       | 🟡 Important    | Cost reduction      |

---

## 16. Complete Configuration Reference

### All Revenue-Related Environment Variables

#### Customer Pricing

| Variable                     | Default | Recommended         | Purpose                         |
| ---------------------------- | ------- | ------------------- | ------------------------------- |
| `DELIVERY_FEE_PER_KM`        | 0       | **1.50**            | Per-km delivery fee to customer |
| `DELIVERY_FEE_MIN`           | 0       | **3.00**            | Minimum delivery fee            |
| `DELIVERY_FEE_MAX`           | 0       | **25.00**           | Maximum delivery fee            |
| `DELIVERY_MAX_DISTANCE_KM`   | 50      | **15**              | Max serviceable distance        |
| `SERVICE_FEE_RATE`           | 0       | **0.05**            | 5% of order subtotal            |
| `SERVICE_FEE_MIN`            | 0       | **1.00**            | Min service fee                 |
| `SERVICE_FEE_MAX`            | 0       | **15.00**           | Max service fee                 |
| `TAX_RATE`                   | 0       | **Consult advisor** | Tax on subtotal                 |
| `RAIN_SURGE_ENABLED`         | false   | **true**            | Enable rain pricing             |
| `RAIN_SURGE_FEE`             | 0       | **2.00**            | Flat rain surcharge             |
| `RAIN_INTENSITY_THRESHOLD`   | 0       | **0.5**             | Min rain intensity              |
| `RAIN_PROBABILITY_THRESHOLD` | 0       | **50**              | Min rain probability %          |

#### Parcel Pricing

| Variable                          | Default | Recommended | Purpose            |
| --------------------------------- | ------- | ----------- | ------------------ |
| `PARCEL_BASE_FEE_GHS`             | 8.00    | 8.00        | Base parcel fee    |
| `PARCEL_FEE_PER_KM_GHS`           | 2.20    | 2.20        | Per-km parcel fee  |
| `PARCEL_FEE_PER_MIN_GHS`          | 0.15    | 0.15        | Per-minute fee     |
| `PARCEL_SERVICE_FEE_RATE`         | 0.03    | 0.03        | 3% service fee     |
| `PARCEL_WEIGHT_FEE_PER_KG_GHS`    | 0.25    | 0.25        | Weight surcharge   |
| `PARCEL_RIDER_BASE_FEE_GHS`       | 5.00    | 5.00        | Rider base fee     |
| `PARCEL_RIDER_FEE_PER_KM_GHS`     | 2.00    | 2.00        | Rider per-km rate  |
| `PARCEL_PLATFORM_COMMISSION_RATE` | 0.15    | 0.15        | 15% commission     |
| `PARCEL_RETURN_FEE_ENABLED`       | false   | **true**    | Charge for returns |

#### Cash on Delivery

| Variable                           | Default | Recommended        | Purpose                       |
| ---------------------------------- | ------- | ------------------ | ----------------------------- |
| `COD_ENABLED`                      | false   | **true (month 2)** | Enable COD                    |
| `COD_MAX_ORDER_TOTAL_GHS`          | 250     | 250                | Max COD order value           |
| `COD_MIN_PREPAID_DELIVERED_ORDERS` | 3       | 3                  | Orders before COD eligibility |
| `COD_MAX_CONCURRENT_ORDERS`        | 1       | 1                  | Simultaneous COD limit        |
| `COD_NO_SHOW_DISABLE_THRESHOLD`    | 1       | 1                  | No-shows to disable COD       |

#### Incentive Budget

| Variable             | Default | Recommended (Launch) | Purpose               |
| -------------------- | ------- | -------------------- | --------------------- |
| `BUDGET_CAP_DAILY`   | 5,000   | **1,000**            | Daily incentive cap   |
| `BUDGET_CAP_WEEKLY`  | 25,000  | **5,000**            | Weekly incentive cap  |
| `BUDGET_CAP_MONTHLY` | 80,000  | **15,000**           | Monthly incentive cap |

#### Feature Flags

| Variable                       | Default | Launch Setting           | Purpose               |
| ------------------------------ | ------- | ------------------------ | --------------------- |
| `RIDER_PARTNER_SYSTEM_ENABLED` | false   | **true**                 | Enable partner levels |
| `RIDER_PARTNER_SHADOW_MODE`    | true    | **true (first 2 weeks)** | Silent scoring mode   |
| `RIDER_INCENTIVES_ENABLED`     | false   | **true**                 | Enable all incentives |
| `FRAUD_ENABLED`                | false   | **true**                 | Fraud detection       |
| `FRAUD_SHADOW_MODE`            | true    | **true (first month)**   | Log-only fraud mode   |

---

> **Bottom Line for the CEO (v2):** GrabGo now has **all major revenue streams implemented**: 15% rider commission, vendor commission (configurable per vendor, 0–15%+), customer service fees, delivery fee margins, parcel fees, withdrawal fees, and loan interest. The vendor commission system is live — set `VENDOR_COMMISSION_RATE` to activate it globally, or configure `commissionRate` per vendor for tiered pricing. At 15% vendor commission with 500 daily orders, that's **GHS 112,500/month** in vendor commission alone. Configure the service fee and delivery fee variables before launch — they're currently set to zero. Start at 0% vendor commission to attract vendors, raise to 10–15% by month 3.

---

_This document reflects the GrabGo codebase as of March 5, 2026 (v2.0). All figures assume GHS (Ghanaian Cedi). Revenue projections are estimates based on assumed order volumes and should be validated against actual data post-launch._
