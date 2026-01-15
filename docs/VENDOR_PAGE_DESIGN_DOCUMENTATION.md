# Vendor Page Design & Implementation Documentation

## 📋 Overview

This document outlines the comprehensive design and implementation plan for creating a **Vendor Page** to replace the current **Restaurant Page** in the GrabGo customer app. The vendor page will serve as a unified marketplace for all types of vendors (restaurants, grocery stores, pharmacies, and convenience stores), providing a consistent and premium user experience.

---

## 🎯 Project Objectives

### Primary Goals
1. **Unify Vendor Experience**: Create a single, flexible vendor page that adapts to different vendor types (food, groceries, pharmacy, convenience stores)
2. **Replace Restaurant-Specific Page**: Transition from the restaurant-focused page to a vendor-agnostic design
3. **Maintain Design Excellence**: Apply the same premium design principles used in recent homepage UI updates
4. **Enhance User Discovery**: Improve vendor discovery through better filtering, categorization, and search
5. **Scalability**: Build a foundation that can easily accommodate new vendor types in the future

### Success Metrics
- Seamless integration with existing service selector
- Consistent UI/UX across all vendor types
- Improved user engagement with vendor listings
- Reduced code duplication
- Better performance and loading states

---

## 🔍 Current State Analysis

### Existing Restaurant Page Structure
**Location**: `/packages/grab_go_customer/lib/features/restaurant/view/restaurants.dart`

**Key Components**:
- Restaurant list with horizontal scrolling cards
- Search functionality
- Filter options (rating, delivery time, food type)
- Location-based restaurant discovery
- Restaurant details navigation

**Current Issues**:
1. **Limited to Restaurants**: Only handles food vendors
2. **Separate from Service Selector**: Doesn't integrate with the new service-based architecture
3. **Inconsistent with Homepage**: Different design patterns from updated homepage
4. **Duplicate Logic**: Similar functionality exists in other parts of the app

### Related Files to Modify/Replace
```
Features:
├── /features/restaurant/
│   ├── view/
│   │   ├── restaurants.dart (TO BE REPLACED)
│   │   ├── restaurant_details.dart (TO BE ADAPTED)
│   │   └── restaurant_review_page.dart (KEEP)
│   ├── model/
│   │   └── restaurants_model.dart (TO BE EXTENDED)
│   ├── viewmodel/
│   │   └── restaurant_provider.dart (TO BE REFACTORED)
│   └── service/
│       └── restaurant_service.dart (TO BE EXTENDED)

Shared Widgets:
├── /shared/widgets/
│   ├── restaurant_list.dart (TO BE REPLACED)
│   ├── nearby_restaurant_card.dart (TO BE REPLACED)
│   └── restaurant_search.dart (TO BE REPLACED)
```

---

## 🎨 Design Principles

Following the established GrabGo design system:

### Visual Design
1. **Premium Aesthetics**
   - Vibrant, curated color palettes (HSL-based)
   - Smooth gradients and glassmorphism effects
   - Modern typography (Lato, Inter)
   - Rich visual hierarchy

2. **Dynamic & Interactive**
   - Micro-animations on interactions
   - Smooth transitions between states
   - Hover effects and touch feedback
   - Loading states with skeleton screens

3. **Consistent Branding**
   - Service-specific accent colors:
     - Food: `#FE6132` (Orange)
     - Groceries: `#4CAF50` (Green)
     - Pharmacy: `#2196F3` (Blue)
     - GrabMart: `#9C27B0` (Purple)

### UX Principles
1. **Context-Aware**: Adapts to selected service type
2. **Progressive Disclosure**: Show relevant information at the right time
3. **Familiar Patterns**: Consistent with homepage design
4. **Performance-First**: Optimized loading and caching

---

## 🏗️ Architecture Design

### New Structure
```
/features/vendors/
├── model/
│   ├── vendor_model.dart (NEW - Unified vendor model)
│   ├── vendor_type.dart (NEW - Enum for vendor types)
│   └── vendor_filter_model.dart (NEW - Filter options)
├── view/
│   ├── vendors_page.dart (NEW - Main vendor listing page)
│   ├── vendor_details_page.dart (NEW - Unified details page)
│   └── vendor_review_page.dart (ADAPTED from restaurant)
├── viewmodel/
│   ├── vendor_provider.dart (NEW - Unified vendor state management)
│   └── vendor_filter_provider.dart (NEW - Filter state)
├── service/
│   └── vendor_service.dart (NEW - API service for vendors)
└── repository/
    └── vendor_repository.dart (NEW - Data layer)

/shared/widgets/
├── vendor_card.dart (NEW - Unified vendor card)
├── vendor_grid.dart (NEW - Grid layout for vendors)
├── vendor_list.dart (NEW - List layout for vendors)
├── vendor_search_bar.dart (NEW - Search component)
├── vendor_filter_sheet.dart (NEW - Filter bottom sheet)
└── vendor_category_chips.dart (NEW - Category selection)
```

