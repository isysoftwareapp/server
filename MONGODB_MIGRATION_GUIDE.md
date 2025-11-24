# MongoDB Migration Guide - Server to Local Docker

## Current Status

**Local MongoDB Status:**

- ✅ `isy_clinic` database exists but has **0 users** (that's why login fails!)
- ✅ `isy_api` database has test data only (patients, products from testing)

**What needs to be migrated:**

- Healthcare data from server `isy_clinic` → local `isy_clinic`
- Retail data from server `isy_retail` → local `isy_api` (unified database)

---

## Quick Migration Methods

### Option 1: Automated Script (Recommended)

#### Using SSH Method:

```powershell
.\migrate-from-server-ssh.ps1 -ServerSSH "root@health.isy.software"
```

#### Using Direct MongoDB Connection:

```powershell
.\migrate-from-server.ps1 -ServerPassword "your_server_mongo_password"
```

---

### Option 2: Manual Migration

#### Step 1: On Server (via SSH)

```bash
# SSH to server
ssh root@health.isy.software

# Create dumps
docker exec isy-mongodb mongodump \
  --uri="mongodb://admin:SecurePassword123!@localhost:27017/isy_clinic?authSource=admin" \
  --out=/tmp/dump

docker exec isy-mongodb mongodump \
  --uri="mongodb://admin:SecurePassword123!@localhost:27017/isy_retail?authSource=admin" \
  --out=/tmp/dump

# Copy out of container
docker cp isy-mongodb:/tmp/dump /root/mongodb-backup

# Create archive
cd /root
tar czf mongodb-backup.tar.gz mongodb-backup/

# Exit SSH
exit
```

#### Step 2: Copy to Local (on your Windows machine)

```powershell
# Copy from server
scp root@health.isy.software:/root/mongodb-backup.tar.gz .

# Extract
tar -xzf mongodb-backup.tar.gz
```

#### Step 3: Restore to Local Docker MongoDB

```powershell
# Copy to container
docker cp mongodb-backup isy-mongodb:/tmp/

# Restore isy_clinic
docker exec isy-mongodb mongorestore `
  --uri="mongodb://admin:SecurePassword123!@localhost:27017/isy_clinic?authSource=admin" `
  /tmp/mongodb-backup/isy_clinic --drop

# Restore isy_retail to isy_api (unified database)
docker exec isy-mongodb mongorestore `
  --uri="mongodb://admin:SecurePassword123!@localhost:27017/isy_api?authSource=admin" `
  --nsFrom='isy_retail.*' --nsTo='isy_api.*' `
  /tmp/mongodb-backup/isy_retail
```

#### Step 4: Verify

```powershell
# Check users
docker exec isy-mongodb mongosh -u admin -p SecurePassword123! `
  --authenticationDatabase admin isy_clinic --quiet `
  --eval "db.users.countDocuments()"

# Check products
docker exec isy-mongodb mongosh -u admin -p SecurePassword123! `
  --authenticationDatabase admin isy_api --quiet `
  --eval "db.products.countDocuments()"
```

---

## Option 3: Using mongodump/mongorestore Directly (if installed locally)

```powershell
# Create backup directory
mkdir mongodb-migration
cd mongodb-migration

# Dump from server
mongodump --uri="mongodb://admin:PASSWORD@health.isy.software:27017/isy_clinic?authSource=admin" --out=./

mongodump --uri="mongodb://admin:PASSWORD@health.isy.software:27017/isy_retail?authSource=admin" --out=./

# Restore to local
mongorestore --uri="mongodb://admin:SecurePassword123!@localhost:27017/isy_clinic?authSource=admin" ./isy_clinic --drop

mongorestore --uri="mongodb://admin:SecurePassword123!@localhost:27017/isy_api?authSource=admin" --nsFrom='isy_retail.*' --nsTo='isy_api.*' ./isy_retail
```

---

## Verification Steps

After migration, verify the data:

### Check Healthcare Data

```powershell
# Count users
docker exec isy-mongodb mongosh -u admin -p SecurePassword123! `
  --authenticationDatabase admin isy_clinic --quiet `
  --eval "db.users.countDocuments()"

# List first user (to verify structure)
docker exec isy-mongodb mongosh -u admin -p SecurePassword123! `
  --authenticationDatabase admin isy_clinic --quiet `
  --eval "db.users.findOne()"

# Count patients
docker exec isy-mongodb mongosh -u admin -p SecurePassword123! `
  --authenticationDatabase admin isy_clinic --quiet `
  --eval "db.patients.countDocuments()"
```

### Check Retail Data

```powershell
# Count products
docker exec isy-mongodb mongosh -u admin -p SecurePassword123! `
  --authenticationDatabase admin isy_api --quiet `
  --eval "db.products.countDocuments()"

# Check collections
docker exec isy-mongodb mongosh -u admin -p SecurePassword123! `
  --authenticationDatabase admin isy_api --quiet `
  --eval "db.getCollectionNames()"
```

---

## Database Structure

### Healthcare (isy_clinic)

Collections migrated:

- `users` - User accounts and authentication
- `patients` - Patient records
- `appointments` - Appointments
- `medicalrecords` - Medical records
- `invoices` - Invoices
- `services` - Healthcare services
- `medications` - Medications
- `clinics` - Clinic information
- `exchangerates` - Currency exchange rates
- `notifications` - System notifications
- `messages` - Messages

### Retail (isy_retail → isy_api)

Collections migrated:

- `products` - Product inventory
- `categories` - Product categories
- `orders` - Customer orders
- `customers` - Customer information
- `metadata` - Store metadata

---

## After Migration

### Test Healthcare Login

1. Open browser: http://localhost:3000
2. Go to: http://localhost:3000/login
3. Use your admin credentials from server
4. Should successfully login

### Test Retail API

```powershell
# Get products
curl http://localhost:8080/retail/v1/products

# Get metadata
curl http://localhost:8080/retail/v1/metadata
```

---

## Troubleshooting

### Issue: "No users found after migration"

**Check if server has users:**

```bash
# On server
ssh root@health.isy.software
docker exec isy-mongodb mongosh -u admin -p SecurePassword123! \
  --authenticationDatabase admin isy_clinic --quiet \
  --eval "db.users.countDocuments()"
```

**Check database names on server:**

```bash
docker exec isy-mongodb mongosh -u admin -p SecurePassword123! \
  --authenticationDatabase admin --quiet \
  --eval "db.adminCommand('listDatabases')"
```

### Issue: "Connection refused"

Make sure:

1. Local MongoDB container is running: `docker ps | findstr isy-mongodb`
2. Server MongoDB port is accessible (may need to open firewall)

### Issue: "Authentication failed"

Verify credentials:

- Server MongoDB password in server's docker-compose.yml
- Local MongoDB password: `SecurePassword123!` (default)

---

## Database Unification Note

We're migrating `isy_retail` → `isy_api` because:

1. The centralized API server uses `isy_api` for both healthcare and retail
2. Keeps all API-related data in one database
3. Simplifies backup and management
4. Healthcare frontend uses `isy_clinic` for its own data
5. Both can coexist and reference each other via API

---

## Backup Recommendations

After successful migration:

1. Keep the backup files for a few days
2. Test all functionality thoroughly
3. Once confirmed working, can delete backup
4. Setup automated backups going forward

```powershell
# Delete backup after verification
Remove-Item -Recurse -Force mongodb-migration-*
```

---

## Next Steps After Migration

1. ✅ Verify login works
2. ✅ Test patient data access
3. ✅ Test retail product access
4. ✅ Update deployment documentation
5. ✅ Setup automated backup script
6. ✅ Document production credentials

---

**Created:** November 24, 2025  
**Purpose:** Migrate production data from server to local development environment  
**Target:** ISY Software Healthcare & Retail Applications
