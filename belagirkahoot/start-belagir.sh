#!/bin/bash
set -euo pipefail
cd /home/container

public_url="${PUBLIC_URL%/}"
case "$public_url" in
    https://*) ws_base="wss://${public_url#https://}" ;;
    http://*) ws_base="ws://${public_url#http://}" ;;
    *) echo 'PUBLIC_URL must start with https:// or http://' >&2; exit 1 ;;
esac

# With a tunnel, the site only listens inside the container on a fixed port, so
# the Pelican allocation is never used and nothing is reachable from the host.
# Without one, it serves the allocation port directly.
if [[ -n "${TUNNEL_TOKEN:-}" ]]; then
    web_bind=127.0.0.1 web_port=8080
elif [[ "${SERVER_PORT:-0}" != 0 ]]; then
    web_bind=0.0.0.0 web_port="$SERVER_PORT"
else
    echo 'Set TUNNEL_TOKEN, or give the server an allocation to serve on.' >&2
    exit 1
fi

# Each helper gets only what it needs, so app secrets never reach cloudflared,
# Caddy or Redis, and the tunnel token never reaches the app.
base_env=(PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/home/container TZ="${TZ:-UTC}")

pids=()
cleanup() {
    trap '' TERM INT
    for pid in "${pids[@]}"; do kill -TERM "$pid" 2>/dev/null || true; done
    for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT
trap 'exit 0' TERM INT

# Without an explicit secret, generate one once and keep it in the server's
# files, so host sessions survive restarts and backups restore it.
if [[ -z "${JWT_SECRET:-}" ]]; then
    secret_file=/home/container/.jwt-secret
    if [[ ! -s "$secret_file" ]]; then
        (umask 077; head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$secret_file")
        echo "Generated a JWT secret in .jwt-secret."
    fi
    JWT_SECRET="$(cat "$secret_file")"
    export JWT_SECRET
fi

# The frontend bundle carries a placeholder for the WebSocket origin.
web_root=/tmp/belagir-web
rm -rf "$web_root"
cp -R /opt/belagir/web "$web_root"
grep -rlF __BELAGIR_WS_BASE__ "$web_root" | while IFS= read -r file; do
    sed -i "s#__BELAGIR_WS_BASE__#${ws_base}#g" "$file"
done

redis_url="${REDIS_URL:-}"
if [[ -z "$redis_url" ]]; then
    # Live game state only; a private Redis on loopback is enough.
    env -i "${base_env[@]}" redis-server --bind 127.0.0.1 --port 6379 \
        --dir /home/container/redis --save 60 1 --appendonly no \
        --protected-mode yes --loglevel warning &
    pids+=("$!")
    for _ in $(seq 1 50); do
        redis-cli -h 127.0.0.1 -p 6379 ping >/dev/null 2>&1 && break
        sleep 0.2
    done
    redis_url=redis://127.0.0.1:6379
fi

# The backend runs migrations from ./migrations on every start.
(
    cd /opt/belagir
    exec env -u TUNNEL_TOKEN -u STARTUP PORT=8081 FRONTEND_URL="$public_url" \
        REDIS_URL="$redis_url" VITE_APP_NAME="${VITE_APP_NAME:-Jeunesse Bel Agir}" \
        ./server
) &
pids+=("$!")

env -i "${base_env[@]}" XDG_DATA_HOME=/tmp/caddy XDG_CONFIG_HOME=/tmp/caddy \
    WEB_BIND="$web_bind" WEB_PORT="$web_port" WEB_ROOT="$web_root" \
    caddy run --config /etc/belagir/Caddyfile --adapter caddyfile &
pids+=("$!")

if [[ -n "${TUNNEL_TOKEN:-}" ]]; then
    # cloudflared reads TUNNEL_TOKEN directly; never put it in CLI arguments.
    env -i "${base_env[@]}" TUNNEL_TOKEN="$TUNNEL_TOKEN" \
        cloudflared tunnel --no-autoupdate --metrics 127.0.0.1:20241 run &
    pids+=("$!")
else
    echo "TUNNEL_TOKEN is empty; Cloudflare Tunnel is disabled. Serving on port $web_port."
fi

set +e
wait -n "${pids[@]}"
status=$?
set -e
# Any component unexpectedly exiting must stop the container so Wings can
# restart it.
if (( status == 0 )); then status=1; fi
exit "$status"
