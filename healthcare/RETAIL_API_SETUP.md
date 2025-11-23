# Retail Admin Panel with MongoDB

This setup creates a separate MongoDB database for the retail admin panel, completely isolated from the Next.js healthcare application.

## Architecture

```
┌─────────────────────┐
│   Retail Frontend   │ (Vite Static Site)
│  https://isy.software/retail/
└──────────┬──────────┘
           │
           ├─ Fetch Data ──────────┐
           │                       │
           │                       ▼
┌──────────▼──────────┐   ┌───────────────┐
│   Retail API Server │◄──┤   MongoDB     │
│   Port: 3001        │   │   Database    │
│   /api/*            │   │   Collection: │
└─────────────────────┘   │   - contents  │
                          │   - admins    │
                          └───────────────┘
```

## Database Structure

### Collections:

1. **admins** - Admin users for authentication

   ```json
   {
     "username": "admin",
     "password": "<bcrypt_hashed>",
     "createdAt": ISODate
   }
   ```

2. **contents** - Site content
   ```json
   {
     "type": "site",
     "content": { ...SiteContent object... },
     "updatedAt": ISODate,
     "updatedBy": "admin"
   }
   ```

## API Endpoints

### POST /api/auth

Authenticate admin user

```json
Request:
{
  "username": "admin",
  "password": "admin123"
}

Response:
{
  "token": "jwt_token_here",
  "username": "admin"
}
```

### GET /api/content

Get site content (public, no auth required)

```json
Response:
{
  "content": { ...SiteContent... }
}
```

### POST /api/content

Save site content (requires authentication)

```json
Headers:
Authorization: Bearer <token>

Request:
{
  "content": { ...SiteContent... }
}

Response:
{
  "success": true,
  "message": "Content saved successfully"
}
```

## Deployment Steps

### 1. Copy Server Files to Production

```powershell
# From your local machine
scp -r retail/server adminroot@103.126.116.50:/root/retail/
```

### 2. Deploy the API

```bash
# SSH into server
ssh adminroot@103.126.116.50

# Run deployment script
cd /root
chmod +x deploy-retail-api.sh
./deploy-retail-api.sh
```

### 3. Verify Deployment

```bash
# Check API health
curl https://isy.software/api/health

# Expected response:
# {"status":"ok","timestamp":"..."}
```

### 4. Rebuild Frontend (if needed)

```powershell
# From local machine
cd retail
npm run build

# Copy to server
scp -r dist/* adminroot@103.126.116.50:/tmp/retail-dist/

# SSH and update
ssh adminroot@103.126.116.50
sudo rm -rf /root/retail/dist/*
sudo cp -r /tmp/retail-dist/* /root/retail/dist/
sudo docker compose build retail
sudo docker compose up -d retail
```

## Default Credentials

- **Username:** admin
- **Password:** admin123

⚠️ **IMPORTANT:** Change these credentials in production!

To change the admin password, connect to MongoDB and update:

```bash
# Access MongoDB container
docker exec -it isy-healthcare-mongodb mongosh -u admin -p SecurePassword123!

# Switch to retail database
use retail

# Update password (hash it first with bcrypt)
db.admins.updateOne(
  { username: "admin" },
  { $set: { password: "<new_bcrypt_hash>" } }
)
```

## Environment Variables

In `docker-compose.yml`, the retail-api service uses:

- `MONGO_URI`: MongoDB connection string
- `JWT_SECRET`: Secret key for JWT tokens (change in production!)
- `PORT`: API server port (default: 3001)

## Troubleshooting

### Check API Logs

```bash
docker logs isy-healthcare-retail-api
```

### Check MongoDB Connection

```bash
docker exec -it isy-healthcare-mongodb mongosh -u admin -p SecurePassword123!
use retail
show collections
```

### Test API Directly

```bash
# Test authentication
curl -X POST https://isy.software/api/auth \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Test get content
curl https://isy.software/api/content
```

## Development

### Local Development

```bash
cd retail/server
npm install
npm run dev
```

The API will run on `http://localhost:3001`

### Testing with Frontend

Update `retail/services/database.ts` to point to localhost during development:

```typescript
const API_BASE = "http://localhost:3001/api";
```

## Security Notes

1. ✅ Passwords are hashed with bcrypt
2. ✅ JWT tokens expire after 24 hours
3. ✅ Authentication required for content updates
4. ✅ Public read access for content (landing page)
5. ⚠️ Change default admin credentials
6. ⚠️ Update JWT_SECRET in production
7. ⚠️ Consider adding rate limiting for authentication endpoint

## Database Backup

```bash
# Backup retail database
docker exec isy-healthcare-mongodb mongodump \
  --uri="mongodb://admin:SecurePassword123!@localhost:27017/retail?authSource=admin" \
  --out=/data/backup

# Restore
docker exec isy-healthcare-mongodb mongorestore \
  --uri="mongodb://admin:SecurePassword123!@localhost:27017/retail?authSource=admin" \
  /data/backup/retail
```
