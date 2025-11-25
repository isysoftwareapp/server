# Kiosk Firebase to MongoDB Migration Todo

This document tracks the migration of the kiosk application from Firebase (Firestore, Auth, Storage) to a MongoDB backend with Golang API, enabling deployment on the server infrastructure.

**Migration Overview**: Convert the Next.js kiosk app from client-side Firebase operations to server-side Golang API with MongoDB, integrating with existing Docker/MongoDB setup.

**Estimated Timeline**: 2-4 weeks  
**Current Status**: Phase 2 - Database Migration  
**Last Updated**: November 25, 2025

## Phase 1: Setup and Infrastructure ✅ COMPLETE

- [x] **Integrate Kiosk into Server Docker Setup**

  - ✅ Add new service to `docker-compose.yml` for kiosk app (build from kiosk context, expose port 3002)
  - ✅ Update `nginx.conf` to proxy kiosk routes to kiosk container (kiosk.isy.software)
  - ✅ Ensure `isy-mongodb` is accessible (use `mongodb://admin:SecurePassword123!@mongodb:27017/kiosk?authSource=admin` for new kiosk database)
  - ✅ Test: Run `docker-compose up` and verify kiosk container starts

- [x] **Create Kiosk Go Handlers**

  - ✅ Create `api/kiosk/handlers.go` (similar to `api/retail/handlers.go`)
  - ✅ Define structs for kiosk entities: `Product`, `Customer`, `Order`, `Category` (map Firestore fields to MongoDB)
  - ✅ Implement basic CRUD handlers: `GetProducts`, `CreateProduct`, `GetCustomers`, `Authenticate` (JWT-based auth replacing Firebase Auth)
  - ✅ Add to `api/main.go`: Initialize `kioskHandlers := kiosk.NewKioskHandlers(a.DB)` and route `/kiosk/v1/*` endpoints
  - ✅ Use `bcrypt` for password hashing and `jwt` for tokens (install via `go mod tidy`)

- [x] **Environment and Config**
  - ✅ `NEXT_PUBLIC_API_URL` configured in docker-compose.yml (points to api.isy.software)
  - ⚠️ TODO: Create `kiosk/.env.local` for local development
  - ⚠️ TODO: Remove Firebase env vars from kiosk (will be done in Phase 3)

## Phase 2: Database Migration (3-5 days) 🔄 IN PROGRESS

- [x] **Export Firebase Data** ✅

  - ✅ Created Firebase Admin SDK script: `kiosk/scripts/export-firebase.js`
  - ✅ Script exports all Firestore collections (products, customers, orders, categories, admins) to JSON
  - ✅ Script downloads Firebase Storage files to `kiosk/migration-data/uploads/`
  - ✅ Created comprehensive README with setup instructions
  - ⏳ **TODO**: Download Firebase service account key and run export
    ```powershell
    cd kiosk/scripts
    npm install
    # Add serviceAccountKey.json first!
    npm run export
    ```

- [x] **Create MongoDB Collections and Import** ✅

  - ✅ MongoDB collections defined in `api/kiosk/handlers.go`: products, customers, orders, categories
  - ✅ Created migration tool: `api/kiosk/migration-tool/migrate.go`
  - ✅ Handles data transformations: Firestore timestamps → Go `time.Time`, nested objects, arrays
  - ✅ Special handling for admin passwords (bcrypt hashing)
  - ✅ Creates default admin if none exist (username: admin, password: admin123)
  - ✅ Created PowerShell automation script: `migrate_kiosk_db.ps1`
  - ⏳ **TODO**: Run migration after Firebase export completes

    ```powershell
    # Option 1: Run full migration (export + import)
    .\migrate_kiosk_db.ps1

    # Option 2: Import only (if already exported)
    .\migrate_kiosk_db.ps1 -ImportOnly
    ```

- [x] **Replace Firebase Auth with JWT** ✅

  - ✅ `Authenticate` handler implemented in `api/kiosk/handlers.go`
  - ✅ Verifies username/password against `admins` collection
  - ✅ Generates JWT tokens with 24-hour expiry
  - ✅ Uses bcrypt for secure password comparison
  - ⏳ **TODO**: Update kiosk frontend to use API auth (Phase 3)
  - ⏳ **TODO**: Implement JWT middleware for protected routes
  - ⏳ **TODO**: Add token refresh logic

