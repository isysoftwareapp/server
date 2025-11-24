# ISY API - Golang Backend

A minimalistic Golang API server for centralized data management with MongoDB.

## Features

- ✅ RESTful API endpoints
- ✅ MongoDB integration
- ✅ CORS support
- ✅ Environment-based configuration
- ✅ Docker containerization
- ✅ Health check endpoint

## Quick Start

### Prerequisites

- Go 1.21+
- MongoDB
- Docker (optional)

### Local Development

1. **Clone and setup:**

   ```bash
   cd api
   cp .env.example .env
   ```

2. **Install dependencies:**

   ```bash
   go mod tidy
   ```

3. **Run the server:**

   ```bash
   go run main.go handlers.go
   ```

4. **Test the API:**
   ```bash
   curl http://localhost:8080/health
   ```

### Docker Development

1. **Build and run:**

   ```bash
   docker-compose -f docker-compose.api.yml up --build
   ```

2. **Test the API:**
   ```bash
   curl http://localhost:8080/health
   ```

## API Endpoints

### Health Check

```http
GET /health
```

Response:

```json
{
  "success": true,
  "data": {
    "status": "ok",
    "timestamp": "2025-11-24T...",
    "service": "isy-api"
  }
}
```

### Get Content

```http
GET /api/v1/content
```

Response:

```json
{
  "success": true,
  "data": {
    "type": "site",
    "content": {...},
    "updatedAt": "2025-11-24T..."
  }
}
```

### Save Content

```http
POST /api/v1/content
Content-Type: application/json

{
  "content": {
    "hero": {...},
    "features": [...]
  }
}
```

Response:

```json
{
  "success": true,
  "data": {
    "message": "Content saved successfully"
  }
}
```

## Environment Variables

| Variable        | Default                     | Description                   |
| --------------- | --------------------------- | ----------------------------- |
| `PORT`          | `8080`                      | Server port                   |
| `MONGO_URI`     | `mongodb://localhost:27017` | MongoDB connection URI        |
| `DB_NAME`       | `isy_api`                   | Database name                 |
| `JWT_SECRET`    | -                           | JWT secret for authentication |
| `UPLOAD_DIR`    | `./uploads`                 | File upload directory         |
| `MAX_FILE_SIZE` | `10485760`                  | Max file size in bytes (10MB) |

## Project Structure

```
api/
├── main.go           # Server setup and routing
├── handlers.go       # API endpoint handlers
├── go.mod           # Go module dependencies
├── go.sum           # Dependency checksums
├── Dockerfile       # Docker build configuration
├── .env.example     # Environment variables template
└── README.md        # This file
```

## Development

### Adding New Endpoints

1. Add route in `main.go` `setupRoutes()` method
2. Implement handler in `handlers.go`
3. Update this README

### Database Models

Add new models in `handlers.go` or create separate `models.go`:

```go
type NewModel struct {
    ID        primitive.ObjectID `bson:"_id,omitempty"`
    Name      string            `bson:"name"`
    CreatedAt time.Time         `bson:"createdAt"`
}
```

### Error Handling

Use the standard `APIResponse` structure:

```go
response := APIResponse{
    Success: false,
    Error:   "Something went wrong",
}
```

## Production Deployment

### Docker Compose

Add to your main `docker-compose.yml`:

```yaml
services:
  api:
    build:
      context: ./api
      dockerfile: Dockerfile
    environment:
      - MONGO_URI=mongodb://mongodb:27017
      - DB_NAME=isy_api
    depends_on:
      - mongodb
    ports:
      - "8080:8080"
```

### Environment Variables

Set production environment variables:

```bash
export MONGO_URI="mongodb://user:pass@host:27017"
export DB_NAME="isy_production"
export JWT_SECRET="your-production-secret"
```

## Testing

### Manual Testing

```bash
# Health check
curl http://localhost:8080/health

# Get content
curl http://localhost:8080/api/v1/content

# Save content
curl -X POST http://localhost:8080/api/v1/content \
  -H "Content-Type: application/json" \
  -d '{"content":{"test":"data"}}'
```

### Automated Testing

Add tests in `*_test.go` files:

```go
func TestHealthCheck(t *testing.T) {
    // Test implementation
}
```

## Future Enhancements

- [ ] JWT authentication middleware
- [ ] File upload handling
- [ ] Rate limiting
- [ ] Request logging
- [ ] Database migrations
- [ ] API documentation (Swagger)
- [ ] Unit tests
- [ ] Integration tests

## License

Apache-2.0
