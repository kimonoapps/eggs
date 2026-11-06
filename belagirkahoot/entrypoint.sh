#!/bin/bash
set -euo pipefail
cd /home/container
for var in PUBLIC_URL DATABASE_URL; do
    if [[ -z "${!var:-}" ]]; then
        echo "Set $var in the Pelican panel before starting." >&2
        exit 1
    fi
done
mkdir -p redis
# This egg uses a fixed startup command with no variable placeholders.
# Do not print the startup command or environment: these may contain secrets.
if [[ -n "${STARTUP:-}" ]]; then
    exec /bin/bash -c "$STARTUP"
fi
exec "$@"
