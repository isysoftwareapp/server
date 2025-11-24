package healthcare

import (
	"encoding/json"
	"net/http"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

// APIResponse represents a standard API response
type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// HealthcareHandlers contains all healthcare-related handlers
type HealthcareHandlers struct {
	DB *mongo.Database
}

// NewHealthcareHandlers creates a new healthcare handlers instance
func NewHealthcareHandlers(db *mongo.Database) *HealthcareHandlers {
	return &HealthcareHandlers{DB: db}
}

// GetPatients retrieves all patients
func (h *HealthcareHandlers) GetPatients(w http.ResponseWriter, r *http.Request) {
	if h.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	ctx := r.Context()
	collection := h.DB.Collection("patients")

	cursor, err := collection.Find(ctx, bson.M{})
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to fetch patients")
		return
	}
	defer cursor.Close(ctx)

	var patients []bson.M
	if err := cursor.All(ctx, &patients); err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to parse patients")
		return
	}

	respondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Data:    patients,
	})
}

// CreatePatient creates a new patient
func (h *HealthcareHandlers) CreatePatient(w http.ResponseWriter, r *http.Request) {
	if h.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	var patient map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&patient); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	patient["createdAt"] = time.Now()
	patient["updatedAt"] = time.Now()

	ctx := r.Context()
	collection := h.DB.Collection("patients")

	result, err := collection.InsertOne(ctx, patient)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to create patient")
		return
	}

	patient["_id"] = result.InsertedID

	respondWithJSON(w, http.StatusCreated, APIResponse{
		Success: true,
		Data:    patient,
	})
}

// GetAppointments retrieves appointments
func (h *HealthcareHandlers) GetAppointments(w http.ResponseWriter, r *http.Request) {
	if h.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	ctx := r.Context()
	collection := h.DB.Collection("appointments")

	cursor, err := collection.Find(ctx, bson.M{})
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to fetch appointments")
		return
	}
	defer cursor.Close(ctx)

	var appointments []bson.M
	if err := cursor.All(ctx, &appointments); err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to parse appointments")
		return
	}

	respondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Data:    appointments,
	})
}

// CreateAppointment creates a new appointment
func (h *HealthcareHandlers) CreateAppointment(w http.ResponseWriter, r *http.Request) {
	if h.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	var appointment map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&appointment); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	appointment["createdAt"] = time.Now()
	appointment["updatedAt"] = time.Now()

	ctx := r.Context()
	collection := h.DB.Collection("appointments")

	result, err := collection.InsertOne(ctx, appointment)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to create appointment")
		return
	}

	appointment["_id"] = result.InsertedID

	respondWithJSON(w, http.StatusCreated, APIResponse{
		Success: true,
		Data:    appointment,
	})
}

// GetMedicalRecords retrieves medical records
func (h *HealthcareHandlers) GetMedicalRecords(w http.ResponseWriter, r *http.Request) {
	if h.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	// Get patient ID from query params
	patientID := r.URL.Query().Get("patientId")
	
	ctx := r.Context()
	collection := h.DB.Collection("medicalrecords")

	filter := bson.M{}
	if patientID != "" {
		objID, err := primitive.ObjectIDFromHex(patientID)
		if err == nil {
			filter["patientId"] = objID
		}
	}

	cursor, err := collection.Find(ctx, filter)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to fetch medical records")
		return
	}
	defer cursor.Close(ctx)

	var records []bson.M
	if err := cursor.All(ctx, &records); err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to parse medical records")
		return
	}

	respondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Data:    records,
	})
}

// CreateMedicalRecord creates a new medical record
func (h *HealthcareHandlers) CreateMedicalRecord(w http.ResponseWriter, r *http.Request) {
	if h.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	var record map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&record); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	record["createdAt"] = time.Now()
	record["updatedAt"] = time.Now()

	ctx := r.Context()
	collection := h.DB.Collection("medicalrecords")

	result, err := collection.InsertOne(ctx, record)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to create medical record")
		return
	}

	record["_id"] = result.InsertedID

	respondWithJSON(w, http.StatusCreated, APIResponse{
		Success: true,
		Data:    record,
	})
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
