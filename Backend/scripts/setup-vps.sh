#!/usr/bin/env bash
set -e

# ==============================================================================
# Hostinger VPS Initial Server Provisioning Script (Ubuntu 22.04 / 24.04)
# ==============================================================================
# Run this script once on your fresh Hostinger VPS as root (or sudo):
#   curl -sSL <raw-url> | bash
#   or: bash scripts/setup-vps.sh
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root or with sudo."
  exit 1
fi

echo "🚀 Starting Hostinger VPS initial setup..."

# 1. Update OS packages
echo "📦 Updating apt packages..."
apt-get update && apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg lsb-release git ufw fail2ban certbot

# 2. Install Docker & Docker Compose if not installed
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker Engine..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm -f get-docker.sh
    systemctl enable docker
    systemctl start docker
    echo "✅ Docker installed successfully."
else
    echo "✅ Docker is already installed."
fi

# 3. Configure UFW Firewall
echo "🛡️ Configuring firewall rules..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 8000/tcp comment 'API Port 8000'
ufw allow 80/tcp comment 'HTTP Nginx'
ufw allow 443/tcp comment 'HTTPS Nginx'
echo "y" | ufw enable
ufw status verbose

# 4. Enable fail2ban for brute-force protection
systemctl enable fail2ban
systemctl start fail2ban

# 5. Create deployment directory
DEPLOY_DIR="/var/www/solar-mobile-app"
mkdir -p "$DEPLOY_DIR"
echo "📁 Deployment directory ready at $DEPLOY_DIR"

echo "========================================================"
echo "🎉 VPS Provisioning Complete!"
echo "========================================================"
echo ""
echo "Next steps on this VPS:"
echo "1. Clone your repository into $DEPLOY_DIR:"
echo "   git clone https://github.com/rightads/Solar-Mobile-App.git $DEPLOY_DIR"
echo ""
echo "2. Create the production environment file:"
echo "   cd $DEPLOY_DIR/Backend"
echo "   cp .env.prod.example .env.prod"
echo "   nano .env.prod   # Configure your secrets"
echo ""
echo "3. Generate an SSH Keypair for GitHub Actions CI/CD:"
echo "   ssh-keygen -t ed25519 -C 'github-actions' -f /root/.ssh/github_actions -N ''"
echo "   cat /root/.ssh/github_actions.pub >> /root/.ssh/authorized_keys"
echo "   chmod 600 /root/.ssh/authorized_keys"
echo "   cat /root/.ssh/github_actions   # Copy this private key to GitHub Secrets!"
echo "========================================================"

