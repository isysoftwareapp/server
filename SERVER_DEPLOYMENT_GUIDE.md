# Server Deployment Quick Start Guide

## Pre-Deployment Checklist

### 1. Server Requirements

- [ ] Ubuntu 20.04+ or similar Linux distribution
- [ ] Docker Engine 20.10+ installed
- [ ] Docker Compose 2.0+ installed
- [ ] Ports 80, 443 available
- [ ] Domain DNS configured

### 2. Security Configuration

- [ ] Change MongoDB password in docker-compose.yml
- [ ] Generate new JWT_SECRET (32+ characters)
- [ ] Generate new NEXTAUTH_SECRET (32+ characters)
- [ ] Update domain names in docker-compose.yml
- [ ] Update domain names in nginx.conf

### 3. DNS Configuration

Configure A records for:

- [ ] health.isy.software → Server IP
- [ ] api.isy.software → Server IP
- [ ] retail.isy.software → Server IP

---

## Quick Deployment Commands

### On Server (Linux/Bash):

```bash
# 1. Clone repository
git clone https://github.com/isysoftwareapp/server.git
cd server

# 2. Update environment variables (IMPORTANT!)
# Edit docker-compose.yml and change:
# - MONGO_PASSWORD
# - JWT_SECRET
# - NEXTAUTH_SECRET
nano docker-compose.yml

# 3. Build all images
docker-compose build --no-cache

# 4. Start all services
docker-compose up -d

# 5. Check status
docker-compose ps

# 6. View logs
docker-compose logs -f

# 7. Test API
curl http://localhost:8080/health

# 8. Setup SSL (after DNS propagation)
docker-compose run --rm certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  -d health.isy.software \
  -d api.isy.software \
  -d retail.isy.software \
  --email admin@isy.software \
  --agree-tos

# 9. Update nginx to use SSL (if needed)
# Edit nginx.conf to enable SSL configuration
nano nginx.conf

# 10. Restart nginx
docker-compose restart nginx
```

---

## Test Deployment

### Test API Health

```bash
curl http://localhost:8080/health
# Expected: {"success":true,"data":{"service":"isy-api","status":"ok",...}}
```

### Test Healthcare API

```bash
# Get patients
curl http://localhost:8080/healthcare/v1/patients

# Create patient
curl -X POST http://localhost:8080/healthcare/v1/patients \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Test",
    "lastName": "User",
    "dateOfBirth": "1990-01-01",
    "gender": "male",
    "email": "test@example.com",
    "phone": "+1234567890",
    "address": "123 Test St"
  }'
```

### Test Retail API

```bash
# Get products
curl http://localhost:8080/retail/v1/products

# Create product
curl -X POST http://localhost:8080/retail/v1/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Product",
    "description": "Test description",
    "price": 99.99,
    "sku": "TEST-001",
    "category": "Electronics",
    "stock": 100,
    "status": "active"
  }'
```

### Test Frontends

```bash
# Healthcare
curl -I http://localhost:3000

# Via Nginx
curl -I http://localhost:80
```

---

## Common Issues & Solutions

### Issue: Containers not starting

```bash
# Check logs
docker-compose logs [service-name]

# Restart service
docker-compose restart [service-name]

# Rebuild and restart
docker-compose build [service-name]
docker-compose up -d [service-name]
```

### Issue: Port already in use

```bash
# Check what's using the port
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :443

# Stop conflicting service
sudo systemctl stop apache2  # or nginx, etc.
```

### Issue: Database connection failed

```bash
# Check MongoDB is running
docker exec isy-mongodb mongosh --eval "db.adminCommand('ping')"

# Restart MongoDB
docker-compose restart mongodb

# Check MongoDB logs
docker logs isy-mongodb
```

### Issue: SSL certificate fails

```bash
# Check DNS is propagated
nslookup health.isy.software

# Test HTTP-01 challenge
curl http://health.isy.software/.well-known/acme-challenge/test

# Manual certificate request
docker-compose run --rm certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  -d health.isy.software \
  --email admin@isy.software \
  --agree-tos \
  --dry-run  # Test first
```

---

## Monitoring Commands

### View All Logs

```bash
docker-compose logs -f
```

### View Specific Service Logs

```bash
docker-compose logs -f isy-api
docker-compose logs -f isy-healthcare
docker-compose logs -f isy-mongodb
docker-compose logs -f nginx
```

### Check Container Status

```bash
docker-compose ps
```

### Check Resource Usage

```bash
docker stats
```

### Check Disk Usage

```bash
docker system df
docker system df -v
```

---

