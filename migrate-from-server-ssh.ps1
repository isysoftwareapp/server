# Direct MongoDB Migration - Using mongodump/mongorestore on server
# This script connects to server via SSH and migrates MongoDB data

param(
    [string]$ServerSSH = "root@health.isy.software",
    [string]$LocalPassword = "SecurePassword123!"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MongoDB Migration - Server to Local (SSH)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "This script will:" -ForegroundColor Yellow
Write-Host "  1. SSH to server and create MongoDB dumps" -ForegroundColor Gray
Write-Host "  2. Copy dumps to local machine" -ForegroundColor Gray
Write-Host "  3. Restore to local Docker MongoDB" -ForegroundColor Gray
Write-Host ""

# Create backup directory
$backupDir = "mongodb-migration-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host "Creating backup directory: $backupDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Write-Host "✅ Directory created" -ForegroundColor Green
Write-Host ""

# Step 1: Create dumps on server
Write-Host "Step 1: Creating dumps on server..." -ForegroundColor Cyan
Write-Host ""

$dumpCommands = @"
echo '=== Creating MongoDB dumps on server ==='
mkdir -p /tmp/mongodb-migration

echo '1. Dumping isy_clinic database...'
docker exec isy-mongodb mongodump --uri='mongodb://admin:SecurePassword123!@localhost:27017/isy_clinic?authSource=admin' --out=/tmp/mongodb-dump --db=isy_clinic

echo '2. Dumping isy_retail database (if exists)...'
docker exec isy-mongodb mongodump --uri='mongodb://admin:SecurePassword123!@localhost:27017/isy_retail?authSource=admin' --out=/tmp/mongodb-dump --db=isy_retail 2>/dev/null || echo 'isy_retail not found, skipping'

echo '3. Copying dumps out of container...'
docker cp isy-mongodb:/tmp/mongodb-dump /tmp/mongodb-migration/

echo '4. Creating archive...'
cd /tmp/mongodb-migration
tar czf mongodb-backup.tar.gz mongodb-dump/

echo '=== Dumps created successfully ==='
ls -lh /tmp/mongodb-migration/mongodb-backup.tar.gz
"@

Write-Host "Executing on server via SSH..." -ForegroundColor Yellow
ssh $ServerSSH $dumpCommands

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create dumps on server" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify SSH access: ssh $ServerSSH 'echo Connected'" -ForegroundColor Gray
    Write-Host "  2. Check if MongoDB container is running on server" -ForegroundColor Gray
    Write-Host "  3. Verify MongoDB credentials on server" -ForegroundColor Gray
    exit 1
}

Write-Host "✅ Dumps created on server" -ForegroundColor Green
Write-Host ""

# Step 2: Copy from server to local
Write-Host "Step 2: Copying dumps from server to local..." -ForegroundColor Cyan
scp "${ServerSSH}:/tmp/mongodb-migration/mongodb-backup.tar.gz" "$backupDir/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to copy from server" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Dumps copied to local" -ForegroundColor Green
Write-Host ""

# Step 3: Extract locally
Write-Host "Step 3: Extracting dumps..." -ForegroundColor Cyan
tar -xzf "$backupDir/mongodb-backup.tar.gz" -C $backupDir

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to extract dumps" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Dumps extracted" -ForegroundColor Green
Write-Host ""

# Step 4: Restore to local MongoDB
Write-Host "Step 4: Restoring to local Docker MongoDB..." -ForegroundColor Cyan
Write-Host ""

# Copy to container
Write-Host "4a. Copying dumps to Docker container..." -ForegroundColor Yellow
docker cp "$backupDir/mongodb-dump" isy-mongodb:/tmp/

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to copy to container" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Copied to container" -ForegroundColor Green
Write-Host ""

# Restore isy_clinic
Write-Host "4b. Restoring isy_clinic database..." -ForegroundColor Yellow
docker exec isy-mongodb mongorestore --uri="mongodb://admin:${LocalPassword}@localhost:27017/isy_clinic?authSource=admin" /tmp/mongodb-dump/isy_clinic --drop

Write-Host "✅ isy_clinic restored" -ForegroundColor Green
Write-Host ""

# Restore isy_retail to isy_api
Write-Host "4c. Restoring isy_retail to isy_api (unified database)..." -ForegroundColor Yellow

$retailPath = "$backupDir/mongodb-dump/isy_retail"
if (Test-Path $retailPath) {
    docker cp "$backupDir/mongodb-dump/isy_retail" isy-mongodb:/tmp/mongodb-dump/
    docker exec isy-mongodb mongorestore --uri="mongodb://admin:${LocalPassword}@localhost:27017/isy_api?authSource=admin" --nsFrom='isy_retail.*' --nsTo='isy_api.*' /tmp/mongodb-dump/isy_retail
    Write-Host "✅ isy_retail data merged into isy_api" -ForegroundColor Green
} else {
    Write-Host "⚠️ isy_retail database not found on server, skipping" -ForegroundColor Yellow
}

Write-Host ""

# Step 5: Verify
Write-Host "Step 5: Verifying migration..." -ForegroundColor Cyan
Write-Host ""

$users = docker exec isy-mongodb mongosh -u admin -p $LocalPassword --authenticationDatabase admin isy_clinic --quiet --eval "db.users.countDocuments()"
$patients = docker exec isy-mongodb mongosh -u admin -p $LocalPassword --authenticationDatabase admin isy_clinic --quiet --eval "db.patients.countDocuments()"
$products = docker exec isy-mongodb mongosh -u admin -p $LocalPassword --authenticationDatabase admin isy_api --quiet --eval "db.products.countDocuments()"

Write-Host "Migration Results:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Healthcare (isy_clinic):" -ForegroundColor Cyan
Write-Host "  Users: $users" -ForegroundColor Gray
Write-Host "  Patients: $patients" -ForegroundColor Gray
Write-Host ""
Write-Host "Retail (isy_api):" -ForegroundColor Cyan
Write-Host "  Products: $products" -ForegroundColor Gray
Write-Host ""

# Cleanup
Write-Host "Step 6: Cleaning up..." -ForegroundColor Cyan
docker exec isy-mongodb rm -rf /tmp/mongodb-dump 2>&1 | Out-Null
ssh $ServerSSH "rm -rf /tmp/mongodb-migration" 2>&1 | Out-Null
Write-Host "✅ Cleanup complete" -ForegroundColor Green
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MIGRATION COMPLETE!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ([int]$users -gt 0) {
    Write-Host "✅ SUCCESS! $users users migrated" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now:" -ForegroundColor Yellow
    Write-Host "  1. Login to healthcare: http://localhost:3000/login" -ForegroundColor Gray
    Write-Host "  2. Access retail API: http://localhost:8080/retail/v1/products" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "⚠️ WARNING: No users found in database" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This might mean:" -ForegroundColor Yellow
    Write-Host "  1. Server database is empty" -ForegroundColor Gray
    Write-Host "  2. Different database name on server" -ForegroundColor Gray
    Write-Host "  3. Check server MongoDB manually" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "Backup saved in: $backupDir" -ForegroundColor Cyan
Write-Host "Delete after verifying: Remove-Item -Recurse -Force $backupDir" -ForegroundColor Gray
Write-Host ""
