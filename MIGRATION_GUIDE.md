# ISY Software Platform - Centralized API Migration Guide

This guide walks you through migrating from separate backend services to the centralized API architecture.

## 🎯 Overview

**Before:** Separate MongoDB and backend services for healthcare and retail
**After:** Single centralized API at `api.isy.software` serving both applications

### Benefits

- ✅ Single source of truth for data
- ✅ Easier maintenance and updates
- ✅ Consistent API patterns
- ✅ Better resource utilization
- ✅ Simplified deployment

## 📋 Pre-Migration Checklist

- [ ] Backup existing databases
- [ ] Review current API endpoints
- [ ] Update DNS records for api.isy.software
- [ ] Generate SSL certificates
- [ ] Test API locally

## 🔄 Migration Steps

### Step 1: Backup Current Data

```powershell
# Backup healthcare database
docker exec isy-healthcare-mongodb mongodump --username=admin --password=SecurePassword123! --authenticationDatabase=admin --db=isy_clinic --out=/backup

# Backup retail database
docker exec retail-mongodb-dev mongodump --username=admin --password=admin123 --authenticationDatabase=admin --db=retail --out=/backup

# Copy backups to host
docker cp isy-healthcare-mongodb:/backup ./backup_healthcare
docker cp retail-mongodb-dev:/backup ./backup_retail
```

### Step 2: Deploy Centralized Infrastructure

```powershell
# Stop old services
docker-compose down

# Update nginx configuration
Copy-Item nginx-api.conf nginx.conf

# Start new infrastructure
docker-compose up -d mongodb isy-api
```

### Step 3: Migrate Data

Run the automated migration script:

```powershell
.\migrate_databases.ps1
```

Or manually:

```powershell
# Start centralized MongoDB
docker-compose up -d mongodb
Start-Sleep -Seconds 5

# Import healthcare data
docker exec isy-mongodb mongorestore --username=admin --password=SecurePassword123! --authenticationDatabase=admin --db=isy_api ./backup_healthcare/isy_clinic

# Import retail data
docker exec isy-mongodb mongorestore --username=admin --password=SecurePassword123! --authenticationDatabase=admin --db=isy_api ./backup_retail/retail
```

### Step 4: Verify API

```powershell
# Test health endpoint
curl http://localhost:8080/health

# Test healthcare endpoints
curl http://localhost:8080/healthcare/v1/patients

# Test retail endpoints
curl http://localhost:8080/retail/v1/products
```

### Step 5: Update Frontend Applications

#### Healthcare Frontend

Update `healthcare/.env.production`:

```env
NEXT_PUBLIC_API_URL=https://api.isy.software
```

Update API calls in `healthcare/lib/apiHelpers.ts`:

```typescript
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";

// OLD: /api/v1/patients
// NEW: /healthcare/v1/patients

export const getPatients = async () => {
  const response = await fetch(`${API_BASE_URL}/healthcare/v1/patients`);
  return response.json();
};
```

#### Retail Frontend

Update `retail/.env.production`:

```env
VITE_API_URL=https://api.isy.software
```

Update API service in `retail/services/api.ts`:

```typescript
const API_BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:8080";

// OLD: /api/v1/products
// NEW: /retail/v1/products

export const getProducts = async () => {
  const response = await fetch(`${API_BASE_URL}/retail/v1/products`);
  return response.json();
};
```

### Step 6: Deploy Full Stack

```powershell
# Rebuild and deploy all services
docker-compose up -d --build

# Verify all containers are running
docker-compose ps
```

### Step 7: Configure SSL Certificates

```bash
# Generate certificates for API domain
docker-compose run --rm certbot certonly --webroot -w /var/www/certbot -d api.isy.software

# Restart nginx with SSL
docker-compose restart nginx
```

### Step 8: DNS Configuration

Add DNS A record for your server IP:

```
api.isy.software  A  YOUR_SERVER_IP
```

Wait for DNS propagation (usually 5-30 minutes).

### Step 9: Test Production

