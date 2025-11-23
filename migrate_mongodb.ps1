# MongoDB Migration Script
# Migrates data from first server to second server

$SOURCE_SERVER = "103.126.116.50"
$TARGET_SERVER = "103.94.239.157"
$SSH_USER = "adminroot"
$BACKUP_DIR = "mongodb_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "MongoDB Migration Script" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Source: $SOURCE_SERVER" -ForegroundColor Yellow
Write-Host "Target: $TARGET_SERVER" -ForegroundColor Yellow
Write-Host ""

# Step 1: Create backup on source server
Write-Host "Step 1: Creating backup on source server..." -ForegroundColor Green
ssh ${SSH_USER}@${SOURCE_SERVER} @"
sudo docker exec mongodb mongodump --out /backup/$BACKUP_DIR --authenticationDatabase admin
sudo docker cp mongodb:/backup/$BACKUP_DIR /tmp/$BACKUP_DIR
sudo tar -czf /tmp/${BACKUP_DIR}.tar.gz -C /tmp $BACKUP_DIR
sudo chmod 644 /tmp/${BACKUP_DIR}.tar.gz
"@

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create backup on source server" -ForegroundColor Red
    exit 1
}

Write-Host "Backup created successfully!" -ForegroundColor Green
Write-Host ""

# Step 2: Download backup to local machine
Write-Host "Step 2: Downloading backup to local machine..." -ForegroundColor Green
scp ${SSH_USER}@${SOURCE_SERVER}:/tmp/${BACKUP_DIR}.tar.gz ./${BACKUP_DIR}.tar.gz

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to download backup" -ForegroundColor Red
    exit 1
}

Write-Host "Backup downloaded successfully!" -ForegroundColor Green
Write-Host ""

# Step 3: Upload backup to target server
Write-Host "Step 3: Uploading backup to target server..." -ForegroundColor Green
scp ./${BACKUP_DIR}.tar.gz ${SSH_USER}@${TARGET_SERVER}:/tmp/${BACKUP_DIR}.tar.gz

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to upload backup to target server" -ForegroundColor Red
    exit 1
}

Write-Host "Backup uploaded successfully!" -ForegroundColor Green
Write-Host ""

# Step 4: Restore backup on target server
Write-Host "Step 4: Restoring backup on target server..." -ForegroundColor Green
ssh ${SSH_USER}@${TARGET_SERVER} @"
cd /tmp
sudo tar -xzf ${BACKUP_DIR}.tar.gz
sudo docker cp $BACKUP_DIR mongodb:/tmp/
sudo docker exec mongodb mongorestore /tmp/$BACKUP_DIR --drop --authenticationDatabase admin
"@

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to restore backup on target server" -ForegroundColor Red
    exit 1
}

Write-Host "Backup restored successfully!" -ForegroundColor Green
Write-Host ""

# Step 5: Cleanup
Write-Host "Step 5: Cleaning up..." -ForegroundColor Green
ssh ${SSH_USER}@${SOURCE_SERVER} "sudo rm -rf /tmp/$BACKUP_DIR /tmp/${BACKUP_DIR}.tar.gz"
ssh ${SSH_USER}@${TARGET_SERVER} "sudo rm -rf /tmp/$BACKUP_DIR /tmp/${BACKUP_DIR}.tar.gz"
Remove-Item ./${BACKUP_DIR}.tar.gz -Force

Write-Host "Cleanup completed!" -ForegroundColor Green
Write-Host ""

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Migration completed successfully!" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
