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

echo "📋 Verifying production environment configurations in .env.prod..."

for VAR in MONGODB_URI JWT_SECRET CORS_ORIGINS SUPER_ADMIN_EMAIL SUPER_ADMIN_PHONE RESEND_API_KEY TWO_FACTOR_API_KEY FAST2SMS_API_KEY; do
    if grep -qE "^${VAR}=" .env.prod && [ -n "$(grep -E "^${VAR}=" .env.prod | cut -d'=' -f2-)" ]; then
        echo "  ✅ $VAR is configured."
    else
        echo "  ℹ️ Note: $VAR is not yet configured or is empty in .env.prod."
    fi
done

# Refuse to deploy with a weak signing secret (the API would also refuse to start).
JWT_VALUE="$(grep -E '^JWT_SECRET=' .env.prod | cut -d'=' -f2- | tr -d '"')"
if [ "${#JWT_VALUE}" -lt 32 ]; then
    echo "❌ JWT_SECRET in .env.prod must be at least 32 random characters (generate: openssl rand -hex 32)."
    exit 1
fi
chmod 600 .env.prod

# 2. Launch containers via Docker Compose
echo "📦 Building and restarting website and backend Docker containers..."
docker compose -f docker-compose.prod.yml up -d --build --remove-orphans

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

# 7. Configure CyberPanel / LiteSpeed to serve React website on solarpro-app.in
echo "🌐 Configuring LiteSpeed to serve React SPA on solarpro-app.in..."

# Clean up any proxy context from vhost.conf to avoid 503 proxy errors
VHOST_CONF="/usr/local/lsws/conf/vhosts/solarpro-app.in/vhost.conf"
if [ -f "$VHOST_CONF" ]; then
    echo "🧹 Removing legacy proxy contexts from $VHOST_CONF..."
    python3 -c "
import re
try:
    with open('$VHOST_CONF', 'r') as f:
        c = f.read()
    c = re.sub(r'extprocessor\s+solarpro_proxy\s*\{[^}]*\}', '', c)
    c = re.sub(r'context\s+/\s*\{[^}]*handler\s+solarpro_proxy[^}]*\}', '', c)
    with open('$VHOST_CONF', 'w') as f:
        f.write(c)
except Exception as e:
    print('Notice:', e)
" 2>/dev/null || true
fi

# Deploy built React artifacts to LiteSpeed document root
CYBERPANEL_DIR="/home/solarpro-app.in/public_html"
if [ -d "$CYBERPANEL_DIR" ]; then
    echo "📦 Deploying React production build into $CYBERPANEL_DIR..."
    if [ -d "$DEPLOY_PATH/website/dist" ]; then
        cp -rf "$DEPLOY_PATH/website/dist/"* "$CYBERPANEL_DIR/"
    elif [ -d "../website/dist" ]; then
        cp -rf ../website/dist/* "$CYBERPANEL_DIR/"
    fi

    # Set up clean SPA .htaccess routing for React
    cat << 'EOF' > "$CYBERPANEL_DIR/.htaccess"
RewriteEngine On
RewriteBase /
RewriteRule ^index\.html$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.html [L]
EOF

    # Fix file permissions for LiteSpeed / CyberPanel user
    SITE_USER=$(stat -c '%U:%G' "$CYBERPANEL_DIR" 2>/dev/null || echo "nobody:nogroup")
    chown -R "$SITE_USER" "$CYBERPANEL_DIR" 2>/dev/null || true
    chmod -R 755 "$CYBERPANEL_DIR" 2>/dev/null || true
    chmod 644 "$CYBERPANEL_DIR/.htaccess" 2>/dev/null || true
    echo "✅ React SPA successfully installed into $CYBERPANEL_DIR"
fi

# Reload LiteSpeed so all changes take effect immediately
echo "🔄 Reloading LiteSpeed server..."
if [ -f "/usr/local/lsws/bin/lswsctrl" ]; then
    /usr/local/lsws/bin/lswsctrl reload || true
elif command -v systemctl > /dev/null 2>&1 && systemctl is-active --quiet lsws; then
    systemctl reload lsws || true
fi

# 8. Issue / verify SSL certificate for solarpro-app.in via CyberPanel
echo "🔒 Checking SSL certificate for solarpro-app.in..."
if command -v cyberpanel > /dev/null 2>&1; then
    echo "🔐 Requesting/Refreshing Let's Encrypt SSL for solarpro-app.in via CyberPanel CLI..."
    cyberpanel issueSSL --domainName solarpro-app.in 2>&1 || true
    if [ -f "/usr/local/lsws/bin/lswsctrl" ]; then
        /usr/local/lsws/bin/lswsctrl reload || true
    fi
fi

sleep 2
echo "🩺 Testing local domain resolution for solarpro-app.in..."
curl -is -m 5 -H "Host: solarpro-app.in" http://127.0.0.1/ | head -n 25 || true

# 9. Verify Backend container logs on startup (MongoDB & Super Admin sync)
echo "📋 Backend container startup logs:"
docker compose -f docker-compose.prod.yml logs --tail=20 backend || true

# 10. Housekeeping: remove dangling images to prevent VPS disk from filling up
echo "🧹 Pruning dangling Docker images..."
docker image prune -f

echo "========================================================"
echo "🎉 Deployment completed successfully!"
echo "========================================================"

