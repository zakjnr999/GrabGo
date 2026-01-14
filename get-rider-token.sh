#!/bin/bash

# Quick Rider Token Getter
# Gets a JWT token for testing WebRTC

BACKEND_URL="https://grabgo-backend.onrender.com"

echo "🔐 Rider Token Getter"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Prompt for credentials
read -p "Enter rider email (or press Enter for test account): " EMAIL
read -sp "Enter password: " PASSWORD
echo ""
echo ""

# Use defaults if empty
if [ -z "$EMAIL" ]; then
    EMAIL="test-rider@example.com"
    PASSWORD="Test123!"
    echo "ℹ️  Using test account credentials"
fi

echo "🔄 Logging in..."

# Login - Use the correct endpoint
RESPONSE=$(curl -s -X POST "$BACKEND_URL/api/users/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")

# Check if response contains token
if echo "$RESPONSE" | grep -q '"token"'; then
    # Extract token
    TOKEN=$(echo $RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    
    echo "✅ Login successful!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Your JWT Token:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$TOKEN"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📝 Instructions:"
    echo "1. Copy the token above"
    echo "2. Open the WebRTC test client (webrtc-test-client.html)"
    echo "3. Paste it in the 'Rider JWT Token' field"
    echo "4. Click 'Connect as Rider'"
    echo ""
    
    # Copy to clipboard if available
    if command -v xclip &> /dev/null; then
        echo "$TOKEN" | xclip -selection clipboard
        echo "✅ Token copied to clipboard!"
    elif command -v pbcopy &> /dev/null; then
        echo "$TOKEN" | pbcopy
        echo "✅ Token copied to clipboard!"
    fi
else
    echo "❌ Login failed!"
    echo ""
    echo "Response:"
    echo "$RESPONSE"
    echo ""
    echo "💡 Possible issues:"
    echo "- Wrong email/password"
    echo "- Account doesn't exist"
    echo "- Backend is down"
    echo ""
    echo "Try creating a test account first:"
    echo "  curl -X POST $BACKEND_URL/api/auth/rider/register \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"name\":\"Test Rider\",\"email\":\"test@example.com\",\"password\":\"Test123!\",\"phone\":\"+1234567890\"}'"
fi

echo ""
