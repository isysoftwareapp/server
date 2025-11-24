# File Storage Migration - Summary

## What Was Changed

### ❌ Old System (Inefficient)

- Images converted to base64 strings
- Stored directly in MongoDB
- Large database size (each image = 100KB+ in database)
- Slow load times (entire base64 string sent over network)
- Poor performance (MongoDB not optimized for binary data)

### ✅ New System (Efficient)

- Images uploaded as files to server
- Stored in file system (`server/uploads/`)
- Only URLs stored in MongoDB (~50 bytes per image)
- Fast load times (images served as static files)
- Better performance (proper HTTP caching, CDN-ready)

## Performance Improvement Example

**Before (base64 in MongoDB):**

```json
{
  "logo": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAA..." // 150KB
}
```

**After (URL reference):**

```json
{
  "logo": "/uploads/logo-1732453123456-789012345.jpg" // ~45 bytes
}
```

**Savings:** ~99.97% reduction in database storage per image!

## Files Created/Modified

### ✅ Created Files

1. **`retail/services/storage.ts`**

   - File upload service
   - Handles FormData uploads
   - Returns URLs instead of base64

2. **`retail/server/migrate-images.ts`**

   - Database migration script
   - Scans for base64 images
   - Cleans database (optional)

3. **`retail/docker-compose.dev.yml`**

   - Development Docker setup
   - MongoDB + API + Frontend
   - Hot reload enabled

4. **`retail/server/Dockerfile.dev`**

   - Development API container
   - With source mounting

5. **`retail/Dockerfile.dev`**

   - Development frontend container
   - Vite dev server

6. **`retail/DEVELOPMENT.md`**

   - Complete setup guide
   - Troubleshooting
   - Architecture diagrams

7. **`dev-retail.ps1`**

   - Quick start script for Windows
   - Interactive menu
   - Database migration helpers

8. **`retail/server/uploads/.gitkeep`**
   - Ensures directory is tracked

### 🔧 Modified Files

1. **`retail/server/package.json`**

   - Added `multer` dependency
   - Added migration script

2. **`retail/server/index.ts`**

   - Added multer configuration
   - Added `/api/upload` endpoint (POST)
   - Added `/api/upload/:filename` endpoint (DELETE)
   - Added static file serving for `/uploads`
   - Reduced JSON limit from 50mb to 10mb

3. **`retail/components/AdminPanel.tsx`**

   - Changed `handleFileUpload` to use file upload API
   - No longer converts to base64
   - Returns URLs instead

4. **`docker-compose.yml`**

   - Added `retail_uploads` volume
   - Mounted to API container

5. **`retail/.gitignore`**
   - Added `server/uploads` directory
   - Ignores uploaded files

## How to Use

### 1. Local Development

```powershell
# Run the quick start script
.\dev-retail.ps1

# Or manually
cd retail
docker-compose -f docker-compose.dev.yml up --build
```

Access:

- Frontend: http://localhost:5173
- API: http://localhost:3001
- MongoDB: mongodb://localhost:27017

### 2. Check for Base64 Images

```powershell
cd retail/server
npm run migrate
```

### 3. Clean Database

```powershell
npm run migrate -- --force
```

⚠️ This removes all base64 images. Re-upload through admin panel.

### 4. Upload New Images

1. Go to http://localhost:5173
2. Click "Admin Access" (footer)
3. Login: `admin` / `admin123`
4. Upload images - they'll be stored on server
5. Save - only URLs stored in MongoDB

## Architecture

```
┌──────────────────┐
│  Browser/Client  │
└────────┬─────────┘
         │
         │ 1. Upload file (FormData)
         ▼
┌──────────────────┐
│   Express API    │
│   (multer)       │
└────┬────────┬────┘
     │        │
     │        │ 2. Save file
     │        ▼
     │   ┌──────────────┐
     │   │ File System  │
     │   │  /uploads/   │
     │   └──────────────┘
     │
     │ 3. Save URL
     ▼
┌──────────────────┐
│    MongoDB       │
│ {logo: "/up..."}│
└──────────────────┘

Later: Client requests /uploads/file.jpg → Served directly
```

## API Endpoints

### New Endpoints

**Upload File:**

```http
POST /api/upload
Authorization: Bearer <token>
Content-Type: multipart/form-data

Returns:
{
  "success": true,
  "url": "/uploads/logo-123456789.jpg",
  "filename": "logo-123456789.jpg",
  "size": 45678
}
```

**Delete File:**

```http
DELETE /api/upload/:filename
Authorization: Bearer <token>

Returns:
{
  "success": true,
  "message": "File deleted successfully"
}
```

**Serve File:**

```http
GET /uploads/:filename

Returns: Image file with proper headers
```

## Benefits

### 🚀 Performance

- **99.97% smaller** database records
- **Faster queries** (less data to transfer)
- **Better caching** (browser caches images)
- **CDN-ready** (can serve from CDN later)

### 💾 Storage

- **Separate concerns** (files vs. data)
- **Easier backups** (files + database separately)
- **No 16MB limit** (MongoDB document size limit)

### 🛠️ Maintenance

- **Easy to migrate** to S3/CloudFlare R2 later
- **Simple to debug** (can view files directly)
- **Better monitoring** (file system metrics)

## Migration Path

### Phase 1: Install ✅

```powershell
cd retail/server
npm install
```

### Phase 2: Check Database ✅

```powershell
npm run migrate
```

### Phase 3: Clean (Optional) ⚠️

```powershell
npm run migrate -- --force
```

### Phase 4: Re-upload

Use admin panel to upload new images

### Phase 5: Verify

Check database size:

```javascript
// Before: ~2MB with base64 images
// After: ~50KB with URLs only
```

## Production Deployment

The main `docker-compose.yml` is already updated with:

- ✅ Volume mount for uploads
- ✅ Persistent storage
- ✅ Automatic container restarts

Just deploy as normal:

```powershell
docker-compose up -d
```

## Future Enhancements

### Easy Wins

- [ ] Add image compression on upload
- [ ] Generate thumbnails automatically
- [ ] Add image validation (dimensions, format)

### Advanced

- [ ] Migrate to S3/R2 for CDN delivery
- [ ] Add image optimization pipeline
- [ ] Implement lazy loading
- [ ] Add WebP conversion

## Troubleshooting

### Files not uploading?

1. Check uploads directory exists: `docker exec retail-api-dev ls /app/server/uploads`
2. Check permissions
3. Check logs: `docker logs retail-api-dev`

### Images not loading?

1. Check URL format (should start with `/uploads/`)
2. Check file exists on server
3. Check static file serving is enabled
4. Check CORS settings

### Database still large?

1. Run migration check: `npm run migrate`
2. Clean base64 data: `npm run migrate -- --force`
3. Compact database: MongoDB may need compaction

## Support

Created: 2025-11-24
Author: GitHub Copilot
License: Apache-2.0

For questions:

1. Check `DEVELOPMENT.md` for detailed guide
2. Check Docker logs: `docker-compose logs`
3. Verify file permissions
4. Check network connectivity
