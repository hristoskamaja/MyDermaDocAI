"""
Password reset: signed, expiring, single-use token sent by email. Knowing
an email address must NOT be enough to change someone's password.
"""

import re
from unittest import mock

from django.contrib.auth import get_user_model
from django.core import mail
from django.test import TestCase
from rest_framework.test import APIClient

User = get_user_model()

REQUEST_URL = "/api/jwt-auth/reset-password/request/"
CONFIRM_URL = "/api/jwt-auth/reset-password/confirm/"


class PasswordResetTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username="a@example.com", email="a@example.com",
            password="old-password-1", full_name="Test User",
        )

    def extract_uid_and_token(self):
        body = mail.outbox[0].body
        match = re.search(r"uid=([^&\s]+)&token=([^\s]+)", body)
        self.assertIsNotNone(match, body)
        return match.group(1), match.group(2)

    def test_old_open_endpoint_is_gone(self):
        response = self.client.post(
            "/api/jwt-auth/reset-password/",
            {"email": "a@example.com", "new_password": "hacked-password"},
            format="json",
        )
        self.assertEqual(response.status_code, 404)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("old-password-1"))

    def test_request_sends_email_with_link(self):
        response = self.client.post(REQUEST_URL, {"email": "a@example.com"}, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(mail.outbox[0].to, ["a@example.com"])
        self.assertIn("/reset-password?uid=", mail.outbox[0].body)

    def test_request_answers_the_same_for_unknown_email(self):
        known = self.client.post(REQUEST_URL, {"email": "a@example.com"}, format="json")
        unknown = self.client.post(REQUEST_URL, {"email": "nobody@example.com"}, format="json")
        self.assertEqual(unknown.status_code, 200)
        self.assertEqual(known.json(), unknown.json())
        self.assertEqual(len(mail.outbox), 1)  # only the known one got mail

    def test_email_failure_is_not_revealed(self):
        with mock.patch("jwt_auth.password_reset.send_mail", side_effect=OSError("smtp down")):
            response = self.client.post(REQUEST_URL, {"email": "a@example.com"}, format="json")
        self.assertEqual(response.status_code, 200)

    def test_confirm_with_valid_token_changes_password(self):
        self.client.post(REQUEST_URL, {"email": "a@example.com"}, format="json")
        uid, token = self.extract_uid_and_token()

        response = self.client.post(
            CONFIRM_URL, {"uid": uid, "token": token, "new_password": "brand-new-pass-9"},
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("brand-new-pass-9"))

    def test_token_is_single_use(self):
        self.client.post(REQUEST_URL, {"email": "a@example.com"}, format="json")
        uid, token = self.extract_uid_and_token()
        payload = {"uid": uid, "token": token, "new_password": "brand-new-pass-9"}

        self.assertEqual(self.client.post(CONFIRM_URL, payload, format="json").status_code, 200)
        payload["new_password"] = "another-pass-77"
        self.assertEqual(self.client.post(CONFIRM_URL, payload, format="json").status_code, 400)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("brand-new-pass-9"))

    def test_wrong_token_or_uid_is_rejected(self):
        self.client.post(REQUEST_URL, {"email": "a@example.com"}, format="json")
        uid, token = self.extract_uid_and_token()

        bad_token = self.client.post(
            CONFIRM_URL, {"uid": uid, "token": "bad-token", "new_password": "brand-new-pass-9"},
            format="json",
        )
        bad_uid = self.client.post(
            CONFIRM_URL, {"uid": "zzzz", "token": token, "new_password": "brand-new-pass-9"},
            format="json",
        )
        self.assertEqual(bad_token.status_code, 400)
        self.assertEqual(bad_uid.status_code, 400)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("old-password-1"))

    def test_expired_token_is_rejected(self):
        self.client.post(REQUEST_URL, {"email": "a@example.com"}, format="json")
        uid, token = self.extract_uid_and_token()

        with self.settings(PASSWORD_RESET_TIMEOUT=-1):
            response = self.client.post(
                CONFIRM_URL, {"uid": uid, "token": token, "new_password": "brand-new-pass-9"},
                format="json",
            )
        self.assertEqual(response.status_code, 400)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("old-password-1"))

    def test_weak_password_is_rejected(self):
        self.client.post(REQUEST_URL, {"email": "a@example.com"}, format="json")
        uid, token = self.extract_uid_and_token()

        response = self.client.post(
            CONFIRM_URL, {"uid": uid, "token": token, "new_password": "12345678"},
            format="json",
        )
        self.assertEqual(response.status_code, 400)

    def test_legacy_accounts_endpoint_is_also_safe(self):
        response = self.client.post(
            "/api/auth/reset-password/",
            {"email": "a@example.com", "new_password": "hacked-password"},
            format="json",
        )
        # It only sends the email now; the extra field is ignored.
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("old-password-1"))

        uid, token = self.extract_uid_and_token()
        confirm = self.client.post(
            "/api/auth/reset-password/confirm/",
            {"uid": uid, "token": token, "new_password": "brand-new-pass-9"},
            format="json",
        )
        self.assertEqual(confirm.status_code, 200)