## Phase 3: Frontend Updates (5-7 days)

- [ ] **Update Firebase Calls to API Calls**

  - In `kiosk/src/lib`, replace `firebase.js` with `api.js` (fetch-based client for Go endpoints)
  - Update pages like customer management: Change Firestore queries to API fetches (e.g., `fetch('/kiosk/customers')`)
  - Handle real-time updates: Replace Firestore listeners with polling or WebSockets (add Socket.io to Go API if needed)
  - Update storage: Replace Firebase Storage with API uploads to `/kiosk/upload` (store files locally in `uploads/` volume)

- [ ] **Sync External APIs**

  - Keep Loyverse integration but route through Go: Create `/kiosk/sync-loyverse` handler to fetch and store data in MongoDB
  - Update kiosk pages to call this endpoint instead of direct Firebase sync

- [ ] **Error Handling and Validation**
  - Add input validation in Go handlers (e.g., required fields for products)
  - Implement CORS in Go API for kiosk frontend

## Phase 4: Testing and Deployment (3-5 days)

- [ ] **Unit and Integration Tests**

  - Add Go tests for handlers (e.g., `handlers_test.go`)
  - Test kiosk frontend: Login, CRUD operations, data sync
  - Verify data integrity: Compare Firebase export with MongoDB import

- [ ] **Deploy and Monitor**

  - Update `server_clone_and_deploy.sh` to include kiosk build
  - Run full stack: `docker-compose up`; test endpoints via `test-endpoints.ps1`
  - Monitor logs: Ensure no Firebase dependencies remain

- [ ] **Rollback Plan**
  - Keep Firebase config as backup; add feature flag to switch back if issues arise

## Key Dependencies

- MongoDB connection string: `mongodb://admin:SecurePassword123!@mongodb:27017/kiosk?authSource=admin`
- Go modules: `github.com/golang-jwt/jwt/v5`, `golang.org/x/crypto/bcrypt`
- Docker services: `isy-mongodb`, new `kiosk` service
- External APIs: Loyverse integration to remain functional

## Risks and Mitigations

- **Data Loss**: Backup Firebase data before migration; test import thoroughly
- **Auth Issues**: Implement JWT refresh logic early
- **Real-time Features**: Polling may increase server load; consider WebSockets
- **Performance**: Batch imports for large datasets; optimize queries

## Progress Tracking

- [x] Phase 1 Complete ✅
- [ ] Phase 2 Complete (Backend ready, awaiting Firebase export)
- [ ] Phase 3 Complete
- [ ] Phase 4 Complete
- [ ] Full Migration Complete
- [ ] Deployed on Server

## Quick Start Guide

### Phase 2 Migration Steps:

1. **Prepare Firebase Export**

   ```powershell
   # Download service account key from Firebase Console
   # Save as: kiosk/scripts/serviceAccountKey.json
   # Edit kiosk/scripts/export-firebase.js and set your storage bucket
   ```

2. **Run Migration**

   ```powershell
   # Ensure MongoDB is running
   docker-compose up -d mongodb

   # Run full migration (export + import)
   .\migrate_kiosk_db.ps1
   ```

3. **Verify Migration**

   ```powershell
   # Check MongoDB data
   docker exec -it isy-mongodb mongosh -u admin -p SecurePassword123!
   > use kiosk
   > db.products.countDocuments()
   > db.customers.countDocuments()

   # Test API endpoint
   Invoke-WebRequest -Uri "http://localhost:8080/kiosk/v1/products" -Method GET
   ```

4. **Next Steps**
   - Once data is verified, proceed to Phase 3: Frontend Updates
   - Update kiosk app to use API instead of Firebase
   - Remove Firebase dependencies

## Notes

- Reference `api/retail/handlers.go` for Go API patterns
- Test with small dataset first before full migration
- Update this document as tasks are completed
