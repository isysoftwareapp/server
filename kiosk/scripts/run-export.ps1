# Firebase Export Script Runner
# This script runs the Firebase export and verifies the results

Write-Host "🚀 Firebase Data Export" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host ""

# Check if service account key exists
$serviceAccountPath = Join-Path $PSScriptRoot "serviceAccountKey.json"
if (-not (Test-Path $serviceAccountPath)) {
    Write-Host "❌ ERROR: serviceAccountKey.json not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please download your Firebase service account key:" -ForegroundColor Yellow
    Write-Host "1. Go to: https://console.firebase.google.com/project/candy-kush/settings/serviceaccounts/adminsdk" -ForegroundColor Yellow
    Write-Host "2. Click 'Generate New Private Key'" -ForegroundColor Yellow
    Write-Host "3. Save the file as: $serviceAccountPath" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "✅ Found serviceAccountKey.json" -ForegroundColor Green
Write-Host ""

# Run the export
Write-Host "📦 Starting Firebase export..." -ForegroundColor Cyan
node export-firebase.js

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Export completed successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Show summary
    $summaryPath = Join-Path $PSScriptRoot "..\migration-data\export-summary.json"
    if (Test-Path $summaryPath) {
        Write-Host "📊 Export Summary:" -ForegroundColor Cyan
        Get-Content $summaryPath | ConvertFrom-Json | Format-List
    }
    
    Write-Host ""
    Write-Host "📂 Data exported to: $PSScriptRoot\..\migration-data" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next step: Run the MongoDB migration" -ForegroundColor Yellow
    Write-Host "  cd ..\.." -ForegroundColor Gray
    Write-Host "  .\migrate_kiosk_db.ps1 -ImportOnly" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ Export failed!" -ForegroundColor Red
    Write-Host "Please check the error messages above." -ForegroundColor Yellow
    exit 1
}
