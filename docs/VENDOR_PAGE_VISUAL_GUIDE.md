# Vendor Page Visual Architecture Guide

## 📐 Screen Layout Diagrams

### Main Vendors Page Layout
```
┌─────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════╗  │
│  ║   🍔 Foods  🛒 Groceries  💊 Pharmacy ║  │ ← Service Selector (Sticky)
│  ╚═══════════════════════════════════════╝  │
├─────────────────────────────────────────────┤
│  📍 Accra, Ghana                      🔔    │ ← Location Header
├─────────────────────────────────────────────┤
│  🔍 Search vendors...            [Filter]   │ ← Search Bar
├─────────────────────────────────────────────┤
│  [All] [Italian] [Fast Food] [Asian] →     │ ← Category Chips (Horizontal Scroll)
├─────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐        │
│  │  ┌────────┐  │  │  ┌────────┐  │        │
│  │  │ Image  │  │  │  │ Image  │  │        │
│  │  └────────┘  │  │  └────────┘  │        │
│  │  Vendor Name │  │  Vendor Name │        │
│  │  ⭐ 4.5 • 🚚 │  │  ⭐ 4.8 • 🚚 │        │ ← Vendor Grid
│  │  GHS 5       │  │  GHS 3       │        │
│  └──────────────┘  └──────────────┘        │
│  ┌──────────────┐  ┌──────────────┐        │
│  │  ┌────────┐  │  │  ┌────────┐  │        │
│  │  │ Image  │  │  │  │ Image  │  │        │
│  │  └────────┘  │  │  └────────┘  │        │
│  │  Vendor Name │  │  Vendor Name │        │
│  │  ⭐ 4.2 • 🚚 │  │  ⭐ 4.9 • 🚚 │        │
│  │  GHS 8       │  │  GHS 2       │        │
│  └──────────────┘  └──────────────┘        │
│                                             │
│                    ↓ Scroll ↓               │
└─────────────────────────────────────────────┘
```

### Vendor Card (Grid Layout)
```
┌──────────────────────────────┐
│ ┌──────────────────────────┐ │
│ │                          │ │
│ │    Vendor Hero Image     │ │ ← Image with gradient overlay
│ │                          │ │
│ │    [Featured Badge]  ♥   │ │ ← Badges + Favorite button
│ └──────────────────────────┘ │
│                              │
│ Vendor Name                  │ ← Bold, 18sp
│ 📍 0.5 km away               │ ← Distance
│                              │
│ ⭐ 4.5 (120) • Italian       │ ← Rating + Category
│                              │
│ ┌──────────────────────────┐ │
│ │ 🚚 GHS 5 • ⏱️ 20-30 min  │ │ ← Delivery info bar
│ └──────────────────────────┘ │
│                              │
│ [🟢 Open Now]                │ ← Status badge
└──────────────────────────────┘
```

### Vendor Card (List Layout)
```
┌────────────────────────────────────────────────┐
│ ┌──────┐  Vendor Name                      ♥  │
│ │      │  ⭐ 4.5 (120) • Italian              │
│ │Image │  📍 0.5 km • 🚚 GHS 5 • ⏱️ 20-30 min │
│ │      │  [🟢 Open Now] [Featured]            │
│ └──────┘  Fresh pasta and authentic Italian.. │
└────────────────────────────────────────────────┘
```

