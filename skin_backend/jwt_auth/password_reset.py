"""
password_reset.py

Safe password reset: a signed, expiring, single-use token is emailed to the
account owner. Nobody can reset a password just by knowing the email.

Shared by jwt_auth (used by web/mobile) and the legacy accounts app.
"""

import logging

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.contrib.auth.tokens import default_token_generator
from django.core.exceptions import ValidationError
from django.core.mail import send_mail
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode

logger = logging.getLogger(__name__)

User = get_user_model()

# Same answer whether or not the email exists, so the endpoint can't be used
# to find out which emails are registered.
GENERIC_REQUEST_MESSAGE = (
    "If an account with this email exists, a password reset link has been sent."
)


def send_reset_email(email: str) -> None:
    """Emails a reset link if (and only if) an active user has this email."""
    user = User.objects.filter(email__iexact=email, is_active=True).first()
    if user is None:
        return

    uid = urlsafe_base64_encode(force_bytes(user.pk))
    token = default_token_generator.make_token(user)
    link = f"{settings.FRONTEND_URL.rstrip('/')}/reset-password?uid={uid}&token={token}"
    hours = max(1, settings.PASSWORD_RESET_TIMEOUT // 3600)

    subject = "DermaScanAI - reset your password / Ресетирај лозинка"
    body = (
        f"Hello,\n\n"
        f"Use the link below to choose a new password. It works once and expires in {hours} hour(s).\n"
        f"{link}\n\n"
        f"If you did not ask for this, ignore this email.\n\n"
        f"---\n\n"
        f"Здраво,\n\n"
        f"Користи ја врската подолу за да избереш нова лозинка. Важи еднаш и истекува за {hours} час(а).\n"
        f"{link}\n\n"
        f"Ако не си го побарал ова, игнорирај ја пораката.\n"
    )

    try:
        send_mail(subject, body, settings.DEFAULT_FROM_EMAIL, [user.email])
    except Exception:
        # Never reveal delivery problems to the caller (same generic answer).
        logger.exception("Could not send password reset email")


def confirm_reset(uid: str, token: str, new_password: str):
    """
    Returns (user, None) on success or (None, error_message).
    """
    try:
        user_id = force_str(urlsafe_base64_decode(uid))
        user = User.objects.get(pk=user_id, is_active=True)
    except (TypeError, ValueError, OverflowError, User.DoesNotExist):
        return None, "Invalid or expired reset link."

    if not default_token_generator.check_token(user, token):
        return None, "Invalid or expired reset link."

    try:
        validate_password(new_password, user)
    except ValidationError as error:
        return None, " ".join(error.messages)

    user.set_password(new_password)
    user.save()
    return user, None
