# Image Upload Implementation

## Overview
The API now supports proper file upload with storage instead of base64 encoding. This provides better performance and efficiency.

## Upload Endpoint

**Endpoint:** `POST /api/v1/upload`

**Request:** Multipart form data with file field

**Example (cURL):**
```bash
curl -X POST https://api.isy.software/api/v1/upload \
  -F "file=@/path/to/image.png"
```

**Response:**
```json
{
  "success": true,
  "data": {
    "url": "/uploads/8339509970f90f8a72adb4a00315b5e3.png",
    "filename": "image.png",
    "size": 12345,
    "type": "image/png"
  }
}
```

## Features

### File Validation
- Only image files are accepted
- Maximum file size: 10MB
- Supported formats: PNG, JPEG, GIF, WebP

### Storage
- Files are stored in `/root/uploads` directory in the API container
- Unique filenames are generated using random hex strings
- Files are publicly accessible via `/uploads/` path

### Public Access
Images are served via nginx with:
- 30-day cache expiration
- CORS enabled (Access-Control-Allow-Origin: *)
- Immutable cache control

**Access URL:**
```
https://api.isy.software/uploads/{filename}
https://isy.software/uploads/{filename}
```

## Delete Endpoint

**Endpoint:** `DELETE /api/v1/upload/{filename}`

**Example:**
```bash
curl -X DELETE https://api.isy.software/api/v1/upload/8339509970f90f8a72adb4a00315b5e3.png
```

## Base64 Migration

A migration endpoint is provided to convert existing base64 images to files.

**Endpoint:** `POST /api/v1/migrate-base64`

**What it does:**
- Scans all metadata documents
- Finds base64-encoded images (data:image/...)
- Converts them to files
- Updates database with file URLs
- Processes images in: `content.images`, `content.features[].image`, `content.products[].image`

**Example:**
```bash
curl -X POST https://api.isy.software/api/v1/migrate-base64
```

**Response:**
```json
{
  "success": true,
  "data": {
    "processed": 1,
    "migrated": 1,
    "errors": []
  }
}
```

## Usage in Admin Panel

When uploading an image in the admin CMS:

1. Select an image file
2. Call the upload endpoint with the file
3. Receive the URL in the response
4. Store the URL (not base64) in the database
5. Display using the returned URL

## Benefits

✅ **Performance:** Loading images from files is much faster than parsing large base64 strings  
✅ **Efficiency:** Reduces database size and memory usage  
✅ **Caching:** Browsers and CDNs can cache image files properly  
✅ **Bandwidth:** Images can be served with proper compression and caching headers  
✅ **Scalability:** File storage is easier to scale than database storage

## Migration Status

✅ Migration completed successfully on November 24, 2025
- 1 document processed
- 1 document migrated
- All base64 images converted to file URLs
- Images accessible at: https://api.isy.software/uploads/

## Notes

- Files persist across container restarts (stored in Docker volume)
- Old base64 images were automatically migrated
- Future uploads should use the upload endpoint
- Maximum upload size is 10MB (configurable in nginx)
