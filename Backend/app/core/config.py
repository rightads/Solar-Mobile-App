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
        # Never print secrets from the environment in validation errors / logs
        hide_input_in_errors=True,
    )

    # Environment
    ENV: Literal["dev", "prod", "test"] = "dev"
    DEBUG: bool = False
    APP_NAME: str = "Solar Rooftop Management API"
    APP_VERSION: str = "0.2.0"

    # Business / presentation settings
    TICKET_NUMBER_PREFIX: str = "TCK"
    REPORT_HEADER_COLOR: str = "047857"

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    # Browser origins allowed to call the API. Native mobile/desktop apps do not
    # send an Origin header and are unaffected. Never use "*" in production.
    CORS_ORIGINS: List[str] = Field(default_factory=list)
    # Only honour X-Real-IP / X-Forwarded-For when the API sits behind our nginx.
    TRUST_PROXY_HEADERS: bool = False

    # Database
    DATABASE_URL: str = ""
    TEST_DATABASE_URL: str = ""
    MONGODB_URI: str = ""
    MONGODB_DB_NAME: str = "solar_app_db"
    DB_ECHO: bool = False
    DB_POOL_SIZE: int = 5
    DB_MAX_OVERFLOW: int = 10

    # Security & JWT
    JWT_SECRET: str = ""
    JWT_ALGORITHM: Literal["HS256"] = "HS256"
    JWT_ISSUER: str = "solarpro-api"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Brute-force / abuse limits
    LOGIN_MAX_FAILURES: int = 5           # per identifier per window
    LOGIN_FAILURE_WINDOW_SECONDS: int = 900
    OTP_RESEND_COOLDOWN_SECONDS: int = 60
    OTP_MAX_PER_HOUR: int = 5
    OTP_MAX_VERIFY_FAILURES_PER_HOUR: int = 10

    # SMS gateway providers
    OTP_EXPIRE_SECONDS: int = 300
    OTP_LENGTH: int = 6
    TWO_FACTOR_API_KEY: str = ""
    FAST2SMS_API_KEY: str = ""
    MSG91_AUTH_KEY: str = ""
    MSG91_TEMPLATE_ID: str = ""
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_FROM_NUMBER: str = ""

    # Super Admin (seeded on first start only; existing passwords are never overwritten)
    SUPER_ADMIN_NAME: str = "Super Admin"
    SUPER_ADMIN_EMAIL: str = ""
    SUPER_ADMIN_PHONE: str = ""
    SUPER_ADMIN_PASSWORD: str = ""

    # Email delivery (Resend HTTP API + SMTP fallback). Secrets come from the environment only.
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
    # Forgot-password emails: the link opens this page on the website, which
    # hands the one-time token to the app (the token travels in the #fragment,
    # so it never reaches a server log).
    PASSWORD_RESET_URL: str = "https://solarpro-app.in/reset-password.html"
    PASSWORD_RESET_EXPIRE_SECONDS: int = 1800

    # Uploaded files (KYC documents, receipts, site photos, KEDL papers)
    UPLOAD_DIR: str = "uploads"
    MAX_UPLOAD_MB: int = 10

    # Storage (MinIO / S3) — legacy, unused in Mongo mode
    STORAGE_PROVIDER: Literal["minio", "s3"] = "minio"
    STORAGE_ENDPOINT: str = "http://localhost:9000"
    STORAGE_ACCESS_KEY: str = ""
    STORAGE_SECRET_KEY: str = ""
    STORAGE_BUCKET_NAME: str = "solar-uploads"
    STORAGE_REGION: str = "us-east-1"
    STORAGE_USE_SSL: bool = False

    # Push Notifications (Firebase Cloud Messaging)
    FCM_SERVER_KEY: str = ""

    @property
    def is_prod(self) -> bool:
        return self.ENV == "prod"

    @model_validator(mode="after")
    def _validate_secrets(self) -> "Settings":
        if self.ENV == "prod":
            # Fail fast: every gunicorn worker must share one strong secret, otherwise
            # tokens signed by one worker are rejected by the next.
            if len(self.JWT_SECRET) < 32:
                raise ValueError("JWT_SECRET must be set to at least 32 random characters when ENV=prod")
            if any(o.strip() == "*" for o in self.CORS_ORIGINS):
                raise ValueError("CORS_ORIGINS must list explicit origins when ENV=prod (no '*')")
            if self.DEBUG:
                raise ValueError("DEBUG must be false when ENV=prod")
        elif not self.JWT_SECRET:
            # Dev/test only: ephemeral per-process secret (single worker).
            self.JWT_SECRET = secrets.token_urlsafe(48)
        return self


settings = Settings()
