from fastapi import APIRouter, Depends, Request, status
from app.core.deps import MongoUserProxy, get_current_user
from app.core.ratelimit import client_ip
from app.schemas.auth import (
    EmailVerificationResponse,
    FcmTokenUpdate,
    LogoutRequest,
    OtpRequest,
    OtpRequestResponse,
    OtpVerify,
    PasswordLoginRequest,
    RefreshTokenRequest,
    SendEmailVerificationRequest,
    UserRegisterRequest,
    VerifyEmailRequest,
)
from app.services.auth_service import AuthService, GENERIC_EMAIL_SENT

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/login", status_code=status.HTTP_200_OK, summary="Sign in with email/mobile and password")
async def login_with_password(payload: PasswordLoginRequest, request: Request):
    return await AuthService.login_with_password(
        identifier=payload.identifier,
        password=payload.password,
        ip=client_ip(request),
        device_info=payload.device_info,
    )


@router.post("/register", status_code=status.HTTP_201_CREATED, summary="Create a client account or request a staff account")
async def register_user(payload: UserRegisterRequest, request: Request):
    return await AuthService.register_user(
        name=payload.name,
        phone=payload.phone,
        password=payload.password,
        role=payload.role,
        email=payload.email,
        ip=client_ip(request),
    )


@router.post(
    "/send-verification-email",
    response_model=EmailVerificationResponse,
    summary="Send a 6-digit email verification code",
)
async def send_verification_email(payload: SendEmailVerificationRequest, request: Request):
    await AuthService.send_email_verification(email=payload.email, ip=client_ip(request))
    return EmailVerificationResponse(message=GENERIC_EMAIL_SENT, email=payload.email)


@router.post("/verify-email", summary="Verify email with the 6-digit code")
async def verify_email(payload: VerifyEmailRequest, request: Request):
    return await AuthService.verify_email(email=payload.email, code=payload.code, ip=client_ip(request))


@router.post("/request-otp", response_model=OtpRequestResponse, summary="Request a 6-digit sign-in code by SMS")
async def request_otp(payload: OtpRequest, request: Request):
    return OtpRequestResponse(**await AuthService.request_otp(phone=payload.phone, ip=client_ip(request)))


@router.post("/verify-otp", summary="Verify the SMS code and start a session")
async def verify_otp(payload: OtpVerify, request: Request):
    return await AuthService.verify_otp(
        phone=payload.phone,
        otp=payload.otp,
        ip=client_ip(request),
        device_info=payload.device_info,
    )


@router.post("/refresh", summary="Rotate the refresh token and get a new access token")
async def refresh_token(payload: RefreshTokenRequest, request: Request):
    return AuthService.refresh(payload.refresh_token, ip=client_ip(request))


@router.post("/logout", summary="Revoke the current refresh token")
async def logout(payload: LogoutRequest):
    AuthService.logout(payload.refresh_token or "")
    return {"message": "Logged out successfully."}


@router.post("/logout-all", summary="Sign out of every device")
async def logout_all(current_user: MongoUserProxy = Depends(get_current_user)):
    AuthService.revoke_all_sessions(current_user.id)
    return {"message": "Signed out of all devices."}


@router.get("/me", summary="Current user profile")
async def get_me(current_user: MongoUserProxy = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "name": current_user.name,
        "phone": current_user.phone,
        "email": current_user.email,
        "role": getattr(current_user.role, "value", str(current_user.role)),
        "is_active": current_user.is_active,
        "is_phone_verified": current_user.is_phone_verified,
        "is_email_verified": current_user.is_email_verified,
        "employee_no": current_user.employee_no,
        "team": current_user.team,
        "trade": current_user.trade,
    }


@router.put("/me/fcm-token", summary="Register this device for push notifications")
async def update_fcm_token(payload: FcmTokenUpdate, current_user: MongoUserProxy = Depends(get_current_user)):
    AuthService.update_fcm_token(current_user.id, payload.fcm_token)
    return {"message": "Device registered."}
