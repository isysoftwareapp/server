#!/bin/bash

# Deploy Retail API with MongoDB

echo "🚀 Deploying Retail API Server..."

# Navigate to retail server directory
cd /root/retail/server || exit 1

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Build TypeScript
echo "🔨 Building TypeScript..."
npm run build

# Navigate back to root
cd /root || exit 1

# Rebuild and restart containers
echo "🐳 Rebuilding Docker containers..."
docker compose build retail-api
docker compose up -d retail-api

# Check status
echo "✅ Checking container status..."
docker compose ps | grep retail-api

echo "🎉 Deployment complete!"
echo "📊 API available at: https://isy.software/api/"
echo "🔑 Default credentials: username=admin, password=admin123"
