.PHONY: build run test clean docker-build docker-run dev deps

# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOMOD=$(GOCMD) mod

# Main package
MAIN_PACKAGE=main.go handlers.go
BINARY_NAME=main
BINARY_UNIX=$(BINARY_NAME)_unix

# Build the project
build:
	$(GOBUILD) -o $(BINARY_NAME) -v $(MAIN_PACKAGE)

# Run the project
run:
	$(GOCMD) run $(MAIN_PACKAGE)

# Test the project
test:
	$(GOTEST) -v ./...

# Clean build files
clean:
	$(GOCLEAN)
	rm -f $(BINARY_NAME)
	rm -f $(BINARY_UNIX)

# Run tests and build
all: test build

# Download dependencies
deps:
	$(GOMOD) tidy
	$(GOMOD) download

# Development mode with live reload (requires air)
dev:
	air

# Docker commands
docker-build:
	docker build -t isy-api .

docker-run:
	docker run -p 8080:8080 --env-file .env isy-api

docker-dev:
	docker-compose -f ../docker-compose.api.yml up --build

# Install development tools
install-tools:
	$(GOGET) -u github.com/cosmtrek/air

# Format code
fmt:
	$(GOCMD) fmt ./...

# Lint code
lint:
	golangci-lint run

# Create new migration (placeholder)
migrate-new:
	@echo "Creating new migration..."
	@read -p "Migration name: " name; \
	touch migrations/$$(date +%Y%m%d%H%M%S)_$$name.go

# Help
help:
	@echo "Available commands:"
	@echo "  build        - Build the binary"
	@echo "  run          - Run the application"
	@echo "  test         - Run tests"
	@echo "  clean        - Clean build files"
	@echo "  deps         - Download dependencies"
	@echo "  dev          - Run in development mode (requires air)"
	@echo "  docker-build - Build Docker image"
	@echo "  docker-run   - Run Docker container"
	@echo "  docker-dev   - Run with docker-compose"
	@echo "  fmt          - Format code"
	@echo "  lint         - Lint code"
	@echo "  install-tools- Install development tools"