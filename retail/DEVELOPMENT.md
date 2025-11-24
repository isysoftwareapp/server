# Retail Landing Page - Local Development Setup

## Overview

This setup uses Docker Compose to run the retail landing page locally with:

- **MongoDB**: Database for storing content
- **Retail API**: Express server with file upload support
- **Retail Frontend**: Vite dev server with hot reload

## Prerequisites

- Docker Desktop installed and running
- Docker Compose v2+
- Git

## Quick Start

### 1. Start Development Environment

From the `retail` directory:

```powershell
docker-compose -f docker-compose.dev.yml up --build
```

This will start:

- **MongoDB**: `mongodb://localhost:27017`
  - Username: `admin`
  - Password: `admin123`
  - Database: `retail`
- **Retail API**: `http://localhost:3001`
- **Retail Frontend**: `http://localhost:5173`

### 2. Access the Application

- **Landing Page**: http://localhost:5173
- **API Health Check**: http://localhost:3001/health
- **Admin Login**:
  - Username: `admin`
  - Password: `admin123`

### 3. Stop Development Environment

```powershell
docker-compose -f docker-compose.dev.yml down
```

To remove volumes (clean database):

```powershell
docker-compose -f docker-compose.dev.yml down -v
```

## File Storage System

### How It Works

Instead of storing images as base64 in MongoDB (inefficient), we now:

1. **Upload Files**: Images are uploaded to the API server
2. **Store Physically**: Files saved in `/app/server/uploads/` directory
3. **Reference URLs**: Only URLs stored in MongoDB (e.g., `/uploads/image-123456.jpg`)
4. **Serve Static**: Express serves files from the uploads directory

### Benefits

✅ **Faster Load Times**: Small URLs instead of large base64 strings
✅ **Reduced Database Size**: MongoDB only stores references
✅ **Better Performance**: Images served as static files
✅ **Easier Management**: Files can be backed up separately

## Architecture

```
┌─────────────────┐
│  Retail Frontend│  (Port 5173)
│   (Vite + React)│
└────────┬────────┘
         │
         │ HTTP API Calls
         ▼
┌─────────────────┐
│   Retail API    │  (Port 3001)
│   (Express.js)  │
└────┬───────┬────┘
     │       │
     │       │ File Storage
     │       ▼
     │  ┌──────────────┐
     │  │   Uploads/   │
     │  │ (Static Files)│
     │  └──────────────┘
     │
     │ Data Storage
     ▼
┌─────────────────┐
│    MongoDB      │  (Port 27017)
│   (Database)    │
└─────────────────┘
```

## API Endpoints

### Public Endpoints

- `GET /health` - Health check
- `GET /api/test` - API test
- `GET /api/content` - Fetch site content
- `GET /uploads/:filename` - Serve uploaded files

### Protected Endpoints (Requires Authentication)

- `POST /api/auth` - Admin login
- `POST /api/content` - Save site content
- `POST /api/upload` - Upload file
- `DELETE /api/upload/:filename` - Delete file

## Development Workflow

### 1. Admin Panel

1. Click "Admin Access" in footer
2. Login with credentials
3. Upload images - they'll be stored on the server
4. Save changes - only URLs stored in MongoDB

### 2. Hot Reload

Both frontend and backend support hot reload:

- **Frontend**: Vite HMR (instant updates)
- **Backend**: tsx watch (auto-restarts on changes)

### 3. Database Access

Connect to MongoDB using any client:

```
Connection String: mongodb://admin:admin123@localhost:27017/retail?authSource=admin
```

Recommended clients:

- MongoDB Compass
- Studio 3T
- VS Code MongoDB extension

## Migration from Base64 to File Storage

### Check for Base64 Images

```powershell
cd retail/server
npm run migrate
```

This will scan the database and report any base64 images found.

### Clean Database (Remove Base64)

```powershell
npm run migrate -- --force
```

⚠️ **Warning**: This will remove all base64 image data. You'll need to re-upload images through the admin panel.

## Troubleshooting

### Port Already in Use

If ports 3001, 5173, or 27017 are already in use:

1. Stop other services using these ports
2. Or modify ports in `docker-compose.dev.yml`

### Database Connection Failed

1. Check MongoDB container is running:

   ```powershell
   docker ps
   ```

2. Check logs:
   ```powershell
   docker logs retail-mongodb-dev
   ```

### File Upload Failed

1. Check uploads directory exists:

   ```powershell
   docker exec retail-api-dev ls -la /app/server/uploads
   ```

2. Check volume mount:
   ```powershell
   docker volume inspect retail_uploads_dev
   ```

### Cannot Access Admin Panel

1. Clear localStorage:

   ```javascript
   localStorage.clear();
   ```

2. Try default credentials again:
   - Username: `admin`
   - Password: `admin123`

## File Structure

```
retail/
├── server/
│   ├── index.ts              # Main API server
│   ├── migrate-images.ts     # Database migration script
│   ├── uploads/              # Uploaded files (gitignored)
│   ├── Dockerfile.dev        # Development API Dockerfile
│   └── package.json
├── components/
│   └── AdminPanel.tsx        # Admin UI (updated for file uploads)
├── services/
│   ├── database.ts           # Database client
│   └── storage.ts            # File upload service (NEW)
├── docker-compose.dev.yml    # Development Docker Compose
├── Dockerfile.dev            # Development Frontend Dockerfile
└── DEVELOPMENT.md            # This file
```

## Best Practices

### 1. Image Optimization

Before uploading images:

- Resize to appropriate dimensions
- Compress using tools like TinyPNG
- Use modern formats (WebP, AVIF)

### 2. File Naming

The system automatically generates unique filenames:

- Format: `{fieldname}-{timestamp}-{random}.{ext}`
- Example: `logo-1732453123456-789012345.jpg`

### 3. Storage Management

Monitor upload directory size:

```powershell
docker exec retail-api-dev du -sh /app/server/uploads
```

### 4. Backup Strategy

Backup uploads volume regularly:

```powershell
# Create backup
docker run --rm -v retail_uploads_dev:/data -v ${PWD}:/backup alpine tar czf /backup/uploads-backup.tar.gz -C /data .

# Restore backup
docker run --rm -v retail_uploads_dev:/data -v ${PWD}:/backup alpine tar xzf /backup/uploads-backup.tar.gz -C /data
```

## Production Deployment

For production, use the main `docker-compose.yml` instead:

```powershell
docker-compose up -d
```

Key differences:

- Optimized builds (no source mounts)
- Environment variables from .env file
- Nginx reverse proxy
- SSL certificates
- Better security settings

## Environment Variables

### Development (docker-compose.dev.yml)

```env
MONGO_URI=mongodb://admin:admin123@mongodb:27017/retail?authSource=admin
JWT_SECRET=dev-secret-key-change-in-production
NODE_ENV=development
PORT=3001
```

### Production

Use `.env` file:

```env
MONGO_USER=admin
MONGO_PASSWORD=<secure-password>
MONGO_DB=retail
RETAIL_JWT_SECRET=<secure-jwt-secret>
NODE_ENV=production
```

## Support

For issues or questions:

1. Check logs: `docker-compose -f docker-compose.dev.yml logs`
2. Restart services: `docker-compose -f docker-compose.dev.yml restart`
3. Clean slate: `docker-compose -f docker-compose.dev.yml down -v && docker-compose -f docker-compose.dev.yml up --build`

## License

Apache-2.0
