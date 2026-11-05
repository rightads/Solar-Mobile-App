#!/usr/bin/env bash
set -e

# ==============================================================================
# Let's Encrypt SSL Setup for Solar Rooftop Management API on Hostinger VPS
# ==============================================================================
# Usage:
#   bash scripts/init-ssl.sh <your-domain.com> <your-email@example.com>
# Example:
#   bash scripts/init-ssl.sh api.solarpro.com admin@solarpro.com
# ==============================================================================

DOMAIN="$1"
EMAIL="$2"

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "❌ Usage: $0 <domain> <email>"
    echo "Example: $0 api.solarpro.com admin@solarpro.com"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
cd "$BACKEND_DIR"

echo "🔐 Setting up SSL for domain: $DOMAIN with email: $EMAIL"

# Ensure directories exist
mkdir -p certbot/conf certbot/www

# Ensure Nginx is running in HTTP mode to handle ACME challenge
echo "🌐 Starting Nginx for ACME challenge..."
docker compose -f docker-compose.prod.yml up -d nginx

# Request certificate
echo "📜 Requesting Let's Encrypt certificate..."
certbot certonly \
    --webroot \
    --webroot-path certbot/www \
    --config-dir certbot/conf \
    --work-dir certbot/work \
    --logs-dir certbot/logs \
    -d "$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --non-interactive

# Configure SSL Nginx
echo "⚙️ Configuring Nginx with HTTPS..."
sed "s/YOUR_DOMAIN/$DOMAIN/g" nginx/nginx.ssl.conf.template > nginx/nginx.conf

# Reload Nginx
echo "🔄 Reloading Nginx with SSL configuration..."
docker compose -f docker-compose.prod.yml restart nginx

echo "🎉 SSL Certificate successfully issued and configured for https://$DOMAIN !"

