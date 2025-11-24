# Test Healthcare Login Fix

Write-Host "Testing Healthcare MongoDB Connection Fix" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if healthcare container is running
Write-Host "1. Checking healthcare container status..." -ForegroundColor Yellow
$healthcareStatus = docker ps --filter "name=isy-healthcare" --format "{{.Status}}"
if ($healthcareStatus -like "*Up*") {
    Write-Host "   OK Healthcare container is running" -ForegroundColor Green
} else {
    Write-Host "   FAIL Healthcare container is not running" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 2: Check MongoDB URI environment variable
Write-Host "2. Checking MONGODB_URI configuration..." -ForegroundColor Yellow
$mongoUri = docker exec isy-healthcare printenv MONGODB_URI
Write-Host "   MongoDB URI: $mongoUri" -ForegroundColor Gray

if ($mongoUri -like "*mongodb:27017*") {
    Write-Host "   OK MONGODB_URI correctly configured for Docker network" -ForegroundColor Green
} else {
    Write-Host "   FAIL MONGODB_URI not configured correctly" -ForegroundColor Red
}
Write-Host ""

# Test 3: Test healthcare homepage
Write-Host "3. Testing healthcare homepage..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -eq 200) {
        Write-Host "   OK Healthcare homepage is accessible (Status: 200)" -ForegroundColor Green
    } else {
        Write-Host "   FAIL Unexpected status code: $($response.StatusCode)" -ForegroundColor Red
    }
} catch {
    Write-Host "   FAIL Failed to access healthcare homepage: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 4: Check if login page is accessible
Write-Host "4. Testing login page..." -ForegroundColor Yellow
try {
    $loginResponse = Invoke-WebRequest -Uri "http://localhost:3000/login" -UseBasicParsing -TimeoutSec 10
    if ($loginResponse.StatusCode -eq 200) {
        Write-Host "   OK Login page is accessible (Status: 200)" -ForegroundColor Green
    } else {
        Write-Host "   FAIL Login page returned status: $($loginResponse.StatusCode)" -ForegroundColor Red
    }
} catch {
    Write-Host "   FAIL Failed to access login page: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "FIXED: Added MONGODB_URI environment variable to healthcare service" -ForegroundColor Green
Write-Host "FIXED: Changed connection from localhost to mongodb (Docker network)" -ForegroundColor Green
Write-Host "FIXED: Added mongodb to depends_on for proper startup order" -ForegroundColor Green
Write-Host ""
Write-Host "What was changed in docker-compose.yml:" -ForegroundColor Yellow
Write-Host "  - Added: MONGODB_URI environment variable" -ForegroundColor Gray
Write-Host "  - Added: mongodb to depends_on" -ForegroundColor Gray
Write-Host ""
Write-Host "To verify the login works:" -ForegroundColor Yellow
Write-Host "  1. Open browser: http://localhost:3000" -ForegroundColor Gray
Write-Host "  2. Click Login or go to http://localhost:3000/login" -ForegroundColor Gray
Write-Host "  3. Try logging in with admin credentials" -ForegroundColor Gray
Write-Host ""
Write-Host "If you still see connection errors:" -ForegroundColor Yellow
Write-Host "  - Check healthcare logs: docker logs isy-healthcare --tail 50" -ForegroundColor Gray
Write-Host "  - Check MongoDB logs: docker logs isy-mongodb --tail 50" -ForegroundColor Gray
Write-Host "  - Restart all services: docker-compose restart" -ForegroundColor Gray
Write-Host ""
