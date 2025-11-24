package main

import (
	"encoding/json"
	"net/http"
	"time"

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

// uploadFile handles file uploads (placeholder for now)
func (a *App) uploadFile(w http.ResponseWriter, r *http.Request) {
	// TODO: Implement file upload logic
	response := APIResponse{
		Success: false,
		Error:   "File upload not implemented yet",
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusNotImplemented)
	json.NewEncoder(w).Encode(response)
}

// deleteFile handles file deletion (placeholder for now)
func (a *App) deleteFile(w http.ResponseWriter, r *http.Request) {
	// TODO: Implement file deletion logic
	response := APIResponse{
		Success: false,
		Error:   "File deletion not implemented yet",
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusNotImplemented)
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