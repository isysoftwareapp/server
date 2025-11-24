# Complete Deployment Script for ISY Software Platform
# This script deploys the entire stack with centralized API architecture

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "ISY Software Platform Deployment" -ForegroundColor Cyan
Write-Host "Centralized API Architecture" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Pre-deployment checks
Write-Host "Step 1: Pre-deployment checks..." -ForegroundColor Yellow
Write-Host "Checking Docker..." -NoNewline
$dockerVersion = docker --version 2>$null
if ($dockerVersion) {
    Write-Host " ✓" -ForegroundColor Green
    Write-Host "  $dockerVersion" -ForegroundColor Gray
} else {
    Write-Host " ✗" -ForegroundColor Red
    Write-Host "  Docker is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

Write-Host "Checking Docker Compose..." -NoNewline
$composeVersion = docker-compose --version 2>$null
if ($composeVersion) {
    Write-Host " ✓" -ForegroundColor Green
    Write-Host "  $composeVersion" -ForegroundColor Gray
} else {
    Write-Host " ✗" -ForegroundColor Red
    Write-Host "  Docker Compose is not installed" -ForegroundColor Red
    exit 1
}

# Step 2: Environment configuration
Write-Host ""
Write-Host "Step 2: Environment configuration..." -ForegroundColor Yellow

if (!(Test-Path ".env")) {
    Write-Host "  Creating .env file..." -NoNewline
    Copy-Item ".env.example" ".env" -ErrorAction SilentlyContinue
    if (Test-Path ".env") {
        Write-Host " ✓" -ForegroundColor Green
        Write-Host "  ⚠️  Please edit .env with your settings" -ForegroundColor Yellow
    } else {
        Write-Host " ⚠️  Warning: Could not create .env" -ForegroundColor Yellow
    }
} else {
    Write-Host "  .env file exists ✓" -ForegroundColor Green
}

# Step 3: Stop any running containers
Write-Host ""
Write-Host "Step 3: Stopping existing containers..." -ForegroundColor Yellow
docker-compose down 2>$null
Write-Host "  Containers stopped ✓" -ForegroundColor Green

# Step 4: Build services
Write-Host ""
Write-Host "Step 4: Building services..." -ForegroundColor Yellow
Write-Host "  This may take several minutes on first run..." -ForegroundColor Gray

$services = @("isy-api", "healthcare", "retail")
foreach ($service in $services) {
    Write-Host "  Building $service..." -NoNewline
    $output = docker-compose build $service 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host " ✓" -ForegroundColor Green
    } else {
        Write-Host " ✗" -ForegroundColor Red
        Write-Host "  Error building $service" -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
        exit 1
    }
}

# Step 5: Start database
Write-Host ""
Write-Host "Step 5: Starting database..." -ForegroundColor Yellow
docker-compose up -d mongodb
Start-Sleep -Seconds 5

$mongoStatus = docker ps --filter "name=isy-mongodb" --format "{{.Status}}"
if ($mongoStatus -like "*Up*") {
    Write-Host "  MongoDB started ✓" -ForegroundColor Green
} else {
    Write-Host "  MongoDB failed to start ✗" -ForegroundColor Red
    docker logs isy-mongodb --tail 50
    exit 1
}

# Step 6: Start API
Write-Host ""
Write-Host "Step 6: Starting centralized API..." -ForegroundColor Yellow
docker-compose up -d isy-api
Start-Sleep -Seconds 3

$apiStatus = docker ps --filter "name=isy-api" --format "{{.Status}}"
if ($apiStatus -like "*Up*") {
    Write-Host "  API started ✓" -ForegroundColor Green
    
    # Test API health
    Write-Host "  Testing API health..." -NoNewline
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080/health" -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Host " ✓" -ForegroundColor Green
        } else {
            Write-Host " ⚠️  API responded but status code: $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " ⚠️  API not responding yet (may need more time)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  API failed to start ✗" -ForegroundColor Red
    docker logs isy-api --tail 50
    exit 1
}

# Step 7: Start frontend services
Write-Host ""
Write-Host "Step 7: Starting frontend services..." -ForegroundColor Yellow

