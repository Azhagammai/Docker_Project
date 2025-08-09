#!/bin/bash

# Status checker script for the deployed landing page
# Usage: ./check-status.sh [IP_ADDRESS]

IP_ADDRESS=${1:-""}

if [ -z "$IP_ADDRESS" ]; then
    echo "Usage: $0 <IP_ADDRESS>"
    echo "Example: $0 192.168.1.100"
    exit 1
fi

echo "🔍 Checking deployment status for: $IP_ADDRESS"
echo "================================================"

# Check if the server is reachable
echo "📡 Testing connectivity..."
if ping -c 1 $IP_ADDRESS &> /dev/null; then
    echo "✅ Server is reachable"
else
    echo "❌ Server is not reachable"
    exit 1
fi

# Check HTTP response
echo "🌐 Testing HTTP response..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$IP_ADDRESS)
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ HTTP Status: $HTTP_STATUS (OK)"
else
    echo "❌ HTTP Status: $HTTP_STATUS (Error)"
fi

# Check response time
echo "⏱️  Testing response time..."
RESPONSE_TIME=$(curl -w "@curl-format.txt" -o /dev/null -s http://$IP_ADDRESS)
echo "$RESPONSE_TIME"

# Check if specific content is present
echo "📄 Testing page content..."
CONTENT=$(curl -s http://$IP_ADDRESS)
if echo "$CONTENT" | grep -q "YourBrand"; then
    echo "✅ Landing page content detected"
else
    echo "❌ Landing page content not found"
fi

# Check SSL (if HTTPS is configured)
echo "🔒 Testing HTTPS (if configured)..."
if curl -s -k https://$IP_ADDRESS &> /dev/null; then
    echo "✅ HTTPS is working"
else
    echo "ℹ️  HTTPS not configured (HTTP only)"
fi

echo "================================================"
echo "🎉 Status check completed!"
echo "🌐 Your landing page: http://$IP_ADDRESS"
