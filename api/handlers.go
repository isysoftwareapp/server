package main

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gorilla/mux"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// SiteContent represents the structure of site content
type SiteContent struct {
	Type      string                 `json:"type" bson:"type"`
	Content   map[string]interface{} `json:"content" bson:"content"`
	UpdatedAt time.Time             `json:"updatedAt" bson:"updatedAt"`
}

// APIResponse represents a standard API response
type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// healthCheck handles health check requests
func (a *App) healthCheck(w http.ResponseWriter, r *http.Request) {
	response := APIResponse{
		Success: true,
		Data: map[string]interface{}{
			"status":    "ok",
			"timestamp": time.Now().Format(time.RFC3339),
			"service":   "isy-api",
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// getContent retrieves site content from MongoDB
func (a *App) getContent(w http.ResponseWriter, r *http.Request) {
	if a.DB == nil {
		response := APIResponse{
			Success: false,
			Error:   "Database not available",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(response)
		return
	}

	ctx := r.Context()
	collection := a.DB.Collection("contents")

	var content SiteContent
	err := collection.FindOne(ctx, bson.M{"type": "site"}).Decode(&content)

	if err != nil {
		if err == mongo.ErrNoDocuments {
			// Return default content if none exists
			response := APIResponse{
				Success: true,
				Data: map[string]interface{}{
					"type": "site",
					"content": getDefaultContent(),
				},
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(response)
			return
		}
		response := APIResponse{
			Success: false,
			Error:   "Failed to fetch content",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(response)
		return
	}

	response := APIResponse{
		Success: true,
		Data:    content,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// saveContent saves site content to MongoDB
func (a *App) saveContent(w http.ResponseWriter, r *http.Request) {
	if a.DB == nil {
		response := APIResponse{
			Success: false,
			Error:   "Database not available",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(response)
		return
	}

	ctx := r.Context()

	var requestData struct {
		Content map[string]interface{} `json:"content"`
	}

	if err := json.NewDecoder(r.Body).Decode(&requestData); err != nil {
		response := APIResponse{
			Success: false,
			Error:   "Invalid JSON",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(response)
		return
	}

	if requestData.Content == nil {
		response := APIResponse{
			Success: false,
			Error:   "Content is required",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(response)
		return
	}

	collection := a.DB.Collection("contents")

	content := SiteContent{
		Type:      "site",
		Content:   requestData.Content,
		UpdatedAt: time.Now(),
	}

	_, err := collection.ReplaceOne(
		ctx,
		bson.M{"type": "site"},
		content,
		options.Replace().SetUpsert(true),
	)

	if err != nil {
		response := APIResponse{
			Success: false,
			Error:   "Failed to save content",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(response)
		return
	}

	response := APIResponse{
		Success: true,
		Data:    map[string]string{"message": "Content saved successfully"},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// uploadFile handles file uploads
func (a *App) uploadFile(w http.ResponseWriter, r *http.Request) {
	// Parse multipart form with max 10MB
	if err := r.ParseMultipartForm(10 << 20); err != nil {
		response := APIResponse{
			Success: false,
			Error:   "File too large or invalid form data",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(response)
		return
	}

	file, handler, err := r.FormFile("file")
	if err != nil {
		response := APIResponse{
			Success: false,
			Error:   "No file provided",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(response)
		return
	}
	defer file.Close()

	// Validate file type (images only)
	contentType := handler.Header.Get("Content-Type")
	if !strings.HasPrefix(contentType, "image/") {
		response := APIResponse{
			Success: false,
			Error:   "Only image files are allowed",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(response)
		return
	}

	// Generate unique filename
	ext := filepath.Ext(handler.Filename)
	randomBytes := make([]byte, 16)
	rand.Read(randomBytes)
	uniqueFilename := hex.EncodeToString(randomBytes) + ext

	// Ensure uploads directory exists
	uploadDir := "/root/uploads"
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		response := APIResponse{
			Success: false,
			Error:   "Failed to create upload directory",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(response)
		return
	}

	// Create destination file
	filePath := filepath.Join(uploadDir, uniqueFilename)
	dst, err := os.Create(filePath)
	if err != nil {
		response := APIResponse{
			Success: false,
			Error:   "Failed to save file",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(response)
		return
	}
	defer dst.Close()

	// Copy file content
	if _, err := io.Copy(dst, file); err != nil {
		response := APIResponse{
			Success: false,
			Error:   "Failed to save file",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(response)
		return
	}

	// Return the public URL
	publicURL := fmt.Sprintf("/uploads/%s", uniqueFilename)

	response := APIResponse{
		Success: true,
		Data: map[string]interface{}{
			"url":      publicURL,
			"filename": handler.Filename,
			"size":     handler.Size,
			"type":     contentType,
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// deleteFile handles file deletion
func (a *App) deleteFile(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	filename := vars["filename"]

	if filename == "" {
		response := APIResponse{
			Success: false,
			Error:   "Filename is required",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(response)
		return
	}

	// Sanitize filename to prevent directory traversal
	filename = filepath.Base(filename)

	// Delete file
	uploadDir := "/root/uploads"
	filePath := filepath.Join(uploadDir, filename)

	if err := os.Remove(filePath); err != nil {
		if os.IsNotExist(err) {
			response := APIResponse{
				Success: false,
				Error:   "File not found",
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusNotFound)
			json.NewEncoder(w).Encode(response)
			return
		}

		response := APIResponse{
			Success: false,
			Error:   "Failed to delete file",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(response)
		return
	}

	response := APIResponse{
		Success: true,
		Data:    map[string]string{"message": "File deleted successfully"},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// migrateBase64ToFiles migrates base64 images in metadata to file storage
func (a *App) migrateBase64ToFiles(w http.ResponseWriter, r *http.Request) {
	if a.DB == nil {
		response := APIResponse{
			Success: false,
			Error:   "Database not available",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(response)
		return
	}

	ctx := r.Context()
	collection := a.DB.Collection("metadata")

	// Find metadata with base64 images
	cursor, err := collection.Find(ctx, bson.M{})
	if err != nil {
		response := APIResponse{
			Success: false,
			Error:   "Failed to fetch metadata",
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(response)
		return
	}
	defer cursor.Close(ctx)

	migrationStats := map[string]interface{}{
		"processed": 0,
		"migrated":  0,
		"errors":    []string{},
	}

	uploadDir := "/root/uploads"
	os.MkdirAll(uploadDir, 0755)

	for cursor.Next(ctx) {
		var doc bson.M
		if err := cursor.Decode(&doc); err != nil {
			continue
		}

		migrationStats["processed"] = migrationStats["processed"].(int) + 1
		updated := false

		// Process content field
		if content, ok := doc["content"].(bson.M); ok {
			// Process images object
			if images, ok := content["images"].(bson.M); ok {
				for key, value := range images {
					if strVal, ok := value.(string); ok && strings.HasPrefix(strVal, "data:image/") {
						// Extract base64 data
						parts := strings.SplitN(strVal, ",", 2)
						if len(parts) != 2 {
							continue
						}

						// Decode base64
						imageData, err := base64.StdEncoding.DecodeString(parts[1])
						if err != nil {
							migrationStats["errors"] = append(migrationStats["errors"].([]string), 
								fmt.Sprintf("Failed to decode base64 for %s", key))
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
						randomBytes := make([]byte, 16)
						rand.Read(randomBytes)
						filename := fmt.Sprintf("%s_%s%s", key, hex.EncodeToString(randomBytes), ext)
						filePath := filepath.Join(uploadDir, filename)

						// Save file
						if err := os.WriteFile(filePath, imageData, 0644); err != nil {
							migrationStats["errors"] = append(migrationStats["errors"].([]string), 
								fmt.Sprintf("Failed to save file for %s: %v", key, err))
							continue
						}

						// Update with public URL
						images[key] = fmt.Sprintf("/uploads/%s", filename)
						updated = true
					}
				}
			}

			// Process features array for images
			if features, ok := content["features"].(bson.A); ok {
				for i, feature := range features {
					if featMap, ok := feature.(bson.M); ok {
						if imgStr, ok := featMap["image"].(string); ok && strings.HasPrefix(imgStr, "data:image/") {
							parts := strings.SplitN(imgStr, ",", 2)
							if len(parts) == 2 {
								imageData, err := base64.StdEncoding.DecodeString(parts[1])
								if err == nil {
									mimeType := strings.TrimPrefix(strings.Split(parts[0], ";")[0], "data:")
									ext := ".png"
									if strings.Contains(mimeType, "jpeg") || strings.Contains(mimeType, "jpg") {
										ext = ".jpg"
									}

									randomBytes := make([]byte, 16)
									rand.Read(randomBytes)
									filename := fmt.Sprintf("feature_%d_%s%s", i, hex.EncodeToString(randomBytes), ext)
									filePath := filepath.Join(uploadDir, filename)

									if err := os.WriteFile(filePath, imageData, 0644); err == nil {
										featMap["image"] = fmt.Sprintf("/uploads/%s", filename)
										updated = true
									}
								}
							}
						}
					}
				}
			}

			// Process products array
			if products, ok := content["products"].(bson.A); ok {
				for i, product := range products {
					if prodMap, ok := product.(bson.M); ok {
						if imgStr, ok := prodMap["image"].(string); ok && strings.HasPrefix(imgStr, "data:image/") {
							parts := strings.SplitN(imgStr, ",", 2)
							if len(parts) == 2 {
								imageData, err := base64.StdEncoding.DecodeString(parts[1])
								if err == nil {
									mimeType := strings.TrimPrefix(strings.Split(parts[0], ";")[0], "data:")
									ext := ".png"
									if strings.Contains(mimeType, "jpeg") || strings.Contains(mimeType, "jpg") {
										ext = ".jpg"
									}

									randomBytes := make([]byte, 16)
									rand.Read(randomBytes)
									filename := fmt.Sprintf("product_%d_%s%s", i, hex.EncodeToString(randomBytes), ext)
									filePath := filepath.Join(uploadDir, filename)

									if err := os.WriteFile(filePath, imageData, 0644); err == nil {
										prodMap["image"] = fmt.Sprintf("/uploads/%s", filename)
										updated = true
									}
								}
							}
						}
					}
				}
			}
		}

		// Update document if changes were made
		if updated {
			_, err := collection.ReplaceOne(ctx, bson.M{"_id": doc["_id"]}, doc)
			if err != nil {
				migrationStats["errors"] = append(migrationStats["errors"].([]string), 
					fmt.Sprintf("Failed to update document: %v", err))
			} else {
				migrationStats["migrated"] = migrationStats["migrated"].(int) + 1
			}
		}
	}

	response := APIResponse{
		Success: true,
		Data:    migrationStats,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// getDefaultContent returns default site content
func getDefaultContent() map[string]interface{} {
	return map[string]interface{}{
		"hero": map[string]interface{}{
			"titleLine1":    "Welcome to ISY",
			"titleLine2":    "Software",
			"subtitle":     "Professional software solutions",
			"badge":        "Version 1.0",
		},
		"ecosystem": []interface{}{},
		"features":  []interface{}{},
		"hardware": map[string]interface{}{
			"title":    "Hardware Solutions",
			"subtitle": "Complete hardware ecosystem",
		},
		"pricing": []interface{}{},
		"contact": map[string]interface{}{
			"email": "contact@isy.software",
			"phone": "+1-234-567-8900",
		},
		"images": map[string]interface{}{
			"logo":          nil,
			"backgroundImage": nil,
			"heroDashboard": nil,
		},
	}
}