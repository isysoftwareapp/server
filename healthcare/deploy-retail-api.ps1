# Deploy Retail API to Server

Write-Host "🚀 Deploying Retail API Server..." -ForegroundColor Green

# Copy server files
Write-Host "📦 Copying server files to production..." -ForegroundColor Yellow
scp -r retail\server adminroot@103.126.116.50:/tmp/retail-server/

# Copy deployment script
Write-Host "📋 Copying deployment script..." -ForegroundColor Yellow
scp deploy-retail-api.sh adminroot@103.126.116.50:/tmp/deploy-retail-api.sh

# Execute deployment on server
Write-Host "🐳 Executing deployment on server..." -ForegroundColor Yellow
ssh adminroot@103.126.116.50 @"
sudo rm -rf /root/retail/server
sudo mv /tmp/retail-server /root/retail/server
sudo mv /tmp/deploy-retail-api.sh /root/deploy-retail-api.sh
sudo chmod +x /root/deploy-retail-api.sh
cd /root/retail/server && sudo npm install
cd /root && sudo docker compose build retail-api
sudo docker compose up -d retail-api
"@

# Check status
Write-Host "✅ Checking deployment status..." -ForegroundColor Yellow
ssh adminroot@103.126.116.50 "sudo docker compose ps | grep retail-api"

Write-Host ""
Write-Host "🎉 Deployment complete!" -ForegroundColor Green
Write-Host "📊 API available at: https://isy.software/api/" -ForegroundColor Cyan
Write-Host "🔑 Default credentials:" -ForegroundColor Cyan
Write-Host "   Username: admin" -ForegroundColor White
Write-Host "   Password: admin123" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  Remember to change the default password!" -ForegroundColor Red
