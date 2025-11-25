package main

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func main() {
	fmt.Println("🚀 Starting base64 to file migration...")

	// Connect to MongoDB
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://admin:SecurePassword123!@localhost:27017/isy_api?authSource=admin"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	if err != nil {
		fmt.Printf("❌ Failed to connect to MongoDB: %v\n", err)
		return
	}
	defer client.Disconnect(context.Background())

	db := client.Database("isy_api")
	collection := db.Collection("metadata")

	// Create uploads directory
	uploadDir := "./uploads"
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		fmt.Printf("❌ Failed to create uploads directory: %v\n", err)
		return
	}

	// Find metadata documents
	cursor, err := collection.Find(context.Background(), bson.M{"type": "retail"})
	if err != nil {
		fmt.Printf("❌ Failed to query metadata: %v\n", err)
		return
	}
	defer cursor.Close(context.Background())

	stats := map[string]int{
		"processed": 0,
		"migrated":  0,
		"errors":    0,
	}

	for cursor.Next(context.Background()) {
		var doc bson.M
		if err := cursor.Decode(&doc); err != nil {
			continue
		}

		stats["processed"]++
		updated := false

		// Process content field
		content, ok := doc["content"].(bson.M)
		if !ok {
			continue
		}

		// Process pricing array for base64 images
		if pricing, ok := content["pricing"].(bson.A); ok {
			for i, item := range pricing {
				if planMap, ok := item.(bson.M); ok {
					if imgStr, ok := planMap["image"].(string); ok && strings.HasPrefix(imgStr, "data:image/") {
						// Extract base64 data
						parts := strings.SplitN(imgStr, ",", 2)
						if len(parts) != 2 {
							stats["errors"]++
							continue
						}

						// Decode base64
						imageData, err := base64.StdEncoding.DecodeString(parts[1])
						if err != nil {
							fmt.Printf("❌ Failed to decode base64 for pricing[%d]: %v\n", i, err)
							stats["errors"]++
							continue
						}

						// Determine extension from mime type
						mimeType := strings.TrimPrefix(strings.Split(parts[0], ";")[0], "data:")
						ext := ".png"
						switch mimeType {
						case "image/jpeg", "image/jpg":
							ext = ".jpg"
						case "image/png":
							ext = ".png"
						case "image/gif":
							ext = ".gif"
						case "image/webp":
							ext = ".webp"
						}

						// Generate unique filename
						randomBytes := make([]byte, 8)
						rand.Read(randomBytes)
						planName := strings.ToLower(strings.ReplaceAll(planMap["name"].(string), " ", "-"))
						filename := fmt.Sprintf("pricing-%s-%s%s", planName, hex.EncodeToString(randomBytes), ext)
						filePath := filepath.Join(uploadDir, filename)

						// Save file
						if err := os.WriteFile(filePath, imageData, 0644); err != nil {
							fmt.Printf("❌ Failed to save file %s: %v\n", filename, err)
							stats["errors"]++
							continue
						}

						// Update with file URL
						planMap["image"] = fmt.Sprintf("/uploads/%s", filename)
						pricing[i] = planMap
						updated = true
						stats["migrated"]++
						fmt.Printf("✅ Migrated pricing[%d]: %s -> %s\n", i, planName, filename)
					}
				}
			}
			if updated {
				content["pricing"] = pricing
			}
		}

		// Process images object for base64
		if images, ok := content["images"].(bson.M); ok {
			for key, value := range images {
				if strVal, ok := value.(string); ok && strings.HasPrefix(strVal, "data:image/") {
					parts := strings.SplitN(strVal, ",", 2)
					if len(parts) != 2 {
						stats["errors"]++
						continue
					}

					imageData, err := base64.StdEncoding.DecodeString(parts[1])
					if err != nil {
						fmt.Printf("❌ Failed to decode base64 for images.%s: %v\n", key, err)
						stats["errors"]++
						continue
					}

					mimeType := strings.TrimPrefix(strings.Split(parts[0], ";")[0], "data:")
					ext := ".png"
					switch mimeType {
					case "image/jpeg", "image/jpg":
						ext = ".jpg"
					case "image/png":
						ext = ".png"
					case "image/gif":
						ext = ".gif"
					case "image/webp":
						ext = ".webp"
					}

					randomBytes := make([]byte, 8)
					rand.Read(randomBytes)
					filename := fmt.Sprintf("image-%s-%s%s", key, hex.EncodeToString(randomBytes), ext)
					filePath := filepath.Join(uploadDir, filename)

					if err := os.WriteFile(filePath, imageData, 0644); err != nil {
						fmt.Printf("❌ Failed to save file %s: %v\n", filename, err)
						stats["errors"]++
						continue
					}

					images[key] = fmt.Sprintf("/uploads/%s", filename)
					updated = true
					stats["migrated"]++
					fmt.Printf("✅ Migrated images.%s -> %s\n", key, filename)
				}
			}
			if updated {
				content["images"] = images
			}
		}

		// Update document if changes were made
		if updated {
			doc["content"] = content
			doc["updatedAt"] = time.Now()

			_, err := collection.ReplaceOne(
				context.Background(),
				bson.M{"_id": doc["_id"]},
				doc,
			)
			if err != nil {
				fmt.Printf("❌ Failed to update document: %v\n", err)
				stats["errors"]++
			} else {
				fmt.Println("✅ Document updated in database")
			}
		}
	}

	fmt.Println("\n📊 Migration Statistics:")
	fmt.Printf("   Processed: %d documents\n", stats["processed"])
	fmt.Printf("   Migrated: %d images\n", stats["migrated"])
	fmt.Printf("   Errors: %d\n", stats["errors"])
	fmt.Println("\n✅ Migration complete!")
}
