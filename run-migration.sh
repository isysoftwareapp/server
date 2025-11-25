#!/bin/bash

# Script to run base64 to file migration inside the API container

echo "🚀 Running base64 to file migration..."
echo ""

# Check if isy-api container is running
if ! docker ps | grep -q isy-api; then
    echo "❌ Error: isy-api container is not running"
    echo "Please start the API container first with:"
    echo "  docker-compose up -d"
    exit 1
fi

# Build migration tool inside container
echo "📦 Building migration tool..."
docker exec isy-api sh -c "cd /app/cmd/migrate-base64 && go build -o /app/migrate-base64 ."

if [ $? -ne 0 ]; then
    echo "❌ Failed to build migration tool"
    exit 1
fi

# Run migration
echo ""
echo "🔄 Running migration..."
echo ""
docker exec isy-api sh -c "cd /app && MONGO_URI=\$MONGO_URI ./migrate-base64"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Migration completed successfully!"
    echo ""
    echo "📁 Uploaded files are now in the uploads directory"
    echo "🌐 Files are accessible at: http://YOUR_DOMAIN/uploads/"
else
    echo ""
    echo "❌ Migration failed"
    exit 1
fi
