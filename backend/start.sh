#!/bin/sh
set -eu

if ! command -v gunicorn >/dev/null 2>&1; then
    echo "ERROR: gunicorn is not installed or not available on PATH." >&2
    exit 127
fi

if [ -n "${DEMO_EMAIL:-}" ] || [ -n "${DEMO_PASSWORD:-}" ]; then
    python /app/seed_demo_user.py
fi

exec gunicorn \
    --workers 1 \
    --threads 4 \
    --bind 0.0.0.0:7860 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    run:app