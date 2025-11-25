package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"golang.org/x/crypto/bcrypt"
)

const (
	// MongoDB connection string
	mongoURI = "mongodb://admin:SecurePassword123!@localhost:27017/kiosk?authSource=admin"
	dbName   = "kiosk"
	
	// Path to migration data
	migrationDataPath = "../../kiosk/migration-data"
)

// RawDocument represents a generic document structure
type RawDocument map[string]interface{}

func main() {
	fmt.Println("🚀 Starting MongoDB migration...")
	
	// Connect to MongoDB
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	
	client, err := mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	if err != nil {
		log.Fatalf("❌ Failed to connect to MongoDB: %v", err)
	}
	defer client.Disconnect(ctx)
	
	// Ping MongoDB
	if err := client.Ping(ctx, nil); err != nil {
		log.Fatalf("❌ Failed to ping MongoDB: %v", err)
	}
	fmt.Println("✅ Connected to MongoDB")
	
	db := client.Database(dbName)
	
	// Migrate collections
	collections := []string{"products", "customers", "orders", "categories", "subcategories"}
	
	for _, collName := range collections {
		if err := migrateCollection(ctx, db, collName); err != nil {
			log.Printf("⚠️  Warning: Failed to migrate %s: %v", collName, err)
		}
	}
	
	// Special handling for admins (hash passwords)
	if err := migrateAdmins(ctx, db); err != nil {
		log.Printf("⚠️  Warning: Failed to migrate admins: %v", err)
	}
	
	fmt.Println("\n✅ Migration complete!")
}

// migrateCollection imports a JSON file into a MongoDB collection
func migrateCollection(ctx context.Context, db *mongo.Database, collectionName string) error {
	fmt.Printf("\n📦 Migrating collection: %s...\n", collectionName)
	
	// Read JSON file
	filePath := filepath.Join(migrationDataPath, collectionName+".json")
	data, err := ioutil.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Printf("⚠️  File not found: %s (skipping)\n", filePath)
			return nil
		}
		return fmt.Errorf("failed to read file: %w", err)
	}
	
	// Parse JSON
	var documents []RawDocument
	if err := json.Unmarshal(data, &documents); err != nil {
		return fmt.Errorf("failed to parse JSON: %w", err)
	}
	
	if len(documents) == 0 {
		fmt.Printf("⚠️  No documents found in %s\n", collectionName)
		return nil
	}
	
	// Transform documents
	var transformed []interface{}
	for _, doc := range documents {
		transformed = append(transformed, transformDocument(doc))
	}
	
	// Drop existing collection (optional - comment out if you want to preserve existing data)
	db.Collection(collectionName).Drop(ctx)
	
	// Insert documents
	collection := db.Collection(collectionName)
	result, err := collection.InsertMany(ctx, transformed)
	if err != nil {
		return fmt.Errorf("failed to insert documents: %w", err)
	}
	
	fmt.Printf("✅ Imported %d documents into %s\n", len(result.InsertedIDs), collectionName)
	return nil
}

// transformDocument converts Firebase data to MongoDB format
func transformDocument(doc RawDocument) bson.M {
	transformed := bson.M{}
	
	for key, value := range doc {
		// Skip the Firebase ID if it exists
		if key == "id" {
			continue
		}
		
		// Convert ISO timestamp strings to time.Time
		if strVal, ok := value.(string); ok {
			if t, err := time.Parse(time.RFC3339, strVal); err == nil {
				transformed[key] = t
				continue
			}
		}
		
		// Handle nested objects recursively
		if mapVal, ok := value.(map[string]interface{}); ok {
			transformed[key] = transformDocument(mapVal)
			continue
		}
		
		// Handle arrays
		if arrVal, ok := value.([]interface{}); ok {
			transformedArr := make([]interface{}, len(arrVal))
			for i, item := range arrVal {
				if itemMap, ok := item.(map[string]interface{}); ok {
					transformedArr[i] = transformDocument(itemMap)
				} else {
					transformedArr[i] = item
				}
			}
			transformed[key] = transformedArr
			continue
		}
		
		transformed[key] = value
	}
	
	// Add timestamps if they don't exist
	if _, exists := transformed["createdAt"]; !exists {
		transformed["createdAt"] = time.Now()
	}
	if _, exists := transformed["updatedAt"]; !exists {
		transformed["updatedAt"] = time.Now()
	}
	
	return transformed
}

// migrateAdmins handles admin migration with password hashing
func migrateAdmins(ctx context.Context, db *mongo.Database) error {
	fmt.Printf("\n🔐 Migrating admins with password hashing...\n")
	
	filePath := filepath.Join(migrationDataPath, "admins.json")
	data, err := ioutil.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Println("⚠️  No admins.json found, creating default admin...")
			return createDefaultAdmin(ctx, db)
		}
		return fmt.Errorf("failed to read admins file: %w", err)
	}
	
	var admins []RawDocument
	if err := json.Unmarshal(data, &admins); err != nil {
		return fmt.Errorf("failed to parse admins JSON: %w", err)
	}
	
	// Drop existing admins collection
	db.Collection("admins").Drop(ctx)
	
	collection := db.Collection("admins")
	
	for _, admin := range admins {
		// Hash password if it exists
		if password, ok := admin["password"].(string); ok {
			hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
			if err != nil {
				log.Printf("⚠️  Failed to hash password for %s: %v", admin["username"], err)
				continue
			}
			admin["password"] = string(hashedPassword)
		} else {
			// If no password, set a default one
			hashedPassword, _ := bcrypt.GenerateFromPassword([]byte("changeme123"), bcrypt.DefaultCost)
			admin["password"] = string(hashedPassword)
			fmt.Printf("⚠️  No password found for %s, set default: changeme123\n", admin["username"])
		}
		
		transformed := transformDocument(admin)
		transformed["_id"] = primitive.NewObjectID()
		
		if _, err := collection.InsertOne(ctx, transformed); err != nil {
			log.Printf("⚠️  Failed to insert admin %s: %v", admin["username"], err)
		} else {
			fmt.Printf("✅ Imported admin: %s\n", admin["username"])
		}
	}
	
	return nil
}

// createDefaultAdmin creates a default admin user if none exist
func createDefaultAdmin(ctx context.Context, db *mongo.Database) error {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte("admin123"), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}
	
	admin := bson.M{
		"_id":       primitive.NewObjectID(),
		"username":  "admin",
		"password":  string(hashedPassword),
		"email":     "admin@isy.software",
		"role":      "admin",
		"isActive":  true,
		"createdAt": time.Now(),
		"updatedAt": time.Now(),
	}
	
	collection := db.Collection("admins")
	if _, err := collection.InsertOne(ctx, admin); err != nil {
		return fmt.Errorf("failed to create default admin: %w", err)
	}
	
	fmt.Println("✅ Created default admin (username: admin, password: admin123)")
	fmt.Println("⚠️  IMPORTANT: Change this password immediately!")
	
	return nil
}
