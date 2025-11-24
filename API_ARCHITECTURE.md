# ISY Software Platform - Centralized API Architecture

## 🎯 What Changed

### Before

- **Healthcare**: Own MongoDB + Backend API (Node.js)
- **Retail**: Own MongoDB + Backend API (Node.js)
- Each application managed its own data independently

### After

- **Centralized API**: Single Go API server at `api.isy.software`
- **Centralized Database**: Single MongoDB instance for all applications
- **Clear Routing**: `/healthcare/v1/*` and `/retail/v1/*` endpoints
- **Unified Management**: One place to manage all data

## 📁 New Structure

```
isy.software/
├── api/                          # Centralized Go API
│   ├── main.go                  # Router setup
│   ├── handlers.go              # Legacy handlers
│   ├── healthcare/              # Healthcare domain
│   │   └── handlers.go          # Patient, appointment, medical record handlers
│   ├── retail/                  # Retail domain
│   │   └── handlers.go          # Product, metadata handlers
│   ├── Dockerfile
│   └── go.mod
├── healthcare/                   # Healthcare Frontend (Next.js)
│   └── [No MongoDB or backend]
├── retail/                       # Retail Frontend (React)
│   └── [No MongoDB or backend]
├── docker-compose.yml           # Unified deployment
├── nginx-api.conf               # Multi-domain nginx config
└── migrate_databases.ps1        # Data migration script
```

## 🌐 API Endpoints

### Base URLs

- **Production**: `https://api.isy.software`
- **Development**: `http://localhost:8080`

### Healthcare Endpoints

```
GET    /healthcare/v1/patients              # Get all patients
POST   /healthcare/v1/patients              # Create patient
GET    /healthcare/v1/appointments          # Get appointments
POST   /healthcare/v1/appointments          # Create appointment
GET    /healthcare/v1/medical-records       # Get medical records
POST   /healthcare/v1/medical-records       # Create medical record
```

### Retail Endpoints

```
GET    /retail/v1/products                  # Get all products
POST   /retail/v1/products                  # Create product
GET    /retail/v1/products/:id              # Get single product
PUT    /retail/v1/products/:id              # Update product
DELETE /retail/v1/products/:id              # Delete product
GET    /retail/v1/metadata                  # Get metadata
POST   /retail/v1/metadata                  # Save metadata
```

## 🚀 Deployment

### 1. Start Services

```powershell
docker-compose up -d
```

This starts:

- `isy-mongodb` - Centralized MongoDB
- `isy-api` - Go API server
- `isy-healthcare` - Healthcare frontend
- `isy-retail` - Retail frontend
- `isy-nginx` - Reverse proxy

### 2. Verify API

```powershell
curl http://localhost:8080/health
```

Expected response:

```json
{
  "success": true,
  "data": {
    "service": "isy-api",
    "status": "ok",
    "timestamp": "2025-11-24T08:00:00Z"
  }
}
```

## 🔄 Data Migration

### Automatic Migration

```powershell
.\migrate_databases.ps1
```

### Manual Migration

```powershell
# Export from old containers
docker exec isy-healthcare-mongodb mongodump --username=admin --password=SecurePassword123! --authenticationDatabase=admin --db=isy_clinic --archive > healthcare.archive

# Import to centralized MongoDB
docker exec -i isy-mongodb mongorestore --username=admin --password=SecurePassword123! --authenticationDatabase=admin --db=isy_api --archive < healthcare.archive
```

## 🔧 Configuration Changes

### Healthcare Frontend

**File**: `healthcare/.env.production`

```env
# OLD
MONGODB_URI=mongodb://mongodb:27017/isy_clinic

# NEW
NEXT_PUBLIC_API_URL=https://api.isy.software
```

### Retail Frontend

**File**: `retail/.env.production`

```env
# OLD
VITE_API_URL=http://localhost:3001

# NEW
VITE_API_URL=https://api.isy.software
```

### Docker Compose

**File**: `docker-compose.yml`

**Removed Services**:

- `retail-api` (Node.js backend)
- Separate MongoDB instances

**Added Services**:

- `isy-api` (Go API server)
- Single `isy-mongodb` for all data

