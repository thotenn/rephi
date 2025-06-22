#!/bin/bash

# Build script for all frontend applications

set -e

echo "Building frontend applications..."

# Create priv/static directories if they don't exist
mkdir -p priv/static/{dashboard,admin,ecommerce,landing}

# Build dashboard if it exists
if [ -d "apps/dashboard" ]; then
    echo "Building dashboard..."
    cd apps/dashboard
    npm install
    npm run build
    cp -r dist/* ../../priv/static/dashboard/
    cd ../..
fi

# Build admin if it exists
if [ -d "apps/admin" ]; then
    echo "Building admin..."
    cd apps/admin
    npm install
    npm run build
    cp -r dist/* ../../priv/static/admin/
    cd ../..
fi

# Build ecommerce if it exists
if [ -d "apps/ecommerce" ]; then
    echo "Building ecommerce..."
    cd apps/ecommerce
    npm install
    npm run build
    cp -r dist/* ../../priv/static/ecommerce/
    cd ../..
fi

# Build landing if it exists
if [ -d "apps/landing" ]; then
    echo "Building landing..."
    cd apps/landing
    npm install
    npm run build
    cp -r dist/* ../../priv/static/landing/
    cd ../..
fi

echo "Frontend builds completed!"