---

## 📊 Data Model Design

### Unified Vendor Model
```dart
class VendorModel {
  final String id;
  final String name;
  final String description;
  final VendorType type; // food, grocery, pharmacy, convenience
  final String imageUrl;
  final List<String> images; // Gallery
  final double rating;
  final int reviewCount;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final bool isOpen;
  final String openingTime;
  final String closingTime;
  final double deliveryFee;
  final String averageDeliveryTime;
  final List<String> categories; // e.g., ["Italian", "Pizza"] or ["Organic", "Fresh Produce"]
  final List<String> tags; // e.g., ["Fast Delivery", "Popular", "New"]
  final bool isFeatured;
  final bool isVerified;
  final Map<String, dynamic> metadata; // Vendor-specific data
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### Vendor Type Enum
```dart
enum VendorType {
  food('food', 'Restaurant', '🍔', '#FE6132'),
  grocery('grocery', 'Grocery Store', '🛒', '#4CAF50'),
  pharmacy('pharmacy', 'Pharmacy', '💊', '#2196F3'),
  convenience('convenience', 'Convenience Store', '🏪', '#9C27B0');

  final String id;
  final String displayName;
  final String emoji;
  final String colorHex;
  
  const VendorType(this.id, this.displayName, this.emoji, this.colorHex);
}
```

### Filter Model
```dart
class VendorFilterModel {
  final VendorType? vendorType;
  final double? minRating;
  final double? maxDeliveryFee;
  final List<String> categories;
  final bool openNow;
  final SortOption sortBy;
  final double? maxDistance;
}

enum SortOption {
  relevance,
  rating,
  deliveryTime,
  deliveryFee,
  distance,
  newest,
}
```

---

## 🎭 UI Components Breakdown

### 1. Vendors Page (Main Screen)

#### Header Section
- **Collapsible Umbrella Header** (consistent with homepage)
  - Service selector integration
  - Location display
  - Search bar
  - Notification icon

#### Search & Filter Bar
```dart
VendorSearchBar(
  hintText: "Search ${selectedService.name.toLowerCase()}...",
  onSearch: (query) => vendorProvider.searchVendors(query),
  onFilterTap: () => showVendorFilterSheet(context),
  activeFilterCount: vendorProvider.activeFilterCount,
)
```

#### Category Chips (Horizontal Scroll)
```dart
VendorCategoryChips(
  categories: vendorProvider.categories,
  selectedCategory: selectedCategory,
  onCategorySelected: (category) {
    setState(() => selectedCategory = category);
    vendorProvider.filterByCategory(category);
  },
)
```

#### Vendor Listings
**Two Layout Options**:
1. **Grid View** (Default for browsing)
   ```dart
   VendorGrid(
     vendors: vendorProvider.filteredVendors,
     onVendorTap: (vendor) => context.push('/vendor-details', extra: vendor),
     isLoading: vendorProvider.isLoading,
   )
   ```

2. **List View** (Detailed view)
   ```dart
   VendorList(
     vendors: vendorProvider.filteredVendors,
     onVendorTap: (vendor) => context.push('/vendor-details', extra: vendor),
     isLoading: vendorProvider.isLoading,
   )
   ```

#### Empty States
- No vendors found
- No results for search/filter
- Location permission required
- Network error

### 2. Vendor Card Component

**Design Specifications**:
```dart
VendorCard(
  vendor: vendor,
  onTap: () => navigateToDetails(vendor),
  layout: VendorCardLayout.grid, // or .list
  showDistance: true,
  showDeliveryInfo: true,
)
```

**Card Elements**:
- Hero image with gradient overlay
- Vendor name and type badge
- Rating with star icon
- Categories/tags chips
- Open/closed status indicator
- Delivery fee and time
- Distance from user
- Featured/verified badges
- Favorite button (heart icon)

**Visual Enhancements**:
- Glassmorphism effect on overlays
- Smooth shadow transitions
- Shimmer loading state
- Micro-animations on tap

### 3. Vendor Details Page

**Sections**:
1. **Hero Section**
   - Image carousel
   - Vendor name and type
   - Rating and reviews
   - Open status
   - Share and favorite buttons

2. **Quick Info Bar**
   - Delivery fee
   - Delivery time
   - Distance
   - Minimum order (if applicable)

3. **About Section**
   - Description
   - Categories
   - Operating hours
   - Contact info

4. **Menu/Products Section**
   - Category tabs
   - Item grid/list
   - Add to cart functionality

5. **Reviews Section**
   - Rating breakdown
   - Recent reviews
   - "See all reviews" button

6. **Location Section**
   - Map view
   - Address
   - Directions button

### 4. Filter Bottom Sheet

**Filter Options**:
- Sort by (relevance, rating, delivery time, etc.)
- Rating (4+ stars, 3+ stars, etc.)
- Delivery fee range
- Distance range
- Categories (multi-select)
- Open now toggle
- Featured vendors toggle
- Free delivery toggle

**Design**:
- Glassmorphic background
- Smooth slide-up animation
- Clear all / Apply buttons
- Active filter indicators

---

## 🔄 State Management

### Vendor Provider
```dart
class VendorProvider extends ChangeNotifier {
  // State
  List<VendorModel> _vendors = [];
  List<VendorModel> _filteredVendors = [];
  VendorFilterModel _activeFilter = VendorFilterModel();
  bool _isLoading = false;
  String? _error;
  VendorType? _selectedType;
  