## Backup & Restore

### Backup MongoDB

```bash
# Create backup directory
mkdir -p ~/backups

# Backup database
docker exec isy-mongodb mongodump \
  --uri="mongodb://admin:YOUR_PASSWORD@localhost:27017/isy_api?authSource=admin" \
  --out=/data/backup

# Copy to host
docker cp isy-mongodb:/data/backup ~/backups/mongodb-$(date +%Y%m%d_%H%M%S)
```

### Restore MongoDB

```bash
# Copy backup to container
docker cp ~/backups/mongodb-YYYYMMDD_HHMMSS isy-mongodb:/data/restore

# Restore database
docker exec isy-mongodb mongorestore \
  --uri="mongodb://admin:YOUR_PASSWORD@localhost:27017/isy_api?authSource=admin" \
  /data/restore/isy_api
```

### Backup Volumes

```bash
# Backup all volumes
docker run --rm \
  -v isysoftware_mongodb_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/mongodb_data-$(date +%Y%m%d).tar.gz /data

docker run --rm \
  -v isysoftware_api_uploads:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/api_uploads-$(date +%Y%m%d).tar.gz /data
```

---

## Update Deployment

### Update Code

```bash
# Pull latest changes
cd /path/to/server
git pull origin main

# Rebuild services
docker-compose build --no-cache

# Restart services (zero downtime)
docker-compose up -d
```

### Update Single Service

```bash
# Rebuild specific service
docker-compose build healthcare

# Restart specific service
docker-compose up -d healthcare
```

### Rollback

```bash
# Stop services
docker-compose down

# Checkout previous version
git checkout <previous-commit-hash>

# Rebuild and start
docker-compose build --no-cache
docker-compose up -d
```

---

## Maintenance

### Clean Up Docker Resources

```bash
# Remove unused containers, networks, images
docker system prune -a

# Remove specific container
docker-compose rm -f [service-name]

# Remove specific volume (WARNING: deletes data)
docker volume rm isysoftware_mongodb_data
```

### Restart All Services

```bash
docker-compose restart
```

### Stop All Services

```bash
docker-compose down
```

### View Container Shell

```bash
# API container
docker exec -it isy-api sh

# MongoDB container
docker exec -it isy-mongodb mongosh

# Healthcare container
docker exec -it isy-healthcare sh
```

---

## Production Environment Variables

Create a `.env` file or update `docker-compose.yml`:

```env
# MongoDB
MONGO_USER=admin
MONGO_PASSWORD=<STRONG_PASSWORD_HERE>

# API
JWT_SECRET=<GENERATE_RANDOM_32+_CHARACTERS>
DB_NAME=isy_api

# Healthcare
NEXTAUTH_SECRET=<GENERATE_RANDOM_32+_CHARACTERS>
DOMAIN=health.isy.software

# Production settings
NODE_ENV=production
```

### Generate Secure Secrets

```bash
# Generate random secrets
openssl rand -base64 32
# or
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

---

## Firewall Configuration

### Ubuntu/Debian with ufw

```bash
# Allow HTTP
sudo ufw allow 80/tcp

# Allow HTTPS
sudo ufw allow 443/tcp

# Allow SSH (if needed)
sudo ufw allow 22/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

### CentOS/RHEL with firewalld

```bash
# Allow HTTP and HTTPS
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https

# Reload firewall
sudo firewall-cmd --reload

# Check status
sudo firewall-cmd --list-all
```

---

## Health Checks

### API Health

```bash
curl http://localhost:8080/health
```

### MongoDB Health

```bash
docker exec isy-mongodb mongosh --eval "db.adminCommand('ping')"
```

### All Containers Health

```bash
docker-compose ps
```

### Nginx Configuration Test

```bash
docker exec isy-nginx nginx -t
```

---

## Support

- **Documentation:** See DEPLOYMENT_READINESS_REPORT.md
- **Test Script:** Run `.\test-endpoints.ps1` (Windows) or adapt for bash
- **Issues:** https://github.com/isysoftwareapp/server/issues

---

## Success Criteria

After deployment, verify:

- ✅ All containers running: `docker-compose ps`
- ✅ API health check: `curl http://localhost:8080/health`
- ✅ Healthcare frontend loads: `curl -I http://localhost:3000`
- ✅ Nginx proxy works: `curl -I http://localhost:80`
- ✅ Database accessible: Data can be created and retrieved
- ✅ SSL certificates installed (if applicable)
- ✅ Domain names resolve correctly

---

**Last Updated:** November 24, 2025  
**Version:** 1.0  
**Status:** Production Ready ✅
