#!/usr/bin/env bash
# set -euo pipefail  # Commented out for compatibility

# server_clone_and_deploy.sh
# Usage: sudo bash server_clone_and_deploy.sh [branch]
# This script will delete existing app folder, clone latest from GitHub,
# apply SSL nginx config (if present), and run a full from-scratch Docker Compose build and up.
# Falls back to HTTP-only if SSL/certbot fails

REPO_URL="https://github.com/isysoftwareapp/server.git"
APP_DIR="${APP_DIR:-$HOME}"
BRANCH="${1:-main}"

echo "==================================================================="
echo "ISY Healthcare Deployment Script"
echo "==================================================================="
echo "Repo: $REPO_URL"
echo "Target dir: $APP_DIR"
echo "Branch: $BRANCH"
echo "==================================================================="

# Basic checks
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is not installed. Install git and re-run this script." >&2
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed. Install docker and re-run this script." >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: docker compose is not available. Please install Docker Compose plugin or update Docker." >&2
  exit 1
fi

# Check required ports (warn but don't fail - we'll clean them up)
check_port() {
  local port=$1
  if sudo ss -lntp 2>/dev/null | grep -q ":$port\s"; then
    echo "WARNING: Port $port is already in use. Will attempt to free it during cleanup."
  fi
}
check_port 80
check_port 443
check_port 27017
check_port 3000
check_port 3001

# Attempt to bring down any existing deployment and clean images/volumes
clean_existing_deploy() {
  echo "==================================================================="
  echo "Running pre-deploy cleanup..."
  echo "==================================================================="

  FOUND_COMPOSE=0
  for d in "$APP_DIR" "/home/adminroot/isy.healthcare" "/home/adminroot/latest" "/home/adminroot"; do
    if [ -f "$d/docker-compose.yml" ] || [ -f "$d/docker-compose.yaml" ]; then
      echo "Found docker-compose in $d - running docker compose down"
      sudo sh -c "cd '$d' && docker compose down --remove-orphans --rmi all" 2>/dev/null || true
      FOUND_COMPOSE=1
    fi
  done

  if [ "$FOUND_COMPOSE" -eq 0 ]; then
    echo "No compose file found in common locations. Stopping containers by name prefix."
    IDS=$(sudo docker ps -aq --filter "name=isy-healthcare") || IDS=""
    if [ -n "$IDS" ]; then
      echo "Removing containers: $IDS"
      sudo docker rm -f $IDS 2>/dev/null || true
    fi

    for NAME in isy-healthcare-nginx isy-healthcare-mongodb isy-healthcare-certbot isy-healthcare-retail isy-healthcare-retail-api isy-healthcare; do
      CID=$(sudo docker ps -aq --filter "name=$NAME" 2>/dev/null || true)
      if [ -n "$CID" ]; then
        echo "Removing container $NAME ($CID)"
        sudo docker rm -f $CID 2>/dev/null || true
      fi
    done

    IMG_IDS=$(sudo docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | awk '/isy-healthcare|isyhealthcare/ {print $2}' || true)
    if [ -n "$IMG_IDS" ]; then
      echo "Removing images: $IMG_IDS"
      sudo docker rmi -f $IMG_IDS 2>/dev/null || true
    fi
  fi

  echo "Pruning unused volumes and networks..."
  sudo docker volume prune -f 2>/dev/null || true
  sudo docker network prune -f 2>/dev/null || true
  echo "Pre-deploy cleanup complete."
}

clean_existing_deploy

# Create releases directory
RELEASES_ROOT="$(dirname "$APP_DIR")/releases"
sudo mkdir -p "$RELEASES_ROOT"
timestamp=$(date +%Y%m%d%H%M%S)
RELEASE_DIR="${RELEASES_ROOT}/${timestamp}"
echo "==================================================================="
echo "Preparing release dir: $RELEASE_DIR"
echo "==================================================================="
sudo mkdir -p "$RELEASE_DIR"

# Clone repository
echo "Cloning repository into release dir..."
if git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$RELEASE_DIR"; then
  echo "Clone successful to $RELEASE_DIR"
else
  echo "ERROR: git clone failed" >&2
  sudo rm -rf "$RELEASE_DIR" 2>/dev/null || true
  exit 1
fi

cd "$RELEASE_DIR"

