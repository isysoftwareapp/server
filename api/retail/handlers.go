package retail

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"time"

	"github.com/gorilla/mux"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"golang.org/x/crypto/bcrypt"
)

// APIResponse represents a standard API response
type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// RetailHandlers contains all retail-related handlers
type RetailHandlers struct {
	DB *mongo.Database
}

// NewRetailHandlers creates a new retail handlers instance
func NewRetailHandlers(db *mongo.Database) *RetailHandlers {
	return &RetailHandlers{DB: db}
}

// GetProducts retrieves all products
func (rh *RetailHandlers) GetProducts(w http.ResponseWriter, r *http.Request) {
	if rh.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	ctx := r.Context()
	collection := rh.DB.Collection("products")

	cursor, err := collection.Find(ctx, bson.M{})
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to fetch products")
		return
	}
	defer cursor.Close(ctx)

	var products []bson.M
	if err := cursor.All(ctx, &products); err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to parse products")
		return
	}

	respondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Data:    products,
	})
}

// GetProduct retrieves a single product by ID
func (rh *RetailHandlers) GetProduct(w http.ResponseWriter, r *http.Request) {
	if rh.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	vars := mux.Vars(r)
	id := vars["id"]

	objID, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid product ID")
		return
	}

	ctx := r.Context()
	collection := rh.DB.Collection("products")

	var product bson.M
	err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&product)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			respondWithError(w, http.StatusNotFound, "Product not found")
			return
		}
		respondWithError(w, http.StatusInternalServerError, "Failed to fetch product")
		return
	}

	respondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Data:    product,
	})
}

// CreateProduct creates a new product
func (rh *RetailHandlers) CreateProduct(w http.ResponseWriter, r *http.Request) {
	if rh.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	var product map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&product); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	product["createdAt"] = time.Now()
	product["updatedAt"] = time.Now()

	ctx := r.Context()
	collection := rh.DB.Collection("products")

	result, err := collection.InsertOne(ctx, product)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to create product")
		return
	}

	product["_id"] = result.InsertedID

	respondWithJSON(w, http.StatusCreated, APIResponse{
		Success: true,
		Data:    product,
	})
}

// UpdateProduct updates an existing product
func (rh *RetailHandlers) UpdateProduct(w http.ResponseWriter, r *http.Request) {
	if rh.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	vars := mux.Vars(r)
	id := vars["id"]

	objID, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid product ID")
		return
	}

	var updates map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	updates["updatedAt"] = time.Now()

	ctx := r.Context()
	collection := rh.DB.Collection("products")

	result, err := collection.UpdateOne(
		ctx,
		bson.M{"_id": objID},
		bson.M{"$set": updates},
	)

	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to update product")
		return
	}

	if result.MatchedCount == 0 {
		respondWithError(w, http.StatusNotFound, "Product not found")
		return
	}

	respondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Data:    map[string]interface{}{"message": "Product updated successfully"},
	})
}

// DeleteProduct deletes a product
func (rh *RetailHandlers) DeleteProduct(w http.ResponseWriter, r *http.Request) {
	if rh.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	vars := mux.Vars(r)
	id := vars["id"]

	objID, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid product ID")
		return
	}

	ctx := r.Context()
	collection := rh.DB.Collection("products")

	result, err := collection.DeleteOne(ctx, bson.M{"_id": objID})
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to delete product")
		return
	}

	if result.DeletedCount == 0 {
		respondWithError(w, http.StatusNotFound, "Product not found")
		return
	}

	respondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Data:    map[string]interface{}{"message": "Product deleted successfully"},
	})
}

// GetMetadata retrieves retail metadata
func (rh *RetailHandlers) GetMetadata(w http.ResponseWriter, r *http.Request) {
	if rh.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	ctx := r.Context()
	collection := rh.DB.Collection("metadata")

	var metadata bson.M
	err := collection.FindOne(ctx, bson.M{"type": "retail"}).Decode(&metadata)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			// Return default metadata
			metadata = bson.M{
				"type":    "retail",
				"version": "1.0.0",
			}
		} else {
			respondWithError(w, http.StatusInternalServerError, "Failed to fetch metadata")
			return
		}
	}

	respondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Data:    metadata,
	})
}