### Filter Bottom Sheet
```
┌─────────────────────────────────────────────┐
│  ════════════════════════════════════════   │ ← Drag handle
│                                             │
│  Filters                          Clear All │ ← Header
│  ─────────────────────────────────────────  │
│                                             │
│  Sort By                                    │
│  ○ Relevance  ○ Rating  ○ Distance          │
│  ○ Delivery Fee  ○ Delivery Time            │
│                                             │
│  Rating                                     │
│  [4+ Stars] [3+ Stars] [All]                │
│                                             │
│  Delivery Fee                               │
│  ├────●──────────┤  GHS 0 - 10              │ ← Slider
│                                             │
│  Distance                                   │
│  ├──────●────────┤  0 - 5 km                │ ← Slider
│                                             │
│  Categories                                 │
│  [✓ Italian] [✓ Fast Food] [ Asian]        │
│  [ Mexican] [ Desserts] [ Healthy]          │
│                                             │
│  Options                                    │
│  [✓] Open Now                               │
│  [ ] Free Delivery                          │
│  [ ] Featured Only                          │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │     Apply Filters (3 active)        │   │ ← Apply button
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

### Vendor Details Page
```
┌─────────────────────────────────────────────┐
│  ← Back                            ♥ Share  │ ← Header
├─────────────────────────────────────────────┤
│  ┌───────────────────────────────────────┐ │
│  │                                       │ │
│  │      Image Carousel (Swipeable)      │ │ ← Hero section
│  │                                       │ │
│  └───────────────────────────────────────┘ │
│  ● ○ ○ ○                                   │ ← Carousel indicators
├─────────────────────────────────────────────┤
│  Vendor Name                                │
│  ⭐ 4.5 (120 reviews) • Italian             │
│  📍 0.5 km away • 🟢 Open until 10:00 PM    │
├─────────────────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐ ┌─────────┐      │
│  │ 🚚 GHS 5│ │ ⏱️ 20-30│ │ 📦 Min  │      │ ← Quick info
│  │ Delivery│ │  mins   │ │ GHS 20  │      │
│  └─────────┘ └─────────┘ └─────────┘      │
├─────────────────────────────────────────────┤
│  About                                      │
│  Fresh pasta and authentic Italian cuisine  │
│  made with love...                          │
│                                             │
│  [Italian] [Pasta] [Pizza] [Vegetarian]    │ ← Category tags
├─────────────────────────────────────────────┤
│  Menu                                       │
│  [Popular] [Pasta] [Pizza] [Desserts] →    │ ← Category tabs
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ ┌────┐  Margherita Pizza       +    │   │
│  │ │Img │  Fresh mozzarella...          │   │
│  │ └────┘  GHS 45                       │   │ ← Menu items
│  └─────────────────────────────────────┘   │
│  ┌─────────────────────────────────────┐   │
│  │ ┌────┐  Carbonara Pasta        +    │   │
│  │ │Img │  Creamy pasta with...         │   │
│  │ └────┘  GHS 38                       │   │
│  └─────────────────────────────────────┘   │
│                                             │
│                    ↓ Scroll ↓               │
└─────────────────────────────────────────────┘
```

---

## 🏗️ Component Hierarchy

```
VendorsPage
├── UmbrellaHeader (Collapsible)
│   ├── ServiceSelector
│   ├── LocationDisplay
│   ├── SearchBar
│   └── NotificationIcon
│
├── VendorSearchBar
│   ├── SearchInput
│   └── FilterButton (with badge)
│
├── VendorCategoryChips
│   └── CategoryChip[] (horizontal scroll)
│
├── VendorLayoutToggle (Grid/List)
│
└── VendorContent (AnimatedSwitcher)
    ├── VendorGrid (if grid layout)
    │   └── VendorCard[]
    │       ├── VendorImage
    │       ├── VendorInfo
    │       ├── VendorRating
    │       ├── VendorDeliveryInfo
    │       └── VendorStatus
    │
    ├── VendorList (if list layout)
    │   └── VendorListItem[]
    │
    ├── VendorSkeleton (if loading)
    │
    └── EmptyState (if no results)
```

---

## 🔄 State Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    User Actions                         │
└─────────────────────────────────────────────────────────┘
         │                │                │
         │                │                │
    Select Service   Search Vendors   Apply Filters
         │                │                │
         ▼                ▼                ▼
┌─────────────────────────────────────────────────────────┐
│                  VendorProvider                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │ State:                                            │ │
│  │  - vendors: List<VendorModel>                     │ │
│  │  - filteredVendors: List<VendorModel>             │ │
│  │  - selectedType: VendorType?                      │ │
│  │  - activeFilter: VendorFilterModel                │ │
│  │  - isLoading: bool                                │ │
│  │  - error: String?                                 │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
         │                │                │
         ▼                ▼                ▼
┌─────────────────────────────────────────────────────────┐
│                  VendorService                          │
│  ┌───────────────────────────────────────────────────┐ │
│  │ Methods:                                          │ │
│  │  - fetchVendors(type, location)                   │ │
│  │  - searchVendors(query, type)                     │ │
│  │  - getVendorDetails(id)                           │ │
│  │  - toggleFavorite(id)                             │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│                    Backend API                          │
│  GET  /api/vendors?type=food&lat=5.6&lng=-0.2          │
│  GET  /api/vendors/search?q=pizza&type=food            │
│  GET  /api/vendors/:id                                 │
│  POST /api/vendors/:id/favorite                        │
└─────────────────────────────────────────────────────────┘
```

