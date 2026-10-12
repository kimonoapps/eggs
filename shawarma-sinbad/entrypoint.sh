#!/bin/bash
set -euo pipefail
cd /home/container
if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
    echo 'Set ADMIN_PASSWORD in the Pelican panel before starting.' >&2
    exit 1
fi
mkdir -p storage log tmp/pids tmp/cache
# Sinbad only needs secret_key_base from its encrypted credentials, so use a
# key generated on first start instead of upstream's master key. Changing or
# deleting .secret_key_base signs everyone out.
if [[ ! -s .secret_key_base ]]; then
    (umask 077; ruby -rsecurerandom -e 'print SecureRandom.hex(64)' > .secret_key_base)
fi
SECRET_KEY_BASE="$(< .secret_key_base)"
export SECRET_KEY_BASE
unset RAILS_MASTER_KEY
# This egg uses a fixed startup command with no variable placeholders.
# Do not print the startup command or environment: these may contain secrets.
if [[ -n "${STARTUP:-}" ]]; then
    exec /bin/bash -c "$STARTUP"
fi
exec "$@"
