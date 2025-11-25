# Phase 2: Kiosk Database Migration Script
# This script exports Firebase data and imports it into MongoDB

param(
    [switch]$ExportOnly,
    [switch]$ImportOnly,
    [switch]$SkipFirebase
)

$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Kiosk Database Migration - Phase 2" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Paths
$rootDir = $PSScriptRoot
$scriptsDir = Join-Path $rootDir "kiosk\scripts"
$migrationToolDir = Join-Path $rootDir "api\kiosk\migration-tool"
$migrationDataDir = Join-Path $rootDir "kiosk\migration-data"

# Step 1: Export Firebase Data
if (-not $ImportOnly -and -not $SkipFirebase) {
    Write-Host "Step 1: Exporting Firebase Data" -ForegroundColor Yellow
    Write-Host "--------------------------------" -ForegroundColor Yellow
    
    # Check if service account key exists
    $serviceKeyPath = Join-Path $scriptsDir "serviceAccountKey.json"
    if (-not (Test-Path $serviceKeyPath)) {
        Write-Host "❌ ERROR: Firebase service account key not found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please follow these steps:" -ForegroundColor Yellow
        Write-Host "1. Go to Firebase Console -> Project Settings -> Service Accounts"
        Write-Host "2. Click 'Generate New Private Key'"
        Write-Host "3. Save the JSON file as: $serviceKeyPath"
        Write-Host "4. Update the storageBucket in export-firebase.js"
        Write-Host ""
        Write-Host "Then run this script again."
        exit 1
    }
    
    # Install Node dependencies
    Write-Host "Installing Node.js dependencies..." -ForegroundColor Gray
    Push-Location $scriptsDir
    try {
        npm install --silent
        Write-Host "✅ Dependencies installed" -ForegroundColor Green
        
        # Run export
        Write-Host ""
        Write-Host "Running Firebase export..." -ForegroundColor Gray
        npm run export
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Firebase data exported successfully" -ForegroundColor Green
        } else {
            Write-Host "❌ Firebase export failed" -ForegroundColor Red
            exit 1
        }
    } finally {
        Pop-Location
    }
}

if ($ExportOnly) {
    Write-Host ""
    Write-Host "✅ Export complete! Data saved to: $migrationDataDir" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Review the exported data in migration-data/"
    Write-Host "2. Ensure MongoDB is running"
    Write-Host "3. Run: .\migrate_databases.ps1 -ImportOnly"
    exit 0
}

Write-Host ""

# Step 2: Check MongoDB
if (-not $ImportOnly -or -not $SkipFirebase) {
    Write-Host "Step 2: Checking MongoDB Connection" -ForegroundColor Yellow
    Write-Host "------------------------------------" -ForegroundColor Yellow
    
    # Check if Docker is running
    $dockerRunning = docker ps 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  WARNING: Docker doesn't seem to be running" -ForegroundColor Yellow
        Write-Host "Make sure MongoDB is accessible at localhost:27017"
        Write-Host ""
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne "y") {
            exit 1
        }
    } else {
        # Check if MongoDB container is running
        $mongoContainer = docker ps --filter "name=isy-mongodb" --format "{{.Names}}"
        if ($mongoContainer) {
            Write-Host "✅ MongoDB container is running: $mongoContainer" -ForegroundColor Green
        } else {
            Write-Host "⚠️  WARNING: MongoDB container not found" -ForegroundColor Yellow
            Write-Host "Starting MongoDB with docker-compose..."
            docker-compose up -d mongodb
            Start-Sleep -Seconds 5
        }
    }
}

Write-Host ""

# Step 3: Import to MongoDB
Write-Host "Step 3: Importing to MongoDB" -ForegroundColor Yellow
Write-Host "-----------------------------" -ForegroundColor Yellow

# Check if migration data exists
if (-not (Test-Path $migrationDataDir)) {
    Write-Host "❌ ERROR: Migration data not found at: $migrationDataDir" -ForegroundColor Red
    Write-Host "Please run the Firebase export first: .\migrate_databases.ps1 -ExportOnly"
    exit 1
}

# Install Go dependencies
Write-Host "Installing Go dependencies..." -ForegroundColor Gray
Push-Location $migrationToolDir
try {
    go mod tidy
    Write-Host "✅ Go dependencies installed" -ForegroundColor Green
    
    # Run migration
    Write-Host ""
    Write-Host "Running MongoDB import..." -ForegroundColor Gray
    go run migrate.go
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ MongoDB import completed successfully" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "❌ MongoDB import failed" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "✅ Phase 2 Migration Complete!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  📦 Exported Firebase collections to JSON"
Write-Host "  📁 Downloaded Firebase Storage files"
Write-Host "  ✅ Imported all data to MongoDB"
Write-Host "  🔐 Created/updated admin users with hashed passwords"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Verify data in MongoDB:"
Write-Host "     docker exec -it isy-mongodb mongosh -u admin -p SecurePassword123!"
Write-Host "     > use kiosk"
Write-Host "     > db.products.countDocuments()"
Write-Host ""
Write-Host "  2. Test API endpoints:"
Write-Host "     Invoke-WebRequest -Uri 'http://localhost:8080/kiosk/v1/products' -Method GET"
Write-Host ""
Write-Host "  3. Update MIGRATION_TODO.md to mark Phase 2 as complete"
Write-Host ""
Write-Host "  4. Proceed to Phase 3: Frontend Updates"
Write-Host ""

# Show admin credentials if default was created
$summaryFile = Join-Path $migrationDataDir "export-summary.json"
if (Test-Path $summaryFile) {
    $summary = Get-Content $summaryFile | ConvertFrom-Json
    Write-Host "Migration Statistics:" -ForegroundColor Cyan
    Write-Host "  Total Documents: $($summary.totalDocuments)"
    Write-Host "  Total Files: $($summary.totalFiles)"
    Write-Host "  Duration: $($summary.duration)"
    Write-Host ""
}

Write-Host "⚠️  IMPORTANT: If a default admin was created, change the password!" -ForegroundColor Yellow
Write-Host "   Default credentials: username=admin, password=admin123" -ForegroundColor Red
Write-Host ""
