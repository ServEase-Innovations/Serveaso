#!/bin/bash

# ETA Calculation Test Script
# This script tests the complete ETA calculation flow

# Configuration
API_BASE_URL="${TRACKING_API_URL:-https://notifications-mjdp.onrender.com}"
ENGAGEMENT_ID="${1:-353}"
PROVIDER_ID="${2:-123}"

echo "================================================"
echo "ETA Calculation Test Script"
echo "================================================"
echo "API Base URL: $API_BASE_URL"
echo "Engagement ID: $ENGAGEMENT_ID"
echo "Provider ID: $PROVIDER_ID"
echo "================================================"
echo ""

# Step 1: Update provider location
echo "Step 1: Updating provider location..."
echo "Location: Bangalore (12.9000, 77.5500)"
echo ""

LOCATION_RESPONSE=$(curl -s -X POST "$API_BASE_URL/api/tracking/provider/location" \
  -H "Content-Type: application/json" \
  -d "{
    \"engagement_id\": $ENGAGEMENT_ID,
    \"provider_id\": $PROVIDER_ID,
    \"latitude\": 12.9000,
    \"longitude\": 77.5500,
    \"accuracy\": 10,
    \"bearing\": 45,
    \"speed\": 5.5
  }")

echo "Response:"
echo "$LOCATION_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$LOCATION_RESPONSE"
echo ""
echo "================================================"
echo ""

# Wait a moment
sleep 1

# Step 2: Check if location was stored
echo "Step 2: Verifying location was stored..."
echo ""

STORED_LOCATION=$(curl -s "$API_BASE_URL/api/tracking/location/$ENGAGEMENT_ID")

echo "Stored Location:"
echo "$STORED_LOCATION" | python3 -m json.tool 2>/dev/null || echo "$STORED_LOCATION"
echo ""
echo "================================================"
echo ""

# Step 3: Calculate ETA
echo "Step 3: Calculating ETA..."
echo "Note: This requires the engagement to have latitude & longitude columns set"
echo "      The coordinates represent the booking/service location"
echo ""

ETA_RESPONSE=$(curl -s -X POST "$API_BASE_URL/api/tracking/calculate-eta" \
  -H "Content-Type: application/json" \
  -d "{
    \"engagement_id\": $ENGAGEMENT_ID
  }")

echo "ETA Response:"
echo "$ETA_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$ETA_RESPONSE"
echo ""
echo "================================================"
echo ""

# Step 4: Get cached ETA
echo "Step 4: Retrieving cached ETA..."
echo ""

CACHED_ETA=$(curl -s "$API_BASE_URL/api/tracking/eta/$ENGAGEMENT_ID")

echo "Cached ETA:"
echo "$CACHED_ETA" | python3 -m json.tool 2>/dev/null || echo "$CACHED_ETA"
echo ""
echo "================================================"
echo ""

# Summary
echo "Test Summary:"
echo "-------------"

# Check if we got a successful ETA
if echo "$ETA_RESPONSE" | grep -q "duration_seconds"; then
  DURATION=$(echo "$ETA_RESPONSE" | grep -o '"duration_seconds":[0-9]*' | grep -o '[0-9]*')
  DISTANCE=$(echo "$ETA_RESPONSE" | grep -o '"distance_meters":[0-9]*' | grep -o '[0-9]*')
  TRAFFIC=$(echo "$ETA_RESPONSE" | grep -o '"traffic_aware":[a-z]*' | grep -o '[a-z]*$')
  
  MINUTES=$((DURATION / 60))
  KM=$(echo "scale=1; $DISTANCE / 1000" | bc 2>/dev/null || echo "N/A")
  
  echo "✅ ETA Calculated Successfully!"
  echo "   Duration: $MINUTES minutes"
  echo "   Distance: $KM km"
  echo "   Traffic Aware: $TRAFFIC"
else
  echo "❌ ETA Calculation Failed"
  echo "   Check the error message above"
  echo ""
  echo "Common issues:"
  echo "   1. Engagement latitude/longitude columns are NULL"
  echo "   2. Provider location not published yet"
  echo "   3. Google Maps API key not configured"
  echo ""
  echo "To fix issue #1, run this SQL:"
  echo "   UPDATE engagements"
  echo "   SET latitude = 12.9716, longitude = 77.5946"
  echo "   WHERE engagement_id = $ENGAGEMENT_ID;"
fi

echo ""
echo "================================================"
echo "Test complete!"
echo "================================================"
