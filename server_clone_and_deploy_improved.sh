#!/usr/bin/env bash

# Multi-framework deployment script for ISY Healthcare
# Deploys Next.js (healthcare) and Vite (retail) apps in separate containers
# Routes: /healthcare -> Next.js, /retail -> Vite

REPO_URL="https://github.com/isysoftwareapp/server.git"
APP_DIR="${APP_DIR:-$HOME}"
BRANCH="${1:-main}"

echo "==================================================================="
echo "ISY Healthcare Multi-Framework Deployment"
echo "==================================================================="
echo "Repo: $REPO_URL"
echo "Branch: $BRANCH"
echo "==================================================================="

# Basic checks
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is not installed." >&2
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed." >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: docker compose is not available." >&2
  exit 1
fi

# Cleanup existing deployment
clean_existing_deploy() {
  echo "==================================================================="
  echo "Cleaning up existing deployment..."
  echo "==================================================================="

  for d in "$APP_DIR" "/home/adminroot/isy.healthcare" "/home/adminroot/latest" "/home/adminroot"; do
    if [ -f "$d/docker-compose.yml" ]; then
      echo "Found docker-compose in $d - stopping services"
      sudo sh -c "cd '$d' && docker compose down --remove-orphans" 2>/dev/null || true
    fi
  done

  # Remove containers
  for NAME in isy-healthcare-nginx isy-healthcare-mongodb isy-healthcare-certbot isy-healthcare-retail isy-healthcare-retail-api isy-healthcare isy-healthcare-app; do
    CID=$(sudo docker ps -aq --filter "name=$NAME" 2>/dev/null || true)
    if [ -n "$CID" ]; then
      echo "Removing container $NAME"
      sudo docker rm -f $CID 2>/dev/null || true
    fi
  done

  echo "Cleanup complete."
}

clean_existing_deploy

# Create release directory
RELEASES_ROOT="$(dirname "$APP_DIR")/releases"
sudo mkdir -p "$RELEASES_ROOT"
timestamp=$(date +%Y%m%d%H%M%S)
RELEASE_DIR="${RELEASES_ROOT}/${timestamp}"
echo "==================================================================="
echo "Cloning repository to: $RELEASE_DIR"
echo "==================================================================="
sudo mkdir -p "$RELEASE_DIR"

# Clone repository
if ! git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$RELEASE_DIR"; then
  echo "ERROR: git clone failed" >&2
  sudo rm -rf "$RELEASE_DIR" 2>/dev/null || true
  exit 1
fi

cd "$RELEASE_DIR"

# Configuration
DOMAIN="${DOMAIN:-health.isy.software}"
MONGO_USER="${MONGO_USER:-admin}"
MONGO_PASSWORD="${MONGO_PASSWORD:-SecurePassword123!}"
MONGO_DB="${MONGO_DB:-isy_clinic}"
NEXTAUTH_SECRET="${NEXTAUTH_SECRET:-ISY_HEALTHCARE_SECRET_KEY_CHANGE_IN_PRODUCTION_MIN_32_CHARACTERS_LONG}"
JWT_SECRET="${JWT_SECRET:-ISY_HEALTHCARE_JWT_SECRET_CHANGE_IN_PRODUCTION_SECURE_KEY}"
RETAIL_JWT_SECRET="${RETAIL_JWT_SECRET:-RETAIL_JWT_SECRET_CHANGE_IN_PRODUCTION_MIN_32_CHARS}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-info.isysoftware@gmail.com}"
SERVICE_PORT="${SERVICE_PORT:-3000}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-120}"

echo "==================================================================="
echo "Configuration:"
echo "  DOMAIN: $DOMAIN"
echo "  SERVICE_PORT: $SERVICE_PORT"
echo "==================================================================="

# Check repository structure
if [ ! -d "healthcare" ] || [ ! -d "retail" ]; then
  echo "ERROR: Repository must contain 'healthcare' and 'retail' directories" >&2
  sudo rm -rf "$RELEASE_DIR" 2>/dev/null || true
  exit 1
fi

echo "✓ Found healthcare and retail directories"

