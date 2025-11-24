# Database Migration Script for Windows PowerShell
# This script migrates data from individual MongoDB instances to the centralized API MongoDB

Write-Host "=== ISY Software Database Migration ===" -ForegroundColor Cyan

# Step 1: Check if old containers exist
Write-Host "`nStep 1: Checking existing containers..." -ForegroundColor Yellow
$healthcareContainer = docker ps -a --filter "name=isy-healthcare-mongodb" --format "{{.Names}}"
$retailContainer = docker ps -a --filter "name=retail-mongodb-dev" --format "{{.Names}}"

if ($healthcareContainer) {
    Write-Host "Found healthcare MongoDB container" -ForegroundColor Green
} else {
    Write-Host "Healthcare MongoDB container not found" -ForegroundColor Red
}

if ($retailContainer) {
    Write-Host "Found retail MongoDB container" -ForegroundColor Green
} else {
    Write-Host "Retail MongoDB container not found" -ForegroundColor Red
}

# Step 2: Ensure centralized MongoDB is running
Write-Host "`nStep 2: Starting centralized MongoDB..." -ForegroundColor Yellow
docker-compose up -d mongodb

Start-Sleep -Seconds 5

# Step 3: Migrate Healthcare Data
if ($healthcareContainer) {
    Write-Host "`nStep 3: Migrating healthcare data..." -ForegroundColor Yellow
    
    # Create backup directory
    docker exec $healthcareContainer mkdir -p /backup 2>$null
    
    # Export healthcare data
    Write-Host "Exporting healthcare database..."
    docker exec $healthcareContainer mongodump --username=admin --password=SecurePassword123! --authenticationDatabase=admin --db=isy_clinic --out=/backup
    
    # Copy to centralized MongoDB
    Write-Host "Copying to centralized MongoDB..."
    docker exec isy-mongodb mkdir -p /backup 2>$null
    docker cp "${healthcareContainer}:/backup" ./temp_backup
    docker cp ./temp_backup isy-mongodb:/backup
    
    # Import to centralized DB
    Write-Host "Importing healthcare data..."
    docker exec isy-mongodb mongorestore --username=admin --password=SecurePassword123! --authenticationDatabase=admin --db=isy_api /backup/isy_clinic
    
    # Cleanup
    Remove-Item -Recurse -Force ./temp_backup -ErrorAction SilentlyContinue
    
    Write-Host "Healthcare data migrated successfully!" -ForegroundColor Green
}

# Step 4: Migrate Retail Data
if ($retailContainer) {
    Write-Host "`nStep 4: Migrating retail data..." -ForegroundColor Yellow
    
    # Create backup directory
    docker exec $retailContainer mkdir -p /backup 2>$null
    
    # Export retail data
    Write-Host "Exporting retail database..."
    docker exec $retailContainer mongodump --username=admin --password=admin123 --authenticationDatabase=admin --db=retail --out=/backup
    
    # Copy to centralized MongoDB
    Write-Host "Copying to centralized MongoDB..."
    docker cp "${retailContainer}:/backup" ./temp_backup
    docker cp ./temp_backup isy-mongodb:/backup
    
    # Import to centralized DB
    Write-Host "Importing retail data..."
    docker exec isy-mongodb mongorestore --username=admin --password=SecurePassword123! --authenticationDatabase=admin --db=isy_api /backup/retail
    
    # Cleanup
    Remove-Item -Recurse -Force ./temp_backup -ErrorAction SilentlyContinue
    
    Write-Host "Retail data migrated successfully!" -ForegroundColor Green
}

# Step 5: Verify Migration
Write-Host "`nStep 5: Verifying migration..." -ForegroundColor Yellow
docker exec isy-mongodb mongosh --username=admin --password=SecurePassword123! --authenticationDatabase=admin isy_api --eval "print('Collections:'); db.getCollectionNames().forEach(c => print('  - ' + c)); print(''); print('Document counts:'); db.getCollectionNames().forEach(c => print('  ' + c + ': ' + db.getCollection(c).countDocuments({})));"

Write-Host "`n=== Migration Complete ===" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review the migrated data in MongoDB" -ForegroundColor White
Write-Host "2. Test the API endpoints: http://localhost:8080/health" -ForegroundColor White
Write-Host "3. Update application configs to use api.isy.software" -ForegroundColor White
Write-Host "4. After verification, stop old MongoDB containers:" -ForegroundColor White
Write-Host "   docker stop isy-healthcare-mongodb retail-mongodb-dev" -ForegroundColor Gray
