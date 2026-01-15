# Backend Vendor Endpoints Implementation

## ✅ Completed Tasks

### 1. Created New Models

#### PharmacyStore Model (`/models/PharmacyStore.js`)
- **Fields**:
  - Basic store info: `store_name`, `logo`, `description`, `address`, `phone`, `email`
  - Operational: `isOpen`, `deliveryFee`, `minOrder`, `rating`, `totalReviews`
  - Location: `latitude`, `longitude`
  - Categories: Array of category strings
  - **Pharmacy-specific**:
    - `licenseNumber` (required, unique)
    - `pharmacistName` (required)
    - `pharmacistLicense` (required)
    - `operatingHours` (default: '24/7')
    - `prescriptionRequired` (boolean)
    - `emergencyService` (boolean)
    - `insuranceAccepted` (array of insurance providers)

#### GrabMartStore Model (`/models/GrabMartStore.js`)
- **Fields**:
  - Basic store info: `store_name`, `logo`, `description`, `address`, `phone`, `email`
  - Operational: `isOpen`, `deliveryFee`, `minOrder`, `rating`, `totalReviews`
  - Location: `latitude`, `longitude`
  - Categories: Array of category strings
  - **GrabMart-specific**:
    - `operatingHours` (default: '24/7')
    - `is24Hours` (boolean)
    - `hasParking` (boolean)
    - `acceptsCash`, `acceptsCard`, `acceptsMobileMoney` (booleans)
    - `services` (enum: ATM, Bill Payment, Mobile Top-up, Money Transfer, Photocopying, Printing)
    - `productTypes` (enum: Snacks, Beverages, Personal Care, Household, Electronics, Stationery, Tobacco)

### 2. Created API Routes

#### Pharmacy Routes (`/routes/pharmacies.js`)
- `GET /api/pharmacies/stores` - Get all pharmacy stores (with filters)
  - Query params: `isOpen`, `minRating`, `limit`
- `GET /api/pharmacies/stores/:id` - Get pharmacy store by ID
- `GET /api/pharmacies/stores/search` - Search pharmacy stores
  - Query params: `q`, `emergencyService`, `prescriptionService`
- `GET /api/pharmacies/emergency` - Get pharmacies with emergency services
- `GET /api/pharmacies/24-hours` - Get 24-hour pharmacies
- `GET /api/pharmacies/nearby` - Get nearby pharmacies
  - Query params: `lat`, `lng`, `radius` (default: 5km)

#### GrabMart Routes (`/routes/grabmart.js`)
- `GET /api/grabmart/stores` - Get all GrabMart stores (with filters)
  - Query params: `isOpen`, `is24Hours`, `minRating`, `limit`
- `GET /api/grabmart/stores/:id` - Get GrabMart store by ID
- `GET /api/grabmart/search` - Search GrabMart stores
  - Query params: `q`, `services`, `productTypes`
- `GET /api/grabmart/24-hours` - Get 24-hour GrabMart stores
- `GET /api/grabmart/with-services` - Get stores with specific services
  - Query params: `services` (comma-separated)
- `GET /api/grabmart/nearby` - Get nearby GrabMart stores
  - Query params: `lat`, `lng`, `radius` (default: 5km)
- `GET /api/grabmart/payment-methods` - Filter by payment methods
  - Query params: `cash`, `card`, `mobileMoney`

### 3. Updated Server Configuration
- Added pharmacy and GrabMart routes to `server.js`
- Routes are now accessible at:
  - `http://localhost:5000/api/pharmacies/*`
  - `http://localhost:5000/api/grabmart/*`

---

## 📋 API Endpoints Summary

### Pharmacy Endpoints
```
GET  /api/pharmacies/stores              - List all pharmacy stores
GET  /api/pharmacies/stores/:id          - Get specific pharmacy
GET  /api/pharmacies/stores/search       - Search pharmacies
GET  /api/pharmacies/emergency           - Emergency pharmacies
GET  /api/pharmacies/24-hours            - 24-hour pharmacies
GET  /api/pharmacies/nearby              - Nearby pharmacies
```

