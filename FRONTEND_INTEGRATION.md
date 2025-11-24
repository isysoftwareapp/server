# Frontend API Integration Guide

This guide explains how the healthcare and retail frontends have been updated to use the centralized API.

## 🎯 Overview

### Retail Application

- **Status**: ✅ **Fully Migrated**
- **API Endpoints**: `/retail/v1/*`
- **Configuration**: `VITE_API_URL` environment variable

### Healthcare Application

- **Status**: ⚠️ **Hybrid Architecture**
- **Current**: Next.js API routes (built-in backend)
- **Future**: Can gradually migrate to centralized API
- **API Endpoints**: `/healthcare/v1/*`

## 🛠️ Retail Frontend Changes

### Files Modified

#### 1. `retail/services/database.ts`

**Changes:**

- Updated `API_BASE` to use `VITE_API_URL` environment variable
- Changed endpoints to use `/retail/v1/metadata` instead of `/retail/api/content`
- Added response format handling for centralized API structure
- Implemented temporary authentication (to be replaced with real auth)

**Before:**

```typescript
const API_BASE = import.meta.env.DEV
  ? "https://isy.software/retail/api"
  : "/retail/api";

const response = await fetch(`${API_BASE}/content`);
```

**After:**

```typescript
const API_BASE = import.meta.env.VITE_API_URL || "http://localhost:8080";
const RETAIL_API_PATH = "/retail/v1";

const response = await fetch(`${API_BASE}${RETAIL_API_PATH}/metadata`);
```

#### 2. `retail/services/storage.ts`

**Changes:**

- Updated file upload/delete endpoints to use centralized API
- Added explicit URL logging for debugging

**Before:**

```typescript
const response = await fetch(`${API_BASE}/upload`, {...});
```

**After:**

```typescript
const url = `${API_BASE}${API_PATH}/upload`;
const response = await fetch(url, {...});
```

### Environment Configuration

#### Development (`.env`)

```env
VITE_API_URL=http://localhost:8080
```

#### Production (`.env.production`)

```env
VITE_API_URL=https://api.isy.software
```

### API Response Format

The centralized API returns responses in this format:

```json
{
  "success": true,
  "data": {
    "type": "retail",
    "content": { ... },
    "updatedAt": "2025-11-24T08:00:00Z"
  }
}
```

Or on error:

```json
{
  "success": false,
  "error": "Error message"
}
```

### Testing Retail Integration

```powershell
# 1. Start the centralized API
docker-compose up -d isy-api mongodb

# 2. Set environment variable
cd retail
echo "VITE_API_URL=http://localhost:8080" > .env

# 3. Start retail frontend
npm run dev

# 4. Test in browser
# Navigate to http://localhost:5173
# Check browser console for API calls
```

## 🏥 Healthcare Frontend Architecture

### Current Setup

Healthcare uses **Next.js API Routes** as its backend:

```
healthcare/
├── app/
│   ├── api/                    # Backend API routes
│   │   ├── patients/
│   │   ├── appointments/
│   │   ├── medical-records/
│   │   └── ...
│   └── [locale]/              # Frontend pages
├── components/                 # React components
├── lib/
│   ├── mongodb.ts             # Direct DB connection
│   ├── rbac.ts                # Authentication
│   └── apiHelpers.ts          # API utilities
└── models/                     # MongoDB models
```

### Why Not Migrated Yet?

1. **Tight Integration**: Next.js API routes are deeply integrated with:

   - NextAuth.js authentication
   - MongoDB models and schemas
   - RBAC (Role-Based Access Control)
   - Audit logging
   - File uploads

2. **Complex Features**: Healthcare has advanced features:

   - Multi-clinic support
   - Real-time notifications
   - Complex permission system
   - Document management
   - Reporting system

3. **Works Well**: Current architecture is stable and performant

### Future Migration Path

Healthcare can gradually migrate to centralized API:

#### Phase 1: Non-Critical Endpoints

Migrate simple read-only endpoints first:

- Patient list (public profiles)
- Appointment availability
- Clinic information

#### Phase 2: CRUD Operations

Move create/update/delete operations:

- Patient registration
- Appointment booking
- Medical record creation

#### Phase 3: Complex Features

Last to migrate:

- Authentication and authorization
- File uploads and management
- Real-time features
- Reporting

### Hybrid Approach Example

You can use both Next.js API routes and centralized API:

```typescript
// healthcare/lib/apiClient.ts
const USE_CENTRALIZED_API =
  process.env.NEXT_PUBLIC_USE_CENTRALIZED_API === "true";
const CENTRALIZED_API_URL =
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";

export async function getPatients() {
  if (USE_CENTRALIZED_API) {
    // Use centralized Go API
    const response = await fetch(
      `${CENTRALIZED_API_URL}/healthcare/v1/patients`
    );
    return response.json();
  } else {
    // Use Next.js API route
    const response = await fetch("/api/patients");
    return response.json();
  }
}
```

## 📊 API Endpoint Mapping

### Retail Endpoints