### Nginx Configuration

**File**: `nginx-api.conf`

**Added Upstream**:

```nginx
upstream api_backend {
    server isy-api:8080;
}
```

**Added Server Block**:

```nginx
server {
    listen 443 ssl http2;
    server_name api.isy.software;

    location / {
        proxy_pass http://api_backend;
    }
}
```

## 📊 Benefits

### Developer Experience

- ✅ Single API to maintain
- ✅ Consistent response formats
- ✅ Clear endpoint naming (`/healthcare/*`, `/retail/*`)
- ✅ Easier testing and debugging

### Performance

- ✅ Faster startup times (Go vs Node.js)
- ✅ Lower memory footprint
- ✅ Single database connection pool
- ✅ Better resource utilization

### Operations

- ✅ Simplified deployment
- ✅ Centralized logging
- ✅ Single backup point
- ✅ Easier monitoring

### Scalability

- ✅ Independent scaling of API and frontends
- ✅ Easy to add new application domains
- ✅ Clear separation of concerns

## 🔐 Security

### Authentication (Coming Soon)

- JWT middleware for protected endpoints
- Role-based access control (RBAC)
- API key authentication for external clients

### Current Security

- MongoDB authentication enabled
- HTTPS enforced via nginx
- CORS configured
- Rate limiting in nginx

## 📈 Next Steps

### Phase 1: Migration (Current)

- [x] Create centralized API structure
- [x] Implement healthcare endpoints
- [x] Implement retail endpoints
- [x] Update docker-compose
- [x] Create migration scripts
- [ ] Migrate production data
- [ ] Update frontend API calls

### Phase 2: Enhancement

- [ ] Add JWT authentication
- [ ] Implement pagination
- [ ] Add search and filtering
- [ ] Create API documentation (Swagger)
- [ ] Add request validation

### Phase 3: Advanced Features

- [ ] WebSocket support for real-time updates
- [ ] File upload optimization
- [ ] Caching layer (Redis)
- [ ] Background job processing
- [ ] API versioning strategy

## 📝 Development Workflow

### Local Development

```powershell
# 1. Start database
docker-compose up -d mongodb

# 2. Run API locally
cd api
go run .

# 3. Run frontend
cd healthcare
npm run dev
```

### Testing

```powershell
# Test healthcare endpoint
curl http://localhost:8080/healthcare/v1/patients

# Test retail endpoint
curl http://localhost:8080/retail/v1/products

# Create test data
curl -X POST http://localhost:8080/retail/v1/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product","price":99.99}'
```

### Debugging

```powershell
# View API logs
docker-compose logs -f isy-api

# Access MongoDB
docker exec -it isy-mongodb mongosh --username admin --authenticationDatabase admin

# Check database
use isy_api
db.getCollectionNames()
db.products.find()
```

## 🆘 Support

### Documentation

- Migration Guide: `MIGRATION_GUIDE.md`
- Quick Deploy: `QUICK_DEPLOY.md`
- API README: `api/README.md`

### Contact

- Email: support@isy.software
- Issues: https://github.com/isysoftwareapp/server/issues

### Common Issues

**API not responding**

```powershell
docker-compose restart isy-api
docker-compose logs isy-api
```

**Database connection failed**

```powershell
docker-compose restart mongodb
docker exec -it isy-mongodb mongosh --eval "db.adminCommand('ping')"
```

**Frontend can't reach API**

- Check CORS settings in API
- Verify nginx proxy configuration
- Check API URL in frontend .env

## ✅ Checklist

### Before Deploying

- [ ] Environment variables configured
- [ ] DNS records updated (api.isy.software)
- [ ] SSL certificates generated
- [ ] Database backup completed
- [ ] API tested locally

### After Deploying

- [ ] All containers running
- [ ] API endpoints responding
- [ ] Healthcare frontend accessible
- [ ] Retail frontend accessible
- [ ] Database migration verified
- [ ] SSL certificates valid

### Maintenance

- [ ] Set up automated backups
- [ ] Configure monitoring
- [ ] Set up log rotation
- [ ] Document API changes
- [ ] Update version numbers
