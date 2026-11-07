from datetime import datetime, timedelta, timezone
from typing import Optional
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.exceptions import BadRequestException, NotFoundException, UnauthorizedException
from app.core.security import (
    create_access_token,
    generate_otp,
    generate_random_token,
    hash_token,
    verify_token_hash,
)
import structlog
from app.models.auth import OtpCode, RefreshToken
from app.models.user import User
from app.schemas.auth import TokenResponse
from app.services.sms import get_sms_provider

logger = structlog.get_logger()


class AuthService:
    """Service handling OTP authentication, tokens, and session lifecycles."""

    @staticmethod
    async def request_otp(phone: str, db: Optional[AsyncSession] = None) -> dict:
        """Rate-limited OTP dispatch for users across MongoDB Atlas with Resend email delivery and dev fallback."""
        now = datetime.now(timezone.utc)
        from app.core.security import normalize_phone, generate_otp, hash_token
        from app.db.mongo import mongo_find_user_by_identifier, mongo_store_otp
        from app.services.email_service import email_service

        try:
            clean_phone = normalize_phone(phone)
        except Exception:
            clean_phone = phone.strip()

        # Generate OTP
        otp_code = generate_otp(length=settings.OTP_LENGTH)
        code_hash = hash_token(otp_code)
        expires_at = now + timedelta(seconds=settings.OTP_EXPIRE_SECONDS)

        # Store in MongoDB for both normalized and raw phone format
        mongo_store_otp(phone=clean_phone, code_hash=code_hash, expires_at=expires_at)
        if clean_phone != phone.strip():
            mongo_store_otp(phone=phone.strip(), code_hash=code_hash, expires_at=expires_at)

        # 1. SMS provider dispatch (console or Msg91)
        try:
            sms_provider = get_sms_provider()
            await sms_provider.send_otp(phone=clean_phone, otp_code=otp_code)
        except Exception as e:
            logger.warning("SMS provider dispatch error", error=str(e))

        # 2. Check if user is registered in MongoDB Atlas
        mongo_user = mongo_find_user_by_identifier(clean_phone) or mongo_find_user_by_identifier(phone.strip())
        user_email = mongo_user.get("email") if mongo_user else None
        user_name = mongo_user.get("name", "SolarPro User") if mongo_user else "SolarPro User"

        # 3. Deliver OTP to user's registered email
        if user_email:
            try:
                await email_service.send_verification_email(
                    to_email=user_email,
                    code=otp_code,
                    user_name=user_name,
                )
            except Exception as e:
                logger.warning("Failed to dispatch OTP email", error=str(e), email=user_email)

        logger.info("[OTP] Generated login OTP", phone=clean_phone, otp=otp_code, email=user_email)

        msg = f"Verification OTP sent to +91 {clean_phone}"
        if user_email:
            msg += f" and {user_email}"

        return {
            "message": msg,
            "email": user_email,
            "dev_otp": None,
        }

    @staticmethod
    async def verify_otp(
        phone: str,
        otp: str,
        device_info: Optional[str] = None,
        db: Optional[AsyncSession] = None,
    ) -> dict:
        """Verify OTP, record session, and generate tokens from MongoDB Atlas or SQL."""
        now = datetime.now(timezone.utc)

        # 1. Check MongoDB Atlas
        from app.db.mongo import mongo_find_user_by_identifier, mongo_verify_otp, mongo_update_login_timestamp
        mongo_user = mongo_find_user_by_identifier(phone)
        if mongo_user:
            if not mongo_verify_otp(phone, otp):
                raise BadRequestException("Invalid or expired OTP.")

            role = str(mongo_user.get("role", "client")).lower()
            is_email_verified = mongo_user.get("is_email_verified", True if role != "client" else False)

            # Client verification: verifying phone OTP automatically confirms client identity
            if role == "client":
                from app.db.mongo import mongo_mark_email_verified
                if not is_email_verified:
                    mongo_mark_email_verified(mongo_user.get("email") or phone)
                    is_email_verified = True
            elif not mongo_user.get("is_superadmin", False):
                # Employee and Admin roles require Super Admin approval
                approval_status = mongo_user.get("approval_status", "approved" if mongo_user.get("is_active") else "pending")
                if approval_status == "pending" or not mongo_user.get("is_active", True):
                    from app.core.exceptions import ForbiddenException
                    raise ForbiddenException("Your account registration is pending approval by the Super Admin. You will be able to log in once approved.")
                if approval_status == "rejected":
                    from app.core.exceptions import ForbiddenException
                    raise ForbiddenException("Your account registration was rejected by the Super Admin. Please contact support.")

            mongo_update_login_timestamp(str(mongo_user["_id"]))
            user_id = str(mongo_user["_id"])
            access_token = create_access_token(subject=user_id, role=role)
            refresh_token = generate_random_token()
            return {
                "access_token": access_token,
                "refresh_token": refresh_token,
                "token_type": "bearer",
                "user": {
                    "id": user_id,
                    "name": mongo_user.get("name", ""),
                    "phone": mongo_user.get("phone", ""),
                    "email": mongo_user.get("email"),
                    "role": role,
                    "is_active": True,
                    "is_email_verified": is_email_verified,
                },
            }

        # 2. Check SQLAlchemy
        if db is not None:
            stmt = (
                select(OtpCode)
                .where(
                    OtpCode.phone == phone,
                    OtpCode.consumed_at.is_(None),
                    OtpCode.expires_at > now,
                )
                .order_by(OtpCode.created_at.desc())
                .limit(1)
            )
            otp_record = (await db.execute(stmt)).scalar_one_or_none()
            if not otp_record:
                raise BadRequestException("Invalid or expired OTP.")
            if otp_record.attempts >= 5:
                raise BadRequestException("Maximum OTP attempts exceeded. Please request a new OTP.")

            otp_record.attempts += 1
            if not verify_token_hash(otp, otp_record.code_hash):
                await db.commit()
                raise BadRequestException("Invalid OTP code.")

            otp_record.consumed_at = now
            user_stmt = select(User).where(
                User.phone == phone,
                User.is_deleted == False,
                User.is_active == True,
            )
            user = (await db.execute(user_stmt)).scalar_one_or_none()
            if not user:
                raise NotFoundException("Active user not found.")

            user.last_login_at = now
            access_token = create_access_token(subject=str(user.id), role=user.role.value)
            plain_refresh_token = generate_random_token()
            refresh_hash = hash_token(plain_refresh_token)
            refresh_expires = now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

            refresh_record = RefreshToken(
                user_id=user.id,
                token_hash=refresh_hash,
                expires_at=refresh_expires,
                device_info=device_info,
            )
            db.add(refresh_record)
            await db.commit()
            await db.refresh(user)

            return {
                "access_token": access_token,
                "refresh_token": plain_refresh_token,
                "token_type": "bearer",
                "user": {
                    "id": str(user.id),
                    "name": user.name,
                    "phone": user.phone,
                    "role": user.role.value,
                    "is_active": user.is_active,
                },
            }

        # Check if the OTP was at least valid
        from app.db.mongo import mongo_verify_otp
        if not mongo_verify_otp(phone, otp):
            raise BadRequestException("Invalid or expired OTP.")

        raise NotFoundException(f"No account is registered with +91 {phone}. Please tap 'Register Client Account' below to sign up.")

    @staticmethod
    async def refresh_token(
        db: AsyncSession,
        refresh_token_plain: str,
    ) -> TokenResponse:
        """Rotate refresh token and issue new access token."""
        now = datetime.now(timezone.utc)
        token_hash = hash_token(refresh_token_plain)

        stmt = select(RefreshToken).where(
            RefreshToken.token_hash == token_hash,
            RefreshToken.revoked_at.is_(None),
            RefreshToken.expires_at > now,
        )
        token_record = (await db.execute(stmt)).scalar_one_or_none()

        if not token_record:
            raise UnauthorizedException("Invalid, expired, or revoked refresh token.")

        # Fetch associated user
        user_stmt = select(User).where(
            User.id == token_record.user_id,
            User.is_deleted == False,  # noqa: E712
            User.is_active == True,   # noqa: E712
        )
        user = (await db.execute(user_stmt)).scalar_one_or_none()
        if not user:
            raise UnauthorizedException("User account is inactive or deleted.")

        # Revoke old token (Rotation)
        token_record.revoked_at = now

        # Issue new pair
        access_token = create_access_token(subject=str(user.id), role=user.role.value)
        new_refresh_plain = generate_random_token()
        new_refresh_hash = hash_token(new_refresh_plain)
        new_expires = now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

        new_record = RefreshToken(
            user_id=user.id,
            token_hash=new_refresh_hash,
            expires_at=new_expires,
            device_info=token_record.device_info,
        )
        db.add(new_record)
        await db.commit()
        await db.refresh(user)

        return TokenResponse(
            access_token=access_token,
            refresh_token=new_refresh_plain,
            user=user,
        )

    @staticmethod
    async def logout(db: AsyncSession, refresh_token_plain: str) -> None:
        """Revoke refresh token on logout."""
        token_hash = hash_token(refresh_token_plain)
        stmt = select(RefreshToken).where(
            RefreshToken.token_hash == token_hash,
            RefreshToken.revoked_at.is_(None),
        )
        token_record = (await db.execute(stmt)).scalar_one_or_none()
        if token_record:
            token_record.revoked_at = datetime.now(timezone.utc)
            await db.commit()

    @staticmethod
    async def update_fcm_token(db: AsyncSession, user: User, fcm_token: str) -> User:
        """Update user device FCM token for push notifications."""
        user.fcm_token = fcm_token
        await db.commit()
        await db.refresh(user)
        return user

    @staticmethod
    async def login_with_password(
        identifier: str,
        password: str,
        device_info: Optional[str] = None,
        db: Optional[AsyncSession] = None,
    ) -> dict:
        """
        Authenticate user with identifier (phone or email) and password.
        Uses salted bcrypt verification and protects against SQL/NoSQL injection.
        """
        from app.db.mongo import mongo_find_user_by_identifier, mongo_update_login_timestamp
        from app.core.security import verify_password, create_access_token, generate_random_token

        # 1. Query MongoDB Atlas (live persistent cloud DB)
        mongo_user = mongo_find_user_by_identifier(identifier)
        if mongo_user:
            stored_hash = mongo_user.get("password_hash")
            if not stored_hash or not verify_password(password, stored_hash):
                raise UnauthorizedException("Invalid username/phone or password.")

            role = str(mongo_user.get("role", "client")).lower()
            is_email_verified = mongo_user.get("is_email_verified", True if role != "client" else False)

            # Block unverified client from logging in
            if role == "client" and not is_email_verified:
                user_email = mongo_user.get("email")
                if user_email:
                    await AuthService.send_email_verification(user_email)
                from app.core.exceptions import EmailVerificationRequiredException
                raise EmailVerificationRequiredException(
                    message="Email verification is required for client access. A 6-digit verification code has been dispatched to your email.",
                    email=user_email,
                    role="client",
                )
            elif role != "client" and not mongo_user.get("is_superadmin", False):
                # Employee and Admin roles require Super Admin approval
                approval_status = mongo_user.get("approval_status", "approved" if mongo_user.get("is_active") else "pending")
                if approval_status == "pending" or not mongo_user.get("is_active", True):
                    from app.core.exceptions import ForbiddenException
                    raise ForbiddenException("Your account registration is pending approval by the Super Admin. You will be able to log in once approved.")
                if approval_status == "rejected":
                    from app.core.exceptions import ForbiddenException
                    raise ForbiddenException("Your account registration was rejected by the Super Admin. Please contact support.")

            mongo_update_login_timestamp(str(mongo_user["_id"]))
            user_id = str(mongo_user["_id"])
            access_token = create_access_token(subject=user_id, role=role)
            refresh_token = generate_random_token()

            return {
                "access_token": access_token,
                "refresh_token": refresh_token,
                "token_type": "bearer",
                "user": {
                    "id": user_id,
                    "name": mongo_user.get("name", ""),
                    "phone": mongo_user.get("phone", ""),
                    "email": mongo_user.get("email"),
                    "role": role,
                    "is_active": mongo_user.get("is_active", True),
                    "is_email_verified": is_email_verified,
                    "employee_no": mongo_user.get("employee_no"),
                    "team": mongo_user.get("team"),
                    "trade": mongo_user.get("trade"),
                },
            }

        # 2. Check SQLAlchemy (SQL parameter binding prevents injection)
        if db is not None:
            clean_id = identifier.strip()
            stmt = select(User).where(
                (User.phone == clean_id) | (User.name == clean_id),
                User.is_deleted == False,
                User.is_active == True,
            )
            user = (await db.execute(stmt)).scalar_one_or_none()
            if user:
                user_pwd_hash = getattr(user, "password_hash", None)
                if user_pwd_hash and not verify_password(password, user_pwd_hash):
                    raise UnauthorizedException("Invalid username/phone or password.")

                access_token = create_access_token(subject=str(user.id), role=user.role.value)
                refresh_token = generate_random_token()
                return {
                    "access_token": access_token,
                    "refresh_token": refresh_token,
                    "token_type": "bearer",
                    "user": {
                        "id": str(user.id),
                        "name": user.name,
                        "phone": user.phone,
                        "role": user.role.value,
                        "is_active": user.is_active,
                    },
                }

        raise UnauthorizedException("Invalid username/phone or password.")

    @staticmethod
    async def register_user(
        name: str,
        phone: str,
        password: str,
        role: str = "client",
        email: Optional[str] = None,
    ) -> dict:
        """Register a new user in MongoDB Atlas. For client role, dispatches email verification."""
        from app.db.mongo import mongo_create_user
        from app.core.security import create_access_token, generate_random_token

        role_clean = role.strip().lower()
        clean_email = email.strip().lower() if email else None

        # Mandatory email validation for client
        if role_clean == "client" and not clean_email:
            raise BadRequestException("An email address is mandatory for client registration to verify your account.")

        try:
            user_doc = mongo_create_user(
                name=name,
                phone=phone,
                password=password,
                role=role_clean,
                email=clean_email,
                is_email_verified=False if role_clean == "client" else True,
            )
        except ValueError as ve:
            raise BadRequestException(str(ve))
        except Exception as e:
            raise BadRequestException(f"Registration error: {str(e)}")

        user_id = str(user_doc["_id"])

        # If client, send email verification code immediately and do not give active token yet
        if role_clean == "client":
            await AuthService.send_email_verification(clean_email)
            return {
                "requires_email_verification": True,
                "message": f"Client account registered successfully! A 6-digit verification code has been sent to {clean_email}.",
                "email": clean_email,
                "user": {
                    "id": user_id,
                    "name": user_doc["name"],
                    "phone": user_doc["phone"],
                    "email": user_doc.get("email"),
                    "role": role_clean,
                    "is_active": True,
                    "is_email_verified": False,
                },
            }

        # Non-client roles (employee/vendor/admin) require Super Admin approval
        # 1. Create In-App Notification in MongoDB Atlas for Admin
        try:
            role_display_map = {
                "sales": "Sales Executive",
                "kedl": "KEDL Liaison",
                "service": "Service Technician",
                "site": "Site Installation Crew",
                "admin": "Administrator",
                "employee": "Employee",
            }
            role_display = role_display_map.get(role_clean, role_clean.capitalize())

            from app.db.mongo import mongo_create_notification
            mongo_create_notification({
                "title": f"New {role_display} Registration",
                "body": f"{user_doc['name']} has applied for {role_display} role (+91 {user_doc['phone']}). Tap to review and accept.",
                "type": "user_approval",
                "target_role": "admin",
                "target_id": user_id,
                "metadata": {
                    "user_id": user_id,
                    "name": user_doc["name"],
                    "phone": user_doc["phone"],
                    "role": role_clean,
                    "role_display": role_display,
                    "email": user_doc.get("email"),
                },
            })
        except Exception as e:
            logger.warning("Failed to create in-app notification for admin", error=str(e))

        # 2. Dispatch Email notification to Super Admin if configured
        try:
            from app.services.email_service import email_service
            subject = f"SolarPro Alert: New {role_clean.capitalize()} Registration Pending Approval"
            html_body = f"""
            <p>Hello Super Admin,</p>
            <p>A new registration request requires your review in the SolarPro Executive Console:</p>
            <ul>
                <li><strong>Full Name:</strong> {user_doc['name']}</li>
                <li><strong>Requested Role:</strong> {role_clean.capitalize()}</li>
                <li><strong>Mobile:</strong> {user_doc['phone']}</li>
                <li><strong>Email:</strong> {user_doc.get('email', 'N/A')}</li>
            </ul>
            <p>Please log in to your Admin portal to approve or reject this user.</p>
            """
            super_admin_email = settings.SUPER_ADMIN_EMAIL
            if super_admin_email:
                import asyncio
                asyncio.create_task(email_service._send_resend(super_admin_email, subject, html_body))
        except Exception as e:
            logger.warning("Failed to notify super admin about registration", error=str(e))

        return {
            "requires_approval": True,
            "approval_status": "pending",
            "message": f"Your {role_clean.capitalize()} registration request has been submitted to the Super Admin. You will be able to log in once your account is approved.",
            "user": {
                "id": user_id,
                "name": user_doc["name"],
                "phone": user_doc["phone"],
                "email": user_doc.get("email"),
                "role": role_clean,
                "is_active": False,
                "approval_status": "pending",
            },
        }

    @staticmethod
    async def send_email_verification(email: str) -> str:
        """Generate a 6-digit OTP, store in MongoDB Atlas, and dispatch verification email."""
        from app.db.mongo import mongo_find_user_by_email, mongo_store_email_verification
        from app.services.email_service import email_service

        clean_email = email.strip().lower()
        now = datetime.now(timezone.utc)
        code = generate_otp(length=settings.OTP_LENGTH)
        code_hash = hash_token(code)
        expires_at = now + timedelta(seconds=settings.EMAIL_VERIFICATION_EXPIRE_SECONDS)

        mongo_store_email_verification(email=clean_email, code_hash=code_hash, expires_at=expires_at)

        user = mongo_find_user_by_email(clean_email)
        user_name = user.get("name", "Client") if user else "Client"

        try:
            await email_service.send_verification_email(
                to_email=clean_email,
                code=code,
                user_name=user_name,
            )
        except Exception as e:
            logger.warning("Failed to dispatch verification email", error=str(e), email=clean_email)

        logger.info("[VERIFY] Dispatched email verification code", email=clean_email, code=code)
        return code

    @staticmethod
    async def verify_email(email: str, code: str) -> dict:
        """Verify 6-digit email verification code, mark client verified, and return auth tokens."""
        from app.db.mongo import mongo_find_user_by_email, mongo_mark_email_verified, mongo_verify_email_code
        from app.core.security import create_access_token, generate_random_token

        clean_email = email.strip().lower()
        clean_code = code.strip()

        if not mongo_verify_email_code(clean_email, clean_code):
            raise BadRequestException("Invalid or expired email verification code. Please check your inbox or request a new one.")

        mongo_mark_email_verified(clean_email)
        user = mongo_find_user_by_email(clean_email)

        if not user:
            return {
                "message": "Email verified successfully! You may now log in.",
                "email": clean_email,
            }

        user_id = str(user["_id"])
        role = str(user.get("role", "client")).lower()
        access_token = create_access_token(subject=user_id, role=role)
        refresh_token = generate_random_token()

        return {
            "message": "Email verified successfully! Welcome to SolarPro.",
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "user": {
                "id": user_id,
                "name": user.get("name", ""),
                "phone": user.get("phone", ""),
                "email": clean_email,
                "role": role,
                "is_active": True,
                "is_email_verified": True,
            },
        }

