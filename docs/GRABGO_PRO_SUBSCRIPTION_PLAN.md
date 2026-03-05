# GrabGo Pro — Subscription & Premium Plans

**Version:** 1.0  
**Date:** March 2026  
**Status:** Implementation Ready  
**Priority:** 3 — Revenue Multiplier

---

## 📋 Executive Summary

GrabGo Pro is a customer subscription system with two tiers (**GrabGo Plus** and **GrabGo Premium**) that converts volatile per-transaction revenue into predictable Monthly Recurring Revenue (MRR). Subscribers pay a fixed monthly fee in exchange for delivery fee waivers, service fee discounts, and premium perks — driving higher order frequency and customer retention.

---

## 🎯 Why Subscriptions? The Business Case

### The Core Problem

GrabGo currently earns **per-transaction only** — rider commission (15%) + vendor commission + service fees. If a customer orders 3 times this week and 0 next week, revenue drops. Subscriptions fix this by creating **guaranteed recurring income**.

### Revenue Impact (MRR Projections)

| Subscribers (Mixed) | GrabGo Plus (GHS 30/mo)      | GrabGo Premium (GHS 60/mo)  | **Blended MRR**    |
| ------------------- | ---------------------------- | --------------------------- | ------------------ |
| 500                 | 350 × GHS 30 = GHS 10,500    | 150 × GHS 60 = GHS 9,000    | **GHS 19,500/mo**  |
| 2,000               | 1,400 × GHS 30 = GHS 42,000  | 600 × GHS 60 = GHS 36,000   | **GHS 78,000/mo**  |
| 5,000               | 3,500 × GHS 30 = GHS 105,000 | 1,500 × GHS 60 = GHS 90,000 | **GHS 195,000/mo** |

> 💡 **Investor note:** Startups are typically valued at 5-10× annual MRR. At 5,000 subscribers, GrabGo Pro alone adds **GHS 11.7M–23.4M** to company valuation.

### The Psychology — Why It Profits GrabGo

**Sunk Cost Effect:** Once a customer pays GHS 30/month, they think _"I've already paid, I should order more to get my money's worth."_ Studies show subscription users order **2–3× more frequently** than non-subscribers.

### The Math — Per-Subscriber Economics

| Metric                                                      | Non-Subscriber | GrabGo Plus Subscriber              |
| ----------------------------------------------------------- | -------------- | ----------------------------------- |
| Orders per month                                            | ~4             | ~10 (2.5× increase)                 |
| Delivery fees waived                                        | GHS 0          | ~GHS 5 × 7 eligible orders = GHS 35 |
| Subscription revenue                                        | GHS 0          | GHS 30                              |
| Net delivery fee impact                                     | —              | **-GHS 5** (minor loss)             |
| Extra vendor commission (10% × 6 extra orders × GHS 50 avg) | —              | **+GHS 30**                         |
| Extra rider commission (15% of extra rider earnings)        | —              | **+GHS 12**                         |
| **Net gain per subscriber/month**                           | **GHS 0**      | **+GHS 37**                         |

> Even though GrabGo "loses" GHS 35 in delivery fees, it **gains GHS 42+** from increased order volume + the subscription fee itself. **Net positive.**

### Strategic Benefits

1. **Customer Lock-In:** Monthly subscribers churn at 5–8% vs 30–40% for non-subscribers
2. **Predictable Cash Flow:** Guaranteed monthly revenue regardless of daily order volume
3. **Data Advantage:** Predictable ordering patterns → better rider scheduling → lower idle costs
4. **Competitive Moat:** First-mover advantage in Ghana's delivery subscription market
5. **Valuation Multiplier:** MRR directly increases startup valuation for fundraising

---

## 💎 Tier Structure

| Feature                  | GrabGo Plus                     | GrabGo Premium                |
| ------------------------ | ------------------------------- | ----------------------------- |
| **Monthly Price**        | GHS 30                          | GHS 60                        |
| **Free Delivery**        | Orders above GHS 30             | All orders                    |
| **Service Fee Discount** | 5% off                          | 10% off                       |
| **Priority Support**     | ❌                              | ✅                            |
| **Exclusive Deals**      | ❌                              | ✅ (vendor-sponsored)         |
| **Target Customer**      | Regular users (4+ orders/month) | Power users (8+ orders/month) |
| **Customer Break-Even**  | ~6 orders/month                 | ~8 orders/month               |

