package kiosk

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"golang.org/x/crypto/bcrypt"
)

// APIResponse represents a standard API response
type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// Product represents a kiosk product
type Product struct {
	ID             primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	ProductID      string            `bson:"productId" json:"productId"`
	Name           string            `bson:"name" json:"name"`
	Description    string            `bson:"description" json:"description"`
	CategoryID     string            `bson:"categoryId" json:"categoryId"`
	SubcategoryID  *string           `bson:"subcategoryId,omitempty" json:"subcategoryId,omitempty"`
	HasVariants    bool              `bson:"hasVariants" json:"hasVariants"`
	Variants       []Variant         `bson:"variants" json:"variants"`
	Price          float64           `bson:"price" json:"price"`
	MemberPrice    float64           `bson:"memberPrice" json:"memberPrice"`
	MainImage      string            `bson:"mainImage" json:"mainImage"`
	Images         []Image           `bson:"images" json:"images"`
	SKU            string            `bson:"sku" json:"sku"`
	BackgroundImage string           `bson:"backgroundImage" json:"backgroundImage"`
	BackgroundFit  string            `bson:"backgroundFit" json:"backgroundFit"`
	TextColor      string            `bson:"textColor" json:"textColor"`
	ModelURL       string            `bson:"modelUrl" json:"modelUrl"`
	IsActive       bool              `bson:"isActive" json:"isActive"`
	IsFeatured     bool              `bson:"isFeatured" json:"isFeatured"`
	Notes          string            `bson:"notes" json:"notes"`
	CreatedAt      time.Time         `bson:"createdAt" json:"createdAt"`
	UpdatedAt      time.Time         `bson:"updatedAt" json:"updatedAt"`
}

// Variant represents a product variant
type Variant struct {
	ID       string  `bson:"id" json:"id"`
	Name     string  `bson:"name" json:"name"`
	Price    float64 `bson:"price" json:"price"`
	MemberPrice float64 `bson:"memberPrice" json:"memberPrice"`
	SKU      string  `bson:"sku" json:"sku"`
	Stock    int     `bson:"stock" json:"stock"`
}

// Image represents a product image
type Image struct {
	URL  string `bson:"url" json:"url"`
	Path string `bson:"path" json:"path"`
	Name string `bson:"name" json:"name"`
}

// Customer represents a kiosk customer
type Customer struct {
	ID               primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	CustomerID       string            `bson:"customerId" json:"customerId"`
	Name             string            `bson:"name" json:"name"`
	LastName         string            `bson:"lastName" json:"lastName"`
	Nickname         string            `bson:"nickname" json:"nickname"`
	Email            string            `bson:"email" json:"email"`
	Cell             string            `bson:"cell" json:"cell"`
	MemberID         string            `bson:"memberId" json:"memberId"`
	Points           []PointEntry      `bson:"points" json:"points"`
	TotalSpent       float64           `bson:"totalSpent" json:"totalSpent"`
	VisitCount       int               `bson:"visitCount" json:"visitCount"`
	IsActive         bool              `bson:"isActive" json:"isActive"`
	AllowedCategories []string         `bson:"allowedCategories" json:"allowedCategories"`
	DateOfBirth      string            `bson:"dateOfBirth" json:"dateOfBirth"`
	CustomPoints     float64           `bson:"customPoints" json:"customPoints"`
	CreatedAt        time.Time         `bson:"createdAt" json:"createdAt"`
	UpdatedAt        time.Time         `bson:"updatedAt" json:"updatedAt"`
}

// PointEntry represents a points transaction
type PointEntry struct {
	Amount    float64   `bson:"amount" json:"amount"`
	Type      string    `bson:"type" json:"type"`
	Date      time.Time `bson:"date" json:"date"`
	Reference string    `bson:"reference" json:"reference"`
}

// Order represents a kiosk order/transaction
type Order struct {
	ID            primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	TransactionID string            `bson:"transactionId" json:"transactionId"`
	CustomerID    string            `bson:"customerId" json:"customerId"`
	Items         []OrderItem       `bson:"items" json:"items"`
	Total         float64           `bson:"total" json:"total"`
	Discount      float64           `bson:"discount" json:"discount"`
	FinalTotal    float64           `bson:"finalTotal" json:"finalTotal"`
	PaymentMethod string            `bson:"paymentMethod" json:"paymentMethod"`
	Status        string            `bson:"status" json:"status"`
	Notes         string            `bson:"notes" json:"notes"`
	CreatedAt     time.Time         `bson:"createdAt" json:"createdAt"`
	UpdatedAt     time.Time         `bson:"updatedAt" json:"updatedAt"`
}

