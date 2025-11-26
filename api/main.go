package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/mux"
	"github.com/joho/godotenv"
	"github.com/rs/cors"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"

	"isy-api/healthcare"
	"isy-api/kiosk"
	"isy-api/retail"
)

type App struct {
	Router   *mux.Router
	DB       *mongo.Database
	Client   *mongo.Client
}

func (a *App) Initialize() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	// Get MongoDB connection string
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017"
	}

	// Try to connect to MongoDB, but don't fail if it's not available
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	if err != nil {
		log.Printf("Warning: Failed to connect to MongoDB: %v", err)
		log.Println("Server will start without database connection")
		a.DB = nil
		a.Client = nil
	} else {
		// Ping the database
		if err := client.Ping(ctx, nil); err != nil {
			log.Printf("Warning: Failed to ping MongoDB: %v", err)
			log.Println("Server will start without database connection")
			a.DB = nil
			a.Client = nil
		} else {
			fmt.Println("✅ Connected to MongoDB")

			// Get database name
			dbName := os.Getenv("DB_NAME")
			if dbName == "" {
				dbName = "isy_api"
			}

			a.DB = client.Database(dbName)
			a.Client = client
		}
	}

	// Initialize router
	a.Router = mux.NewRouter()

	// Setup routes
	a.setupRoutes()
}

func (a *App) setupRoutes() {
	// Health check
	a.Router.HandleFunc("/health", a.healthCheck).Methods("GET")
	
	// Serve uploaded files from /root/uploads (Docker volume mount)
	uploadsDir := os.Getenv("UPLOADS_DIR")
	if uploadsDir == "" {
		uploadsDir = "/root/uploads" // Default Docker location
	}
	a.Router.PathPrefix("/uploads/").Handler(http.StripPrefix("/uploads/", http.FileServer(http.Dir(uploadsDir))))

	// Initialize handlers
	healthcareHandlers := healthcare.NewHealthcareHandlers(a.DB)
	retailHandlers := retail.NewRetailHandlers(a.DB)
	kioskHandlers := kiosk.NewKioskHandlers(a.DB)

	// Healthcare API v1 routes
	healthcareAPI := a.Router.PathPrefix("/healthcare/v1").Subrouter()
	healthcareAPI.HandleFunc("/patients", healthcareHandlers.GetPatients).Methods("GET")
	healthcareAPI.HandleFunc("/patients", healthcareHandlers.CreatePatient).Methods("POST")
	healthcareAPI.HandleFunc("/appointments", healthcareHandlers.GetAppointments).Methods("GET")
	healthcareAPI.HandleFunc("/appointments", healthcareHandlers.CreateAppointment).Methods("POST")
	healthcareAPI.HandleFunc("/medical-records", healthcareHandlers.GetMedicalRecords).Methods("GET")
	healthcareAPI.HandleFunc("/medical-records", healthcareHandlers.CreateMedicalRecord).Methods("POST")

	// Retail API v1 routes
	retailAPI := a.Router.PathPrefix("/retail/v1").Subrouter()
	retailAPI.HandleFunc("/auth", retailHandlers.Authenticate).Methods("POST")
	retailAPI.HandleFunc("/products", retailHandlers.GetProducts).Methods("GET")
	retailAPI.HandleFunc("/products", retailHandlers.CreateProduct).Methods("POST")
	retailAPI.HandleFunc("/products/{id}", retailHandlers.GetProduct).Methods("GET")
	retailAPI.HandleFunc("/products/{id}", retailHandlers.UpdateProduct).Methods("PUT")
	retailAPI.HandleFunc("/products/{id}", retailHandlers.DeleteProduct).Methods("DELETE")
	retailAPI.HandleFunc("/metadata", retailHandlers.GetMetadata).Methods("GET")
	retailAPI.HandleFunc("/metadata", retailHandlers.SaveMetadata).Methods("POST")
	retailAPI.HandleFunc("/migrate-base64", retailHandlers.MigrateBase64ToFiles).Methods("POST")

	// Kiosk API v1 routes
	kioskAPI := a.Router.PathPrefix("/kiosk/v1").Subrouter()
	kioskAPI.HandleFunc("/auth", kioskHandlers.Authenticate).Methods("POST")
	kioskAPI.HandleFunc("/products", kioskHandlers.GetProducts).Methods("GET")
	kioskAPI.HandleFunc("/products", kioskHandlers.CreateProduct).Methods("POST")
	kioskAPI.HandleFunc("/customers", kioskHandlers.GetCustomers).Methods("GET")

	// Legacy API v1 routes (for backward compatibility)
	api := a.Router.PathPrefix("/api/v1").Subrouter()
	api.HandleFunc("/content", a.getContent).Methods("GET")
	api.HandleFunc("/content", a.saveContent).Methods("POST")
	api.HandleFunc("/upload", a.uploadFile).Methods("POST")
	api.HandleFunc("/upload/{filename}", a.deleteFile).Methods("DELETE")
	api.HandleFunc("/migrate-base64", a.migrateBase64ToFiles).Methods("POST")
}

func (a *App) Run(addr string) {
	fmt.Printf("🚀 ISY API Server starting on %s\n", addr)

	c := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"*"},
		AllowCredentials: true,
	})

	handler := c.Handler(a.Router)
	log.Fatal(http.ListenAndServe(addr, handler))
}

func main() {
	a := App{}
	a.Initialize()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	a.Run(":" + port)
}