"""
Django settings for skin_scan project.

Same structure as leafscan/leafscan/settings.py, with two deliberate differences:

1. The database defaults to SQLite (zero setup - works immediately in PyCharm).
   If you want PostgreSQL (like in leafscan), set DB_ENGINE=postgres in .env
   - see the DATABASES section below.
2. There's also an "analytics" app (dashboard/statistics for the React admin panel).
"""

import os
from pathlib import Path
from datetime import timedelta

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent

load_dotenv(BASE_DIR / ".env")


# --- Core ---

SECRET_KEY = os.getenv("SECRET_KEY", "django-insecure-skinscan-development-key")

DEBUG = os.getenv("DEBUG", "True") == "True"

ALLOWED_HOSTS = ["*"]


# --- Applications ---

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",

    # Third-party
    "corsheaders",
    "rest_framework",
    "rest_framework.authtoken",
    "rest_framework_simplejwt",
    "rest_framework_simplejwt.token_blacklist",

    # Local apps
    "accounts",
    "core",
    "analyses",
    "analytics",
    "jwt_auth",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    # Right after SecurityMiddleware (whitenoise's own requirement) - serves
    # /static/ (Django admin's CSS/JS) directly from the gunicorn process
    # in Docker/K8s, where there's no `manage.py runserver` auto-serving
    # static files and no nginx <-> Django shared volume for them.
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "skin_scan.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "skin_scan.wsgi.application"


# --- Database ---
# By default: SQLite (skin_scan/db.sqlite3), zero setup required.
# For PostgreSQL: set in .env -> DB_ENGINE=postgres, DB_NAME, DB_USER, DB_PASSWORD, DB_HOST, DB_PORT

if os.getenv("DB_ENGINE", "sqlite") == "postgres":
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": os.getenv("DB_NAME"),
            "USER": os.getenv("DB_USER"),
            "PASSWORD": os.getenv("DB_PASSWORD"),
            "HOST": os.getenv("DB_HOST", "localhost"),
            "PORT": os.getenv("DB_PORT", "5432"),
        }
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }


# --- Custom user model ---

AUTH_USER_MODEL = "accounts.User"


# --- Django REST Framework ---

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
        "rest_framework.authentication.TokenAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
}


# --- Password validation ---

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]


# --- I18N ---

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True


# --- Static / Media ---

# Deliberately a different prefix from React's own build output (which
# also serves files under /static/js/, /static/css/ from the SAME nginx
# container) - without this, nginx's /static/ proxy rule to Django
# swallows React's own JS/CSS requests too, and Django's 404 HTML
# response gets served back with the wrong MIME type.
STATIC_URL = "django-static/"
# Only used by `collectstatic` (Docker/K8s build step) + whitenoise above -
# local dev with `manage.py runserver` never touches this.
STATIC_ROOT = BASE_DIR / "staticfiles"
STORAGES = {
    # Uploaded scan photos (Analysis.image) - plain local disk storage,
    # same as Django's implicit default before Django 4.2 required this
    # dict to be spelled out explicitly. Missing this key is what caused
    # "Could not find config for 'default' in settings.STORAGES" the
    # moment scan-skin tried to save an uploaded image.
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}

MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"


# --- JWT ---

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=60),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": False,
    "BLACKLIST_AFTER_ROTATION": True,
    "AUTH_HEADER_TYPES": ("Bearer",),
}


# --- CORS ---
# Allows React (localhost:3000) and Flutter dev to talk to the backend.

CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
]
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_ALL_ORIGINS = DEBUG  # only in DEBUG, never in production


# --- Gemini ---
# Read directly in analyses/services/gemini_service.py via os.getenv("GEMINI_API_KEY")
# Don't forget to add GEMINI_API_KEY to .env (see .env.example)
