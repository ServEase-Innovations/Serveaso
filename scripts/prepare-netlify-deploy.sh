#!/bin/bash

# Prepare for Netlify Deployment
# This script helps verify everything is ready for deployment

echo "🚀 ServEaso Netlify Deployment Preparation"
echo "=========================================="
echo ""

# Check if netlify.toml exists
echo "✓ Checking configuration files..."

if [ -f "apps/servease-website/netlify.toml" ]; then
    echo "  ✓ Website netlify.toml found"
else
    echo "  ✗ Website netlify.toml missing!"
    exit 1
fi

if [ -f "apps/servase-ui/netlify.toml" ]; then
    echo "  ✓ Booking app netlify.toml found"
else
    echo "  ✗ Booking app netlify.toml missing!"
    exit 1
fi

# Check environment files
echo ""
echo "✓ Checking environment files..."

if [ -f "apps/servease-website/.env.production" ]; then
    echo "  ✓ Website .env.production found"
else
    echo "  ✗ Website .env.production missing!"
    exit 1
fi

# Test builds locally
echo ""
echo "🔨 Testing local builds..."
echo ""

# Build website
echo "Building website..."
cd apps/servease-website
if npm run build; then
    echo "  ✓ Website builds successfully"
else
    echo "  ✗ Website build failed!"
    exit 1
fi
cd ../..

# Build booking app
echo ""
echo "Building booking app..."
cd apps/servase-ui
if npm run build:prod; then
    echo "  ✓ Booking app builds successfully"
else
    echo "  ✗ Booking app build failed!"
    exit 1
fi
cd ../..

echo ""
echo "=========================================="
echo "✅ All checks passed!"
echo ""
echo "Next steps:"
echo "1. Push code to GitHub/GitLab"
echo "2. Connect repository to Netlify"
echo "3. Deploy booking app first"
echo "4. Deploy website second"
echo "5. Configure custom domain"
echo ""
echo "See NETLIFY_DEPLOYMENT_GUIDE.md for detailed instructions"
echo "=========================================="