### Why Two Tiers?

- **Plus** catches the mass market — most customers won't commit to GHS 60
- **Premium** captures high-value power users who order almost daily
- **Upgrade path** creates natural revenue growth as users increase ordering

---

## 🏗️ Technical Architecture

### Database Models

```
Subscription
├── id (cuid)
├── userId → User
├── tier (grabgo_plus | grabgo_premium)
├── status (active | cancelled | expired | past_due)
├── paystackSubscriptionCode (from Paystack API)
├── paystackCustomerCode
├── currentPeriodStart
├── currentPeriodEnd
├── cancelledAt
├── createdAt / updatedAt

SubscriptionPayment
├── id (cuid)
├── subscriptionId → Subscription
├── amount
├── currency
├── paystackReference
├── status (success | failed | pending)
├── paidAt
├── createdAt
```

### Paystack Integration Flow

```
1. Customer selects tier in app
2. Backend creates Paystack Plan (if not exists)
3. Backend initializes subscription via Paystack API
4. Customer authorizes card on Paystack hosted page
5. Paystack charges card monthly and sends webhooks:
   - subscription.create → Activate subscription
   - invoice.payment_failed → Mark as past_due
   - subscription.not_renew → Mark as cancelled
   - invoice.update → Record payment
6. Backend checks subscription status at checkout time
```

### Checkout Integration

At order time, the pricing service:

1. Checks if the customer has an active subscription
2. Applies delivery fee waiver (based on tier + order subtotal)
3. Applies service fee discount (5% for Plus, 10% for Premium)
4. Records subscription benefit on the order for analytics

---

## 📊 Key Performance Indicators (KPIs)

| KPI                       | Target (6 months) | Target (12 months) |
| ------------------------- | ----------------- | ------------------ |
| Total subscribers         | 1,000             | 5,000              |
| Plus : Premium ratio      | 70:30             | 65:35              |
| Subscriber monthly orders | 8+ avg            | 10+ avg            |
| Monthly churn rate        | < 8%              | < 5%               |
| Subscriber LTV            | GHS 360           | GHS 600            |
| MRR from subscriptions    | GHS 39,000        | GHS 195,000        |

---

## ⚠️ Risks & Mitigations

| Risk                                 | Likelihood | Impact | Mitigation                                       |
| ------------------------------------ | ---------- | ------ | ------------------------------------------------ |
| Low adoption                         | Medium     | High   | Launch with GHS 15 first-month promo             |
| Subscribers order less than expected | Low        | Medium | 30-day free trial → only committed users convert |
| Delivery fee waivers eat margin      | Low        | Low    | Plus tier has GHS 30 minimum order threshold     |
| Paystack billing failures            | Medium     | Medium | Grace period + retry logic + push notifications  |
| Competitor copies model              | Medium     | Low    | First-mover advantage + switching costs          |

---

## 🚀 Launch Strategy

### Phase 1 — Soft Launch (Week 1–2)

- Enable for top 10% customers by order frequency
- GHS 15 introductory first month
- Collect feedback on tier value

### Phase 2 — Full Launch (Week 3–4)

- Open to all customers
- In-app subscription page with benefit calculator
- Push notification campaign

### Phase 3 — Optimization (Month 2+)

- A/B test pricing (GHS 25 vs GHS 30 for Plus)
- Add annual plans at 2-month discount
- Introduce "Exclusive Deals" for Premium (vendor-sponsored offers)

---

## 💻 Backend API Endpoints

| Method | Endpoint                       | Purpose                             |
| ------ | ------------------------------ | ----------------------------------- |
| GET    | `/api/subscriptions/plans`     | List available plans with pricing   |
| GET    | `/api/subscriptions/me`        | Get current user's subscription     |
| POST   | `/api/subscriptions/subscribe` | Start a new subscription            |
| POST   | `/api/subscriptions/cancel`    | Cancel subscription (end of period) |
| POST   | `/api/subscriptions/webhook`   | Paystack subscription webhooks      |
| GET    | `/api/subscriptions/benefits`  | Check benefits for current order    |

---

_GrabGo Pro transforms the business from "hope they order today" to "guaranteed GHS X every month" — the foundation of a scalable, investable company._