Write-Host "  Starting healthcare frontend..." -NoNewline
docker-compose up -d healthcare
Start-Sleep -Seconds 2
$healthcareStatus = docker ps --filter "name=isy-healthcare" --format "{{.Status}}"
if ($healthcareStatus -like "*Up*") {
    Write-Host " ✓" -ForegroundColor Green
} else {
    Write-Host " ✗" -ForegroundColor Red
}

Write-Host "  Starting retail frontend..." -NoNewline
docker-compose up -d retail
Start-Sleep -Seconds 2
$retailStatus = docker ps --filter "name=isy-retail" --format "{{.Status}}"
if ($retailStatus -like "*Up*") {
    Write-Host " ✓" -ForegroundColor Green
} else {
    Write-Host " ✗" -ForegroundColor Red
}

# Step 8: Start nginx
Write-Host ""
Write-Host "Step 8: Starting nginx reverse proxy..." -ForegroundColor Yellow
docker-compose up -d nginx
Start-Sleep -Seconds 2

$nginxStatus = docker ps --filter "name=isy-nginx" --format "{{.Status}}"
if ($nginxStatus -like "*Up*") {
    Write-Host "  Nginx started ✓" -ForegroundColor Green
} else {
    Write-Host "  Nginx failed to start ✗" -ForegroundColor Red
    docker logs isy-nginx --tail 50
}

# Step 9: Verify deployment
Write-Host ""
Write-Host "Step 9: Verifying deployment..." -ForegroundColor Yellow

$containers = docker-compose ps --format json | ConvertFrom-Json
$runningCount = 0
$totalCount = 0

foreach ($container in $containers) {
    $totalCount++
    if ($container.State -eq "running") {
        $runningCount++
    }
}

Write-Host "  Running containers: $runningCount / $totalCount" -ForegroundColor $(if ($runningCount -eq $totalCount) { "Green" } else { "Yellow" })

# Step 10: Display access information
Write-Host ""
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Access URLs:" -ForegroundColor Yellow
Write-Host "  Healthcare:  http://localhost:3000" -ForegroundColor White
Write-Host "  Retail:      http://localhost:80" -ForegroundColor White
Write-Host "  API:         http://localhost:8080" -ForegroundColor White
Write-Host "  API Health:  http://localhost:8080/health" -ForegroundColor White
Write-Host ""
Write-Host "API Endpoints:" -ForegroundColor Yellow
Write-Host "  Healthcare:  http://localhost:8080/healthcare/v1/*" -ForegroundColor White
Write-Host "  Retail:      http://localhost:8080/retail/v1/*" -ForegroundColor White
Write-Host ""
Write-Host "Production URLs (after DNS/SSL setup):" -ForegroundColor Yellow
Write-Host "  Healthcare:  https://health.isy.software" -ForegroundColor White
Write-Host "  Retail:      https://retail.isy.software" -ForegroundColor White
Write-Host "  API:         https://api.isy.software" -ForegroundColor White
Write-Host ""
Write-Host "Useful Commands:" -ForegroundColor Yellow
Write-Host "  View logs:          docker-compose logs -f" -ForegroundColor Gray
Write-Host "  View API logs:      docker-compose logs -f isy-api" -ForegroundColor Gray
Write-Host "  Stop all:           docker-compose down" -ForegroundColor Gray
Write-Host "  Restart service:    docker-compose restart <service-name>" -ForegroundColor Gray
Write-Host "  Check status:       docker-compose ps" -ForegroundColor Gray
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Test applications in your browser" -ForegroundColor White
Write-Host "  2. Run database migration: .\migrate_databases.ps1" -ForegroundColor White
Write-Host "  3. Configure DNS for production domains" -ForegroundColor White
Write-Host "  4. Generate SSL certificates for HTTPS" -ForegroundColor White
Write-Host ""
Write-Host "Documentation:" -ForegroundColor Yellow
Write-Host "  API Architecture:     API_ARCHITECTURE.md" -ForegroundColor Gray
Write-Host "  Migration Guide:      MIGRATION_GUIDE.md" -ForegroundColor Gray
Write-Host "  Frontend Integration: FRONTEND_INTEGRATION.md" -ForegroundColor Gray
Write-Host "  Quick Deploy:         QUICK_DEPLOY.md" -ForegroundColor Gray
Write-Host ""
Write-Host "=================================" -ForegroundColor Cyan
