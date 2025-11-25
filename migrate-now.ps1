# Direct MongoDB Migration Script
# Migrates data from server to local Docker MongoDB

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MongoDB Migration - Direct Method" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ServerSSH = "adminroot@isy.software"
$LocalPassword = "SecurePassword123!"
$ServerContainer = "isy-healthcare-mongodb"
$LocalContainer = "isy-mongodb"

# Create backup directory
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = "mongodb-backup-$timestamp"

Write-Host "Step 1: Creating local backup directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Write-Host "   Created: $backupDir" -ForegroundColor Green
Write-Host ""

# Step 2: Dump from server
Write-Host "Step 2: Creating dumps on server..." -ForegroundColor Yellow
Write-Host "   This may take a few minutes depending on database size..." -ForegroundColor Gray
Write-Host ""

$serverCommands = @"
# Clean up any old dumps
sudo rm -rf /tmp/mongodb-backup 2>/dev/null

# Create backup directory
sudo mkdir -p /tmp/mongodb-backup

# Dump isy_clinic database
echo "Dumping isy_clinic..."
sudo docker exec $ServerContainer mongodump \
  --uri='mongodb://admin:SecurePassword123!@localhost:27017/isy_clinic?authSource=admin' \
  --out=/data/backup \
  --db=isy_clinic

# Dump isy_retail database (if exists)
echo "Dumping isy_retail..."
sudo docker exec $ServerContainer mongodump \
  --uri='mongodb://admin:SecurePassword123!@localhost:27017/isy_retail?authSource=admin' \
  --out=/data/backup \
  --db=isy_retail 2>/dev/null || echo "isy_retail not found, skipping"

# Copy dumps out of container
echo "Copying dumps from container..."
sudo docker cp ${ServerContainer}:/data/backup /tmp/mongodb-backup/

# Create tarball
echo "Creating archive..."
cd /tmp/mongodb-backup
sudo tar czf backup.tar.gz backup/
sudo chmod 644 backup.tar.gz

echo "Done! Archive created at /tmp/mongodb-backup/backup.tar.gz"
ls -lh /tmp/mongodb-backup/backup.tar.gz
"@

ssh -o StrictHostKeyChecking=no $ServerSSH $serverCommands

if ($LASTEXITCODE -ne 0) {
    Write-Host "   Failed to create dumps on server" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Please check:" -ForegroundColor Yellow
    Write-Host "   1. SSH access is working" -ForegroundColor Gray
    Write-Host "   2. MongoDB container is running on server" -ForegroundColor Gray
    Write-Host "   3. MongoDB credentials are correct" -ForegroundColor Gray
    exit 1
}

Write-Host "   Dumps created successfully on server" -ForegroundColor Green
Write-Host ""

# Step 3: Copy to local
Write-Host "Step 3: Downloading dumps from server..." -ForegroundColor Yellow
scp -o StrictHostKeyChecking=no "${ServerSSH}:/tmp/mongodb-backup/backup.tar.gz" "$backupDir/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "   Failed to download from server" -ForegroundColor Red
    exit 1
}

Write-Host "   Downloaded successfully" -ForegroundColor Green
Write-Host ""

# Step 4: Extract
Write-Host "Step 4: Extracting dumps..." -ForegroundColor Yellow
tar -xzf "$backupDir/backup.tar.gz" -C $backupDir

if ($LASTEXITCODE -ne 0) {
    Write-Host "   Failed to extract" -ForegroundColor Red
    exit 1
}

Write-Host "   Extracted successfully" -ForegroundColor Green
Write-Host ""

# Step 5: Copy to local container
Write-Host "Step 5: Copying to local MongoDB container..." -ForegroundColor Yellow

# Check if local container is running
$containerStatus = docker ps --filter "name=$LocalContainer" --format "{{.Status}}"
if (-not ($containerStatus -like "*Up*")) {
    Write-Host "   Local MongoDB container is not running!" -ForegroundColor Red
    Write-Host "   Start it with: docker-compose up -d mongodb" -ForegroundColor Yellow
    exit 1
}

docker cp "$backupDir/backup" "${LocalContainer}:/tmp/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "   Failed to copy to container" -ForegroundColor Red
    exit 1
}

Write-Host "   Copied to container" -ForegroundColor Green
Write-Host ""

