# Quick Deployment Guide

## 🚀 Quick Start (5 minutes)

### 1. Build and Start Services

```powershell
# Build the API
docker-compose build isy-api

# Start MongoDB and API
docker-compose up -d mongodb isy-api

# Wait for services to be ready
Start-Sleep -Seconds 10

# Verify API is running
curl http://localhost:8080/health
```

### 2. Test API Endpoints

```powershell
# Test healthcare endpoint
Invoke-WebRequest -Uri "http://localhost:8080/healthcare/v1/patients" -Method GET

# Test retail endpoint
Invoke-WebRequest -Uri "http://localhost:8080/retail/v1/products" -Method GET
```

### 3. Start Frontend Services

```powershell
# Start healthcare frontend
docker-compose up -d healthcare

# Start retail frontend
docker-compose up -d retail

# Start nginx
docker-compose up -d nginx
```

### 4. Access Applications

- Healthcare: http://localhost:3000
- Retail: http://localhost:80
- API: http://localhost:8080

## 📦 Full Production Deployment

```powershell
# 1. Set environment variables
Copy-Item .env.example .env
# Edit .env with your settings

# 2. Build all services
docker-compose build

# 3. Start all services
docker-compose up -d

# 4. Check status
docker-compose ps

# 5. View logs
docker-compose logs -f
```

## 🔄 Update Deployed Services

```powershell
# Update API only
docker-compose up -d --build isy-api

# Update healthcare only
docker-compose up -d --build healthcare

# Update retail only
docker-compose up -d --build retail
```

## 🛑 Stop Services

```powershell
# Stop all
docker-compose down

# Stop specific service
docker-compose stop isy-api

# Stop and remove volumes
docker-compose down -v
```

## 📊 Monitoring

```powershell
# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f isy-api

# Check resource usage
docker stats
```

## 🔧 Common Commands

```powershell
# Restart a service
docker-compose restart isy-api

# Rebuild and restart
docker-compose up -d --build isy-api

# Execute command in container
docker exec -it isy-api sh

# View MongoDB data
docker exec -it isy-mongodb mongosh --username admin --password SecurePassword123! --authenticationDatabase admin isy_api
```

## ✅ Health Checks

```powershell
# API health
curl http://localhost:8080/health

# Healthcare health
curl http://localhost:3000

# MongoDB health
docker exec isy-mongodb mongosh --username admin --password SecurePassword123! --authenticationDatabase admin --eval "db.adminCommand('ping')"
```

## 🆘 Troubleshooting

### API not starting

```powershell
docker-compose logs isy-api
docker-compose restart isy-api
```

### Database issues

```powershell
docker-compose logs mongodb
docker exec -it isy-mongodb mongosh
```

### Port conflicts

```powershell
# Check what's using the port
netstat -ano | Select-String ":8080"

# Stop the process or change port in docker-compose.yml
```
