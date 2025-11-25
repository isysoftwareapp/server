# Firebase Export Instructions

## Prerequisites

1. Download your Firebase service account key:

   - Go to Firebase Console → Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save the JSON file as `serviceAccountKey.json` in this directory

2. Update `export-firebase.js`:
   - Replace `'your-project-id.appspot.com'` with your actual Firebase Storage bucket name

## Run Export

```powershell
# Install dependencies
npm install

# Run export
npm run export
```

## Output

The script will create a `migration-data/` directory containing:

- `products.json` - All products
- `customers.json` - All customers
- `orders.json` - All orders
- `categories.json` - All categories
- `admins.json` - Admin users (passwords will need to be re-hashed)
- `uploads/` - All uploaded files from Firebase Storage
- `export-summary.json` - Export statistics

## Next Steps

After exporting, run the Go migration script to import data into MongoDB:

```powershell
cd ../api/kiosk
go run migrate.go
```
