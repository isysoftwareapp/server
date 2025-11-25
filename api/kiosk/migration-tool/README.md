# Kiosk MongoDB Migration Tool

This tool migrates Firebase data to MongoDB for the kiosk application.

## Prerequisites

1. Export Firebase data first using `kiosk/scripts/export-firebase.js`
2. Ensure MongoDB is running (via Docker or locally)
3. The migration data should be in `kiosk/migration-data/`

## Configuration

Edit `migrate.go` if needed:

- `mongoURI`: MongoDB connection string (default: localhost:27017)
- `dbName`: Database name (default: "kiosk")
- `migrationDataPath`: Path to migration data directory

## Run Migration

```powershell
# Install dependencies
go mod tidy

# Run migration
go run migrate.go
```

## What It Does

1. **Connects to MongoDB** using the specified connection string
2. **Migrates Collections**:
   - products
   - customers
   - orders
   - categories
   - subcategories
3. **Handles Admin Users**:
   - Hashes passwords using bcrypt
   - Creates default admin if none exist (username: admin, password: admin123)
4. **Transforms Data**:
   - Converts Firebase timestamps to MongoDB time.Time
   - Adds createdAt/updatedAt timestamps if missing
   - Handles nested objects and arrays

## Output

The script will:

- Drop existing collections (to avoid duplicates)
- Import all documents
- Report statistics for each collection
- Create a default admin if needed

## Important Notes

⚠️ **WARNING**: This script drops existing collections! Back up your data first.

⚠️ **Security**: Change default admin password immediately after migration.

## Troubleshooting

- **Connection failed**: Make sure MongoDB is running and accessible
- **File not found**: Verify migration data path is correct
- **Import errors**: Check JSON format in migration data files

## Next Steps

After successful migration:

1. Verify data in MongoDB using MongoDB Compass or CLI
2. Test API endpoints to ensure data is accessible
3. Update kiosk frontend to use API instead of Firebase
