import httpx
import structlog
from app.core.config import settings
from app.services.sms.base import BaseSmsProvider

logger = structlog.get_logger()


class Msg91SmsProvider(BaseSmsProvider):
    def __init__(self, auth_key: str = "", template_id: str = ""):
        self.auth_key = auth_key or getattr(settings, "MSG91_AUTH_KEY", "")
        self.template_id = template_id or getattr(settings, "MSG91_TEMPLATE_ID", "")
        self.fast2sms_key = getattr(settings, "FAST2SMS_API_KEY", "")

    async def send_otp(self, phone: str, otp_code: str) -> bool:
        clean_phone = phone.strip().replace("+", "")
        if clean_phone.startswith("91") and len(clean_phone) > 10:
            mobile_10 = clean_phone[-10:]
            mobile_with_cc = clean_phone
        else:
            mobile_10 = clean_phone[-10:]
            mobile_with_cc = f"91{mobile_10}"

        # 1. Try Msg91 if credentials are configured
        if self.auth_key:
            try:
                url = "https://control.msg91.com/api/v5/otp"
                params = {
                    "template_id": self.template_id,
                    "mobile": mobile_with_cc,
                    "authkey": self.auth_key,
                    "otp": otp_code,
                }
                async with httpx.AsyncClient(timeout=10.0) as client:
                    resp = await client.post(url, params=params)
                    if resp.is_success:
                        logger.info("Msg91 SMS sent successfully", phone=mobile_with_cc)
                        return True
                    logger.warning("Msg91 SMS dispatch returned error status", status=resp.status_code, body=resp.text)
            except Exception as e:
                logger.error("Msg91 SMS dispatch exception", error=str(e))

        # 2. Try Fast2SMS if configured
        if self.fast2sms_key:
            try:
                url = "https://www.fast2sms.com/dev/bulkV2"
                headers = {"authorization": self.fast2sms_key}
                payload = {
                    "variables_values": otp_code,
                    "route": "otp",
                    "numbers": mobile_10,
                }
                async with httpx.AsyncClient(timeout=10.0) as client:
                    resp = await client.post(url, headers=headers, json=payload)
                    if resp.is_success:
                        logger.info("Fast2SMS OTP sent successfully", phone=mobile_10)
                        return True
                    logger.warning("Fast2SMS returned error status", status=resp.status_code, body=resp.text)
            except Exception as e:
                logger.error("Fast2SMS dispatch exception", error=str(e))

        logger.info("[SMS Mock] OTP generated", phone=mobile_with_cc, otp=otp_code)
        return True