# Update Next.js config for subpath
if [ -f "healthcare/next.config.ts" ]; then
  echo "Updating Next.js config with basePath..."
  if ! grep -q "basePath:" "healthcare/next.config.ts"; then
    cp healthcare/next.config.ts healthcare/next.config.ts.backup
    sed -i "s|const nextConfig = {|const nextConfig = {\n  basePath: '/healthcare',\n  assetPrefix: '/healthcare',|g" healthcare/next.config.ts
  fi
elif [ -f "healthcare/next.config.mjs" ]; then
  if ! grep -q "basePath:" "healthcare/next.config.mjs"; then
    cp healthcare/next.config.mjs healthcare/next.config.mjs.backup
    sed -i "s|const nextConfig = {|const nextConfig = {\n  basePath: '/healthcare',\n  assetPrefix: '/healthcare',|g" healthcare/next.config.mjs
  fi
fi

# Update Vite config for subpath
if [ -f "retail/vite.config.ts" ]; then
  echo "Updating Vite config with base path..."
  if ! grep -q "base:" "retail/vite.config.ts"; then
    cp retail/vite.config.ts retail/vite.config.ts.backup
    sed -i "s|export default defineConfig({|export default defineConfig({\n  base: '/retail/',|g" retail/vite.config.ts
  fi
fi

# Create healthcare Dockerfile if missing
if [ ! -f "healthcare/Dockerfile" ]; then
  echo "Creating Dockerfile for healthcare (Next.js)..."
  cat > "healthcare/Dockerfile" << 'HEALTHCARE_DOCKERFILE_EOF'
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:18-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

FROM node:18-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT=3000
CMD ["node", "server.js"]
HEALTHCARE_DOCKERFILE_EOF
fi

# Create retail Dockerfile if missing
if [ ! -f "retail/Dockerfile" ]; then
  echo "Creating Dockerfile for retail (Vite)..."
  cat > "retail/Dockerfile" << 'RETAIL_DOCKERFILE_EOF'
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
RUN echo 'server { listen 80; root /usr/share/nginx/html; index index.html; location / { try_files $uri $uri/ /index.html; } }' > /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
RETAIL_DOCKERFILE_EOF
fi

# Create retail server Dockerfile if missing
if [ -d "retail/server" ] && [ ! -f "retail/server/Dockerfile" ]; then
  echo "Creating Dockerfile for retail-api..."
  cat > "retail/server/Dockerfile" << 'RETAIL_API_DOCKERFILE_EOF'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
EXPOSE 3001
CMD ["node", "index.js"]
RETAIL_API_DOCKERFILE_EOF
fi

# Create docker-compose.yml
echo "Creating docker-compose.yml..."
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
    networks:
      - isy-network

  healthcare:
    build:
      context: ./healthcare
      dockerfile: Dockerfile
    container_name: isy-healthcare-app
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - NEXT_PUBLIC_APP_NAME=ISY Healthcare
      - NEXT_PUBLIC_APP_URL=http://${DOMAIN:-localhost}
      - MONGODB_URI=mongodb://${MONGO_USER:-admin}:${MONGO_PASSWORD:-SecurePassword123!}@mongodb:27017/${MONGO_DB:-isy_clinic}?authSource=admin
      - NEXTAUTH_URL=http://${DOMAIN:-localhost}/healthcare
      - NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - mongodb
    networks:
      - isy-network

  retail:
    build:
      context: ./retail
      dockerfile: Dockerfile
    container_name: isy-healthcare-retail
    restart: unless-stopped
    networks:
      - isy-network

  retail-api:
    build:
      context: ./retail
      dockerfile: server/Dockerfile
    container_name: isy-healthcare-retail-api
    restart: unless-stopped
    environment:
      - PORT=3001
      - MONGO_URI=mongodb://${MONGO_USER:-admin}:${MONGO_PASSWORD:-SecurePassword123!}@mongodb:27017/${MONGO_DB:-isy_clinic}?authSource=admin
      - JWT_SECRET=${RETAIL_JWT_SECRET}
      - NODE_ENV=production
    depends_on:
      - mongodb
    networks:
      - isy-network

  nginx:
    image: nginx:alpine
    container_name: isy-healthcare-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - certbot_etc:/etc/letsencrypt
      - certbot_www:/var/www/certbot
    depends_on:
      - healthcare
      - retail
    networks:
      - isy-network

  certbot:
    image: certbot/certbot
    container_name: isy-healthcare-certbot
    volumes:
      - certbot_etc:/etc/letsencrypt
      - certbot_www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
    networks:
      - isy-network

