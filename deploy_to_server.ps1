# PowerShell deployment script for ISY Healthcare multi-framework setup
# This script pushes local code to GitHub and deploys to server

param(
    [string]$ServerIP = "103.94.239.157",
    [string]$ServerUser = "adminroot",
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host "ISY Healthcare Multi-Framework Deployment" -ForegroundColor Cyan
Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host "Server: $ServerUser@$ServerIP" -ForegroundColor Yellow
Write-Host "Branch: $Branch" -ForegroundColor Yellow
Write-Host ""

# Step 1: Commit and push local changes to GitHub
Write-Host "Step 1: Pushing local code to GitHub..." -ForegroundColor Green
Write-Host "=======================================================================" -ForegroundColor Cyan

try {
    # Check if we're in a git repository
    $gitStatus = git status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Not in a git repository. Please initialize git first." -ForegroundColor Red
        exit 1
    }

    # Add all changes
    Write-Host "Adding changes..." -ForegroundColor Yellow
    git add .
    
    # Commit changes
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "Committing changes..." -ForegroundColor Yellow
    git commit -m "Deployment update: $timestamp" 2>&1 | Out-Null
    
    # Push to GitHub
    Write-Host "Pushing to GitHub ($Branch branch)..." -ForegroundColor Yellow
    git push origin $Branch
    
    Write-Host "✓ Code pushed to GitHub successfully!" -ForegroundColor Green
} catch {
    Write-Host "Note: No changes to commit or push failed (continuing anyway)" -ForegroundColor Yellow
}

Write-Host ""

# Step 2: Upload deployment script to server
Write-Host "Step 2: Uploading deployment script to server..." -ForegroundColor Green
Write-Host "=======================================================================" -ForegroundColor Cyan

scp ".\server_clone_and_deploy_improved.sh" "${ServerUser}@${ServerIP}:~/server_deploy.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to upload deployment script" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Deployment script uploaded!" -ForegroundColor Green
Write-Host ""

# Step 3: Run deployment on server
Write-Host "Step 3: Running deployment on server..." -ForegroundColor Green
Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host ""

ssh -t "${ServerUser}@${ServerIP}" "sudo bash ~/server_deploy.sh $Branch"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Deployment failed on server" -ForegroundColor Red
    Write-Host "Check logs with: ssh ${ServerUser}@${ServerIP} 'sudo docker compose logs'" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host "✓ DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Access your applications:" -ForegroundColor Yellow
Write-Host "  Healthcare: http://${ServerIP}/healthcare" -ForegroundColor Cyan
Write-Host "  Retail:     http://${ServerIP}/retail" -ForegroundColor Cyan
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Yellow
Write-Host "  View logs:     ssh ${ServerUser}@${ServerIP} 'sudo docker compose logs -f'" -ForegroundColor Gray
Write-Host "  Check status:  ssh ${ServerUser}@${ServerIP} 'sudo docker compose ps'" -ForegroundColor Gray
Write-Host "  Restart:       ssh ${ServerUser}@${ServerIP} 'sudo docker compose restart'" -ForegroundColor Gray
Write-Host ""
