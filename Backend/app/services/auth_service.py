"""Authentication: registration, password/OTP login, email verification and
refresh-token sessions — all backed by MongoDB.

Security properties:
* Generic error messages and constant-time password checks (no user enumeration).
* Per-identifier lockout and per-IP throttling on every credential endpoint.
* OTPs/verification codes are stored only as HMACs, are single-use, expire,
  are invalidated when re-issued, and are capped per hour (no SMS pumping, no
  brute force by re-requesting codes).
* Refresh tokens are random, stored hashed, rotated on every use, and reuse of
  a rotated token revokes the whole session family.
"""
from datetime import datetime, timedelta, timezone
import html
import uuid
from typing import Any, Dict, Optional
import structlog
from app.core import ratelimit
from app.core.access import PUBLIC_REGISTRATION_ROLES
from app.core.config import settings
from app.core.deps import assert_can_sign_in, load_user
from app.core.exceptions import (
    BadRequestException,
    EmailVerificationRequiredException,
    ForbiddenException,
    UnauthorizedException,
)
from app.core.security import (
    create_access_token,
    generate_otp,
    generate_random_token,
    hash_password,
    hash_token,
    normalize_email,
    normalize_phone,
    validate_password_strength,
    verify_password,
    verify_token_hash,
)

logger = structlog.get_logger()

INVALID_LOGIN = "Invalid email/mobile or password."
GENERIC_OTP_SENT = "If this mobile number is registered, a verification code has been sent."
GENERIC_EMAIL_SENT = "If this email needs verification, a code has been sent to it."


def _db():
    from app.db.mongo import get_mongo_db
    db = get_mongo_db()
    if db is None:
        raise BadRequestException("Service temporarily unavailable. Please try again shortly.")
    return db


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _find_user(identifier: str) -> Optional[Dict[str, Any]]:
    """Look up a user by email or phone, regardless of status."""
    ident = str(identifier).strip()
    conds = []
    try:
        conds.append({"email": normalize_email(ident)})
    except ValueError:
        pass
    try:
        conds.append({"phone": normalize_phone(ident)})
    except ValueError:
        pass
    if not conds:
        return None
    return _db()["users"].find_one({"$or": conds})


def _user_payload(doc: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "id": str(doc.get("id") or doc["_id"]),
        "name": doc.get("name", ""),
        "phone": doc.get("phone", ""),
        "email": doc.get("email"),
        "role": str(doc.get("role", "client")).lower(),
        "is_active": bool(doc.get("is_active", False)),
        "is_email_verified": bool(doc.get("is_email_verified", False)),
        "is_phone_verified": bool(doc.get("is_phone_verified", False)),
        "employee_no": doc.get("employee_no"),
        "team": doc.get("team"),
        "trade": doc.get("trade"),
    }


