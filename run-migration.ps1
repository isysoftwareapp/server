# Script to run base64 to file migration inside the API container

Write-Host "🚀 Running base64 to file migration..." -ForegroundColor Cyan
Write-Host ""

# Check if isy-api container is running
$containerRunning = ssh adminroot@103.94.239.157 "sudo docker ps | grep isy-api"

if (!$containerRunning) {
    Write-Host "❌ Error: isy-api container is not running" -ForegroundColor Red
    Write-Host "Please start the API container first"
    exit 1
}

# Copy migration tool to container
Write-Host "📦 Copying migration tool to container..." -ForegroundColor Yellow
$apiPath = "C:\Users\kevin\SynologyDrive\isy.software\isy.software\api"

# Build locally first
Push-Location "$apiPath\cmd\migrate-base64"
Write-Host "🔨 Building migration tool..." -ForegroundColor Yellow
$env:GOOS = "linux"
$env:GOARCH = "amd64"
$env:CGO_ENABLED = "0"
go build -o migrate-base64 .

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to build migration tool" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Copy to server
Write-Host "📤 Copying to server..." -ForegroundColor Yellow
scp migrate-base64 adminroot@103.94.239.157:/tmp/migrate-base64

# Copy into container and run
Write-Host ""
Write-Host "🔄 Running migration..." -ForegroundColor Yellow
Write-Host ""

ssh adminroot@103.94.239.157 @"
sudo docker cp /tmp/migrate-base64 isy-api:/app/migrate-base64
sudo docker exec isy-api chmod +x /app/migrate-base64
sudo docker exec isy-api sh -c 'cd /app && MONGO_URI=mongodb://admin:SecurePassword123!@isy-mongodb:27017/isy_api?authSource=admin ./migrate-base64'
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Migration completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📁 Uploaded files are now in the uploads directory" -ForegroundColor Cyan
    Write-Host "🌐 Files are accessible at: http://103.94.239.157:8080/uploads/" -ForegroundColor Cyan
    Write-Host "🌐 Or via domain: http://isy.software/api/uploads/" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "❌ Migration failed" -ForegroundColor Red
    exit 1
}

# Cleanup
Remove-Item migrate-base64 -ErrorAction SilentlyContinue
ssh adminroot@103.94.239.157 "rm /tmp/migrate-base64"

Pop-Location
