#!/bin/bash

# Backend Tracking Verification Script
# This script checks if all tracking files are properly set up

echo "🔍 GrabGo Backend Tracking Verification"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Check if we're in the backend directory
if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ Error: Not in backend directory${NC}"
    echo "Please run this script from the backend folder"
    exit 1
fi

echo "📁 Checking file structure..."
echo ""

# Check models
if [ -f "models/OrderTracking.js" ]; then
    echo -e "${GREEN}✅ models/OrderTracking.js${NC}"
else
    echo -e "${RED}❌ models/OrderTracking.js NOT FOUND${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check services
SERVICES=("tracking_service.js" "socket_service.js" "geofence_service.js" "tracking_notification_service.js")
for service in "${SERVICES[@]}"; do
    if [ -f "services/$service" ]; then
        echo -e "${GREEN}✅ services/$service${NC}"
    else
        echo -e "${RED}❌ services/$service NOT FOUND${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check routes
if [ -f "routes/tracking_routes.js" ]; then
    echo -e "${GREEN}✅ routes/tracking_routes.js${NC}"
else
    echo -e "${RED}❌ routes/tracking_routes.js NOT FOUND${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "📦 Checking dependencies..."
echo ""

# Check if node_modules exists
if [ -d "node_modules" ]; then
    echo -e "${GREEN}✅ node_modules directory exists${NC}"
    
    # Check specific packages
    PACKAGES=("geolib" "@googlemaps/google-maps-services-js")
    for package in "${PACKAGES[@]}"; do
        if [ -d "node_modules/$package" ]; then
            echo -e "${GREEN}✅ $package installed${NC}"
        else
            echo -e "${YELLOW}⚠️  $package NOT installed${NC}"
            echo "   Run: npm install $package"
        fi
    done
else
    echo -e "${RED}❌ node_modules NOT FOUND${NC}"
    echo "   Run: npm install"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "🔧 Checking server.js configuration..."
echo ""

# Check if tracking routes are registered
if grep -q "api/tracking" server.js; then
    echo -e "${GREEN}✅ Tracking routes registered in server.js${NC}"
else
    echo -e "${RED}❌ Tracking routes NOT registered in server.js${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check if socket service is initialized
if grep -q "socket_service" server.js; then
    echo -e "${GREEN}✅ Socket service initialized in server.js${NC}"
else
    echo -e "${YELLOW}⚠️  Socket service NOT initialized in server.js${NC}"
fi

echo ""
echo "🔐 Checking environment variables..."
echo ""

if [ -f ".env" ]; then
    echo -e "${GREEN}✅ .env file exists${NC}"
    
    # Check for required variables
    if grep -q "GOOGLE_MAPS_API_KEY" .env; then
        echo -e "${GREEN}✅ GOOGLE_MAPS_API_KEY configured${NC}"
    else
        echo -e "${YELLOW}⚠️  GOOGLE_MAPS_API_KEY not set${NC}"
        echo "   Add: GOOGLE_MAPS_API_KEY=your_key_here"
    fi
    
    if grep -q "MONGODB_URI" .env; then
        echo -e "${GREEN}✅ MONGODB_URI configured${NC}"
    else
        echo -e "${YELLOW}⚠️  MONGODB_URI not set${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  .env file NOT FOUND${NC}"
    echo "   Create .env file with required variables"
fi

echo ""
echo "========================================"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! Backend is ready for tracking.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Make sure MongoDB is running"
    echo "2. Start the server: npm run dev"
    echo "3. Test endpoints with Postman"
    echo "4. Implement mobile apps"
else
    echo -e "${RED}❌ Found $ERRORS error(s). Please fix them before proceeding.${NC}"
    exit 1
fi

echo ""
