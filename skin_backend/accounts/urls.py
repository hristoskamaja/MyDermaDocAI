from django.urls import path

from . import views

urlpatterns = [
    path("register/", views.register, name="register"),
    path("login/", views.login, name="login"),
    path("logout/", views.logout_user, name="logout"),
    path("me/", views.me, name="me"),
    path("change-password/", views.change_password, name="change_password"),
    path("reset-password/", views.reset_password, name="reset_password"),
    path("reset-password/confirm/", views.reset_password_confirm, name="reset_password_confirm"),
]
