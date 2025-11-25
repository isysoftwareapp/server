# Firebase to MongoDB Migration - Quick Start

## Current Status: Ready to Export ✅

### Prerequisites Completed:

- ✅ Export script configured with your Firebase bucket: `candy-kush.firebasestorage.app`
- ✅ NPM dependencies installed
- ✅ Helper script created: `run-export.ps1`

---

## 🎯 **ACTION REQUIRED: Get Service Account Key**

### Step 1: Download Firebase Service Account Key

**Direct Link:** https://console.firebase.google.com/project/candy-kush/settings/serviceaccounts/adminsdk

**Instructions:**

1. Click the link above (opens Firebase Console)
2. Click the "Generate New Private Key" button
3. Click "Generate Key" in the confirmation dialog
4. Save the downloaded JSON file as:
   ```
   c:\Users\kevin\SynologyDrive\isy.software\isy.software\kiosk\scripts\serviceAccountKey.json
   ```

### Step 2: Run the Export

```powershell
cd c:\Users\kevin\SynologyDrive\isy.software\isy.software\kiosk\scripts
.\run-export.ps1
```

**This will:**

- Export all Firestore collections (products, customers, orders, categories, admins, etc.)
- Download all Firebase Storage files to `migration-data/uploads/`
- Create an export summary

**Expected Output:**

```
migration-data/
├── products.json
├── customers.json
├── orders.json
├── categories.json
├── admins.json
├── uploads/
│   └── (all your uploaded images/files)
└── export-summary.json
```

---

## 📊 **What Gets Exported**

The script will export the following Firestore collections:

- **products** - All product data
- **customers** - Customer information
- **orders** - Order history
- **transactions** - Transaction records
- **categories** - Product categories
- **subcategories** - Product subcategories
- **admins** - Admin users (passwords will be re-hashed in MongoDB)

Plus:

- All files from Firebase Storage

---

## 🔄 **After Export: Import to MongoDB**

Once the export completes successfully, run:

```powershell
cd c:\Users\kevin\SynologyDrive\isy.software\isy.software
.\migrate_kiosk_db.ps1 -ImportOnly
```

This will:

1. Start MongoDB (if not running)
2. Import all exported data into MongoDB
3. Hash admin passwords with bcrypt
4. Create default admin if none exist

---

## ⚠️ **Important Notes**

1. **Service Account Key Security**:

   - The `serviceAccountKey.json` file contains sensitive credentials
   - It's already in `.gitignore` - do NOT commit it to git
   - Keep it secure on your local machine only

2. **Firebase Project**:

   - Project: `candy-kush`
   - Storage: `candy-kush.firebasestorage.app`

3. **Backup**:
   - This export creates a backup of your Firebase data
   - Keep the `migration-data/` folder until migration is verified

---

## 🆘 **Troubleshooting**

### Error: "serviceAccountKey.json not found"

→ You need to download the service account key from Firebase Console (see Step 1)

### Error: "Permission denied" or "Authentication failed"

→ Make sure you downloaded the correct service account key for the `candy-kush` project

### Error: "Storage bucket not found"

→ The bucket name is already configured correctly, but verify in Firebase Console that Storage is enabled

---

## 📞 **Need Help?**

If you encounter any issues:

1. Check the error message in the console
2. Verify the service account key is in the correct location
3. Ensure you have admin access to the Firebase project