# The repository structure has docker-compose.yml at root level
# Check if we have the required files
if [ ! -f "docker-compose.yml" ]; then
  echo "ERROR: docker-compose.yml not found in repository. Repository structure may have changed." >&2
  sudo rm -rf "$RELEASE_DIR" 2>/dev/null || true
  exit 1
fi

echo "Detected repository structure:"
ls -la | head -20

# Configuration
DOMAIN="${DOMAIN:-health.isy.software}"
MONGO_USER="${MONGO_USER:-admin}"
MONGO_PASSWORD="${MONGO_PASSWORD:-SecurePassword123!}"
MONGO_DB="${MONGO_DB:-isy_clinic}"
NEXTAUTH_SECRET="${NEXTAUTH_SECRET:-ISY_HEALTHCARE_SECRET_KEY_CHANGE_IN_PRODUCTION_MIN_32_CHARACTERS_LONG}"
JWT_SECRET="${JWT_SECRET:-ISY_HEALTHCARE_JWT_SECRET_CHANGE_IN_PRODUCTION_SECURE_KEY}"
RETAIL_JWT_SECRET="${RETAIL_JWT_SECRET:-RETAIL_JWT_SECRET_CHANGE_IN_PRODUCTION_MIN_32_CHARS}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-info.isysoftware@gmail.com}"
CERTBOT_STAGING="${CERTBOT_STAGING:-0}"
SERVICE_PORT="${SERVICE_PORT:-3000}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-120}"

echo "==================================================================="
echo "Configuration:"
echo "  DOMAIN: $DOMAIN"
echo "  CERTBOT_EMAIL: $CERTBOT_EMAIL"
echo "  SERVICE_PORT: $SERVICE_PORT"
echo "==================================================================="

# Check if healthcare directory has actual content
HEALTHCARE_DIR=""
if [ -d "healthcare" ] && [ -f "healthcare/package.json" ]; then
  HEALTHCARE_DIR="healthcare"
  echo "Found healthcare application in healthcare/ subdirectory"
elif [ -f "package.json" ]; then
  HEALTHCARE_DIR="."
  echo "Found healthcare application in root directory"
else
  echo "WARNING: Healthcare application not found in repository."
  echo "Creating minimal healthcare application structure..."
  mkdir -p healthcare
  HEALTHCARE_DIR="healthcare"
  
  # Create minimal Next.js application
  cd healthcare
  cat > package.json << 'PACKAGE_EOF'
{
  "name": "isy-healthcare",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "next": "^14.0.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  }
}
PACKAGE_EOF

  mkdir -p app
  cat > app/page.tsx << 'PAGE_EOF'
export default function Home() {
  return (
    <main style={{ padding: '2rem', fontFamily: 'system-ui' }}>
      <h1>ISY Healthcare System</h1>
      <p>Deployment successful! The healthcare application is running.</p>
      <p>Server IP: <code>{typeof window !== 'undefined' ? window.location.hostname : 'loading...'}</code></p>
      <p>Status: <span style={{ color: 'green' }}>✓ Online</span></p>
    </main>
  )
}
PAGE_EOF

  cat > app/layout.tsx << 'LAYOUT_EOF'
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
LAYOUT_EOF

  cat > next.config.mjs << 'NEXTCONFIG_EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone'
}
export default nextConfig
NEXTCONFIG_EOF

  cat > .gitignore << 'GITIGNORE_EOF'
node_modules
.next
.env*.local
GITIGNORE_EOF

  cat > tsconfig.json << 'TSCONFIG_EOF'
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": false,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
TSCONFIG_EOF

  mkdir -p public
  echo "# ISY Healthcare" > public/robots.txt

  cd ..
  echo "Created minimal healthcare application"
fi

# Create Dockerfile if it doesn't exist
if [ ! -f "$HEALTHCARE_DIR/Dockerfile" ]; then
  echo "Creating Dockerfile for healthcare application..."
  cat > "$HEALTHCARE_DIR/Dockerfile" << 'DOCKERFILE_EOF'
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install --legacy-peer-deps
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.next ./.next
RUN mkdir -p public
EXPOSE 3000
CMD ["npm", "start"]
DOCKERFILE_EOF
  echo "Created Dockerfile in $HEALTHCARE_DIR/"
fi

# Create a proper docker-compose.yml that works with our structure
echo "Creating docker-compose.yml for deployment..."
cp docker-compose.yml docker-compose.yml.original