// OrderItem represents an item in an order
type OrderItem struct {
	ProductID   string  `bson:"productId" json:"productId"`
	ProductName string  `bson:"productName" json:"productName"`
	VariantID   string  `bson:"variantId,omitempty" json:"variantId,omitempty"`
	Quantity    int     `bson:"quantity" json:"quantity"`
	Price       float64 `bson:"price" json:"price"`
	Total       float64 `bson:"total" json:"total"`
}

// Category represents a product category
type Category struct {
	ID          primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	Name        string            `bson:"name" json:"name"`
	Description string            `bson:"description" json:"description"`
	ImageURL    string            `bson:"imageUrl" json:"imageUrl"`
	IsActive    bool              `bson:"isActive" json:"isActive"`
	Order       int               `bson:"order" json:"order"`
	CreatedAt   time.Time         `bson:"createdAt" json:"createdAt"`
	UpdatedAt   time.Time         `bson:"updatedAt" json:"updatedAt"`
}

// AuthRequest represents login credentials
type AuthRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

// JWTClaims represents JWT claims
type JWTClaims struct {
	Username string `json:"username"`
	jwt.RegisteredClaims
}

// KioskHandlers contains all kiosk-related handlers
type KioskHandlers struct {
	DB *mongo.Database
}

// NewKioskHandlers creates a new kiosk handlers instance
func NewKioskHandlers(db *mongo.Database) *KioskHandlers {
	return &KioskHandlers{DB: db}
}

// Authenticate handles user authentication
func (kh *KioskHandlers) Authenticate(w http.ResponseWriter, r *http.Request) {
	if kh.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	var authReq AuthRequest
	if err := json.NewDecoder(r.Body).Decode(&authReq); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	// For now, check against a simple admin collection
	// In production, this should be more secure
	collection := kh.DB.Collection("admins")
	var admin bson.M
	err := collection.FindOne(r.Context(), bson.M{"username": authReq.Username}).Decode(&admin)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			respondWithError(w, http.StatusUnauthorized, "Invalid credentials")
			return
		}
		respondWithError(w, http.StatusInternalServerError, "Authentication failed")
		return
	}

	// Check password
	storedPassword, ok := admin["password"].(string)
	if !ok {
		respondWithError(w, http.StatusInternalServerError, "Invalid password format")
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(storedPassword), []byte(authReq.Password)); err != nil {
		respondWithError(w, http.StatusUnauthorized, "Invalid credentials")
		return
	}

	// Generate JWT token
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, JWTClaims{
		Username: authReq.Username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	})

	tokenString, err := token.SignedString([]byte("your-secret-key")) // Use env var in production
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to generate token")
		return
	}

	respondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Data: map[string]string{
			"token": tokenString,
		},
	})
}

// GetProducts retrieves all products
func (kh *KioskHandlers) GetProducts(w http.ResponseWriter, r *http.Request) {
	if kh.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	ctx := r.Context()
	collection := kh.DB.Collection("products")

	cursor, err := collection.Find(ctx, bson.M{})
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to fetch products")
		return
	}
	defer cursor.Close(ctx)

	var products []Product
	if err := cursor.All(ctx, &products); err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to parse products")
		return
	}

	respondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Data:    products,
	})
}

// CreateProduct creates a new product
func (kh *KioskHandlers) CreateProduct(w http.ResponseWriter, r *http.Request) {
	if kh.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	var product Product
	if err := json.NewDecoder(r.Body).Decode(&product); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	product.CreatedAt = time.Now()
	product.UpdatedAt = time.Now()

	ctx := r.Context()
	collection := kh.DB.Collection("products")

	result, err := collection.InsertOne(ctx, product)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to create product")
		return
	}

	product.ID = result.InsertedID.(primitive.ObjectID)

	respondWithJSON(w, http.StatusCreated, APIResponse{
		Success: true,
		Data:    product,
	})
}

// GetCustomers retrieves all customers
func (kh *KioskHandlers) GetCustomers(w http.ResponseWriter, r *http.Request) {
	if kh.DB == nil {
		respondWithError(w, http.StatusServiceUnavailable, "Database not available")
		return
	}

	ctx := r.Context()
	collection := kh.DB.Collection("customers")

	cursor, err := collection.Find(ctx, bson.M{})
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to fetch customers")
		return
	}
	defer cursor.Close(ctx)

	var customers []Customer
	if err := cursor.All(ctx, &customers); err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to parse customers")
		return
	}

	respondWithJSON(w, http.StatusOK, APIResponse{
		Success: true,
		Data:    customers,
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
	response, _ := json.Marshal(payload)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	w.Write(response)
}