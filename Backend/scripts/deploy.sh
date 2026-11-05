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
    if curl -sf http://127.0.0.1:3005/healthz > /dev/null 2>&1 || curl -sf http://127.0.0.1:3005 > /dev/null 2>&1 || curl -sf http://localhost:3005 > /dev/null 2>&1; then
        WEB_HEALTHY=true
        break
    fi
    echo "Waiting for website container to respond... ($i/8)"
    sleep 2
done

if [ "$WEB_HEALTHY" = true ]; then
    echo "✅ Website container is live on port 3005."
else
    echo "⚠️ Warning: Website container did not respond to health check yet. Container logs:"
    docker compose -f docker-compose.prod.yml logs --tail=20 website || true
fi

# 7. Configure CyberPanel / LiteSpeed reverse proxy for solarpro-app.in
echo "🌐 Checking CyberPanel / LiteSpeed setup for solarpro-app.in..."

# List existing home directories and vhosts for diagnostics
echo "Current /home/ entries:"
ls -la /home/ 2>/dev/null || true

# If solarpro-app.in directory doesn't exist, try creating via CyberPanel CLI
if [ ! -d "/home/solarpro-app.in/public_html" ]; then
    echo "🔍 /home/solarpro-app.in/public_html not found."
    if command -v cyberpanel > /dev/null 2>&1; then
        echo "⚙️ Creating website solarpro-app.in via CyberPanel CLI..."
        cyberpanel createWebsite --package Default --owner admin --domainName solarpro-app.in --email admin@solarpro-app.in --php 8.1 2>&1 || true
    fi
fi

# Determine target directory
TARGET_HTACCESS=""
if [ -d "/home/solarpro-app.in/public_html" ]; then
    TARGET_HTACCESS="/home/solarpro-app.in/public_html/.htaccess"
elif [ -d "/home/www.solarpro-app.in/public_html" ]; then
    TARGET_HTACCESS="/home/www.solarpro-app.in/public_html/.htaccess"
fi

if [ -n "$TARGET_HTACCESS" ]; then
    echo "🔗 Writing LiteSpeed reverse proxy rules to $TARGET_HTACCESS..."
    cat << 'EOF' > "$TARGET_HTACCESS"
RewriteEngine On
RewriteRule ^(.*)$ http://127.0.0.1:3005/$1 [P,L]
EOF
    chmod 644 "$TARGET_HTACCESS"
    SITE_USER=$(stat -c '%U:%G' "$(dirname "$TARGET_HTACCESS")" 2>/dev/null || echo "")
    if [ -n "$SITE_USER" ]; then
        chown "$SITE_USER" "$TARGET_HTACCESS" 2>/dev/null || true
    fi
    echo "✅ Reverse proxy configured in $TARGET_HTACCESS -> http://127.0.0.1:3005"
    
    # Reload LiteSpeed so changes take effect
    if [ -f "/usr/local/lsws/bin/lswsctrl" ]; then
        /usr/local/lsws/bin/lswsctrl reload 2>/dev/null || true
    elif command -v systemctl > /dev/null 2>&1 && systemctl is-active --quiet lsws; then
        systemctl reload lsws 2>/dev/null || true
    fi
else
    echo "ℹ️ Notice: Website solarpro-app.in directory not found under /home/."
    echo "ℹ️ Please create the website in CyberPanel UI (Websites -> Create Website -> solarpro-app.in)."
fi

# 8. Housekeeping: remove dangling images to prevent VPS disk from filling up
echo "🧹 Pruning dangling Docker images..."
docker image prune -f

echo "========================================================"
echo "🎉 Deployment completed successfully!"
echo "========================================================"

