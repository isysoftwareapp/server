/**
 * Firebase Data Export Script for Kiosk Migration
 * Exports Firestore collections and Storage files to local directory
 *
 * Usage: node export-firebase.js
 * Output: ./migration-data/ directory with JSON files and uploads
 */

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const https = require("https");

// Initialize Firebase Admin SDK
// NOTE: You need to download your service account key from Firebase Console
// and save it as serviceAccountKey.json in this directory
try {
  const serviceAccount = require("./serviceAccountKey.json");

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: "your-project-id.appspot.com", // Replace with your actual bucket
  });

  console.log("✅ Firebase Admin initialized successfully");
} catch (error) {
  console.error("❌ Error initializing Firebase Admin:", error.message);
  console.log("\nPlease:");
  console.log("1. Download your service account key from Firebase Console");
  console.log("2. Save it as serviceAccountKey.json in kiosk/scripts/");
  console.log("3. Update the storageBucket value above");
  process.exit(1);
}

const db = admin.firestore();
const bucket = admin.storage().bucket();

// Output directory
const OUTPUT_DIR = path.join(__dirname, "../migration-data");
const UPLOADS_DIR = path.join(OUTPUT_DIR, "uploads");

// Ensure output directories exist
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

/**
 * Export a Firestore collection to JSON
 */
async function exportCollection(collectionName) {
  console.log(`\n📦 Exporting collection: ${collectionName}...`);

  try {
    const snapshot = await db.collection(collectionName).get();
    const documents = [];

    snapshot.forEach((doc) => {
      const data = doc.data();

      // Convert Firestore timestamps to ISO strings
      Object.keys(data).forEach((key) => {
        if (data[key] && typeof data[key].toDate === "function") {
          data[key] = data[key].toDate().toISOString();
        }
      });

      documents.push({
        id: doc.id,
        ...data,
      });
    });

    const outputPath = path.join(OUTPUT_DIR, `${collectionName}.json`);
    fs.writeFileSync(outputPath, JSON.stringify(documents, null, 2));

    console.log(
      `✅ Exported ${documents.length} documents to ${collectionName}.json`
    );
    return documents.length;
  } catch (error) {
    console.error(`❌ Error exporting ${collectionName}:`, error.message);
    return 0;
  }
}

/**
 * Download a file from Firebase Storage
 */
async function downloadFile(filePath, localPath) {
  try {
    const file = bucket.file(filePath);
    const [exists] = await file.exists();

    if (!exists) {
      console.log(`⚠️  File not found: ${filePath}`);
      return false;
    }

    await file.download({ destination: localPath });
    return true;
  } catch (error) {
    console.error(`❌ Error downloading ${filePath}:`, error.message);
    return false;
  }
}

/**
 * Export Firebase Storage files
 */
async function exportStorage() {
  console.log("\n📁 Exporting Firebase Storage files...");

  try {
    const [files] = await bucket.getFiles();

    let downloaded = 0;
    for (const file of files) {
      const fileName = path.basename(file.name);
      const localPath = path.join(UPLOADS_DIR, fileName);

      console.log(`  Downloading: ${file.name}...`);
      const success = await downloadFile(file.name, localPath);
      if (success) downloaded++;
    }

    console.log(`✅ Downloaded ${downloaded}/${files.length} files`);
    return downloaded;
  } catch (error) {
    console.error("❌ Error exporting storage:", error.message);
    return 0;
  }
}

/**
 * Main export function
 */
async function exportAllData() {
  console.log("🚀 Starting Firebase data export...");
  console.log(`📂 Output directory: ${OUTPUT_DIR}\n`);

  const startTime = Date.now();
  const stats = {};

  // Collections to export (adjust based on your Firestore structure)
  const collections = [
    "products",
    "customers",
    "orders",
    "transactions",
    "categories",
    "subcategories",
    "admins",
  ];

  // Export each collection
  for (const collection of collections) {
    stats[collection] = await exportCollection(collection);
  }

  // Export storage files
  stats.storageFiles = await exportStorage();

  // Create summary file
  const summary = {
    exportDate: new Date().toISOString(),
    duration: `${((Date.now() - startTime) / 1000).toFixed(2)}s`,
    statistics: stats,
    totalDocuments:
      Object.values(stats).reduce((sum, count) => sum + count, 0) -
      stats.storageFiles,
    totalFiles: stats.storageFiles,
  };

  fs.writeFileSync(
    path.join(OUTPUT_DIR, "export-summary.json"),
    JSON.stringify(summary, null, 2)
  );

  console.log("\n✅ Export complete!");
  console.log("📊 Summary:");
  console.log(`   Total documents: ${summary.totalDocuments}`);
  console.log(`   Total files: ${summary.totalFiles}`);
  console.log(`   Duration: ${summary.duration}`);
  console.log(`\n📂 Output: ${OUTPUT_DIR}`);
}

// Run the export
exportAllData()
  .then(() => {
    console.log("\n✅ All done! You can now run the MongoDB migration script.");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ Export failed:", error);
    process.exit(1);
  });
