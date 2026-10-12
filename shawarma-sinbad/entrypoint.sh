#!/bin/bash
set -euo pipefail
cd /home/container
for var in RAILS_MASTER_KEY ADMIN_PASSWORD; do
    if [[ -z "${!var:-}" ]]; then
        echo "Set $var in the Pelican panel before starting." >&2
        exit 1
    fi
done
mkdir -p storage log tmp/pids tmp/cache
# This egg uses a fixed startup command with no variable placeholders.
# Do not print the startup command or environment: these may contain secrets.
if [[ -n "${STARTUP:-}" ]]; then
    exec /bin/bash -c "$STARTUP"
fi
exec "$@"
