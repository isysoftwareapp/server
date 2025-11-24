# Retail Development Environment - Quick Start Script
# This script sets up and runs the retail landing page in development mode

Write-Host "🚀 ISY.Software Retail - Development Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
Write-Host "🔍 Checking Docker..." -ForegroundColor Yellow
try {
    docker info | Out-Null
    Write-Host "✅ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not running. Please start Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Navigate to retail directory
$retailPath = Join-Path $PSScriptRoot "retail"
if (-not (Test-Path $retailPath)) {
    Write-Host "❌ Retail directory not found at: $retailPath" -ForegroundColor Red
    exit 1
}

Set-Location $retailPath
Write-Host "📁 Working directory: $retailPath" -ForegroundColor Gray
Write-Host ""

# Check if docker-compose.dev.yml exists
if (-not (Test-Path "docker-compose.dev.yml")) {
    Write-Host "❌ docker-compose.dev.yml not found!" -ForegroundColor Red
    exit 1
}

# Menu
Write-Host "What would you like to do?" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Start development environment (fresh build)" -ForegroundColor White
Write-Host "  2. Start development environment (quick start)" -ForegroundColor White
Write-Host "  3. Stop development environment" -ForegroundColor White
Write-Host "  4. Stop and remove volumes (clean slate)" -ForegroundColor White
Write-Host "  5. View logs" -ForegroundColor White
Write-Host "  6. Check database for base64 images" -ForegroundColor White
Write-Host "  7. Clean database (remove base64 images)" -ForegroundColor White
Write-Host "  0. Exit" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Enter your choice (0-7)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "🏗️  Building and starting services..." -ForegroundColor Yellow
        Write-Host ""
        docker-compose -f docker-compose.dev.yml up --build
    }
    "2" {
        Write-Host ""
        Write-Host "🚀 Starting services..." -ForegroundColor Yellow
        Write-Host ""
        docker-compose -f docker-compose.dev.yml up
    }
    "3" {
        Write-Host ""
        Write-Host "🛑 Stopping services..." -ForegroundColor Yellow
        docker-compose -f docker-compose.dev.yml down
        Write-Host ""
        Write-Host "✅ Services stopped" -ForegroundColor Green
    }
    "4" {
        Write-Host ""
        Write-Host "⚠️  This will remove all data (database + uploads)!" -ForegroundColor Red
        $confirm = Read-Host "Are you sure? (yes/no)"
        if ($confirm -eq "yes") {
            Write-Host ""
            Write-Host "🧹 Cleaning up..." -ForegroundColor Yellow
            docker-compose -f docker-compose.dev.yml down -v
            Write-Host ""
            Write-Host "✅ All data removed" -ForegroundColor Green
        } else {
            Write-Host "❌ Cancelled" -ForegroundColor Yellow
        }
    }
    "5" {
        Write-Host ""
        Write-Host "📋 Showing logs (Ctrl+C to exit)..." -ForegroundColor Yellow
        Write-Host ""
        docker-compose -f docker-compose.dev.yml logs -f
    }
    "6" {
        Write-Host ""
        Write-Host "🔍 Checking database..." -ForegroundColor Yellow
        Write-Host ""
        docker-compose -f docker-compose.dev.yml exec retail-api npm run migrate
    }
    "7" {
        Write-Host ""
        Write-Host "⚠️  This will remove all base64 images from the database!" -ForegroundColor Red
        Write-Host "⚠️  You will need to re-upload images through the admin panel." -ForegroundColor Red
        $confirm = Read-Host "Are you sure? (yes/no)"
        if ($confirm -eq "yes") {
            Write-Host ""
            Write-Host "🧹 Cleaning database..." -ForegroundColor Yellow
            docker-compose -f docker-compose.dev.yml exec retail-api npm run migrate -- --force
            Write-Host ""
            Write-Host "✅ Database cleaned" -ForegroundColor Green
        } else {
            Write-Host "❌ Cancelled" -ForegroundColor Yellow
        }
    }
    "0" {
        Write-Host ""
        Write-Host "👋 Goodbye!" -ForegroundColor Cyan
        exit 0
    }
    default {
        Write-Host ""
        Write-Host "❌ Invalid choice" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "📝 Quick Access URLs:" -ForegroundColor Cyan
Write-Host "   Landing Page: http://localhost:5173" -ForegroundColor White
Write-Host "   API Server:   http://localhost:3001" -ForegroundColor White
Write-Host "   MongoDB:      mongodb://localhost:27017" -ForegroundColor White
Write-Host ""
Write-Host "🔑 Admin Credentials:" -ForegroundColor Cyan
Write-Host "   Username: admin" -ForegroundColor White
Write-Host "   Password: admin123" -ForegroundColor White
Write-Host ""