### GrabMart Endpoints
```
GET  /api/grabmart/stores                - List all GrabMart stores
GET  /api/grabmart/stores/:id            - Get specific GrabMart
GET  /api/grabmart/search                - Search GrabMart stores
GET  /api/grabmart/24-hours              - 24-hour GrabMarts
GET  /api/grabmart/with-services         - Filter by services
GET  /api/grabmart/nearby                - Nearby GrabMarts
GET  /api/grabmart/payment-methods       - Filter by payment methods
```

---

## 🔧 Next Steps

### 1. Create Seed Data Scripts
Create scripts to populate the database with sample pharmacy and GrabMart data:
- `/backend/scripts/setup-pharmacies.js`
- `/backend/scripts/setup-grabmarts.js`

### 2. Create Item Models (Optional)
If you want to sell individual items from pharmacies and GrabMarts:
- `PharmacyItem.js` (medicines, health products)
- `GrabMartItem.js` (convenience store products)

### 3. Add More Endpoints
- POST endpoints for creating stores (admin only)
- PUT endpoints for updating stores
- DELETE endpoints for removing stores
- Review endpoints for customer reviews
- Favorite endpoints for saving favorite stores

### 4. Frontend Integration
- Create Dart models matching the backend models
- Create API services using Chopper
- Implement vendor providers for state management
- Build UI components for vendor listings

---

## 🧪 Testing the Endpoints

### Test Pharmacy Endpoints
```bash
# Get all pharmacies
curl http://localhost:5000/api/pharmacies/stores

# Get emergency pharmacies
curl http://localhost:5000/api/pharmacies/emergency

# Search pharmacies
curl "http://localhost:5000/api/pharmacies/stores/search?q=health"

# Get nearby pharmacies
curl "http://localhost:5000/api/pharmacies/nearby?lat=5.6&lng=-0.2&radius=10"
```

### Test GrabMart Endpoints
```bash
# Get all GrabMarts
curl http://localhost:5000/api/grabmart/stores

# Get 24-hour GrabMarts
curl http://localhost:5000/api/grabmart/24-hours

# Search GrabMarts
curl "http://localhost:5000/api/grabmart/search?q=snacks"

# Get GrabMarts with ATM service
curl "http://localhost:5000/api/grabmart/with-services?services=ATM,Bill Payment"
```

---

## 📊 Database Indexes

Both models include optimized indexes for better query performance:

### PharmacyStore Indexes
- `store_name` (ascending)
- `isOpen` (ascending)
- `rating` (descending)
- `licenseNumber` (ascending)

### GrabMartStore Indexes
- `store_name` (ascending)
- `isOpen` (ascending)
- `rating` (descending)
- `is24Hours` (ascending)

---

## 🎯 Consistency with Existing Models

The new models follow the same patterns as `GroceryStore.js`:
- Similar field naming conventions
- Same validation patterns
- Consistent response formats
- Compatible with existing infrastructure

---

## 🔐 Security Considerations

### Current Implementation
- All endpoints are public (no authentication required)
- Input validation on query parameters
- Error handling for invalid requests

### Recommended Additions
- Add authentication for admin endpoints (create, update, delete)
- Rate limiting for search endpoints
- Input sanitization for search queries
- API key validation for production

---

## 📝 Notes

1. **Distance Calculation**: Currently using Haversine formula for nearby queries. For production, consider using MongoDB's geospatial queries with 2dsphere indexes.

2. **Search Implementation**: Basic regex search is implemented. For better performance with large datasets, consider:
   - MongoDB text indexes
   - Elasticsearch integration
   - Full-text search service

3. **Pagination**: Not yet implemented. Add pagination for endpoints that return large result sets.

4. **Caching**: Consider adding Redis caching for frequently accessed data (popular stores, nearby stores).

---

**Status**: ✅ Backend endpoints ready for testing  
**Next**: Create seed data and test the endpoints  
**Date**: 2026-01-15