| Frontend Call              | Centralized API                   | Method | Description       |
| -------------------------- | --------------------------------- | ------ | ----------------- |
| `fetchSiteContent()`       | `GET /retail/v1/metadata`         | GET    | Get site content  |
| `saveSiteContent(content)` | `POST /retail/v1/metadata`        | POST   | Save site content |
| `uploadFile(file)`         | `POST /api/v1/upload`             | POST   | Upload file       |
| `deleteFile(url)`          | `DELETE /api/v1/upload/:filename` | DELETE | Delete file       |

### Healthcare Endpoints (Available in Centralized API)

| Feature               | Centralized API                       | Method | Status       |
| --------------------- | ------------------------------------- | ------ | ------------ |
| List patients         | `GET /healthcare/v1/patients`         | GET    | ✅ Available |
| Create patient        | `POST /healthcare/v1/patients`        | POST   | ✅ Available |
| List appointments     | `GET /healthcare/v1/appointments`     | GET    | ✅ Available |
| Create appointment    | `POST /healthcare/v1/appointments`    | POST   | ✅ Available |
| List medical records  | `GET /healthcare/v1/medical-records`  | GET    | ✅ Available |
| Create medical record | `POST /healthcare/v1/medical-records` | POST   | ✅ Available |

**Note:** Healthcare currently uses Next.js API routes. The centralized API endpoints are available but not yet integrated into the frontend.

## 🔧 Configuration

### Retail Configuration

1. **Development**

   ```bash
   cd retail
   cp .env.example .env
   # Edit .env and set:
   VITE_API_URL=http://localhost:8080
   ```

2. **Production**
   ```bash
   # In docker-compose.yml
   retail:
     environment:
       - VITE_API_URL=https://api.isy.software
   ```

### Healthcare Configuration

1. **Current Setup** (No changes needed)

   ```env
   MONGODB_URI=mongodb://admin:password@mongodb:27017/isy_clinic
   NEXTAUTH_URL=https://health.isy.software
   NEXTAUTH_SECRET=your-secret-key
   ```

2. **Future API Integration** (Optional)
   ```env
   NEXT_PUBLIC_API_URL=https://api.isy.software
   NEXT_PUBLIC_USE_CENTRALIZED_API=false
   ```

## 🧪 Testing

### Test Retail Integration

```powershell
# 1. Ensure API is running
curl http://localhost:8080/health

# 2. Test retail metadata endpoint
curl http://localhost:8080/retail/v1/metadata

# 3. Start retail frontend
cd retail
npm run dev

# 4. Open browser and check console logs
# You should see API calls to http://localhost:8080/retail/v1/*
```

### Test Healthcare API (Not Yet Integrated)

```powershell
# Test available healthcare endpoints
curl http://localhost:8080/healthcare/v1/patients
curl http://localhost:8080/healthcare/v1/appointments

# Note: These work but healthcare frontend still uses Next.js API routes
```

## 🚀 Deployment

### Retail Deployment

```yaml
# docker-compose.yml
retail:
  build:
    context: ./retail
  environment:
    - VITE_API_URL=https://api.isy.software # ← Use centralized API
  depends_on:
    - isy-api # ← Depends on centralized API
```

### Healthcare Deployment

```yaml
# docker-compose.yml
healthcare:
  build:
    context: ./healthcare
  environment:
    - MONGODB_URI=mongodb://admin:password@mongodb:27017/isy_clinic # ← Still uses MongoDB directly
    - NEXTAUTH_URL=https://health.isy.software
    # Optional: Add for future API integration
    - NEXT_PUBLIC_API_URL=https://api.isy.software
```

## 📝 Summary

### ✅ Completed

- [x] Centralized Go API created with healthcare and retail packages
- [x] Retail frontend fully migrated to use centralized API
- [x] API endpoints follow clear naming: `/healthcare/v1/*` and `/retail/v1/*`
- [x] Environment configuration for retail
- [x] File upload/storage updated for retail

### ⏳ Pending

- [ ] Healthcare frontend migration (optional - can stay as-is)
- [ ] Authentication endpoints in centralized API
- [ ] JWT token management
- [ ] Gradual migration of healthcare features

### 🎯 Recommendation

**For Retail**: Use centralized API (already done) ✅

**For Healthcare**:

- **Short term**: Keep using Next.js API routes (stable and feature-complete)
- **Long term**: Gradually migrate non-critical endpoints to centralized API
- **Benefit**: Can use both architectures simultaneously during transition

## 🆘 Troubleshooting

### Retail: API calls failing

```powershell
# Check if API is running
docker ps | Select-String "isy-api"

# Check API logs
docker logs isy-api

# Test API directly
curl http://localhost:8080/retail/v1/metadata
```

### Retail: CORS errors

The centralized API has CORS enabled. If you see CORS errors:

1. Check API logs for the request
2. Verify `VITE_API_URL` is set correctly
3. Ensure API is accessible from frontend

### Healthcare: Still using old endpoints

This is expected! Healthcare uses Next.js API routes and doesn't need to change unless you want to migrate specific features.

## 📚 Additional Resources

- **API Documentation**: `api/README.md`
- **Migration Guide**: `MIGRATION_GUIDE.md`
- **Architecture Overview**: `API_ARCHITECTURE.md`
- **Quick Deploy**: `QUICK_DEPLOY.md`
