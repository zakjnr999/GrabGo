#!/bin/bash

# Decode JWT Token to get Rider ID

echo "🔍 JWT Token Decoder"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Paste your JWT token: " TOKEN

if [ -z "$TOKEN" ]; then
    echo "❌ No token provided"
    exit 1
fi

# Extract payload (second part of JWT)
PAYLOAD=$(echo $TOKEN | cut -d'.' -f2)

# Add padding if needed
case $((${#PAYLOAD} % 4)) in
    2) PAYLOAD="${PAYLOAD}==" ;;
    3) PAYLOAD="${PAYLOAD}=" ;;
esac

# Decode base64
DECODED=$(echo $PAYLOAD | base64 -d 2>/dev/null)

if [ -z "$DECODED" ]; then
    echo "❌ Failed to decode token"
    exit 1
fi

echo "✅ Token decoded!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Token Payload:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$DECODED" | python3 -m json.tool 2>/dev/null || echo "$DECODED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Extract rider ID
RIDER_ID=$(echo "$DECODED" | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ ! -z "$RIDER_ID" ]; then
    echo "📋 Your Rider ID: $RIDER_ID"
    echo ""
    echo "✅ Use this ID in the web test client!"
else
    echo "⚠️  Could not extract rider ID automatically"
    echo "Please look for 'id' field in the payload above"
fi

echo ""
