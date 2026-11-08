"""POST /api/jwt-auth/refresh/ - what the web and mobile clients rely on when the access token expires."""

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

User = get_user_model()
LOGIN = "/api/jwt-auth/login/"
REFRESH = "/api/jwt-auth/refresh/"
LOGOUT = "/api/jwt-auth/logout/"
ME = "/api/jwt-auth/me/"


class TokenRefreshTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        User.objects.create_user(
            username="r@example.com", email="r@example.com",
            password="pw-123456", full_name="Refresh User",
        )
        login = self.client.post(LOGIN, {"email": "r@example.com", "password": "pw-123456"}, format="json")
        self.assertEqual(login.status_code, 200, login.content)
        self.access = login.json()["access"]
        self.refresh = login.json()["refresh"]

    def test_valid_refresh_gives_a_working_access_token(self):
        response = self.client.post(REFRESH, {"refresh": self.refresh}, format="json")
        self.assertEqual(response.status_code, 200)
        new_access = response.json()["access"]
        self.assertTrue(new_access)

        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {new_access}")
        me = client.get(ME)
        self.assertEqual(me.status_code, 200)
        self.assertEqual(me.json()["email"], "r@example.com")

    def test_garbage_refresh_is_rejected(self):
        response = self.client.post(REFRESH, {"refresh": "not-a-token"}, format="json")
        self.assertEqual(response.status_code, 401)

    def test_missing_refresh_is_rejected(self):
        response = self.client.post(REFRESH, {}, format="json")
        self.assertEqual(response.status_code, 400)

    def test_access_token_is_not_accepted_as_refresh(self):
        response = self.client.post(REFRESH, {"refresh": self.access}, format="json")
        self.assertEqual(response.status_code, 401)

    def test_logged_out_refresh_token_stops_working(self):
        authed = APIClient()
        authed.credentials(HTTP_AUTHORIZATION=f"Bearer {self.access}")
        self.assertEqual(authed.post(LOGOUT, {"refresh": self.refresh}, format="json").status_code, 200)

        response = self.client.post(REFRESH, {"refresh": self.refresh}, format="json")
        self.assertEqual(response.status_code, 401)

    def test_refresh_does_not_need_an_access_token(self):
        # The client calls this exactly when its access token has expired.
        response = APIClient().post(REFRESH, {"refresh": self.refresh}, format="json")
        self.assertEqual(response.status_code, 200)
