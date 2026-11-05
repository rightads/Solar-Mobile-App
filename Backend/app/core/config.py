import secrets
from typing import List, Literal
from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Environment
    ENV: Literal["dev", "prod", "test"] = "dev"
    DEBUG: bool = True
    APP_NAME: str = "Solar Rooftop Management API"
    APP_VERSION: str = "0.1.0"

    # Business / presentation settings
    TICKET_NUMBER_PREFIX: str = "TCK"
    REPORT_HEADER_COLOR: str = "047857"

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    # Explicit origins only; wildcard supported for mobile/web apps
    CORS_ORIGINS: List[str] = Field(
        default=["http://localhost:3000", "http://localhost:8000", "http://localhost:8080", "*"]
    )

    # Database
    DATABASE_URL: str = ""
    TEST_DATABASE_URL: str = ""
    MONGODB_URI: str = ""
    DB_ECHO: bool = False
    DB_POOL_SIZE: int = 5
    DB_MAX_OVERFLOW: int = 10

    # Security & JWT
    JWT_SECRET: str = ""
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # OTP Settings
    OTP_EXPIRE_SECONDS: int = 300
    OTP_LENGTH: int = 6

    # Super Admin Configuration (seeded in DB via ENV)
    SUPER_ADMIN_NAME: str = "Super Admin"
    SUPER_ADMIN_EMAIL: str = "admin@solarpro.com"
    SUPER_ADMIN_PHONE: str = "9876543210"
    # Secret: used only when creating the admin on first seed (existing DB passwords are never overwritten)
    SUPER_ADMIN_PASSWORD: str = ""

    # Email & Delivery Settings (Resend HTTP API + SMTP Fallback)
    # Secrets (RESEND_API_KEY, SMTP_USER, SMTP_PASSWORD) must come from environment / .env
    RESEND_API_KEY: str = ""
    RESEND_FROM_EMAIL: str = "SolarPro <onboarding@resend.dev>"
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_TLS: bool = True
    SMTP_SSL: bool = False
    EMAILS_FROM_EMAIL: str = ""
    EMAILS_FROM_NAME: str = "SolarPro Verification"
    EMAIL_VERIFICATION_EXPIRE_SECONDS: int = 600

    # Storage (MinIO / S3)
    STORAGE_PROVIDER: Literal["minio", "s3"] = "minio"
    STORAGE_ENDPOINT: str = "http://localhost:9000"
    STORAGE_ACCESS_KEY: str = ""
    STORAGE_SECRET_KEY: str = ""
    STORAGE_BUCKET_NAME: str = "solar-uploads"
    STORAGE_REGION: str = "us-east-1"
    STORAGE_USE_SSL: bool = False

    # Push Notifications (Firebase Cloud Messaging)
    FCM_SERVER_KEY: str = ""


    @model_validator(mode="after")
    def _validate_secrets(self) -> "Settings":
        if not self.JWT_SECRET:
            self.JWT_SECRET = secrets.token_urlsafe(32)
        return self


settings = Settings()


