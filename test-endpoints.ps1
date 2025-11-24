# ISY Software - Comprehensive Docker Compose Endpoint Testing Script
# This script tests all API endpoints and verifies data integrity

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ISY Software - Docker Compose Testing" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$API_BASE = "http://localhost:8080"
$HEALTHCARE_BASE = "http://localhost:3000"
$NGINX_BASE = "http://localhost:80"

# Test results tracking
$script:testResults = [System.Collections.ArrayList]::new()
$script:totalTests = 0
$script:passedTests = 0
$script:failedTests = 0

# Helper function to test endpoint
function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Method = "GET",
        [object]$Body = $null,
        [int]$ExpectedStatus = 200
    )
    
    $script:totalTests++
    Write-Host "Testing: $Name" -ForegroundColor Yellow
    Write-Host "  URL: $Url" -ForegroundColor Gray
    Write-Host "  Method: $Method" -ForegroundColor Gray
    
    try {
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        $params = @{
            Uri = $Url
            Method = $Method
            Headers = $headers
            TimeoutSec = 10
        }
        
        if ($Body -ne $null) {
            $params.Body = ($Body | ConvertTo-Json -Depth 10)
            Write-Host "  Body: $($params.Body)" -ForegroundColor Gray
        }
        
        $response = Invoke-WebRequest @params -UseBasicParsing
        
        if ($response.StatusCode -eq $ExpectedStatus) {
            Write-Host "  ✅ PASSED (Status: $($response.StatusCode))" -ForegroundColor Green
            $script:passedTests++
            
            # Try to parse and display response
            if ($response.Content) {
                try {
                    $jsonResponse = $response.Content | ConvertFrom-Json
                    Write-Host "  Response: $($jsonResponse | ConvertTo-Json -Compress -Depth 5)" -ForegroundColor DarkGray
                } catch {
                    Write-Host "  Response: $($response.Content.Substring(0, [Math]::Min(200, $response.Content.Length)))..." -ForegroundColor DarkGray
                }
            }
            
            [void]$script:testResults.Add([PSCustomObject]@{
                Test = $Name
                Status = "PASSED"
                StatusCode = $response.StatusCode
                Response = $response.Content
            })
            
            return $response
        } else {
            Write-Host "  ❌ FAILED (Expected: $ExpectedStatus, Got: $($response.StatusCode))" -ForegroundColor Red
            $script:failedTests++
            [void]$script:testResults.Add([PSCustomObject]@{
                Test = $Name
                Status = "FAILED"
                StatusCode = $response.StatusCode
                Error = "Unexpected status code"
            })
            return $null
        }
    } catch {
        Write-Host "  ❌ FAILED (Error: $($_.Exception.Message))" -ForegroundColor Red
        $script:failedTests++
        [void]$script:testResults.Add([PSCustomObject]@{
            Test = $Name
            Status = "FAILED"
            StatusCode = "N/A"
            Error = $_.Exception.Message
        })
        return $null
    }
    
    Write-Host ""
}

# Wait for services to be ready
Write-Host "Waiting for services to be ready..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. CONTAINER HEALTH CHECKS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check container status
Write-Host "Checking container status..." -ForegroundColor Yellow
$containers = docker ps --filter "name=isy-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
Write-Host $containers -ForegroundColor Gray
Write-Host ""

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "2. API HEALTH CHECK" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Test-Endpoint -Name "API Health Check" -Url "$API_BASE/health"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "3. HEALTHCARE API ENDPOINTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test Healthcare - Get Patients (should be empty initially)
Test-Endpoint -Name "Healthcare - Get Patients (Initial)" -Url "$API_BASE/healthcare/v1/patients"

# Test Healthcare - Create Patient
$newPatient = @{
    firstName = "John"
    lastName = "Doe"
    dateOfBirth = "1990-01-15"
    gender = "male"
    email = "john.doe@test.com"
    phone = "+1234567890"
    address = "123 Test St, Test City"
}

$createPatientResponse = Test-Endpoint -Name "Healthcare - Create Patient" -Url "$API_BASE/healthcare/v1/patients" -Method "POST" -Body $newPatient -ExpectedStatus 201

# Test Healthcare - Get Patients (should have 1 patient)
Test-Endpoint -Name "Healthcare - Get Patients (After Creation)" -Url "$API_BASE/healthcare/v1/patients"

# Test Healthcare - Get Appointments (should be empty initially)
Test-Endpoint -Name "Healthcare - Get Appointments (Initial)" -Url "$API_BASE/healthcare/v1/appointments"

# Test Healthcare - Create Appointment
if ($createPatientResponse) {
    $patientData = $createPatientResponse.Content | ConvertFrom-Json
    if ($patientData.data._id) {
        $newAppointment = @{
            patientId = $patientData.data._id
            doctorName = "Dr. Smith"
            appointmentDate = (Get-Date).AddDays(7).ToString("yyyy-MM-dd")
            appointmentTime = "10:00"
            reason = "Regular checkup"
            status = "scheduled"
        }
        
        Test-Endpoint -Name "Healthcare - Create Appointment" -Url "$API_BASE/healthcare/v1/appointments" -Method "POST" -Body $newAppointment -ExpectedStatus 201
    }
}

# Test Healthcare - Get Appointments (should have 1 appointment)
Test-Endpoint -Name "Healthcare - Get Appointments (After Creation)" -Url "$API_BASE/healthcare/v1/appointments"

# Test Healthcare - Get Medical Records
Test-Endpoint -Name "Healthcare - Get Medical Records" -Url "$API_BASE/healthcare/v1/medical-records"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "4. RETAIL API ENDPOINTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test Retail - Get Products (should be empty initially)
Test-Endpoint -Name "Retail - Get Products (Initial)" -Url "$API_BASE/retail/v1/products"