# Step 6: Restore isy_clinic
Write-Host "Step 6: Restoring isy_clinic database..." -ForegroundColor Yellow
docker exec $LocalContainer mongorestore `
  --uri="mongodb://admin:${LocalPassword}@localhost:27017/isy_clinic?authSource=admin" `
  /tmp/backup/isy_clinic --drop 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "   isy_clinic restored successfully" -ForegroundColor Green
} else {
    Write-Host "   isy_clinic restore completed (check warnings above)" -ForegroundColor Yellow
}
Write-Host ""

# Step 7: Restore isy_retail to isy_api
Write-Host "Step 7: Restoring isy_retail to isy_api (unified database)..." -ForegroundColor Yellow

$retailPath = "$backupDir/backup/isy_retail"
if (Test-Path $retailPath) {
    docker exec $LocalContainer mongorestore `
      --uri="mongodb://admin:${LocalPassword}@localhost:27017/isy_api?authSource=admin" `
      --nsFrom='isy_retail.*' --nsTo='isy_api.*' `
      /tmp/backup/isy_retail 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   isy_retail data merged into isy_api successfully" -ForegroundColor Green
    } else {
        Write-Host "   isy_retail merge completed (check warnings above)" -ForegroundColor Yellow
    }
} else {
    Write-Host "   isy_retail database not found, skipping" -ForegroundColor Yellow
}
Write-Host ""

# Step 8: Verify
Write-Host "Step 8: Verifying migration..." -ForegroundColor Yellow
Write-Host ""

$users = docker exec $LocalContainer mongosh -u admin -p $LocalPassword `
  --authenticationDatabase admin isy_clinic --quiet `
  --eval "db.users.countDocuments()" 2>$null

$patients = docker exec $LocalContainer mongosh -u admin -p $LocalPassword `
  --authenticationDatabase admin isy_clinic --quiet `
  --eval "db.patients.countDocuments()" 2>$null

$appointments = docker exec $LocalContainer mongosh -u admin -p $LocalPassword `
  --authenticationDatabase admin isy_clinic --quiet `
  --eval "db.appointments.countDocuments()" 2>$null

$products = docker exec $LocalContainer mongosh -u admin -p $LocalPassword `
  --authenticationDatabase admin isy_api --quiet `
  --eval "db.products.countDocuments()" 2>$null

Write-Host "Migration Results:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Healthcare Database (isy_clinic):" -ForegroundColor Yellow
Write-Host "  Users: $users" -ForegroundColor Gray
Write-Host "  Patients: $patients" -ForegroundColor Gray
Write-Host "  Appointments: $appointments" -ForegroundColor Gray
Write-Host ""
Write-Host "Retail Database (isy_api):" -ForegroundColor Yellow
Write-Host "  Products: $products" -ForegroundColor Gray
Write-Host ""

# Step 9: Cleanup
Write-Host "Step 9: Cleaning up..." -ForegroundColor Yellow
docker exec $LocalContainer rm -rf /tmp/backup 2>&1 | Out-Null
ssh -o StrictHostKeyChecking=no $ServerSSH "sudo rm -rf /tmp/mongodb-backup" 2>&1 | Out-Null
Write-Host "   Cleanup complete" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MIGRATION COMPLETE!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($users -and [int]$users -gt 0) {
    Write-Host "SUCCESS! Migrated $users users from server" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now:" -ForegroundColor Yellow
    Write-Host "  1. Login to healthcare at: http://localhost:3000/login" -ForegroundColor Gray
    Write-Host "  2. Use your server admin credentials" -ForegroundColor Gray
    Write-Host "  3. Access retail API at: http://localhost:8080/retail/v1/products" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Backup saved in: $backupDir" -ForegroundColor Cyan
    Write-Host "You can delete it after verifying everything works" -ForegroundColor Gray
} else {
    Write-Host "WARNING: No users were migrated" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This could mean:" -ForegroundColor Yellow
    Write-Host "  1. The server database is empty" -ForegroundColor Gray
    Write-Host "  2. The database name on server is different" -ForegroundColor Gray
    Write-Host "  3. MongoDB credentials are incorrect" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Backup saved in: $backupDir" -ForegroundColor Cyan
    Write-Host "Check the backup folder for more details" -ForegroundColor Gray
}

Write-Host ""
Write-Host "To restart healthcare with new data:" -ForegroundColor Yellow
Write-Host "  docker-compose restart healthcare" -ForegroundColor Gray
Write-Host ""
