# Jeunesse Bel Agir (belagirkahoot) on Pelican (Kimono Hosting)

Image: `ghcr.io/akramboussanni/belagirkahoot:pelican`. It builds the backend and
frontend straight from `akramboussanni/belagirkahoot` (`BELAGIR_REF`, default
`main`), so build from this `belagirkahoot/` folder; the app repository needs no
changes:

```sh
docker buildx build --platform linux/amd64 -f Dockerfile.pelican -t ghcr.io/akramboussanni/belagirkahoot:pelican --push .
```

Rebuild whenever the app's `main` changes, then restart the server.

1. Import `egg-belagirkahoot.json` from the repository root.
2. On your PostgreSQL server, create a database and user:
   ```sql
   CREATE USER belagir WITH PASSWORD 'REPLACE_PASSWORD';
   CREATE DATABASE belagir OWNER belagir;
   ```
3. Create a server. With a tunnel, leave it without an allocation; Pelican
   allows that, and no host port is published.
4. As an admin, set `PUBLIC_URL` (e.g. `https://kahoot.example.org`),
   `DATABASE_URL`
   (`postgres://belagir:URL_ENCODED_PASSWORD@PRIVATE_VM_IP:PG_ALLOCATION_PORT/belagir?sslmode=disable`),
   `TUNNEL_TOKEN` and the SMTP fields. Hosts must verify their email before
   they can log in, so SMTP is needed in practice.
5. In Cloudflare, give the remotely managed tunnel the public hostname from
   `PUBLIC_URL` with service `http://localhost:8080`. The connector needs
   outbound port 7844.

Generated for you: the JWT secret (kept in `.jwt-secret` unless `JWT_SECRET`
is set) and Redis, which runs privately inside the container unless
`REDIS_URL` is set. `PUBLIC_URL` must match the browser's origin exactly, or
game WebSockets are refused.

With a tunnel token, the site listens only on `127.0.0.1:8080` inside the
container. Without one, it serves the allocation port on `0.0.0.0`, so the
server then needs one. Migrations run on every start. Back up PostgreSQL
separately: file backups of this server hold only the JWT secret and Redis.
