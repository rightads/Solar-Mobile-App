# ☀️ Solar Rooftop Management Backend API

FastAPI backend for Solar Rooftop Installation & Sales Management mobile app (Flutter).

---

## 🚀 Quick Start

### 1. Requirements
- Docker & Docker Compose
- Python 3.12+ (for local development)

### 2. Environment Setup
Copy the example environment file:
```bash
cp .env.example .env
```

### 3. Run with Docker Compose
```bash
docker compose up --build -d
```
Services started:
- **FastAPI API**: [http://localhost:8000](http://localhost:8000)
- **Interactive Swagger Docs**: [http://localhost:8000/docs](http://localhost:8000/docs)
- **PostgreSQL 16**: `localhost:5432`
- **MinIO Console**: [http://localhost:9001](http://localhost:9001) (User: `minioadmin`, Password: `minioadmin`)

### 4. Database Migrations
```bash
# Inside docker api container or locally with virtual environment active
alembic upgrade head
```

### 5. Running Tests
```bash
pytest -v
```

### 6. Linting & Code Quality
```bash
ruff check .
ruff format .
```

---

## 🌐 Production Deployment (Hostinger VPS & GitHub Actions CI/CD)

### 1. Architecture Overview
- **Reverse Proxy**: Nginx container (`:80`, `:443`) handling rate-limiting and SSL termination.
- **App Server**: FastAPI running with Gunicorn + Uvicorn workers on `:8000`.
- **Database**: PostgreSQL 16 Alpine container with persistent Docker volume storage.
- **CI/CD**: GitHub Actions workflow at `.github/workflows/backend-ci-cd.yml`.
  - Runs automated linting and pytest test suite.
  - Automatically deploys to Hostinger VPS upon every push to `main` (restricted to changes in `Backend/`).

### 2. VPS Setup (One-time)
1. Run the initial provisioning script on your Hostinger VPS as `root`:
   ```bash
   bash scripts/setup-vps.sh
   ```
2. Clone the repository into `/var/www/solar-mobile-app`:
   ```bash
   git clone https://github.com/rightads/Solar-Mobile-App.git /var/www/solar-mobile-app
   ```
3. Set up the production `.env.prod`:
   ```bash
   cd /var/www/solar-mobile-app/Backend
   cp .env.prod.example .env.prod
   nano .env.prod   # Configure strong secrets
   ```
4. Run your first deployment manually:
   ```bash
   bash scripts/deploy.sh
   ```

### 3. GitHub Actions Secrets Configuration
Add the following secrets under **Repository Settings > Secrets and variables > Actions**:
- `HOSTINGER_HOST`: Your VPS IP address (e.g. `194.163.xxx.xxx`) or server domain.
- `HOSTINGER_USERNAME`: SSH username (`root` or your sudo user).
- `HOSTINGER_SSH_KEY`: Private SSH Key (e.g. content of `id_ed25519`).
- `HOSTINGER_PORT`: SSH port (default `22`).
- `HOSTINGER_DEPLOY_PATH`: Path on server (default `/var/www/solar-mobile-app`).

### 4. SSL / HTTPS Configuration (Let's Encrypt)
Once your domain points to your Hostinger VPS IP:
```bash
bash scripts/init-ssl.sh api.yourdomain.com admin@yourdomain.com
```
