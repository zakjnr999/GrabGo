#!/usr/bin/env bash
# Render start script for GrabGo ML Service

set -e  # Exit on error

echo "🚀 Starting GrabGo ML Service..."

# Determine number of workers based on instance size
if [ -z "$WORKERS" ]; then
    WORKERS=2
fi

# Start the application
exec uvicorn app.main:app \
    --host 0.0.0.0 \
    --port ${PORT:-8000} \
    --workers $WORKERS \
    --log-level ${LOG_LEVEL:-info} \
    --no-access-log