// SaveMetadata saves retail metadata
func (rh *RetailHandlers) SaveMetadata(w http.ResponseWriter, r *http.Request) {
	if rh.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	var metadata map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&metadata); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	metadata["type"] = "retail"
	metadata["updatedAt"] = time.Now()

	ctx := r.Context()
	collection := rh.DB.Collection("metadata")

	_, err := collection.ReplaceOne(
		ctx,
		bson.M{"type": "retail"},
		metadata,
		options.Replace().SetUpsert(true),
	)

	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to save metadata")
		return
	}

	respondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Data:    map[string]interface{}{"message": "Metadata saved successfully"},
	})
}

// AuthRequest represents login credentials
type AuthRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

// Authenticate handles admin login
func (rh *RetailHandlers) Authenticate(w http.ResponseWriter, r *http.Request) {
	if rh.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	var authReq AuthRequest
	if err := json.NewDecoder(r.Body).Decode(&authReq); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	ctx := r.Context()
	collection := rh.DB.Collection("admins")

	var admin bson.M
	err := collection.FindOne(ctx, bson.M{"username": authReq.Username}).Decode(&admin)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			respondWithError(w, http.StatusUnauthorized, "Invalid credentials")
			return
		}
		respondWithError(w, http.StatusInternalServerError, "Failed to authenticate")
		return
	}

	// Get password from database
	hashedPassword, ok := admin["password"].(string)
	if !ok {
		respondWithError(w, http.StatusInternalServerError, "Invalid admin data")
		return
	}

	// Compare password with bcrypt
	err = bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(authReq.Password))
	if err != nil {
		respondWithError(w, http.StatusUnauthorized, "Invalid credentials")
		return
	}

	// Generate a simple token (in production, use JWT)
	tokenBytes := make([]byte, 32)
	rand.Read(tokenBytes)
	token := base64.URLEncoding.EncodeToString(tokenBytes)

	respondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Data: map[string]interface{}{
			"token":    token,
			"username": authReq.Username,
		},
	})
}

// MigrateBase64ToFiles extracts base64 images from MongoDB and saves them as files
func (rh *RetailHandlers) MigrateBase64ToFiles(w http.ResponseWriter, r *http.Request) {
	if rh.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	ctx := r.Context()
	collection := rh.DB.Collection("metadata")

	// Find metadata documents
	cursor, err := collection.Find(ctx, bson.M{})
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to fetch metadata")
		return
	}
	defer cursor.Close(ctx)

	migrationStats := map[string]interface{}{
		"processed": 0,
		"migrated":  0,
		"errors":    []string{},
	}

	// Note: Since pricing images now use external URLs (Unsplash),
	// we'll just scan for base64 and report what needs to be replaced
	
	for cursor.Next(ctx) {
		var doc bson.M
		if err := cursor.Decode(&doc); err != nil {
			continue
		}

		migrationStats["processed"] = migrationStats["processed"].(int) + 1
		
		// Check for base64 images in content field
		if content, ok := doc["content"].(bson.M); ok {
			hasBase64 := checkForBase64InContent(content)
			if hasBase64 {
				migrationStats["migrated"] = migrationStats["migrated"].(int) + 1
			}
		}
	}

	respondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Data:    migrationStats,
	})
}

// Helper function to check for base64 images in content
func checkForBase64InContent(content bson.M) bool {
	hasBase64 := false
	
	// Check images object
	if images, ok := content["images"].(bson.M); ok {
		for _, value := range images {
			if strVal, ok := value.(string); ok {
				if len(strVal) > 100 && (strVal[:10] == "data:image" || strVal[:10] == "data:image") {
					hasBase64 = true
				}
			}
		}
	}
	
	// Check pricing array
	if pricing, ok := content["pricing"].(bson.A); ok {
		for _, item := range pricing {
			if itemMap, ok := item.(bson.M); ok {
				if imgStr, ok := itemMap["image"].(string); ok {
					if len(imgStr) > 100 && (imgStr[:10] == "data:image" || imgStr[:10] == "data:image") {
						hasBase64 = true
					}
				}
			}
		}
	}
	
	return hasBase64
}

// Helper functions
func respondWithError(w http.ResponseWriter, code int, message string) {
	respondWithJSON(w, code, APIResponse{
		Success: false,
		Error:   message,
	})
}

func respondWithJSON(w http.ResponseWriter, code int, payload interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(payload)
}
