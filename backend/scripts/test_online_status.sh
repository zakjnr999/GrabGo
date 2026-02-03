#!/bin/bash
#
# Quick Test: Rider Online Status & Auto-Offline System
# 
# Usage:
#   chmod +x scripts/test_online_status.sh
#   ./scripts/test_online_status.sh
#
# This script tests against production (Render)
#

BASE_URL="https://grabgo-backend.onrender.com/api"

echo ""
echo "🧪 Testing Online Status System on Render"
echo "📡 Base URL: $BASE_URL"
echo "=============================================="

# Step 1: Login to get token
echo ""
echo "📝 Step 1: Login as Rider"
echo "Enter rider email:"
read RIDER_EMAIL
echo "Enter rider password:"
read -s RIDER_PASSWORD
echo ""

LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$RIDER_EMAIL\", \"password\": \"$RIDER_PASSWORD\"}")

TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "❌ Login failed!"
  echo "Response: $LOGIN_RESPONSE"
  exit 1
fi

echo "✅ Login successful!"
echo ""

# Step 2: Check online status
echo "📊 Step 2: Check Online Status"
STATUS_RESPONSE=$(curl -s -X GET "$BASE_URL/riders/online-status" \
  -H "Authorization: Bearer $TOKEN")
echo "Response: $STATUS_RESPONSE"
echo ""

# Step 3: Go online with battery
echo "🟢 Step 3: Go Online with Battery (85%)"
ONLINE_RESPONSE=$(curl -s -X POST "$BASE_URL/riders/go-online" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"latitude": 5.6037, "longitude": -0.187, "batteryLevel": 85, "isCharging": false}')
echo "Response: $ONLINE_RESPONSE"
echo ""

# Step 4: Update location with battery
echo "📍 Step 4: Update Location with Battery (82%)"
LOCATION_RESPONSE=$(curl -s -X POST "$BASE_URL/riders/location" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"latitude": 5.6050, "longitude": -0.185, "batteryLevel": 82, "isCharging": false}')
echo "Response: $LOCATION_RESPONSE"
echo ""

# Step 5: Check status again
echo "🔍 Step 5: Check Status (should be online)"
STATUS_RESPONSE=$(curl -s -X GET "$BASE_URL/riders/online-status" \
  -H "Authorization: Bearer $TOKEN")
echo "Response: $STATUS_RESPONSE"
echo ""

# Step 6: Go offline
echo "🔴 Step 6: Go Offline"
OFFLINE_RESPONSE=$(curl -s -X POST "$BASE_URL/riders/go-offline" \
  -H "Authorization: Bearer $TOKEN")
echo "Response: $OFFLINE_RESPONSE"
echo ""

# Step 7: Verify offline
echo "✅ Step 7: Verify Offline Status"
FINAL_STATUS=$(curl -s -X GET "$BASE_URL/riders/online-status" \
  -H "Authorization: Bearer $TOKEN")
echo "Response: $FINAL_STATUS"
echo ""

echo "=============================================="
echo "🎉 Tests completed!"
echo ""
echo "💡 Notes:"
echo "   - Default status is OFFLINE for new/returning riders"
echo "   - Battery level is now tracked for scoring"
echo "   - Auto-offline job runs every 5 minutes"
