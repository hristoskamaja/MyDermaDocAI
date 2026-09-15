#!/bin/sh
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
