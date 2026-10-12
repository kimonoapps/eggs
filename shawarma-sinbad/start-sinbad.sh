#!/bin/bash
set -euo pipefail
cd /rails
# With a tunnel, Rails only listens inside the container on a fixed port, so the
# Pelican allocation is never used and nothing is reachable from the host.
# Without one, Rails serves the allocation port directly.
if [[ -n "${TUNNEL_TOKEN:-}" ]]; then
    bind=127.0.0.1 port=3000
elif [[ "${SERVER_PORT:-0}" != 0 ]]; then
    bind=0.0.0.0 port="$SERVER_PORT"
else
    echo 'Set TUNNEL_TOKEN, or give the server an allocation to serve on.' >&2
    exit 1
fi
app_pid=''
tunnel_pid=''
cleanup() {
    trap '' TERM INT
    for pid in "$app_pid" "$tunnel_pid"; do
        [[ -z "$pid" ]] || kill -TERM "$pid" 2>/dev/null || true
    done
    for pid in "$app_pid" "$tunnel_pid"; do
        [[ -z "$pid" ]] || wait "$pid" 2>/dev/null || true
    done
}
trap cleanup EXIT
trap 'exit 0' TERM INT
env -u TUNNEL_TOKEN ./bin/rails db:prepare
# Keep the Cloudflare credential out of the web application's environment.
env -u TUNNEL_TOKEN ./bin/rails server -b "$bind" -p "$port" &
app_pid=$!
pids=("$app_pid")
if [[ -n "${TUNNEL_TOKEN:-}" ]]; then
    # cloudflared reads TUNNEL_TOKEN directly; never put it in CLI arguments.
    env -u SECRET_KEY_BASE -u ADMIN_PASSWORD cloudflared tunnel --no-autoupdate run &
    tunnel_pid=$!
    pids+=("$tunnel_pid")
else
    echo "TUNNEL_TOKEN is empty; Cloudflare Tunnel is disabled. Serving on port $port."
fi
set +e
wait -n "${pids[@]}"
status=$?
set -e
# A tunnel unexpectedly exiting must stop the container so Wings can restart it.
if (( status == 0 )); then status=1; fi
exit "$status"
