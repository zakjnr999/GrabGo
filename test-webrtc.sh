#!/bin/bash

# WebRTC Test Helper Script
# Makes testing the WebRTC feature super easy!

echo "🎧 WebRTC Testing Helper"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "backend/test/webrtc-test-client.html" ]; then
    echo -e "${RED}❌ Error: Please run this script from the GrabGo project root${NC}"
    exit 1
fi

echo -e "${BLUE}📋 What would you like to do?${NC}"
echo ""
echo "1) Open Browser Test Client (Simulates Rider)"
echo "2) Run Flutter Customer App"
echo "3) Start Backend Server"
echo "4) View Testing Guide"
echo "5) Run Full Test (Backend + Test Client + Flutter)"
echo "6) Exit"
echo ""
read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo -e "${GREEN}🌐 Opening Browser Test Client...${NC}"
        echo ""
        echo -e "${YELLOW}Instructions:${NC}"
        echo "1. Click 'Connect as Rider'"
        echo "2. Wait for incoming calls from customer app"
        echo "3. Click 'Answer Call' when call comes in"
        echo ""
        
        # Try to open in default browser
        if command -v xdg-open > /dev/null; then
            xdg-open backend/test/webrtc-test-client.html
        elif command -v open > /dev/null; then
            open backend/test/webrtc-test-client.html
        elif command -v google-chrome > /dev/null; then
            google-chrome backend/test/webrtc-test-client.html
        elif command -v firefox > /dev/null; then
            firefox backend/test/webrtc-test-client.html
        else
            echo -e "${YELLOW}⚠️  Please manually open: backend/test/webrtc-test-client.html${NC}"
        fi
        ;;
        
    2)
        echo -e "${GREEN}📱 Running Flutter Customer App...${NC}"
        echo ""
        cd packages/grab_go_customer
        flutter run
        ;;
        
    3)
        echo -e "${GREEN}🚀 Starting Backend Server...${NC}"
        echo ""
        cd backend
        npm start
        ;;
        
    4)
        echo -e "${GREEN}📖 Opening Testing Guide...${NC}"
        echo ""
        if command -v code > /dev/null; then
            code docs/WEBRTC_TESTING_GUIDE.md
        elif command -v xdg-open > /dev/null; then
            xdg-open docs/WEBRTC_TESTING_GUIDE.md
        elif command -v open > /dev/null; then
            open docs/WEBRTC_TESTING_GUIDE.md
        else
            cat docs/WEBRTC_TESTING_GUIDE.md
        fi
        ;;
        
    5)
        echo -e "${GREEN}🚀 Starting Full Test Environment...${NC}"
        echo ""
        echo -e "${YELLOW}This will open:${NC}"
        echo "1. Backend server in a new terminal"
        echo "2. Browser test client"
        echo "3. Flutter customer app"
        echo ""
        read -p "Continue? (y/n): " confirm
        
        if [ "$confirm" = "y" ]; then
            # Start backend in new terminal
            echo -e "${BLUE}Starting backend...${NC}"
            if command -v gnome-terminal > /dev/null; then
                gnome-terminal -- bash -c "cd backend && npm start; exec bash"
            elif command -v xterm > /dev/null; then
                xterm -e "cd backend && npm start" &
            else
                echo -e "${YELLOW}⚠️  Please start backend manually: cd backend && npm start${NC}"
            fi
            
            sleep 2
            
            # Open test client
            echo -e "${BLUE}Opening test client...${NC}"
            if command -v xdg-open > /dev/null; then
                xdg-open backend/test/webrtc-test-client.html
            elif command -v open > /dev/null; then
                open backend/test/webrtc-test-client.html
            fi
            
            sleep 2
            
            # Run Flutter app
            echo -e "${BLUE}Starting Flutter app...${NC}"
            cd packages/grab_go_customer
            flutter run
        fi
        ;;
        
    6)
        echo -e "${GREEN}👋 Goodbye!${NC}"
        exit 0
        ;;
        
    *)
        echo -e "${RED}❌ Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✅ Done!${NC}"
