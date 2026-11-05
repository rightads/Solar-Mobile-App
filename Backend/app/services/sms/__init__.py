from app.core.config import settings
from app.services.sms.base import BaseSmsProvider
from app.services.sms.console import ConsoleSmsProvider
from app.services.sms.msg91 import Msg91SmsProvider


def get_sms_provider() -> BaseSmsProvider:
    if getattr(settings, "MSG91_AUTH_KEY", "") or getattr(settings, "FAST2SMS_API_KEY", ""):
        return Msg91SmsProvider()
    if settings.ENV == "dev" or settings.ENV == "test":
        return ConsoleSmsProvider()
    return Msg91SmsProvider()


__all__ = [
    "BaseSmsProvider",
    "ConsoleSmsProvider",
    "Msg91SmsProvider",
    "get_sms_provider",
]