---

## 🎨 Color System by Service Type

```
┌──────────────────────────────────────────────────────────┐
│  Service Type Color Mapping                              │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  🍔 FOOD SERVICE                                         │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Primary:   #FE6132 ████████                        │ │
│  │ Gradient:  #FE6132 → #FF8A5B ████████ → ████████   │ │
│  │ Light:     #FFF3EF ░░░░░░░░                        │ │
│  │ Dark:      #C94D28 ████████                        │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  🛒 GROCERY SERVICE                                      │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Primary:   #4CAF50 ████████                        │ │
│  │ Gradient:  #4CAF50 → #66BB6A ████████ → ████████   │ │
│  │ Light:     #E8F5E9 ░░░░░░░░                        │ │
│  │ Dark:      #388E3C ████████                        │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  💊 PHARMACY SERVICE                                     │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Primary:   #2196F3 ████████                        │ │
│  │ Gradient:  #2196F3 → #42A5F5 ████████ → ████████   │ │
│  │ Light:     #E3F2FD ░░░░░░░░                        │ │
│  │ Dark:      #1976D2 ████████                        │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  🏪 CONVENIENCE SERVICE                                  │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Primary:   #9C27B0 ████████                        │ │
│  │ Gradient:  #9C27B0 → #AB47BC ████████ → ████████   │ │
│  │ Light:     #F3E5F5 ░░░░░░░░                        │ │
│  │ Dark:      #7B1FA2 ████████                        │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

---

## 📊 Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                            │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐              │
│  │  Vendors  │  │  Vendor   │  │  Filter   │              │
│  │   Page    │  │  Details  │  │   Sheet   │              │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘              │
│        │              │              │                      │
└────────┼──────────────┼──────────────┼──────────────────────┘
         │              │              │
         ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────┐
│                    State Management Layer                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              VendorProvider (ChangeNotifier)         │  │
│  │  ┌────────────────────────────────────────────────┐ │  │
│  │  │  notifyListeners() triggers UI rebuild        │ │  │
│  │  └────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Business Logic Layer                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              VendorRepository                        │  │
│  │  - Data transformation                               │  │
│  │  - Caching logic                                     │  │
│  │  - Error handling                                    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│                      Service Layer                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              VendorService (Chopper)                 │  │
│  │  - HTTP requests                                     │  │
│  │  - Request/Response serialization                    │  │
│  │  - Network error handling                            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│                      Network Layer                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                  Backend API                         │  │
│  │  - REST endpoints                                    │  │
│  │  - Database queries                                  │  │
│  │  - Business logic                                    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔀 Navigation Flow

```
                    ┌─────────────┐
                    │  Home Page  │
                    └──────┬──────┘
                           │
                           │ Tap "See All Vendors"
                           │ or Service Selector
                           ▼
                    ┌─────────────┐
                    │   Vendors   │
                    │    Page     │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    Tap Vendor        Tap Filter        Tap Search
         │                 │                 │
         ▼                 ▼                 ▼
  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
  │   Vendor    │   │   Filter    │   │   Search    │
  │   Details   │   │    Sheet    │   │   Results   │
  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘
         │                 │                 │
         │            Apply Filters      Select Result
         │                 │                 │
         │                 └─────────┬───────┘
         │                           │
         │                           ▼
         │                    ┌─────────────┐
         │                    │   Vendors   │
         │                    │    Page     │
         │                    │  (Filtered) │
         │                    └─────────────┘
         │
    Add to Cart
         │
         ▼
  ┌─────────────┐
  │  Cart Page  │
  └─────────────┘
```

---

## 📱 Responsive Grid Layout

```
Mobile (< 600px) - 1 Column
┌─────────────────────────┐
│  ┌───────────────────┐  │
│  │   Vendor Card 1   │  │
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │   Vendor Card 2   │  │
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │   Vendor Card 3   │  │
│  └───────────────────┘  │
└─────────────────────────┘

