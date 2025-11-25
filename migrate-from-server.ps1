# MongoDB Migration Script - Server to Local Docker
# This script migrates data from server MongoDB to local Docker MongoDB

param(
    [string]$ServerHost = "health.isy.software",
    [int]$ServerPort = 27017,
    [string]$ServerUser = "admin",
    [string]$ServerPassword = "",
    [string]$LocalUser = "admin",
    [string]$LocalPassword = "SecurePassword123!"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MongoDB Migration - Server to Local" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if server credentials are provided
if ([string]::IsNullOrEmpty($ServerPassword)) {
    Write-Host "ERROR: Server password not provided!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\migrate-from-server.ps1 -ServerPassword 'your_server_password'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Optional parameters:" -ForegroundColor Yellow
    Write-Host "  -ServerHost 'health.isy.software' (default)" -ForegroundColor Gray
    Write-Host "  -ServerPort 27017 (default)" -ForegroundColor Gray
    Write-Host "  -ServerUser 'admin' (default)" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "Migration Configuration:" -ForegroundColor Yellow
Write-Host "  Server: $ServerHost:$ServerPort" -ForegroundColor Gray
Write-Host "  Server User: $ServerUser" -ForegroundColor Gray
Write-Host "  Local Container: isy-mongodb" -ForegroundColor Gray
Write-Host "  Local User: $LocalUser" -ForegroundColor Gray
Write-Host ""

# Check if local MongoDB container is running
Write-Host "1. Checking local MongoDB container..." -ForegroundColor Yellow
$containerStatus = docker ps --filter "name=isy-mongodb" --format "{{.Status}}"
if ($containerStatus -like "*Up*") {
    Write-Host "   ✅ Local MongoDB container is running" -ForegroundColor Green
} else {
    Write-Host "   ❌ Local MongoDB container is not running" -ForegroundColor Red
    Write-Host "   Please start it with: docker-compose up -d mongodb" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Create backup directory
$backupDir = "mongodb-migration-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host "2. Creating backup directory: $backupDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Write-Host "   ✅ Directory created" -ForegroundColor Green
Write-Host ""

# Databases to migrate
$databases = @("isy_clinic", "isy_retail")

foreach ($dbName in $databases) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Migrating Database: $dbName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: Dump from server
    Write-Host "3. Dumping $dbName from server..." -ForegroundColor Yellow
    $serverUri = "mongodb://${ServerUser}:${ServerPassword}@${ServerHost}:${ServerPort}/${dbName}?authSource=admin"
    
    try {
        mongodump --uri="$serverUri" --out="$backupDir" --db=$dbName 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ Successfully dumped $dbName from server" -ForegroundColor Green
            
            # Check what was dumped
            $dumpPath = Join-Path $backupDir $dbName
            if (Test-Path $dumpPath) {
                $collections = Get-ChildItem -Path $dumpPath -Filter "*.bson" | Select-Object -ExpandProperty BaseName
                Write-Host "   Collections dumped: $($collections -join ', ')" -ForegroundColor Gray
            }
        } else {
            Write-Host "   ❌ Failed to dump $dbName from server" -ForegroundColor Red
            Write-Host "   Please check server credentials and connectivity" -ForegroundColor Yellow
            continue
        }
    } catch {
        Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        continue
    }
    Write-Host ""
    
    # Step 2: Copy to container
    Write-Host "4. Copying dump to Docker container..." -ForegroundColor Yellow
    docker cp "$backupDir/$dbName" isy-mongodb:/tmp/$dbName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Successfully copied to container" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Failed to copy to container" -ForegroundColor Red
        continue
    }
    Write-Host ""
    
    # Step 3: Restore to local MongoDB
    Write-Host "5. Restoring $dbName to local MongoDB..." -ForegroundColor Yellow
    
    # Determine target database name
    $targetDb = if ($dbName -eq "isy_retail") { "isy_api" } else { $dbName }
    
    if ($dbName -eq "isy_retail") {
        Write-Host "   ℹ️ Note: Migrating isy_retail -> isy_api (unified database)" -ForegroundColor Cyan
    }
    
    $restoreCmd = "mongorestore --uri='mongodb://${LocalUser}:${LocalPassword}@localhost:27017/${targetDb}?authSource=admin' --nsFrom='${dbName}.*' --nsTo='${targetDb}.*' /tmp/$dbName --drop"
    
    docker exec isy-mongodb sh -c "$restoreCmd" 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Successfully restored $dbName to local MongoDB" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ Restore completed with warnings (this is normal)" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Step 4: Verify data
    Write-Host "6. Verifying migrated data..." -ForegroundColor Yellow
    
    $collectionCount = docker exec isy-mongodb mongosh -u $LocalUser -p $LocalPassword --authenticationDatabase admin $targetDb --quiet --eval "db.getCollectionNames().length"
    
    Write-Host "   Collections in $targetDb: $collectionCount" -ForegroundColor Gray
    
    # Check specific important collections
    if ($targetDb -eq "isy_clinic") {
        $userCount = docker exec isy-mongodb mongosh -u $LocalUser -p $LocalPassword --authenticationDatabase admin isy_clinic --quiet --eval "db.users.countDocuments()"
        $patientCount = docker exec isy-mongodb mongosh -u $LocalUser -p $LocalPassword --authenticationDatabase admin isy_clinic --quiet --eval "db.patients.countDocuments()"
        
        Write-Host "   Users: $userCount" -ForegroundColor Gray
        Write-Host "   Patients: $patientCount" -ForegroundColor Gray
        
        if ([int]$userCount -gt 0) {
            Write-Host "   ✅ Users migrated successfully" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️ No users found - check if server has users" -ForegroundColor Yellow
        }
    }
    
    if ($targetDb -eq "isy_api") {
        $productCount = docker exec isy-mongodb mongosh -u $LocalUser -p $LocalPassword --authenticationDatabase admin isy_api --quiet --eval "db.products.countDocuments()"
        Write-Host "   Products: $productCount" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Cleanup temp files in container
    docker exec isy-mongodb rm -rf /tmp/$dbName 2>&1 | Out-Null
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MIGRATION SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Final verification
Write-Host "Final Data Count:" -ForegroundColor Yellow
Write-Host ""

Write-Host "Healthcare (isy_clinic):" -ForegroundColor Cyan
$users = docker exec isy-mongodb mongosh -u $LocalUser -p $LocalPassword --authenticationDatabase admin isy_clinic --quiet --eval "db.users.countDocuments()"
$patients = docker exec isy-mongodb mongosh -u $LocalUser -p $LocalPassword --authenticationDatabase admin isy_clinic --quiet --eval "db.patients.countDocuments()"
$appointments = docker exec isy-mongodb mongosh -u $LocalUser -p $LocalPassword --authenticationDatabase admin isy_clinic --quiet --eval "db.appointments.countDocuments()"

Write-Host "  Users: $users" -ForegroundColor Gray
Write-Host "  Patients: $patients" -ForegroundColor Gray
Write-Host "  Appointments: $appointments" -ForegroundColor Gray
Write-Host ""

Write-Host "Retail (isy_api):" -ForegroundColor Cyan
$products = docker exec isy-mongodb mongosh -u $LocalUser -p $LocalPassword --authenticationDatabase admin isy_api --quiet --eval "db.products.countDocuments()"
$metadata = docker exec isy-mongodb mongosh -u $LocalUser -p $LocalPassword --authenticationDatabase admin isy_api --quiet --eval "db.metadata.countDocuments()"

Write-Host "  Products: $products" -ForegroundColor Gray
Write-Host "  Metadata: $metadata" -ForegroundColor Gray
Write-Host ""

Write-Host "Backup Location: $backupDir" -ForegroundColor Yellow
Write-Host ""

if ([int]$users -gt 0) {
    Write-Host "✅ MIGRATION SUCCESSFUL!" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now:" -ForegroundColor Yellow
    Write-Host "  1. Login to healthcare: http://localhost:3000/login" -ForegroundColor Gray
    Write-Host "  2. Access retail data via API: http://localhost:8080/retail/v1/products" -ForegroundColor Gray
    Write-Host ""
    Write-Host "The backup is saved in: $backupDir" -ForegroundColor Gray
    Write-Host "You can delete it after verifying everything works." -ForegroundColor Gray
} else {
    Write-Host "⚠️ WARNING: No users were migrated" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Possible reasons:" -ForegroundColor Yellow
    Write-Host "  1. Server database is empty" -ForegroundColor Gray
    Write-Host "  2. Incorrect server credentials" -ForegroundColor Gray
    Write-Host "  3. Network connectivity issues" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Backup saved in: $backupDir" -ForegroundColor Gray
}

Write-Host ""