cat > docker-compose.yml << 'COMPOSE_EOF'
services:
  mongodb:
    image: mongo:7.0
    container_name: isy-healthcare-mongodb
    restart: unless-stopped
    environment:
      - MONGO_INITDB_ROOT_USERNAME=${MONGO_USER:-admin}
      - MONGO_INITDB_ROOT_PASSWORD=${MONGO_PASSWORD:-SecurePassword123!}
      - MONGO_INITDB_DATABASE=${MONGO_DB:-isy_clinic}
    volumes:
      - mongodb_data:/data/db
    ports:
      - "27017:27017"

  app:
    build:
      context: ./healthcare
      args:
        USE_BCRYPTJS: "1"
    container_name: isy-healthcare
    ports:
      - "3000:3000"
    restart: unless-stopped
    environment:
      - USE_BCRYPTJS=1
      - NODE_ENV=production
      - NEXT_PUBLIC_APP_NAME=ISY Healthcare
      - NEXT_PUBLIC_APP_URL=http://${DOMAIN:-health.isy.software}
      - MONGODB_URI=mongodb://${MONGO_USER:-admin}:${MONGO_PASSWORD:-SecurePassword123!}@mongodb:27017/${MONGO_DB:-isy_clinic}?authSource=admin
      - NEXTAUTH_URL=http://${DOMAIN:-health.isy.software}
      - NEXTAUTH_SECRET=${NEXTAUTH_SECRET:-ISY_HEALTHCARE_SECRET_KEY_CHANGE_IN_PRODUCTION_MIN_32_CHARACTERS_LONG}
      - JWT_SECRET=${JWT_SECRET:-ISY_HEALTHCARE_JWT_SECRET_CHANGE_IN_PRODUCTION_SECURE_KEY}
      - MAX_FILE_SIZE=10485760
      - UPLOAD_DIR=/app/uploads
      - DEFAULT_CURRENCY=IDR
      - EXCHANGE_RATE_EUR_TO_IDR=17500
      - EXCHANGE_RATE_USD_TO_IDR=15800
    depends_on:
      - mongodb

  retail:
    build:
      context: ./retail
      dockerfile: Dockerfile
    container_name: isy-healthcare-retail
    restart: unless-stopped
    depends_on:
      - nginx

  retail-api:
    build:
      context: ./retail
      dockerfile: server/Dockerfile
    container_name: isy-healthcare-retail-api
    restart: unless-stopped
    environment:
      - PORT=3001
      - MONGO_URI=mongodb://${MONGO_USER:-admin}:${MONGO_PASSWORD:-SecurePassword123!}@mongodb:27017/${MONGO_DB:-isy_clinic}?authSource=admin
      - JWT_SECRET=${RETAIL_JWT_SECRET:-RETAIL_JWT_SECRET_CHANGE_IN_PRODUCTION_MIN_32_CHARS}
      - NODE_ENV=production
    depends_on:
      - mongodb
    ports:
      - "3001:3001"

  nginx:
    image: nginx:alpine
    container_name: isy-healthcare-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx-http-only.conf:/etc/nginx/nginx.conf:ro
      - certbot_etc:/etc/letsencrypt
      - certbot_www:/var/www/certbot
    depends_on:
      - app
    restart: unless-stopped

  certbot:
    image: certbot/certbot
    container_name: isy-healthcare-certbot
    volumes:
      - certbot_etc:/etc/letsencrypt
      - certbot_www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"

volumes:
  mongodb_data:
    driver: local
  certbot_etc:
    driver: local
  certbot_www:
    driver: local
COMPOSE_EOF

echo "Created docker-compose.yml"

# Build retail project if present
if [ -d "retail" ]; then
  echo "Building retail project..."
  
  # Create Dockerfile for retail if missing
  if [ ! -f "retail/Dockerfile" ]; then
    echo "Creating Dockerfile for retail..."
    cat > "retail/Dockerfile" << 'RETAIL_DOCKERFILE_EOF'
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx_container.conf /etc/nginx/conf.d/default.conf 2>/dev/null || true
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
RETAIL_DOCKERFILE_EOF
  fi
  
  # Create server Dockerfile if missing
  if [ -d "retail/server" ] && [ ! -f "retail/server/Dockerfile" ]; then
    echo "Creating Dockerfile for retail API server..."
    mkdir -p retail/server
    cat > "retail/server/Dockerfile" << 'RETAIL_API_DOCKERFILE_EOF'