volumes:
  mongodb_data:
  certbot_etc:
  certbot_www:

networks:
  isy-network:
    driver: bridge
COMPOSE_EOF

# Create nginx configuration
echo "Creating nginx configuration..."
cat > nginx.conf << 'NGINX_EOF'
events {
    worker_connections 1024;
}

http {
    client_max_body_size 50m;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    upstream healthcare {
        server isy-healthcare-app:3000;
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

        # Healthcare app (Next.js with basePath)
        location /healthcare {
            proxy_pass http://healthcare;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Healthcare Next.js static files
        location /_next/ {
            proxy_pass http://healthcare;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
        }

        # Retail API
        location /retail/api/ {
            proxy_pass http://retail-api/api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Retail app (Vite static files served by nginx)
        location /retail/ {
            proxy_pass http://isy-healthcare-retail:80/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # Root redirects to healthcare
        location = / {
            return 301 /healthcare;
        }
    }
}
NGINX_EOF

# Set ownership
sudo chown -R $(whoami):$(whoami) "$RELEASE_DIR" 2>/dev/null || true

# Build and start services
echo "==================================================================="
echo "Building Docker images..."
echo "==================================================================="

if ! sudo docker compose build --no-cache; then
  echo "ERROR: Docker build failed" >&2
  sudo docker compose logs
  sudo rm -rf "$RELEASE_DIR" 2>/dev/null || true
  exit 1
fi

echo "==================================================================="
echo "Starting containers..."
echo "==================================================================="

if ! sudo docker compose up -d --force-recreate; then
  echo "ERROR: Failed to start containers" >&2
  sudo docker compose logs --tail 100
  sudo rm -rf "$RELEASE_DIR" 2>/dev/null || true
  exit 1
fi

# Health check
echo "==================================================================="
echo "Waiting for services to be healthy..."
echo "==================================================================="

sleep 10

# Check healthcare
ELAPSED=0
until curl -sSf --max-time 5 "http://127.0.0.1/healthcare" >/dev/null 2>&1 || [ $ELAPSED -ge $HEALTH_TIMEOUT ]; do
  sleep 5
  ELAPSED=$((ELAPSED+5))
  echo "Waiting for healthcare app... ${ELAPSED}s"
  if [ $((ELAPSED % 30)) -eq 0 ]; then
    sudo docker compose ps
  fi
done

if [ $ELAPSED -ge $HEALTH_TIMEOUT ]; then
  echo "ERROR: Healthcare app not healthy" >&2
  sudo docker compose logs --tail 200
  exit 1
fi

echo "✓ Healthcare app is healthy"

# Check retail
if curl -sSf --max-time 5 "http://127.0.0.1/retail/" >/dev/null 2>&1; then
  echo "✓ Retail app is healthy"
else
  echo "WARNING: Retail app health check failed, but continuing..."
fi

# SSL check (optional)
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "unknown")
echo "Server IP: $SERVER_IP"

# Promote to production
echo "==================================================================="
echo "Promoting release to production..."
echo "==================================================================="
sudo mkdir -p "$APP_DIR"
sudo cp -a "$RELEASE_DIR"/. "$APP_DIR"/
sudo chown -R $(whoami):$(whoami) "$APP_DIR" 2>/dev/null || true
sudo rm -rf "$RELEASE_DIR" 2>/dev/null || true

echo "==================================================================="
echo "✓ DEPLOYMENT COMPLETE!"
echo "==================================================================="
echo ""
echo "Container Status:"
sudo docker compose ps
echo ""
echo "Access URLs:"
echo "  Healthcare: http://$SERVER_IP/healthcare"
echo "  Retail:     http://$SERVER_IP/retail"
echo ""
echo "Useful Commands:"
echo "  View logs:    sudo docker compose logs -f"
echo "  Check status: sudo docker compose ps"
echo "  Restart:      sudo docker compose restart"
echo "==================================================================="
