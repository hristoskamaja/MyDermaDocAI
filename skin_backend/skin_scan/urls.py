"""
Project-level urls.py - same as leafscan/leafscan/urls.py.

/api/auth/        -> accounts.urls      (token-based login/register, used by React admin)
/api/jwt-auth/     -> jwt_auth.urls     (JWT access/refresh, used by the Flutter app)
/api/users/        -> accounts.user_urls (admin user management)
/api/              -> core.urls        (SkinCondition/Recommendation CRUD for the admin panel)
/api/analyses/     -> analyses.urls    (scan-skin + analysis history)
/api/              -> analytics.urls   (dashboard/statistics for the React admin panel)
/api/tracking/     -> tracking.urls    (private per-user skin tracker)
"""

from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path("admin/", admin.site.urls),

    path("api/auth/", include("accounts.urls")),
    path("api/users/", include("accounts.user_urls")),

    path("api/jwt-auth/", include("jwt_auth.urls")),

    path("api/", include("core.urls")),

    path("api/analyses/", include("analyses.urls")),

    path("api/", include("analytics.urls")),

    path("api/tracking/", include("tracking.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
