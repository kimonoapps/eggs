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
2. Create a server. With a tunnel, leave it without an allocation; Pelican
   allows that, and no host port is published.
3. As an admin, set `PUBLIC_URL` (e.g. `https://kahoot.example.org`),
   `TUNNEL_TOKEN` and the SMTP fields. Hosts must verify their email before
   they can log in, so SMTP is needed in practice.
4. In Cloudflare, give the remotely managed tunnel the public hostname from
   `PUBLIC_URL` with service `http://localhost:8080`. The connector needs
   outbound port 7844.

Everything else runs inside the container:

- PostgreSQL 17, data in `postgres/`. It listens only on a private socket, so
  it has no password and no port. Set `DATABASE_URL` to use an external
  server instead. Pelican's own databases are MySQL only, so they cannot be
  used.
- Redis, data in `redis/`, unless `REDIS_URL` is set.
- The JWT secret, in `.jwt-secret`, unless `JWT_SECRET` is set.

Pelican file backups include all of it; stop the server first for a
consistent database copy. Migrations run on every start. `PUBLIC_URL` must
match the browser's origin exactly, or game WebSockets are refused.

With a tunnel token, the site listens only on `127.0.0.1:8080` inside the
container. Without one, it serves the allocation port on `0.0.0.0`, so the
server then needs one.
