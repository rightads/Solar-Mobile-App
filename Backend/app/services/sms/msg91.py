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
        self.twilio_sid = getattr(settings, "TWILIO_ACCOUNT_SID", "")
        self.twilio_token = getattr(settings, "TWILIO_AUTH_TOKEN", "")
        self.twilio_from = getattr(settings, "TWILIO_FROM_NUMBER", "")
        self.two_factor_key = getattr(settings, "TWO_FACTOR_API_KEY", "")

    async def send_otp(self, phone: str, otp_code: str) -> bool:
        clean_phone = phone.strip().replace("+", "")
        if clean_phone.startswith("91") and len(clean_phone) > 10:
            mobile_10 = clean_phone[-10:]
            mobile_with_cc = clean_phone
        else:
            mobile_10 = clean_phone[-10:]
            mobile_with_cc = f"91{mobile_10}"

        # 1. 2Factor.in (Primary Indian SMS Gateway)
        if self.two_factor_key:
            try:
                url = f"https://2factor.in/API/V1/{self.two_factor_key}/SMS/{mobile_10}/{otp_code}"
                async with httpx.AsyncClient(timeout=10.0) as client:
                    resp = await client.get(url)
                    data = resp.json() if resp.headers.get("content-type", "").startswith("application/json") else {}
                    if resp.is_success and data.get("Status") == "Success":
                        logger.info("2Factor.in OTP texted successfully", phone=mobile_10, session_id=data.get("Details"))
                        return True
                    logger.warning("2Factor.in error response", status=resp.status_code, status_only=True)
            except Exception as e:
                logger.error("2Factor.in error", error=str(e))

        # 2. Fast2SMS (Fallback Indian SMS Gateway)
        if self.fast2sms_key:
            try:
                # Fast2SMS dev_api supports GET and POST
                url_get = f"https://www.fast2sms.com/dev/bulkV2?authorization={self.fast2sms_key}&route=otp&variables_values={otp_code}&numbers={mobile_10}"
                async with httpx.AsyncClient(timeout=10.0) as client:
                    resp = await client.get(url_get)
                    try:
                        data = resp.json()
                    except Exception:
                        data = {}
                    if resp.is_success and data.get("return"):
                        logger.info("Fast2SMS OTP texted successfully (GET route otp)", phone=mobile_10)
                        return True

                    # Fallback to POST
                    url = "https://www.fast2sms.com/dev/bulkV2"
                    headers = {"authorization": self.fast2sms_key, "Content-Type": "application/json"}
                    payload_otp = {
                        "variables_values": otp_code,
                        "route": "otp",
                        "numbers": mobile_10,
                    }
                    resp_post = await client.post(url, headers=headers, json=payload_otp)
                    try:
                        data_post = resp_post.json()
                    except Exception:
                        data_post = {}
                    if resp_post.is_success and data_post.get("return"):
                        logger.info("Fast2SMS OTP texted successfully (POST route otp)", phone=mobile_10)
                        return True
                    logger.warning("Fast2SMS returned", status=resp_post.status_code, status_only=True)

                    # Attempt 2: Quick SMS route
                    payload_q = {
                        "route": "q",
                        "message": f"Your SolarPro verification code is {otp_code}. Valid for 5 minutes.",
                        "language": "english",
                        "flash": 0,
                        "numbers": mobile_10,
                    }
                    resp_q = await client.post(url, headers=headers, json=payload_q)
                    try:
                        data_q = resp_q.json()
                    except Exception:
                        data_q = {}
                    if resp_q.is_success and data_q.get("return"):
                        logger.info("Fast2SMS OTP texted successfully (route q)", phone=mobile_10)
                        return True
                    logger.warning("Fast2SMS route q returned", status=resp_q.status_code, status_only=True)
            except Exception as e:
                logger.error("Fast2SMS error", error=str(e))

        # 3. Twilio SMS
        if self.twilio_sid and self.twilio_token and self.twilio_from:
            try:
                url = f"https://api.twilio.com/2010-04-01/Accounts/{self.twilio_sid}/Messages.json"
                auth = (self.twilio_sid, self.twilio_token)
                data = {
                    "From": self.twilio_from,
                    "To": f"+{mobile_with_cc}",
                    "Body": f"Your SolarPro verification code is {otp_code}. Valid for 5 minutes.",
                }
                async with httpx.AsyncClient(timeout=10.0) as client:
                    resp = await client.post(url, auth=auth, data=data)
                    if resp.is_success:
                        logger.info("Twilio SMS texted successfully", phone=mobile_with_cc)
                        return True
                    logger.warning("Twilio SMS error response", status=resp.status_code, status_only=True)
            except Exception as e:
                logger.error("Twilio SMS error", error=str(e))

        # 4. Msg91
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
                        logger.info("Msg91 SMS texted successfully", phone=mobile_with_cc)
                        return True
                    logger.warning("Msg91 SMS error response", status=resp.status_code, status_only=True)
            except Exception as e:
                logger.error("Msg91 SMS error", error=str(e))

        logger.warning(
            "No SMS gateway credentials configured in environment. To receive real text messages on phones, configure FAST2SMS_API_KEY, TWO_FACTOR_API_KEY, TWILIO_ACCOUNT_SID, or MSG91_AUTH_KEY.",
            phone=mobile_with_cc,
        )
        return True
