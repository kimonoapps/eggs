#!/bin/bash
set -euo pipefail
cd /home/container
# Wings runs the container under its own UID. PostgreSQL refuses to run as a
# user with no passwd entry, so add one for whatever UID this is.
if ! grep -q "^[^:]*:[^:]*:$(id -u):" /etc/passwd; then
    echo "container:x:$(id -u):$(id -g):container:/home/container:/bin/bash" >> /etc/passwd
fi
if [[ -z "${PUBLIC_URL:-}" ]]; then
    echo "Set PUBLIC_URL in the Pelican panel before starting." >&2
    exit 1
fi
mkdir -p redis
# This egg uses a fixed startup command with no variable placeholders.
# Do not print the startup command or environment: these may contain secrets.
if [[ -n "${STARTUP:-}" ]]; then
    exec /bin/bash -c "$STARTUP"
fi
exec "$@"
