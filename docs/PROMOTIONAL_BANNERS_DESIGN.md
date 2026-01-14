# Promotional Banners System Design

## Overview
Replaces the "Smart Hero" section with a dynamic, visually stunning banner system designed to maximize conversion for key app actions (referrals, first orders, flash sales).

## Banner Types

### 1. The "Welcome Aboard" (First Time User)
*   **Trigger**: User has 0 completed orders.
*   **Content**: "Get 50% Off Your First Order" or "Free Delivery on First 3 Orders".
*   **Action**: "Claim Offer".
*   **Color Theme**: Vibrant Orange/Gold gradient (Celebratory).

### 2. The "Referral Boost"
*   **Trigger**: Always available, but prioritized if user has completed > 2 orders (loyal user).
*   **Content**: "Refer a friend, Earn GH₵50".
*   **Visual**: Gift box 3D icon or floating coins.
*   **Action**: "Invite Now".
*   **Color Theme**: Deep Purple/Blue or Holographic Silver (Premium).

### 3. The "Flash Deal" (Time Sensitive)
*   **Trigger**: Specific time of day (e.g., 11 AM - 1 PM for Lunch).
*   **Content**: "20% Off All Burgers for the next hour".
*   **Visual**: Countdown timer element.
*   **Action**: "Order Now".
*   **Color Theme**: Red/Pink Alert (Urgency).

### 4. The "GrabMart Highlight"
*   **Trigger**: User mainly orders food but hasn't used Mart.
*   **Content**: "Groceries delivered in 20 mins. Try GrabMart."
*   **Action**: "Shop Store".
*   **Color Theme**: Green/Teal (Fresh).

---

## Unique Design Concepts

### Option A: The "Floating 3D Stack" (Carousel)
Instead of a flat 2D slider, this uses a specialized carousel where the active card is front and center, while the next/prev cards are scaled down and faded in the background with a 3D perspective tilt.
*   **Uniqueness**: Elements inside the card (like the Gift Box or Burger) "pop out" of the card frame (overflowing the top).
*   **Animation**: Smooth spring animations when swiping.

### Option B: The "Infinite Ticker" (Marquee Style)
A high-energy, auto-scrolling horizontal band (like a stock ticker but taller and graphical).
*   **Uniqueness**: Constant motion draws the eye. Very modern "streetwear" aesthetic.
*   **Downside**: Harder to read complex text.

### Option C: The "Morphing Glass" (Single Dynamic Hero)
A single container that morphs its shape and gradient background slowly. The content fades in/out to cycle through ads.
*   **Uniqueness**: The container itself feels "alive" with a liquid border radius or shifting mesh gradient background.
*   **Vibe**: Extremely premium and calming.

### Option D: The "Story Bubbles" + "Featured Card"
Top of the section has Instagram-like story bubbles for "Deals", "News", "Winners". Below it, a single large "Featured" card that changes on refresh.

## Recommended Implementation: "The Pop-Out 3D Card" (Variation of Option A)
To achieve the "Very Unique" requirement, we will implement **Option A** but with **"Pop-Out"** elements.
1.  **Background**: Glassmorphic container with a subtle noise texture.
2.  **Foreground**: The main 3D asset (e.g., a Gift Box for referrals) is an actual widget placed *above* the card in the Stack, overlapping the top edge. This breaks the grid and catches attention.
3.  **Interaction**: A "shimmer" effect runs diagonally across the card every few seconds.

## Technical Requirements
*   **Data Source**: `PromotionalProvider` (needs to be created/updated).
*   **Widget**: `PromotionalBannerCarousel`.
*   **Persistence**: Close button to dismiss specific banners for the session.