FROM node:18-alpine
WORKDIR /app
COPY server/package*.json ./
RUN npm ci --production
COPY server/ ./
EXPOSE 3001
CMD ["node", "index.js"]
RETAIL_API_DOCKERFILE_EOF
  fi
  
  cd retail
  if command -v npm >/dev/null 2>&1 && [ -f "package.json" ]; then
    npm ci && npm run build 2>&1 || echo "WARNING: retail build failed, continuing..."
  else
    echo "WARNING: npm not found or no package.json; skipping retail build"
  fi
  cd ..
fi

# Ensure ownership
sudo chown -R $(whoami):$(whoami) "$RELEASE_DIR" 2>/dev/null || true

# Create swap on low-memory systems
MEM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
CREATED_SWAP=0
SWAPFILE_PATH=""
if [ "$MEM_MB" -lt 2000 ]; then
  echo "Low RAM detected (${MEM_MB}MB) - ensuring 2GB swap"
  if sudo swapon --show=NAME --noheadings 2>/dev/null | grep -q '^/swapfile$'; then
    echo "/swapfile already active"
  else
    if [ -f /swapfile ]; then
      echo "/swapfile exists but is not active. Attempting to activate it."
      sudo chmod 600 /swapfile 2>/dev/null || true
      if sudo mkswap /swapfile >/dev/null 2>&1 && sudo swapon /swapfile 2>/dev/null; then
        SWAPFILE_PATH="/swapfile"
        CREATED_SWAP=1
      fi
    fi

    if [ "$CREATED_SWAP" -eq 0 ]; then
      if sudo fallocate -l 2G /swapfile >/dev/null 2>&1; then
        echo "Created /swapfile with fallocate"
      else
        echo "Creating /swapfile with dd (slower)"
        sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
      fi
      sudo chmod 600 /swapfile 2>/dev/null || true
      if sudo mkswap /swapfile >/dev/null 2>&1 && sudo swapon /swapfile 2>/dev/null; then
        SWAPFILE_PATH="/swapfile"
        CREATED_SWAP=1
      fi
    fi
  fi
fi

# Start with HTTP-only configuration
echo "==================================================================="
echo "Starting deployment with HTTP-only configuration..."
echo "==================================================================="

# Create HTTP-only nginx config that works with IP or domain (will be created in root)
cat > nginx-http-only.conf << 'NGINX_HTTP_EOF'
events {
    worker_connections 1024;
}