```powershell
# Test healthcare via API
curl https://api.isy.software/healthcare/v1/patients

# Test retail via API
curl https://api.isy.software/retail/v1/products

# Test healthcare frontend
curl https://health.isy.software

# Test retail frontend
curl https://retail.isy.software
```

## 🗺️ API Endpoint Migration Map

### Healthcare

| Old Endpoint           | New Endpoint                     | Method    |
| ---------------------- | -------------------------------- | --------- |
| `/api/patients`        | `/healthcare/v1/patients`        | GET, POST |
| `/api/appointments`    | `/healthcare/v1/appointments`    | GET, POST |
| `/api/medical-records` | `/healthcare/v1/medical-records` | GET, POST |

### Retail

| Old Endpoint        | New Endpoint              | Method           |
| ------------------- | ------------------------- | ---------------- |
| `/api/products`     | `/retail/v1/products`     | GET, POST        |
| `/api/products/:id` | `/retail/v1/products/:id` | GET, PUT, DELETE |
| `/api/metadata`     | `/retail/v1/metadata`     | GET, POST        |

## 🔧 Troubleshooting

### API not responding

```powershell
# Check API logs
docker logs -f isy-api

# Check API container status
docker ps | grep isy-api

# Restart API
docker-compose restart isy-api
```

### Database connection issues

```powershell
# Check MongoDB logs
docker logs -f isy-mongodb

# Test MongoDB connection
docker exec -it isy-mongodb mongosh --username admin --password SecurePassword123! --authenticationDatabase admin
```

### Frontend can't connect to API

1. Verify CORS settings in API
2. Check nginx proxy configuration
3. Verify API domain SSL certificate
4. Check browser console for CORS errors

### SSL certificate issues

```bash
# Check certificate status
docker-compose run --rm certbot certificates

# Renew certificates
docker-compose run --rm certbot renew
```

## 🔙 Rollback Plan

If issues occur:

```powershell
# 1. Stop new infrastructure
docker-compose down

# 2. Restore old docker-compose configuration
git checkout docker-compose.yml

# 3. Restore old MongoDB data
docker-compose up -d mongodb
docker cp ./backup_healthcare isy-healthcare-mongodb:/backup
docker exec isy-healthcare-mongodb mongorestore --username=admin --password=SecurePassword123! --authenticationDatabase=admin /backup/isy_clinic

# 4. Start old services
docker-compose up -d
```

## ✅ Post-Migration Checklist

- [ ] All API endpoints responding correctly
- [ ] Healthcare frontend can fetch/create data
- [ ] Retail frontend can fetch/create data
- [ ] SSL certificates active and valid
- [ ] Database backups configured
- [ ] Monitoring and logging active
- [ ] Old containers stopped and removed
- [ ] Documentation updated

## 📊 Performance Optimization

After migration:

1. **Enable MongoDB indexes**

   ```javascript
   docker exec -it isy-mongodb mongosh --username admin --password SecurePassword123! --authenticationDatabase admin isy_api

   // Create indexes
   db.patients.createIndex({ "email": 1 }, { unique: true });
   db.products.createIndex({ "sku": 1 }, { unique: true });
   db.appointments.createIndex({ "date": 1, "time": 1 });
   ```

2. **Configure nginx caching** (optional)

   ```nginx
   proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m max_size=1g inactive=60m;
   ```

3. **Monitor resource usage**
   ```powershell
   docker stats isy-api isy-mongodb
   ```

## 🎓 Next Steps

1. **Add Authentication**

   - Implement JWT middleware
   - Add user authentication endpoints
   - Secure sensitive endpoints

2. **Add Monitoring**

   - Set up Prometheus metrics
   - Configure Grafana dashboards
   - Add health check alerts

3. **Enhance API**
   - Add pagination
   - Implement search filters
   - Add data validation
   - Create API documentation (Swagger)

## 📞 Support

For assistance:

- Email: support@isy.software
- Docs: https://docs.isy.software
- Issues: https://github.com/isysoftwareapp/server/issues
