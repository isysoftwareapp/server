/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 *
 * Migration script to remove base64 images from MongoDB
 * This script will clear all base64 image data from the site content
 */

import { MongoClient } from "mongodb";

const MONGO_URI = process.env.MONGO_URI || "mongodb://localhost:27017/retail";

async function migrateImages() {
  console.log("🚀 Starting image migration...");
  console.log("📡 Connecting to MongoDB:", MONGO_URI);

  const client = new MongoClient(MONGO_URI);

  try {
    await client.connect();
    const db = client.db("retail");
    const contents = db.collection("contents");

    console.log("✅ Connected to MongoDB");

    // Fetch current content
    const siteContent = await contents.findOne({ type: "site" });

    if (!siteContent) {
      console.log("❌ No site content found");
      return;
    }

    console.log("📄 Found site content");

    // Check if there are any base64 images
    const content = siteContent.content;
    let hasBase64 = false;

    const checkBase64 = (obj: any, path: string = "") => {
      for (const key in obj) {
        if (typeof obj[key] === "string" && obj[key].startsWith("data:image")) {
          console.log(`🔍 Found base64 image at: ${path}.${key}`);
          console.log(
            `   Size: ${(obj[key].length / 1024).toFixed(2)} KB (${
              obj[key].length
            } bytes)`
          );
          hasBase64 = true;
        } else if (typeof obj[key] === "object" && obj[key] !== null) {
          checkBase64(obj[key], `${path}.${key}`);
        }
      }
    };

    checkBase64(content, "content");

    if (!hasBase64) {
      console.log("✅ No base64 images found. Database is already clean!");
      return;
    }

    console.log("\n⚠️  Base64 images found in database!");
    console.log("⚠️  These should be replaced with file uploads.");
    console.log("\n📝 To clean the database, you have two options:\n");
    console.log("   1. Upload new images through the admin panel");
    console.log("   2. Run this script with --force to clear all image URLs\n");

    // Check if force flag is provided
    if (process.argv.includes("--force")) {
      console.log("🧹 Force mode enabled. Clearing all image data...\n");

      // Clear all image fields
      const clearImages = (obj: any) => {
        for (const key in obj) {
          if (
            typeof obj[key] === "string" &&
            obj[key].startsWith("data:image")
          ) {
            obj[key] = null;
            console.log(`   Cleared: ${key}`);
          } else if (typeof obj[key] === "object" && obj[key] !== null) {
            clearImages(obj[key]);
          }
        }
      };

      clearImages(content);

      // Update database
      await contents.updateOne(
        { type: "site" },
        {
          $set: {
            content,
            updatedAt: new Date(),
            migratedAt: new Date(),
          },
        }
      );

      console.log(
        "\n✅ All base64 images have been cleared from the database!"
      );
      console.log("📝 Please upload new images through the admin panel.");
    } else {
      console.log("ℹ️  Run with --force flag to clear all image data:");
      console.log("   npm run migrate -- --force\n");
    }
  } catch (error) {
    console.error("💥 Migration error:", error);
  } finally {
    await client.close();
    console.log("👋 MongoDB connection closed");
  }
}

migrateImages();
