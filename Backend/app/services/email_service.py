import asyncio
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import smtplib
from typing import Optional
import structlog
from app.core.config import settings

logger = structlog.get_logger()


class EmailService:
    """Enterprise email delivery service with SMTP integration and resilient dev fallback."""

    @staticmethod
    def _render_verification_html(code: str, user_name: str) -> str:
        import html as _html
        user_name = _html.escape(str(user_name or "there"))
        code = _html.escape(str(code))
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>SolarPro Email Verification</title>
        </head>
        <body style="margin: 0; padding: 0; background-color: #0b1120; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #f8fafc;">
          <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #0b1120; padding: 40px 20px;">
            <tr>
              <td align="center">
                <table width="100%" max-width="540" style="max-width: 540px; background-color: #111d33; border: 1px solid #1e293b; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.5);">
                  <!-- Header -->
                  <tr>
                    <td style="padding: 32px 32px 20px; background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%); text-align: center; border-bottom: 1px solid #334155;">
                      <div style="display: inline-block; width: 44px; height: 44px; line-height: 44px; background: linear-gradient(135deg, #f59e0b, #d97706); border-radius: 12px; font-weight: bold; font-size: 24px; color: #0b1120;">☀️</div>
                      <h1 style="margin: 12px 0 0; font-size: 22px; font-weight: 800; color: #ffffff; letter-spacing: -0.5px;">SolarPro Portal</h1>
                      <p style="margin: 4px 0 0; font-size: 13px; color: #94a3b8; font-weight: 500;">Client Security & Email Verification</p>
                    </td>
                  </tr>

                  <!-- Content Body -->
                  <tr>
                    <td style="padding: 32px;">
                      <p style="margin: 0 0 16px; font-size: 16px; color: #e2e8f0;">Hello <strong style="color: #fbbf24;">{user_name}</strong>,</p>
                      <p style="margin: 0 0 24px; font-size: 14px; line-height: 1.6; color: #94a3b8;">
                        Thank you for registering with SolarPro. To protect your solar rooftop investments and activate your client dashboard, please enter the following 6-digit verification code:
                      </p>

                      <!-- OTP Box -->
                      <div style="background-color: #0b1329; border: 1.5px dashed #f59e0b; border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0;">
                        <span style="font-family: monospace; font-size: 34px; font-weight: 800; letter-spacing: 8px; color: #f59e0b; text-shadow: 0 0 12px rgba(245, 158, 11, 0.3);">
                          {code}
                        </span>
                        <div style="margin-top: 8px; font-size: 12px; color: #64748b;">
                          Valid for 10 minutes &bull; Do not share with anyone
                        </div>
                      </div>

                      <p style="margin: 24px 0 0; font-size: 13px; line-height: 1.5; color: #64748b;">
                        If you did not request this verification code, please ignore this email or contact our support team.
                      </p>
                    </td>
                  </tr>

                  <!-- Footer -->
                  <tr>
                    <td style="padding: 20px 32px; background-color: #0b1120; border-top: 1px solid #1e293b; text-align: center;">
                      <p style="margin: 0; font-size: 12px; color: #475569;">
                        &copy; 2026 SolarPro Technologies Inc. All rights reserved.
                      </p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </body>
        </html>
        """

    @classmethod
    def _send_smtp_sync(
        cls,
        to_email: str,
        subject: str,
        body_text: str,
        body_html: Optional[str] = None,
    ) -> bool:
        """Synchronous SMTP worker executed within an async worker thread."""
        sender_email = settings.EMAILS_FROM_EMAIL or "noreply@solarpro.com"
        sender_name = settings.EMAILS_FROM_NAME or "SolarPro Support"

        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = f"{sender_name} <{sender_email}>"
        msg["To"] = to_email

        # Attach text and HTML parts
        msg.attach(MIMEText(body_text, "plain", "utf-8"))
        if body_html:
            msg.attach(MIMEText(body_html, "html", "utf-8"))

        # If SMTP server host is configured, attempt real network delivery
        if settings.SMTP_HOST and settings.SMTP_USER and settings.SMTP_PASSWORD:
            smtp_user = settings.SMTP_USER
            smtp_pass = settings.SMTP_PASSWORD

            # Attempt 1: Port 587 STARTTLS
            try:
                server = smtplib.SMTP(settings.SMTP_HOST, 587, timeout=10)
                server.ehlo()
                server.starttls()
                server.ehlo()
                server.login(smtp_user, smtp_pass)
                server.sendmail(sender_email, [to_email], msg.as_string())
                server.quit()
                logger.info("Email successfully sent via SMTP (port 587 TLS)", to=to_email, subject=subject)
                return True
            except Exception as e587:
                logger.warning("SMTP port 587 attempt failed, trying port 465 SSL", error=str(e587), to=to_email)

            # Attempt 2: Port 465 SSL
            try:
                server = smtplib.SMTP_SSL(settings.SMTP_HOST, 465, timeout=10)
                server.ehlo()
                server.login(smtp_user, smtp_pass)
                server.sendmail(sender_email, [to_email], msg.as_string())
                server.quit()
                logger.info("Email successfully sent via SMTP (port 465 SSL)", to=to_email, subject=subject)
                return True
            except Exception as e465:
                logger.error("SMTP port 465 attempt also failed", error=str(e465), to=to_email)
                return False

        return False

    @classmethod
    async def _send_resend(
        cls,
        to_email: str,
        subject: str,
        body_html: str,
    ) -> bool:
        """Deliver transactional email using Resend HTTP API (bypasses cloud SMTP port blocks)."""
        import httpx
        url = "https://api.resend.com/emails"
        headers = {
            "Authorization": f"Bearer {settings.RESEND_API_KEY}",
            "Content-Type": "application/json",
            "User-Agent": "SolarPro-Backend/1.0",
        }
        from_email = settings.RESEND_FROM_EMAIL or "SolarPro <onboarding@resend.dev>"
        payload = {
            "from": from_email,
            "to": [to_email],
            "subject": subject,
            "html": body_html,
        }
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(url, headers=headers, json=payload)
                if resp.status_code in (200, 201):
                    logger.info("Email delivered via Resend HTTP API", to=to_email, resend_id=resp.json().get("id"))
                    return True
                else:
                    logger.error("Resend API rejected email dispatch", status_code=resp.status_code, status_only=True)
                    return False
        except Exception as e:
            logger.error("Failed to connect to Resend HTTP API", error=str(e))
            return False

    @classmethod
    async def send_verification_email(
        cls,
        to_email: str,
        code: str,
        user_name: str = "Client",
    ) -> bool:
        """
        Send a 6-digit email verification code to the client.
        Prioritizes Resend HTTP API (fast & immune to SMTP port blocks), with SMTP fallback.
        """
        subject = f"SolarPro Verification Code: {code}"
        body_text = (
            f"Hello {user_name},\n\n"
            f"Your SolarPro client verification code is: {code}\n"
            f"This code will expire in 10 minutes.\n\n"
            f"Thank you,\nSolarPro Support"
        )
        body_html = cls._render_verification_html(code, user_name)

        logger.info(
            "email_verification_dispatch",
            to_email=to_email,
            recipient=user_name,
            code="******",
            expires_in="10 minutes",
            resend_configured=bool(settings.RESEND_API_KEY),
            smtp_configured=bool(settings.SMTP_HOST and settings.SMTP_USER),
        )

        # 1. Primary: SMTP delivery (sends real email directly to recipient inbox via SMTP)
        if settings.SMTP_HOST and settings.SMTP_USER and settings.SMTP_PASSWORD:
            try:
                smtp_ok = await asyncio.to_thread(
                    cls._send_smtp_sync,
                    to_email,
                    subject,
                    body_text,
                    body_html,
                )
                if smtp_ok:
                    logger.info("Email verification dispatched successfully via SMTP", to=to_email)
                    return True
            except Exception as e:
                logger.error("Async SMTP dispatch error", error=str(e), to=to_email)

        # 2. Secondary fallback: Resend HTTP API
        if settings.RESEND_API_KEY:
            try:
                resend_ok = await cls._send_resend(to_email, subject, body_html)
                if resend_ok:
                    logger.info("Email verification dispatched via Resend HTTP API", to=to_email)
                    return True
            except Exception as e:
                logger.warning("Resend fallback dispatch failed", error=str(e), to=to_email)

        logger.error("All email delivery providers failed or are not configured", to=to_email)
        return False

    @classmethod
    async def _deliver(cls, to_email: str, subject: str, body_text: str, body_html: str) -> bool:
        """Send through SMTP first, then Resend. Returns False when nothing worked."""
        if settings.SMTP_HOST and settings.SMTP_USER and settings.SMTP_PASSWORD:
            try:
                if await asyncio.to_thread(cls._send_smtp_sync, to_email, subject, body_text, body_html):
                    return True
            except Exception as e:
                logger.error("Async SMTP dispatch error", error=str(e), to=to_email)
        if settings.RESEND_API_KEY:
            try:
                if await cls._send_resend(to_email, subject, body_html):
                    return True
            except Exception as e:
                logger.warning("Resend fallback dispatch failed", error=str(e), to=to_email)
        logger.error("All email delivery providers failed or are not configured", to=to_email)
        return False

    @staticmethod
    def _render_password_reset_html(user_name: str, link: str, code: str, minutes: int) -> str:
        import html as _html
        user_name = _html.escape(str(user_name or "there"))
        link = _html.escape(link, quote=True)
        code = _html.escape(str(code))
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Reset your SolarPro password</title>
        </head>
        <body style="margin:0;padding:0;background-color:#0b1120;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#f8fafc;">
          <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color:#0b1120;padding:40px 20px;">
            <tr>
              <td align="center">
                <table width="100%" style="max-width:540px;background-color:#111d33;border:1px solid #1e293b;border-radius:16px;overflow:hidden;">
                  <tr>
                    <td style="padding:32px 32px 20px;text-align:center;border-bottom:1px solid #334155;">
                      <div style="display:inline-block;width:44px;height:44px;line-height:44px;background:#f59e0b;border-radius:12px;font-size:24px;">&#9728;&#65039;</div>
                      <h1 style="margin:12px 0 0;font-size:22px;font-weight:800;color:#ffffff;">Reset your password</h1>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:32px;">
                      <p style="margin:0 0 16px;font-size:16px;color:#e2e8f0;">Hello <strong style="color:#fbbf24;">{user_name}</strong>,</p>
                      <p style="margin:0 0 24px;font-size:14px;line-height:1.6;color:#94a3b8;">
                        We received a request to reset your SolarPro password. Tap the button on the phone that has the SolarPro app to choose a new password.
                      </p>
                      <p style="text-align:center;margin:0 0 28px;">
                        <a href="{link}" style="display:inline-block;background:#f59e0b;color:#0b1120;text-decoration:none;font-weight:800;font-size:16px;padding:14px 28px;border-radius:10px;">Reset Password</a>
                      </p>
                      <p style="margin:0 0 8px;font-size:14px;line-height:1.6;color:#94a3b8;">
                        Using SolarPro on a computer, or the button does not open the app? In the app choose
                        <strong style="color:#e2e8f0;">Forgot password &rarr; I have a code</strong> and enter:
                      </p>
                      <div style="background-color:#0b1329;border:1.5px dashed #f59e0b;border-radius:12px;padding:20px;text-align:center;margin:16px 0;">
                        <span style="font-family:monospace;font-size:32px;font-weight:800;letter-spacing:8px;color:#f59e0b;">{code}</span>
                      </div>
                      <p style="margin:0 0 8px;font-size:12px;color:#64748b;">The link and the code work once and expire in {minutes} minutes. Never share them with anyone.</p>
                      <p style="margin:16px 0 0;font-size:13px;line-height:1.5;color:#64748b;">
                        If you did not ask to reset your password, you can ignore this email &mdash; your password stays the same.
                      </p>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:20px 32px;background-color:#0b1120;border-top:1px solid #1e293b;text-align:center;">
                      <p style="margin:0;font-size:12px;color:#475569;">&copy; 2026 SolarPro Technologies Inc. All rights reserved.</p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </body>
        </html>
        """

    @classmethod
    async def send_password_reset_email(cls, to_email: str, link: str, code: str,
                                        user_name: str = "", minutes: int = 30) -> bool:
        """Email a one-time password reset link plus a 6-digit fallback code."""
        subject = "Reset your SolarPro password"
        body_text = (
            f"Hello {user_name or 'there'},\n\n"
            f"Open this link on the phone that has the SolarPro app to choose a new password:\n{link}\n\n"
            f"On a computer, or if the link does not open the app, choose "
            f"'Forgot password -> I have a code' in the app and enter: {code}\n\n"
            f"The link and code work once and expire in {minutes} minutes.\n"
            f"If you did not ask for this, ignore this email; your password stays the same.\n\n"
            f"SolarPro Support"
        )
        body_html = cls._render_password_reset_html(user_name, link, code, minutes)
        logger.info("password_reset_email_dispatch", to_email=to_email, code="******")
        return await cls._deliver(to_email, subject, body_text, body_html)


email_service = EmailService()