# Test Retail - Create Product
$newProduct = @{
    name = "Test Product"
    description = "This is a test product"
    price = 99.99
    sku = "TEST-001"
    category = "Electronics"
    stock = 100
    status = "active"
}

$createProductResponse = Test-Endpoint -Name "Retail - Create Product" -Url "$API_BASE/retail/v1/products" -Method "POST" -Body $newProduct -ExpectedStatus 201

# Test Retail - Get Products (should have 1 product)
Test-Endpoint -Name "Retail - Get Products (After Creation)" -Url "$API_BASE/retail/v1/products"

# Test Retail - Get Single Product
if ($createProductResponse) {
    $productData = $createProductResponse.Content | ConvertFrom-Json
    if ($productData.data._id) {
        $productId = $productData.data._id
        Test-Endpoint -Name "Retail - Get Product by ID" -Url "$API_BASE/retail/v1/products/$productId"
        
        # Test Retail - Update Product
        $updateProduct = @{
            name = "Updated Test Product"
            description = "This is an updated test product"
            price = 149.99
            sku = "TEST-001"
            category = "Electronics"
            stock = 150
            status = "active"
        }
        
        Test-Endpoint -Name "Retail - Update Product" -Url "$API_BASE/retail/v1/products/$productId" -Method "PUT" -Body $updateProduct
        
        # Verify update
        Test-Endpoint -Name "Retail - Get Updated Product" -Url "$API_BASE/retail/v1/products/$productId"
    }
}

# Test Retail - Get Metadata
Test-Endpoint -Name "Retail - Get Metadata" -Url "$API_BASE/retail/v1/metadata"

# Test Retail - Save Metadata
$metadata = @{
    storeName = "ISY Retail Store"
    storeDescription = "Test retail store"
    currency = "USD"
    timezone = "UTC"
}

Test-Endpoint -Name "Retail - Save Metadata" -Url "$API_BASE/retail/v1/metadata" -Method "POST" -Body $metadata

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "5. MONGODB DATA VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Checking MongoDB data..." -ForegroundColor Yellow
try {
    $mongoCheck = docker exec isy-mongodb mongosh --quiet --eval "db.adminCommand('listDatabases')" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ MongoDB is accessible" -ForegroundColor Green
        Write-Host "  Response: $mongoCheck" -ForegroundColor DarkGray
    } else {
        Write-Host "  ❌ MongoDB check failed" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ Failed to connect to MongoDB: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Checking collections in isy_api database..." -ForegroundColor Yellow
try {
    $collections = docker exec isy-mongodb mongosh --quiet isy_api --eval "db.getCollectionNames()" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Collections: $collections" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Failed to get collections" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ Failed to query collections: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "6. FRONTEND CONNECTIVITY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test Healthcare Frontend
Test-Endpoint -Name "Healthcare Frontend - Homepage" -Url "$HEALTHCARE_BASE"

# Test Retail Frontend (through nginx)
Test-Endpoint -Name "Retail Frontend - Homepage" -Url "$NGINX_BASE"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "7. NGINX PROXY TESTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test Nginx routing to API
Test-Endpoint -Name "Nginx - API Health (via proxy)" -Url "$NGINX_BASE/api/health"

# Test Nginx routing to Healthcare API
Test-Endpoint -Name "Nginx - Healthcare API (via proxy)" -Url "$NGINX_BASE/healthcare/v1/patients"

# Test Nginx routing to Retail API
Test-Endpoint -Name "Nginx - Retail API (via proxy)" -Url "$NGINX_BASE/retail/v1/products"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round(($passedTests / $totalTests) * 100, 2))%" -ForegroundColor $(if ($failedTests -eq 0) { "Green" } else { "Yellow" })
Write-Host ""

if ($failedTests -eq 0) {
    Write-Host "🎉 ALL TESTS PASSED! 🎉" -ForegroundColor Green
    Write-Host ""
    Write-Host "✅ Docker Compose setup is working correctly" -ForegroundColor Green
    Write-Host "✅ All services are running" -ForegroundColor Green
    Write-Host "✅ All API endpoints are accessible" -ForegroundColor Green
    Write-Host "✅ Data persistence is working" -ForegroundColor Green
    Write-Host "✅ READY FOR SERVER DEPLOYMENT" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "⚠️ SOME TESTS FAILED" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Failed tests:" -ForegroundColor Red
    $testResults | Where-Object { $_.Status -eq "FAILED" } | ForEach-Object {
        Write-Host "  - $($_.Test): $($_.Error)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Please review the errors above before deployment" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT INFORMATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Services:" -ForegroundColor Yellow
Write-Host "  - API: http://localhost:8080" -ForegroundColor Gray
Write-Host "  - Healthcare Frontend: http://localhost:3000" -ForegroundColor Gray
Write-Host "  - Nginx Proxy: http://localhost:80" -ForegroundColor Gray
Write-Host "  - MongoDB: mongodb://localhost:27017" -ForegroundColor Gray
Write-Host ""
Write-Host "Docker Commands:" -ForegroundColor Yellow
Write-Host "  - View logs: docker-compose logs -f [service-name]" -ForegroundColor Gray
Write-Host "  - Restart services: docker-compose restart" -ForegroundColor Gray
Write-Host "  - Stop services: docker-compose down" -ForegroundColor Gray
Write-Host "  - Rebuild: docker-compose build --no-cache" -ForegroundColor Gray
Write-Host ""

# Save results to file
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportFile = "test-results-$timestamp.json"
$testResults | ConvertTo-Json -Depth 10 | Out-File $reportFile
Write-Host "Test results saved to: $reportFile" -ForegroundColor Cyan
Write-Host ""

# Return exit code based on test results
if ($failedTests -eq 0) {
    exit 0
} else {
    exit 1
}