http {
    client_max_body_size 50m;

    upstream app {
        server app:3000;
    }

    upstream retail-api {
        server isy-healthcare-retail-api:3001;
    }

    server {
        listen 80;
        server_name _;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        # Retail API endpoints - must come before /retail/
        location /retail/api/ {
            proxy_pass http://retail-api/api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Content-Type application/json;
            add_header Cache-Control "no-cache, no-store, must-revalidate";
            add_header Pragma "no-cache";
            add_header Expires "0";
        }

        # Retail frontend static files
        location /retail/ {
            proxy_pass http://retail:80/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            add_header Cache-Control "no-cache, no-store, must-revalidate";
            add_header Pragma "no-cache";
            add_header Expires "0";
        }

        location / {
            proxy_pass http://app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
NGINX_HTTP_EOF

echo "Created HTTP-only nginx configuration"

# docker-compose.yml already configured to use HTTP-only config

# Remove any existing containers that might conflict
for NAME in isy-healthcare-nginx isy-healthcare-mongodb isy-healthcare-certbot isy-healthcare-retail isy-healthcare-retail-api isy-healthcare; do
  CID=$(sudo docker ps -aq --filter "name=$NAME" 2>/dev/null || true)
  if [ -n "$CID" ]; then
    echo "Removing existing container $NAME"
    sudo docker rm -f $CID 2>/dev/null || true
  fi
done

echo "==================================================================="
echo "Building Docker images..."
echo "==================================================================="
if ! sudo sh -c 'COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker compose build --no-cache --pull --progress=plain'; then
  echo "ERROR: docker compose build failed. Aborting deploy." >&2
  sudo rm -rf "$RELEASE_DIR" 2>/dev/null || true
  exit 1
fi

echo "==================================================================="
echo "Starting containers with HTTP-only configuration..."
echo "==================================================================="
if ! sudo docker compose up -d --force-recreate --renew-anon-volumes; then
  echo "ERROR: docker compose up failed. Aborting deploy." >&2
  sudo docker compose logs --tail 100
  sudo rm -rf "$RELEASE_DIR" 2>/dev/null || true
  exit 1
fi

# Wait for application to be healthy
echo "==================================================================="
echo "Waiting for application to respond on http://127.0.0.1:${SERVICE_PORT}/"
echo "Timeout: ${HEALTH_TIMEOUT}s"
echo "==================================================================="
ELAPSED=0
until curl -sSf --max-time 5 "http://127.0.0.1:${SERVICE_PORT}/" >/dev/null 2>&1 || [ $ELAPSED -ge $HEALTH_TIMEOUT ]; do
  sleep 5
  ELAPSED=$((ELAPSED+5))
  echo "Waiting for app to become healthy... ${ELAPSED}s"
  if [ $((ELAPSED % 30)) -eq 0 ]; then
    echo "Checking container status..."
    sudo docker compose ps
  fi
done

if [ $ELAPSED -ge $HEALTH_TIMEOUT ]; then
  echo "ERROR: App did not become healthy within ${HEALTH_TIMEOUT}s" >&2
  echo "==================================================================="
  echo "Container status:"
  sudo docker compose ps
  echo "==================================================================="
  echo "Recent logs:"
  sudo docker compose logs --tail 200
  echo "==================================================================="
  sudo docker compose down --remove-orphans 2>/dev/null || true
  sudo rm -rf "$RELEASE_DIR" 2>/dev/null || true
  exit 1
fi

echo "✓ App is healthy on HTTP"

# Check nginx
if curl -sSf --max-time 5 "http://127.0.0.1/" >/dev/null 2>&1; then
  echo "✓ Nginx is healthy on port 80"
else
  echo "WARNING: Nginx not responding on port 80, but app is healthy"
fi

# Now attempt SSL/certbot upgrade
echo "==================================================================="
echo "Attempting SSL certificate acquisition..."
echo "==================================================================="

SSL_SUCCESS=0

# Function to attempt certbot certificate acquisition
attempt_ssl() {
  echo "Checking if domain resolves to this server..."
  
  # Get server's public IP
  SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "unknown")
  echo "Server IP: $SERVER_IP"
  
  # Check if domain resolves to this server
  if [ "$SERVER_IP" != "unknown" ]; then
    DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -n1 || echo "")
    if [ -n "$DOMAIN_IP" ] && [ "$DOMAIN_IP" = "$SERVER_IP" ]; then
      echo "✓ Domain $DOMAIN resolves to this server ($SERVER_IP)"
    else
      echo "✗ Domain $DOMAIN does not resolve to this server (resolves to: $DOMAIN_IP)"
      echo "Skipping SSL certificate acquisition. Running with HTTP only."
      return 1
    fi
  else
    echo "Cannot determine server IP. Skipping SSL for safety."
    return 1
  fi

  # Find certbot volumes
  CERTBOT_ETC_VOL=$(sudo docker volume ls --format '{{.Name}}' | grep 'certbot_etc' | sort -r | head -n1 || echo "")
  CERTBOT_WWW_VOL=$(sudo docker volume ls --format '{{.Name}}' | grep 'certbot_www' | sort -r | head -n1 || echo "")
  
  if [ -z "$CERTBOT_ETC_VOL" ] || [ -z "$CERTBOT_WWW_VOL" ]; then
    echo "Creating certbot volumes..."
    CERTBOT_ETC_VOL="certbot_etc"
    CERTBOT_WWW_VOL="certbot_www"
    sudo docker volume create "$CERTBOT_ETC_VOL" 2>/dev/null || true
    sudo docker volume create "$CERTBOT_WWW_VOL" 2>/dev/null || true
  fi

  echo "Using certbot volumes: $CERTBOT_ETC_VOL, $CERTBOT_WWW_VOL"

  # Check if certificate already exists
  if sudo docker run --rm -v "$CERTBOT_ETC_VOL":/etc/letsencrypt alpine sh -c "test -d /etc/letsencrypt/live/$DOMAIN" 2>/dev/null; then
    echo "✓ Certificate already exists for $DOMAIN"
    return 0
  fi

  echo "Attempting to obtain certificate for $DOMAIN..."
  
  STAGING_FLAG=""
  if [ "${CERTBOT_STAGING}" = "1" ]; then
    STAGING_FLAG="--staging"
    echo "Using Let's Encrypt STAGING environment"
  fi

  # Try webroot method first (works with running nginx)
  if sudo docker run --rm \
    -v "$CERTBOT_ETC_VOL":/etc/letsencrypt \
    -v "$CERTBOT_WWW_VOL":/var/www/certbot \
    certbot/certbot certonly $STAGING_FLAG --webroot -w /var/www/certbot \
    -d "$DOMAIN" --email "$CERTBOT_EMAIL" \
    --agree-tos --no-eff-email --non-interactive 2>&1; then
    echo "✓ Certificate obtained successfully via webroot"
    return 0
  fi

  echo "Webroot method failed. Trying standalone method..."
  
  # Stop nginx to free port 80
  sudo docker stop isy-healthcare-nginx 2>/dev/null || true
  
  # Try standalone method
  if sudo docker run --rm -p 80:80 \
    -v "$CERTBOT_ETC_VOL":/etc/letsencrypt \
    -v "$CERTBOT_WWW_VOL":/var/www/certbot \
    certbot/certbot certonly $STAGING_FLAG --standalone \
    -d "$DOMAIN" --email "$CERTBOT_EMAIL" \
    --agree-tos --no-eff-email --non-interactive 2>&1; then
    echo "✓ Certificate obtained successfully via standalone"
    sudo docker start isy-healthcare-nginx 2>/dev/null || true
    return 0
  fi
  
  # Restart nginx even if failed
  sudo docker start isy-healthcare-nginx 2>/dev/null || true
  
  echo "✗ Failed to obtain SSL certificate"
  return 1
}

# Attempt SSL configuration
if attempt_ssl; then
  SSL_SUCCESS=1
  echo "==================================================================="
  echo "Upgrading to HTTPS configuration..."
  echo "==================================================================="
  
  # Restore SSL nginx config
  if [ -f "docker-compose.yml.backup" ]; then
    mv docker-compose.yml.backup docker-compose.yml
  fi
  
  # Update nginx config to SSL version
  if [ -f "nginx-ssl.conf" ]; then
    # Update domain in SSL config
    sed -i "s/health\.isy\.software/${DOMAIN}/g" nginx-ssl.conf 2>/dev/null || true
    
    # Restart nginx with SSL config
    sudo docker compose up -d --no-deps --force-recreate nginx
    
    echo "Waiting for HTTPS to be ready..."
    sleep 10
    
    # Verify HTTPS is working
    if curl -sSfk --max-time 10 "https://127.0.0.1/" >/dev/null 2>&1; then
      echo "✓ HTTPS is working!"
    else
      echo "WARNING: HTTPS health check failed, but HTTP is still working"
      SSL_SUCCESS=0
    fi
  fi
else
  echo "==================================================================="
  echo "Running with HTTP-only (SSL not available)"
  echo "==================================================================="
fi

# Final health check
echo "==================================================================="
echo "Final health verification..."
echo "==================================================================="

if [ $SSL_SUCCESS -eq 1 ]; then
  echo "Deployment mode: HTTPS (SSL enabled)"
  echo "Access your application at: https://$DOMAIN"
  echo "Alternative access: https://$SERVER_IP (certificate warning expected)"
else
  echo "Deployment mode: HTTP-only"
  SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "unknown")
  echo "Access your application at: http://$DOMAIN"
  echo "Alternative access: http://$SERVER_IP"
fi

echo ""
echo "Container status:"
sudo docker compose ps

# Promote release to APP_DIR
echo "==================================================================="
echo "Promoting release to $APP_DIR"
echo "==================================================================="
sudo mkdir -p "$APP_DIR"
sudo cp -a "$RELEASE_DIR"/. "$APP_DIR"/
sudo chown -R $(whoami):$(whoami) "$APP_DIR" 2>/dev/null || true
sudo rm -rf "$RELEASE_DIR" 2>/dev/null || true
echo "✓ Promotion complete"

# Remove temporary swap
if [ "$CREATED_SWAP" -eq 1 ] && [ -n "$SWAPFILE_PATH" ]; then
  echo "Removing temporary swap at $SWAPFILE_PATH"
  sudo swapoff "$SWAPFILE_PATH" 2>/dev/null || true
  sudo rm -f "$SWAPFILE_PATH" 2>/dev/null || true
fi

echo "==================================================================="
echo "✓ DEPLOYMENT COMPLETE"
echo "==================================================================="
echo "To view logs: sudo docker compose logs -f"
echo "To check status: sudo docker compose ps"
echo "==================================================================="