class AuthService:
    # ── Sessions ────────────────────────────────────────────────────────────

    @staticmethod
    def _issue_tokens(doc: Dict[str, Any], device_info: Optional[str] = None, family_id: Optional[str] = None) -> Dict[str, Any]:
        assert_can_sign_in(doc)
        db = _db()
        now = _now()
        uid = str(doc.get("id") or doc["_id"])
        role = str(doc.get("role", "client")).lower()
        access = create_access_token(subject=uid, role=role, token_version=int(doc.get("token_version", 0) or 0))
        refresh_plain = generate_random_token()
        db["refresh_tokens"].insert_one({
            "_id": hash_token(refresh_plain),
            "user_id": uid,
            "family_id": family_id or uuid.uuid4().hex,
            "device_info": (device_info or "")[:200],
            "created_at": now,
            "expires_at": now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
            "revoked_at": None,
        })
        db["users"].update_one({"_id": doc["_id"]}, {"$set": {"last_login_at": now}})
        return {
            "access_token": access,
            "refresh_token": refresh_plain,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            "user": _user_payload(doc),
        }

    @staticmethod
    def refresh(refresh_token_plain: str, ip: str) -> Dict[str, Any]:
        ratelimit.hit(f"refresh:ip:{ip}", 60, 300)
        db = _db()
        now = _now()
        token_id = hash_token(refresh_token_plain or "")
        record = db["refresh_tokens"].find_one({"_id": token_id})
        if not record:
            raise UnauthorizedException("Invalid or expired session. Please sign in again.")
        if record.get("revoked_at") is not None:
            # A rotated token was replayed: assume theft and kill the whole family.
            db["refresh_tokens"].update_many(
                {"family_id": record.get("family_id"), "revoked_at": None},
                {"$set": {"revoked_at": now, "revoked_reason": "reuse_detected"}},
            )
            logger.warning("refresh_token_reuse_detected", user_id=record.get("user_id"))
            raise UnauthorizedException("Session expired. Please sign in again.")
        expires = record["expires_at"]
        if (expires if expires.tzinfo else expires.replace(tzinfo=timezone.utc)) <= now:
            raise UnauthorizedException("Session expired. Please sign in again.")

        doc = load_user(str(record["user_id"]))
        if not doc:
            raise UnauthorizedException("Session expired. Please sign in again.")
        try:
            assert_can_sign_in(doc)
        except ForbiddenException as e:
            raise UnauthorizedException(e.message)

        res = db["refresh_tokens"].update_one(
            {"_id": token_id, "revoked_at": None},
            {"$set": {"revoked_at": now, "revoked_reason": "rotated"}},
        )
        if res.modified_count != 1:
            raise UnauthorizedException("Session expired. Please sign in again.")
        return AuthService._issue_tokens(doc, record.get("device_info"), family_id=record.get("family_id"))

    @staticmethod
    def logout(refresh_token_plain: str) -> None:
        if not refresh_token_plain:
            return
        _db()["refresh_tokens"].update_one(
            {"_id": hash_token(refresh_token_plain), "revoked_at": None},
            {"$set": {"revoked_at": _now(), "revoked_reason": "logout"}},
        )

    @staticmethod
    def revoke_all_sessions(user_id: str) -> None:
        """Invalidate every access and refresh token for a user."""
        db = _db()
        doc = load_user(str(user_id))  # resolves string and ObjectId _ids alike
        ids = {str(user_id)}
        if doc:
            ids |= {str(doc["_id"]), str(doc.get("id") or doc["_id"])}
        db["users"].update_one({"_id": doc["_id"] if doc else user_id}, {"$inc": {"token_version": 1}})
        db["refresh_tokens"].update_many(
            {"user_id": {"$in": sorted(ids)}, "revoked_at": None},
            {"$set": {"revoked_at": _now(), "revoked_reason": "revoke_all"}},
        )

    # ── Password login ──────────────────────────────────────────────────────

    @staticmethod
    async def login_with_password(identifier: str, password: str, ip: str, device_info: Optional[str] = None) -> Dict[str, Any]:
        ident_key = str(identifier).strip().lower()[:120]
        ratelimit.hit(f"login:ip:{ip}", 30, 900)
        fail_key = f"login:fail:{ident_key}"
        ratelimit.ensure_below(
            fail_key, settings.LOGIN_MAX_FAILURES,
            "Too many failed sign-in attempts. Please wait 15 minutes or sign in with OTP.",
            settings.LOGIN_FAILURE_WINDOW_SECONDS,
        )

        doc = _find_user(identifier)
        if not verify_password(password, doc.get("password_hash") if doc else None) or not doc:
            ratelimit.hit(fail_key, 10_000, settings.LOGIN_FAILURE_WINDOW_SECONDS)
            raise UnauthorizedException(INVALID_LOGIN)
        ratelimit.reset(fail_key)

        # Correct password: status messages can now be shown without enabling enumeration.
        role = str(doc.get("role", "client")).lower()
        if role == "client" and not doc.get("is_email_verified") and not doc.get("is_phone_verified"):
            await AuthService.send_email_verification(doc.get("email") or "", ip, quiet=True)
            raise EmailVerificationRequiredException(
                message="Please verify your email. A 6-digit code has been sent to your inbox.",
                email=doc.get("email"),
                role="client",
            )
        return AuthService._issue_tokens(doc, device_info)

    # ── Registration ────────────────────────────────────────────────────────

    @staticmethod
    async def register_user(name: str, phone: str, password: str, role: str, email: Optional[str], ip: str) -> Dict[str, Any]:
        ratelimit.hit(f"register:ip:{ip}", 5, 3600, "Too many sign-up attempts from this network. Please try later.")

        role_clean = str(role or "client").strip().lower()
        if role_clean not in PUBLIC_REGISTRATION_ROLES:
            raise BadRequestException("This role cannot be requested through sign-up.")
        try:
            clean_phone = normalize_phone(phone)
            clean_email = normalize_email(email) if email else None
            validate_password_strength(password)
        except ValueError as e:
            raise BadRequestException(str(e))
        if not clean_email:
            raise BadRequestException("An email address is required.")
        clean_name = " ".join(str(name).split())[:100]
        if len(clean_name) < 2:
            raise BadRequestException("Please enter your full name.")

        db = _db()
        if db["users"].find_one({"$or": [{"phone": clean_phone}, {"email": clean_email}]}):
            # Existing accounts are never modified by sign-up (prevents takeover).
            raise BadRequestException("An account with this mobile number or email already exists. Please sign in.")

        now = _now()
        uid = str(uuid.uuid4())
        is_client = role_clean == "client"
        doc = {
            "_id": uid,
            "id": uid,
            "name": clean_name,
            "phone": clean_phone,
            "email": clean_email,
            "role": role_clean,
            "requested_role": role_clean,
            "password_hash": hash_password(password),
            "is_active": is_client,
            "approval_status": "approved" if is_client else "pending",
            "is_email_verified": False,
            "is_phone_verified": False,
            "token_version": 0,
            "created_at": now,
            "updated_at": now,
            "last_login_at": None,
        }
        try:
            db["users"].insert_one(doc)
        except Exception:
            raise BadRequestException("An account with this mobile number or email already exists. Please sign in.")

        # Every new account proves both contact points: a code to the email and
        # a separate code by SMS to the mobile (see verify_signup).
        await AuthService.send_email_verification(clean_email, ip, quiet=True)
        await AuthService._send_phone_code(clean_phone, quiet=True)
        if is_client:
            return {
                "requires_verification": True,
                "requires_email_verification": True,
                "requires_phone_verification": True,
                "message": "Account created. Enter the codes we sent to your email and mobile.",
                "email": clean_email,
                "phone": clean_phone,
                "user": _user_payload(doc),
            }

        role_display = {
            "sales": "Sales Executive", "kedl": "KEDL Liaison",
            "service": "Service Technician", "site": "Site Installation Crew",
        }.get(role_clean, role_clean.capitalize())
        try:
            from app.db.mongo import mongo_create_notification
            mongo_create_notification({
                "title": f"New {role_display} Registration",
                "body": f"{clean_name} has applied for the {role_display} role. Review in Staff Approvals.",
                "type": "user_approval",
                "target_role": "admin",
                "target_id": uid,
                "metadata": {"user_id": uid, "role": role_clean, "role_display": role_display},
            })
        except Exception as e:
            logger.warning("registration_notification_failed", error=str(e))
        try:
            if settings.SUPER_ADMIN_EMAIL:
                from app.services.email_service import email_service
                import asyncio
                asyncio.create_task(email_service._send_resend(
                    settings.SUPER_ADMIN_EMAIL,
                    f"SolarPro: new {role_display} registration pending approval",
                    f"<p>A new <strong>{html.escape(role_display)}</strong> registration from "
                    f"<strong>{html.escape(clean_name)}</strong> is waiting for your review in the "
                    f"SolarPro admin portal.</p>",
                ))
        except Exception as e:
            logger.warning("registration_admin_email_failed", error=str(e))

        return {
            "requires_approval": True,
            "requires_verification": True,
            "requires_email_verification": True,
            "requires_phone_verification": True,
            "approval_status": "pending",
            "message": "Verify your email and mobile. You can sign in once an administrator approves your account.",
            "email": clean_email,
            "phone": clean_phone,
            "user": _user_payload(doc),
        }

    # ── Email verification ──────────────────────────────────────────────────

    @staticmethod
    async def send_email_verification(email: str, ip: str, quiet: bool = False) -> None:
        try:
            clean_email = normalize_email(email)
        except ValueError:
            if quiet:
                return
            raise BadRequestException("Invalid email address.")
        if not quiet:
            ratelimit.hit(f"verify_email:ip:{ip}", 10, 3600)
        try:
            ratelimit.hit(f"verify_email:cooldown:{clean_email}", 1, settings.OTP_RESEND_COOLDOWN_SECONDS,
                          "Please wait a minute before requesting another code.")
            ratelimit.hit(f"verify_email:hour:{clean_email}", settings.OTP_MAX_PER_HOUR, 3600)
        except Exception:
            if quiet:
                return
            raise

        db = _db()
        user = db["users"].find_one({"email": clean_email})
        if not user or user.get("is_email_verified"):
            return  # generic response; nothing to send

        code = generate_otp(length=settings.OTP_LENGTH)
        now = _now()
        db["email_verifications"].update_many(
            {"email": clean_email, "consumed_at": None},
            {"$set": {"consumed_at": now, "superseded": True}},
        )
        db["email_verifications"].insert_one({
            "_id": str(uuid.uuid4()),
            "email": clean_email,
            "code_hash": hash_token(code),
            "expires_at": now + timedelta(seconds=settings.EMAIL_VERIFICATION_EXPIRE_SECONDS),
            "attempts": 0,
            "consumed_at": None,
            "created_at": now,
        })
        try:
            from app.services.email_service import email_service
            await email_service.send_verification_email(to_email=clean_email, code=code, user_name=user.get("name", ""))
        except Exception as e:
            logger.warning("verification_email_failed", error=str(e))

    @staticmethod
    async def verify_email(email: str, code: str, ip: str) -> Dict[str, Any]:
        ratelimit.hit(f"verify_email_check:ip:{ip}", 30, 900)
        try:
            clean_email = normalize_email(email)
        except ValueError:
            raise BadRequestException("Invalid or expired verification code.")
        fail_key = f"verify_email:fail:{clean_email}"
        ratelimit.ensure_below(fail_key, settings.OTP_MAX_VERIFY_FAILURES_PER_HOUR,
                               "Too many incorrect codes. Please request a new code later.", 3600)

        db = _db()
        now = _now()
        rec = db["email_verifications"].find_one(
            {"email": clean_email, "consumed_at": None, "expires_at": {"$gt": now}},
            sort=[("created_at", -1)],
        )
        if not rec or rec.get("attempts", 0) >= 5 or not verify_token_hash(str(code).strip(), rec["code_hash"]):
            if rec:
                db["email_verifications"].update_one({"_id": rec["_id"]}, {"$inc": {"attempts": 1}})
            ratelimit.hit(fail_key, 10_000, 3600)
            raise BadRequestException("Invalid or expired verification code.")
        db["email_verifications"].update_one({"_id": rec["_id"]}, {"$set": {"consumed_at": now}})
        ratelimit.reset(fail_key)

        db["users"].update_one(
            {"email": clean_email},
            {"$set": {"is_email_verified": True, "email_verified_at": now, "updated_at": now}},
        )
        doc = db["users"].find_one({"email": clean_email})
        if not doc:
            raise BadRequestException("Invalid or expired verification code.")
        if str(doc.get("role")) != "client" or doc.get("approval_status") != "approved":
            return {"message": "Email verified. You can sign in once your account is approved.", "email": clean_email}
        res = AuthService._issue_tokens(doc)
        res["message"] = "Email verified successfully. Welcome to SolarPro!"
        return res

    # ── Mobile OTP ──────────────────────────────────────────────────────────

    @staticmethod
    async def request_otp(phone: str, ip: str) -> Dict[str, Any]:
        try:
            clean_phone = normalize_phone(phone)
        except ValueError:
            raise BadRequestException("Please enter a valid 10-digit mobile number.")
        ratelimit.hit(f"otp:ip:{ip}", 10, 3600, "Too many code requests from this network. Please try later.")
        ratelimit.hit(f"otp:cooldown:{clean_phone}", 1, settings.OTP_RESEND_COOLDOWN_SECONDS,
                      "Please wait a minute before requesting another code.")
        ratelimit.hit(f"otp:hour:{clean_phone}", settings.OTP_MAX_PER_HOUR, 3600,
                      "Too many codes requested for this number. Please try again in an hour.")

        db = _db()
        user = db["users"].find_one({"phone": clean_phone})
        if not user:
            # Same response as success: never reveal which numbers are registered,
            # and never spend SMS credits on unknown numbers.
            return {"message": GENERIC_OTP_SENT}

        code = AuthService._issue_phone_code(clean_phone)
        await AuthService._sms(clean_phone, code)
        if user.get("email"):
            try:
                from app.services.email_service import email_service
                await email_service.send_verification_email(to_email=user["email"], code=code, user_name=user.get("name", ""))
            except Exception as e:
                logger.warning("otp_email_failed", error=str(e))
        return {"message": GENERIC_OTP_SENT}

    @staticmethod
    def _issue_phone_code(clean_phone: str) -> str:
        """Store a fresh single-use SMS code (hashed) and return the plain code."""
        db = _db()
        code = generate_otp(length=settings.OTP_LENGTH)
        now = _now()
        db["otp_codes"].update_many(
            {"phone": clean_phone, "consumed_at": None},
            {"$set": {"consumed_at": now, "superseded": True}},
        )
        db["otp_codes"].insert_one({
            "_id": str(uuid.uuid4()),
            "phone": clean_phone,
            "code_hash": hash_token(code),
            "expires_at": now + timedelta(seconds=settings.OTP_EXPIRE_SECONDS),
            "attempts": 0,
            "consumed_at": None,
            "created_at": now,
        })
        return code

    @staticmethod
    async def _sms(clean_phone: str, code: str) -> None:
        try:
            from app.services.sms import get_sms_provider
            await get_sms_provider().send_otp(phone=clean_phone, otp_code=code)
        except Exception as e:
            logger.warning("sms_dispatch_failed", error=str(e))

    @staticmethod
    async def _send_phone_code(clean_phone: str, quiet: bool = False) -> None:
        """SMS-only verification code for a not-yet-verified mobile number.

        Unlike the sign-in OTP this is never copied to email: it must prove the
        person holds the phone.
        """
        try:
            ratelimit.hit(f"otp:cooldown:{clean_phone}", 1, settings.OTP_RESEND_COOLDOWN_SECONDS,
                          "Please wait a minute before requesting another code.")
            ratelimit.hit(f"otp:hour:{clean_phone}", settings.OTP_MAX_PER_HOUR, 3600,
                          "Too many codes requested for this number. Please try again in an hour.")
        except Exception:
            if quiet:
                return
            raise
        user = _db()["users"].find_one({"phone": clean_phone})
        if not user or user.get("is_phone_verified"):
            return  # generic response; nothing to send
        await AuthService._sms(clean_phone, AuthService._issue_phone_code(clean_phone))

    @staticmethod
    async def send_phone_verification(phone: str, ip: str) -> None:
        try:
            clean_phone = normalize_phone(phone)
        except ValueError:
            raise BadRequestException("Please enter a valid 10-digit mobile number.")
        ratelimit.hit(f"otp:ip:{ip}", 10, 3600, "Too many code requests from this network. Please try later.")
        await AuthService._send_phone_code(clean_phone)

    @staticmethod
    def _find_code(collection: str, field: str, value: str, code: str) -> Optional[Dict[str, Any]]:
        """Return the live code record if ``code`` matches it, counting failed attempts."""
        db = _db()
        rec = db[collection].find_one(
            {field: value, "consumed_at": None, "expires_at": {"$gt": _now()}},
            sort=[("created_at", -1)],
        )
        if not rec or rec.get("attempts", 0) >= 5 or not verify_token_hash(str(code).strip(), rec["code_hash"]):
            if rec:
                db[collection].update_one({"_id": rec["_id"]}, {"$inc": {"attempts": 1}})
            return None
        return rec

    @staticmethod
    async def verify_signup(email: str, email_code: str, phone: str, phone_code: str, ip: str,
                            device_info: Optional[str] = None) -> Dict[str, Any]:
        """Verify the email code and the SMS code of a new account together."""
        ratelimit.hit(f"verify_signup:ip:{ip}", 30, 900)
        try:
            clean_email = normalize_email(email)
            clean_phone = normalize_phone(phone)
        except ValueError:
            raise BadRequestException("Invalid or expired verification code.")
        fail_key = f"verify_signup:fail:{clean_phone}"
        ratelimit.ensure_below(fail_key, settings.OTP_MAX_VERIFY_FAILURES_PER_HOUR,
                               "Too many incorrect codes. Please request new codes later.", 3600)

        db = _db()
        doc = db["users"].find_one({"email": clean_email, "phone": clean_phone})
        if not doc:
            ratelimit.hit(fail_key, 10_000, 3600)
            raise BadRequestException("Invalid or expired verification code.")

        email_rec = None if doc.get("is_email_verified") else AuthService._find_code(
            "email_verifications", "email", clean_email, email_code)
        phone_rec = None if doc.get("is_phone_verified") else AuthService._find_code(
            "otp_codes", "phone", clean_phone, phone_code)
        email_ok = bool(doc.get("is_email_verified")) or email_rec is not None
        phone_ok = bool(doc.get("is_phone_verified")) or phone_rec is not None
        if not (email_ok and phone_ok):
            ratelimit.hit(fail_key, 10_000, 3600)
            if not email_ok and not phone_ok:
                raise BadRequestException("Both codes are incorrect or expired.")
            raise BadRequestException("The email code is incorrect or expired." if not email_ok
                                      else "The mobile (SMS) code is incorrect or expired.")
        ratelimit.reset(fail_key)

        now = _now()
        if email_rec:
            db["email_verifications"].update_one({"_id": email_rec["_id"]}, {"$set": {"consumed_at": now}})
        if phone_rec:
            db["otp_codes"].update_one({"_id": phone_rec["_id"]}, {"$set": {"consumed_at": now}})
        db["users"].update_one({"_id": doc["_id"]}, {"$set": {
            "is_email_verified": True, "email_verified_at": doc.get("email_verified_at") or now,
            "is_phone_verified": True, "phone_verified_at": doc.get("phone_verified_at") or now,
            "updated_at": now,
        }})
        doc = db["users"].find_one({"_id": doc["_id"]})
        if str(doc.get("role")) != "client" or doc.get("approval_status") != "approved":
            return {
                "requires_approval": True,
                "message": "Email and mobile verified. You can sign in once an administrator approves your account.",
            }
        res = AuthService._issue_tokens(doc, device_info)
        res["message"] = "Email and mobile verified. Welcome to SolarPro!"
        return res

    # ── Password change ─────────────────────────────────────────────────────

    @staticmethod
    def change_password(user_id: str, current_password: Optional[str], new_password: str,
                        device_info: Optional[str] = None) -> Dict[str, Any]:
        """Change (or first set) the caller's password, then sign out every other session."""
        fail_key = f"change_pw:fail:{user_id}"
        ratelimit.ensure_below(fail_key, settings.LOGIN_MAX_FAILURES,
                               "Too many incorrect attempts. Please wait 15 minutes and try again.",
                               settings.LOGIN_FAILURE_WINDOW_SECONDS)
        doc = load_user(user_id)
        if not doc:
            raise UnauthorizedException("Session expired. Please sign in again.")
        existing_hash = doc.get("password_hash")
        if existing_hash:
            if not current_password or not verify_password(current_password, existing_hash):
                ratelimit.hit(fail_key, 10_000, settings.LOGIN_FAILURE_WINDOW_SECONDS)
                raise BadRequestException("Your current password is incorrect.")
            if verify_password(new_password, existing_hash):
                raise BadRequestException("The new password must be different from your current password.")
        try:
            validate_password_strength(new_password)
        except ValueError as e:
            raise BadRequestException(str(e))
        ratelimit.reset(fail_key)

        db = _db()
        now = _now()
        db["users"].update_one({"_id": doc["_id"]}, {
            "$set": {"password_hash": hash_password(new_password), "password_changed_at": now, "updated_at": now},
        })
        # Old access/refresh tokens (other devices) stop working; this device
        # gets a fresh session so the user stays signed in.
        AuthService.revoke_all_sessions(str(doc["_id"]))
        doc = db["users"].find_one({"_id": doc["_id"]})
        res = AuthService._issue_tokens(doc, device_info)
        res["message"] = "Password changed. Other devices have been signed out."
        return res

    @staticmethod
    async def verify_otp(phone: str, otp: str, ip: str, device_info: Optional[str] = None) -> Dict[str, Any]:
        ratelimit.hit(f"otp_check:ip:{ip}", 30, 900)
        try:
            clean_phone = normalize_phone(phone)
        except ValueError:
            raise BadRequestException("Invalid or expired code.")
        fail_key = f"otp:fail:{clean_phone}"
        ratelimit.ensure_below(fail_key, settings.OTP_MAX_VERIFY_FAILURES_PER_HOUR,
                               "Too many incorrect codes. Please try again in an hour.", 3600)

        db = _db()
        now = _now()
        rec = db["otp_codes"].find_one(
            {"phone": clean_phone, "consumed_at": None, "expires_at": {"$gt": now}},
            sort=[("created_at", -1)],
        )
        if not rec or rec.get("attempts", 0) >= 5 or not verify_token_hash(str(otp).strip(), rec["code_hash"]):
            if rec:
                db["otp_codes"].update_one({"_id": rec["_id"]}, {"$inc": {"attempts": 1}})
            ratelimit.hit(fail_key, 10_000, 3600)
            raise BadRequestException("Invalid or expired code.")
        db["otp_codes"].update_one({"_id": rec["_id"]}, {"$set": {"consumed_at": now}})
        ratelimit.reset(fail_key)

        doc = db["users"].find_one({"phone": clean_phone})
        if not doc:
            raise BadRequestException("Invalid or expired code.")
        # The SMS code proves ownership of this number.
        db["users"].update_one(
            {"_id": doc["_id"]},
            {"$set": {"is_phone_verified": True, "phone_verified_at": now, "updated_at": now}},
        )
        doc["is_phone_verified"] = True
        return AuthService._issue_tokens(doc, device_info)

    # ── Profile ─────────────────────────────────────────────────────────────

    @staticmethod
    def update_fcm_token(user_id: str, fcm_token: str) -> None:
        _db()["users"].update_one({"_id": user_id}, {"$set": {"fcm_token": fcm_token[:255], "updated_at": _now()}})
