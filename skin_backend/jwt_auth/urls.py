from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .views import (
    JwtRegisterView,
    JwtLoginView,
    JwtLogoutView,
    JwtMeView,
    JwtChangePasswordView,
    JwtResetPasswordRequestView,
    JwtResetPasswordConfirmView,
)

urlpatterns = [
    path("register/", JwtRegisterView.as_view(), name="jwt_register"),
    path("login/", JwtLoginView.as_view(), name="jwt_login"),
    path("refresh/", TokenRefreshView.as_view(), name="jwt_refresh"),
    path("logout/", JwtLogoutView.as_view(), name="jwt_logout"),
    path("me/", JwtMeView.as_view(), name="jwt_me"),
    path("change-password/", JwtChangePasswordView.as_view(), name="jwt_change_password"),
    path("reset-password/request/", JwtResetPasswordRequestView.as_view(), name="jwt_reset_password_request"),
    path("reset-password/confirm/", JwtResetPasswordConfirmView.as_view(), name="jwt_reset_password_confirm"),
]