Tablet (600-900px) - 2 Columns
┌─────────────────────────────────────┐
│  ┌──────────────┐  ┌──────────────┐ │
│  │ Vendor Card 1│  │ Vendor Card 2│ │
│  └──────────────┘  └──────────────┘ │
│  ┌──────────────┐  ┌──────────────┐ │
│  │ Vendor Card 3│  │ Vendor Card 4│ │
│  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────┘

Desktop (> 900px) - 3 Columns
┌──────────────────────────────────────────────────┐
│  ┌────────┐  ┌────────┐  ┌────────┐             │
│  │ Card 1 │  │ Card 2 │  │ Card 3 │             │
│  └────────┘  └────────┘  └────────┘             │
│  ┌────────┐  ┌────────┐  ┌────────┐             │
│  │ Card 4 │  │ Card 5 │  │ Card 6 │             │
│  └────────┘  └────────┘  └────────┘             │
└──────────────────────────────────────────────────┘
```

---

## 🎭 Animation Timeline

```
Vendor Card Tap Animation (200ms)
─────────────────────────────────────────
0ms     50ms    100ms   150ms   200ms
│       │       │       │       │
├───────┼───────┼───────┼───────┤
│       │       │       │       │
Scale:  1.0 →  0.98 →  0.98 →  1.0
Opacity: 1.0 →  0.9  →  0.9  →  1.0


Filter Sheet Slide Animation (300ms)
─────────────────────────────────────────
0ms     100ms   200ms   300ms
│       │       │       │
├───────┼───────┼───────┤
│       │       │       │
Y-Pos:  100% → 50%  → 25%  →  0%
Opacity: 0.0 → 0.5  → 0.8  →  1.0


Skeleton Shimmer Animation (1500ms, repeating)
─────────────────────────────────────────────────
0ms     375ms   750ms   1125ms  1500ms
│       │       │       │       │
├───────┼───────┼───────┼───────┤
│       │       │       │       │
Shimmer: ◀─────────────────────▶ (loop)
Position: -100% → -50% → 0% → 50% → 100%
```

---

## 🔧 File Structure Tree

```
lib/
├── features/
│   └── vendors/
│       ├── model/
│       │   ├── vendor_model.dart
│       │   ├── vendor_type.dart
│       │   ├── vendor_filter_model.dart
│       │   └── vendor_sort_option.dart
│       │
│       ├── view/
│       │   ├── vendors_page.dart
│       │   ├── vendor_details_page.dart
│       │   └── vendor_review_page.dart
│       │
│       ├── viewmodel/
│       │   ├── vendor_provider.dart
│       │   └── vendor_filter_provider.dart
│       │
│       ├── service/
│       │   └── vendor_service.dart
│       │
│       └── repository/
│           └── vendor_repository.dart
│
└── shared/
    └── widgets/
        ├── vendor_card.dart
        ├── vendor_grid.dart
        ├── vendor_list.dart
        ├── vendor_list_item.dart
        ├── vendor_search_bar.dart
        ├── vendor_filter_sheet.dart
        ├── vendor_category_chips.dart
        ├── vendor_skeleton.dart
        ├── vendor_empty_state.dart
        └── vendor_error_state.dart