  // Getters
  List<VendorModel> get vendors => _vendors;
  List<VendorModel> get filteredVendors => _filteredVendors;
  bool get isLoading => _isLoading;
  int get activeFilterCount => _activeFilter.getActiveCount();
  
  // Methods
  Future<void> fetchVendors(VendorType type);
  Future<void> searchVendors(String query);
  void applyFilter(VendorFilterModel filter);
  void filterByCategory(String category);
  void sortVendors(SortOption sortBy);
  Future<void> toggleFavorite(String vendorId);
  Future<void> refreshVendors();
}
```

---

## 🎬 User Flows

### Flow 1: Browse Vendors
1. User selects service type (Food, Groceries, etc.) on homepage
2. Taps "See all" or navigates to vendors page
3. Vendors page loads with selected service type
4. User can browse, search, or filter vendors
5. Taps on vendor card to view details
6. Views menu/products and adds items to cart

### Flow 2: Search for Specific Vendor
1. User taps search bar on vendors page
2. Types vendor name or category
3. Results update in real-time
4. User selects vendor from results
5. Navigates to vendor details

### Flow 3: Filter Vendors
1. User taps filter icon
2. Filter sheet slides up
3. User selects filter criteria
4. Taps "Apply"
5. Vendor list updates with filtered results
6. Active filter count shows on filter button

---

## 🎨 Visual Design Specifications

### Color Palette (Service-Specific)
```dart
// Food Service
primary: #FE6132 (Orange)
gradient: [#FE6132, #FF8A5B]

// Grocery Service
primary: #4CAF50 (Green)
gradient: [#4CAF50, #66BB6A]

// Pharmacy Service
primary: #2196F3 (Blue)
gradient: [#2196F3, #42A5F5]

// Convenience Service
primary: #9C27B0 (Purple)
gradient: [#9C27B0, #AB47BC]
```

### Typography
```dart
// Vendor Name
fontSize: 18.sp
fontWeight: FontWeight.w800
fontFamily: 'Lato'

// Description
fontSize: 13.sp
fontWeight: FontWeight.w400
color: colors.textSecondary

// Category Chips
fontSize: 11.sp
fontWeight: FontWeight.w600
```

### Spacing
```dart
cardPadding: 12.r
cardMargin: 16.w (horizontal), 8.h (vertical)
sectionSpacing: 20.h
chipSpacing: 8.w
```

### Animations
```dart
// Card tap
duration: 200ms
curve: Curves.easeInOut
scale: 0.98

// Filter sheet
duration: 300ms
curve: Curves.easeOutCubic

// Skeleton loading
shimmerDuration: 1500ms
```

---

## 🔌 API Integration

### Endpoints Required
```
GET /api/vendors?type={type}&lat={lat}&lng={lng}
GET /api/vendors/:id
GET /api/vendors/search?q={query}&type={type}
GET /api/vendors/categories?type={type}
POST /api/vendors/:id/favorite
DELETE /api/vendors/:id/favorite
GET /api/vendors/:id/reviews
```

### Response Format
```json
{
  "success": true,
  "data": {
    "vendors": [...],
    "total": 45,
    "page": 1,
    "limit": 20
  }
}
```

---

## 📱 Responsive Design

### Grid Breakpoints
- **Mobile (< 600px)**: 1 column
- **Tablet (600-900px)**: 2 columns
- **Desktop (> 900px)**: 3 columns

### Card Sizes
- **Grid**: Width = (screenWidth - padding) / columns
- **List**: Full width with fixed height
- **Aspect Ratio**: 1.2:1 for grid cards

---

## ♿ Accessibility

### Requirements
1. **Semantic Labels**: All interactive elements have proper labels
2. **Color Contrast**: WCAG AA compliance (4.5:1 minimum)
3. **Touch Targets**: Minimum 48x48 logical pixels
4. **Screen Reader Support**: Proper announcements for state changes
5. **Keyboard Navigation**: Support for external keyboards

---

## 🧪 Testing Strategy

### Unit Tests
- Vendor model serialization/deserialization
- Filter logic
- Search functionality
- Sort algorithms

### Widget Tests
- Vendor card rendering
- Filter sheet interactions
- Search bar functionality
- Empty states

### Integration Tests
- Complete vendor browsing flow
- Search and filter combination
- Navigation to details
- Add to cart from vendor page

### Performance Tests
- List scrolling performance
- Image loading optimization
- State update efficiency
- Memory usage monitoring

---

## 📦 Migration Plan

### Phase 1: Foundation (Week 1)
1. Create new vendor models and enums
2. Set up vendor provider with basic state management
3. Create vendor service and repository
4. Set up API endpoints (backend)

### Phase 2: UI Components (Week 2)
1. Build VendorCard component with all variants
2. Create VendorGrid and VendorList layouts
3. Implement VendorSearchBar
4. Build VendorFilterSheet
5. Create loading skeletons

### Phase 3: Main Page (Week 3)
1. Build VendorsPage with header integration
2. Implement search functionality
3. Add filter integration
4. Connect to vendor provider
5. Add empty states and error handling

### Phase 4: Details Page (Week 4)
1. Adapt restaurant details to vendor details
2. Make it service-type aware
3. Integrate with existing cart functionality
4. Add reviews section

### Phase 5: Integration & Testing (Week 5)
1. Integrate with service selector
2. Update navigation routes
3. Migrate existing restaurant data
4. Comprehensive testing
5. Performance optimization

### Phase 6: Deployment (Week 6)
1. Feature flag implementation
2. Gradual rollout
3. Monitor analytics
4. Gather user feedback
5. Iterate based on feedback

---

## 🚀 Implementation Checklist

### Backend Tasks
- [ ] Create unified vendor schema in database
- [ ] Migrate restaurant data to vendor model
- [ ] Create vendor API endpoints
- [ ] Add vendor search with Elasticsearch/similar
- [ ] Implement vendor filtering logic
- [ ] Set up vendor image optimization
- [ ] Add vendor analytics tracking

### Frontend Tasks
- [ ] Create vendor feature folder structure
- [ ] Implement VendorModel and related models
- [ ] Build VendorProvider with state management
- [ ] Create VendorCard component
- [ ] Build VendorGrid and VendorList layouts
- [ ] Implement VendorSearchBar
- [ ] Create VendorFilterSheet
- [ ] Build VendorsPage
- [ ] Adapt VendorDetailsPage
- [ ] Create loading skeletons
- [ ] Add empty states
- [ ] Implement error handling
- [ ] Add animations and transitions
- [ ] Integrate with service selector
- [ ] Update routing
- [ ] Write unit tests
- [ ] Write widget tests
- [ ] Write integration tests
- [ ] Performance optimization
- [ ] Accessibility audit

### Design Tasks
- [ ] Create vendor card designs for all service types
- [ ] Design filter sheet UI
- [ ] Create empty state illustrations
- [ ] Design loading states
- [ ] Create vendor detail page mockups
- [ ] Design error states
- [ ] Create animation specifications

### Documentation Tasks
- [ ] API documentation
- [ ] Component documentation
- [ ] User guide updates
- [ ] Developer onboarding guide
- [ ] Migration guide for existing code

---

## 🎯 Key Differences from Restaurant Page

### Conceptual Changes
1. **Vendor-Agnostic**: Works for all service types, not just restaurants
2. **Service-Aware**: UI adapts based on selected service type
3. **Unified Data Model**: Single model for all vendor types
4. **Consistent Design**: Matches homepage design language
5. **Better Performance**: Optimized loading and caching

### Technical Changes
1. **Provider-Based**: Uses Provider for state management
2. **Modular Components**: Reusable widgets across service types
3. **Better Filtering**: Advanced filter options with bottom sheet
4. **Improved Search**: Real-time search with debouncing
5. **Lazy Loading**: Pagination for large vendor lists

### UX Improvements
1. **Faster Navigation**: Smoother transitions and animations
2. **Better Discovery**: Category chips and improved filtering
3. **Visual Feedback**: Loading states and micro-animations
4. **Contextual Information**: Service-specific details
5. **Accessibility**: Better screen reader support

---

## 📈 Success Metrics

### Performance Metrics
- Page load time < 2 seconds
- Smooth scrolling at 60fps
- Image loading < 500ms
- Search results < 300ms

### User Engagement Metrics
- Vendor page views
- Search usage rate
- Filter usage rate
- Vendor detail navigation rate
- Add to cart conversion rate

### Quality Metrics
- Crash-free rate > 99.9%
- API error rate < 0.1%
- User satisfaction score > 4.5/5

---

## 🔮 Future Enhancements

### Phase 2 Features
1. **Vendor Recommendations**: AI-based suggestions
2. **Favorites Management**: Organize favorite vendors
3. **Vendor Comparison**: Compare multiple vendors
4. **Advanced Filters**: Dietary preferences, cuisine types
5. **Map View**: Browse vendors on a map
6. **Vendor Stories**: Instagram-style vendor highlights
7. **Live Vendor Status**: Real-time availability updates
8. **Vendor Promotions**: Special offers and deals section

### Phase 3 Features
1. **Vendor Chat**: Direct messaging with vendors
2. **Vendor Ratings**: Detailed rating breakdowns
3. **Vendor Badges**: Achievement and quality badges
4. **Vendor Events**: Special events and promotions
5. **Vendor Loyalty**: Points and rewards program

---

## 📝 Notes & Considerations

### Design Decisions
1. **Why Unified Model?**: Reduces code duplication and makes adding new vendor types easier
2. **Why Grid Layout?**: Better visual browsing experience, especially for image-heavy content
3. **Why Bottom Sheet for Filters?**: Familiar pattern, doesn't navigate away from results
4. **Why Service-Specific Colors?**: Helps users understand context and creates visual hierarchy

### Technical Decisions
1. **Provider vs Bloc**: Provider chosen for consistency with existing codebase
2. **Pagination Strategy**: Infinite scroll for better UX
3. **Image Caching**: Aggressive caching to reduce data usage
4. **Search Debouncing**: 300ms delay to reduce API calls

### Potential Challenges
1. **Data Migration**: Migrating existing restaurant data to vendor model
2. **Backward Compatibility**: Ensuring existing features still work
3. **Performance**: Handling large vendor lists efficiently
4. **Testing**: Comprehensive testing across all service types

---

## 🤝 Collaboration & Review

### Review Points
1. **Design Review**: UI/UX team approval on mockups
2. **Technical Review**: Architecture and code quality review
3. **Product Review**: Feature completeness and user value
4. **QA Review**: Testing coverage and bug fixes
5. **Accessibility Review**: WCAG compliance check

### Stakeholders
- Product Manager: Feature requirements and priorities
- Design Team: UI/UX design and consistency
- Engineering Team: Technical implementation
- QA Team: Testing and quality assurance
- Users: Feedback and validation

---

## 📚 References

### Design Inspiration
- Uber Eats vendor browsing
- DoorDash restaurant discovery
- Instacart store selection
- GrabFood vendor page

### Technical Resources
- Flutter documentation
- Provider package documentation
- Material Design guidelines
- iOS Human Interface Guidelines

---

## ✅ Conclusion

This documentation provides a comprehensive blueprint for creating a unified, premium vendor page that will replace the current restaurant page. The design follows established GrabGo design principles while introducing modern patterns for vendor discovery and browsing.

**Next Steps**:
1. Review and approve this documentation
2. Create detailed UI mockups
3. Set up backend infrastructure
4. Begin Phase 1 implementation
5. Iterate based on feedback

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-15  
**Author**: GrabGo Development Team  
**Status**: Draft - Pending Review
