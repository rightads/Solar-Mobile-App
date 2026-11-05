#!/usr/bin/env bash
set -e

# ==============================================================================
# Solar Rooftop Backend - Production VPS Deploy Script
# ==============================================================================
echo "========================================================"
echo "🚀 Starting Solar Backend VPS Deployment: $(date)"
echo "========================================================"

# Navigate to Backend directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
cd "$BACKEND_DIR"

echo "📂 Working directory: $(pwd)"

# 1. Check for .env.prod
if [ ! -f .env.prod ]; then
    echo "❌ ERROR: .env.prod not found in $BACKEND_DIR!"
    echo "👉 Please copy .env.prod.example to .env.prod and configure your secrets."
    exit 1
fi

# 2. Free port 3005 if occupied by old process and launch containers
echo "🧹 Freeing port 3005 if occupied..."
kill -9 $(lsof -t -i:3005) 2>/dev/null || fuser -k 3005/tcp 2>/dev/null || true

echo "📦 Building website and backend containers and launching docker stack..."
docker compose -f docker-compose.prod.yml up -d --build --remove-orphans

# 3. Wait for PostgreSQL to become healthy
echo "⏳ Waiting for PostgreSQL database container to be healthy..."
RETRIES=10
until docker compose -f docker-compose.prod.yml exec -T postgres pg_isready > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
    echo "Waiting for postgres... ($RETRIES attempts remaining)"
    sleep 3
    RETRIES=$((RETRIES - 1))
done

if [ $RETRIES -eq 0 ]; then
    echo "⚠️ Warning: Postgres healthcheck timed out, proceeding to migrations check..."
fi

# 4. Apply database migrations
echo "🗄️ Running Alembic database migrations..."
docker compose -f docker-compose.prod.yml exec -T backend alembic upgrade head
echo "✅ Database schema updated successfully."

# 5. Reload Nginx so upstream container IP resolution is fresh
echo "🔄 Reloading Nginx reverse proxy..."
docker compose -f docker-compose.prod.yml restart nginx

# 6. Verify API Healthcheck
echo "🩺 Verifying API health on http://127.0.0.1:8000/api/v1/health..."
HEALTHY=false
for i in {1..10}; do
    if curl -sf http://127.0.0.1:8000/api/v1/health > /dev/null 2>&1; then
        HEALTHY=true
        break
    fi
    echo "Waiting for backend service to respond on port 8000... ($i/10)"
    sleep 3
done

if [ "$HEALTHY" = true ]; then
    echo "✅ Health check passed! API is live on port 8000."
else
    echo "❌ Health check failed after 8 retries. Recent container logs:"
    docker compose -f docker-compose.prod.yml logs --tail=40 backend
    exit 1
fi

# 6. Verify Website Container Healthcheck
echo "🩺 Verifying Website container health on http://127.0.0.1:3005..."
WEB_HEALTHY=false
for i in {1..8}; do
    if curl -sf http://127.0.0.1:3005/healthz > /dev/null 2>&1 || curl -sf http://127.0.0.1:3005 > /dev/null 2>&1; then
        WEB_HEALTHY=true
        break
    fi
    echo "Waiting for website container to respond... ($i/8)"
    sleep 2
done

if [ "$WEB_HEALTHY" = true ]; then
    echo "✅ Website container is live on port 3005."
else
    echo "⚠️ Warning: Website container did not respond to /healthz on port 3005 yet."
fi

# 7. Configure CyberPanel / LiteSpeed reverse proxy for solarpro-app.in
if [ -d "/home/solarpro-app.in/public_html" ]; then
    echo "🔗 Configuring CyberPanel reverse proxy for solarpro-app.in -> 127.0.0.1:3005..."
    HTACCESS="/home/solarpro-app.in/public_html/.htaccess"
    if ! grep -q "127.0.0.1:3005" "$HTACCESS" 2>/dev/null; then
        cat << 'EOF' > "$HTACCESS"
RewriteEngine On
RewriteRule ^(.*)$ http://127.0.0.1:3005/$1 [P,L]
EOF
        echo "✅ CyberPanel .htaccess reverse proxy configured successfully."
    else
        echo "✅ CyberPanel reverse proxy already active in $HTACCESS."
    fi
fi

# 8. Housekeeping: remove dangling images to prevent VPS disk from filling up
echo "🧹 Pruning dangling Docker images..."
docker image prune -f

echo "========================================================"
echo "🎉 Deployment completed successfully!"
echo "========================================================"