```

---

## 📊 Performance Optimization Strategy

```
┌─────────────────────────────────────────────────────────┐
│              Image Loading Strategy                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Original Image (Server)                                │
│         │                                               │
│         ▼                                               │
│  ┌──────────────────────────────────────┐              │
│  │  CDN Optimization                    │              │
│  │  - Resize to multiple sizes          │              │
│  │  - Convert to WebP                   │              │
│  │  - Apply compression                 │              │
│  └──────────────────────────────────────┘              │
│         │                                               │
│         ▼                                               │
│  ┌──────────────────────────────────────┐              │
│  │  Client-Side Caching                 │              │
│  │  - Memory cache (CachedNetworkImage) │              │
│  │  - Disk cache (persistent)           │              │
│  │  - Cache expiry: 7 days              │              │
│  └──────────────────────────────────────┘              │
│         │                                               │
│         ▼                                               │
│  ┌──────────────────────────────────────┐              │
│  │  Progressive Loading                 │              │
│  │  1. Show placeholder                 │              │
│  │  2. Load low-res preview (blur)      │              │
│  │  3. Load full image                  │              │
│  │  4. Fade transition                  │              │
│  └──────────────────────────────────────┘              │
│                                                         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│              List Rendering Strategy                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────────────────────────────┐              │
│  │  Pagination                          │              │
│  │  - Initial load: 20 items            │              │
│  │  - Load more: 20 items per page      │              │
│  │  - Infinite scroll trigger: 80%      │              │
│  └──────────────────────────────────────┘              │
│         │                                               │
│         ▼                                               │
│  ┌──────────────────────────────────────┐              │
│  │  ListView.builder                    │              │
│  │  - Lazy rendering                    │              │
│  │  - Item recycling                    │              │
│  │  - Viewport optimization             │              │
│  └──────────────────────────────────────┘              │
│         │                                               │
│         ▼                                               │
│  ┌──────────────────────────────────────┐              │
│  │  State Management                    │              │
│  │  - Debounced search (300ms)          │              │
│  │  - Throttled scroll events           │              │
│  │  - Memoized filter results           │              │
│  └──────────────────────────────────────┘              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🎯 User Journey Map

```
Discovery Phase
┌─────────────────────────────────────────────────────────┐
│  User opens app → Sees service selector → Selects Food │
│                                                         │
│  Emotion: 😊 Excited                                    │
│  Goal: Find a restaurant                                │
│  Pain Point: Too many choices                           │
│  Solution: Category chips + filters                     │
└─────────────────────────────────────────────────────────┘
         │
         ▼
Exploration Phase
┌─────────────────────────────────────────────────────────┐
│  Browses vendors → Uses filters → Finds interesting one │
│                                                         │
│  Emotion: 🤔 Curious                                    │
│  Goal: Evaluate options                                 │
│  Pain Point: Need more information                      │
│  Solution: Rich vendor cards with all key info          │
└─────────────────────────────────────────────────────────┘
         │
         ▼
Decision Phase
┌─────────────────────────────────────────────────────────┐
│  Taps vendor → Views details → Checks menu → Decides   │
│                                                         │
│  Emotion: 😃 Confident                                  │
│  Goal: Make a decision                                  │
│  Pain Point: Unclear pricing/availability               │
│  Solution: Clear pricing, delivery info, reviews        │
└─────────────────────────────────────────────────────────┘
         │
         ▼
Action Phase
┌─────────────────────────────────────────────────────────┐
│  Adds items to cart → Proceeds to checkout → Orders    │
│                                                         │
│  Emotion: 😄 Satisfied                                  │
│  Goal: Complete order                                   │
│  Pain Point: Complicated checkout                       │
│  Solution: Streamlined cart and checkout flow           │
└─────────────────────────────────────────────────────────┘
```

---

## 📐 Spacing & Sizing Guide

```
┌─────────────────────────────────────────────────────────┐
│                  Spacing System                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  KSpacing.xs    = 4.h   ▌                              │
│  KSpacing.sm    = 8.h   ▌▌                             │
│  KSpacing.md    = 12.h  ▌▌▌                            │
│  KSpacing.lg    = 16.h  ▌▌▌▌                           │
│  KSpacing.xl    = 20.h  ▌▌▌▌▌                          │
│  KSpacing.xxl   = 24.h  ▌▌▌▌▌▌                         │
│                                                         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                  Border Radius                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  KBorderSize.borderSmall  = 8.r   ╭─╮                  │
│  KBorderSize.borderMedium = 12.r  ╭──╮                 │
│  KBorderSize.border       = 16.r  ╭───╮                │
│  KBorderSize.borderLarge  = 20.r  ╭────╮               │
│                                                         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                  Touch Targets                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Minimum:  48x48 dp  ┌──────────┐                      │
│                      │          │                      │
│                      │  Button  │                      │
│                      │          │                      │
│                      └──────────┘                      │
│                                                         │
│  Recommended: 56x56 dp for primary actions              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

**Document Version**: 1.0  
**Companion to**: VENDOR_PAGE_DESIGN_DOCUMENTATION.md  
**Last Updated**: 2026-01-15
