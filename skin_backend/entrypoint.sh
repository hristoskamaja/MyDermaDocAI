#!/bin/sh
# Container startup for the Django backend (Docker/K8s only - never used
# for local `manage.py runserver` dev). Order matters:
#   1. wait for Postgres to actually accept connections - `depends_on` in
#      docker-compose (or a Pod just existing in k8s) only means the DB
#      container/pod has STARTED, not that Postgres is ready to accept
#      connections yet, so migrate can otherwise fail on a cold start race.
#   2. run migrations - safe to run on every container start (Django only
#      applies the ones that are new).
#   3. collectstatic - gathers Django admin's CSS/JS into STATIC_ROOT for
#      whitenoise to serve (see settings.py).
#   4. hand off to gunicorn.
set -e

echo "Waiting for the database..."
python <<'PYEOF'
import os
import sys
import time

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "skin_scan.settings")
django.setup()

from django.db import connections
from django.db.utils import OperationalError

conn = connections["default"]
for attempt in range(30):
    try:
        conn.cursor()
        print("Database is up.")
        sys.exit(0)
    except OperationalError:
        print(f"  ...not ready yet (attempt {attempt + 1}/30), retrying in 2s")
        time.sleep(2)

print("Database never became ready - exiting.")
sys.exit(1)
PYEOF

echo "Applying migrations..."
python manage.py migrate --noinput

echo "Collecting static files..."
python manage.py collectstatic --noinput

echo "Starting gunicorn..."
exec gunicorn skin_scan.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers 3 \
    --timeout 60
