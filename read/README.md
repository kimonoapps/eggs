# Read on Pelican (Kimono Hosting)

Image: `ghcr.io/akramboussanni/read-pelican:latest`. The yolk (`Dockerfile.pelican`, `entrypoint.sh`, `start-read.sh`)
lives with the app in `akramboussanni/read` under `next/infra/pelican/`, and its **Deploy to Pelican** workflow builds,
pushes and restarts the server on every push to `main`.

1. Import `egg-read.json` from the repository root.
2. Create a server. With a tunnel, leave it without an allocation; Pelican allows that, and no host port is published.
3. As an admin, set `PUBLIC_URL` (e.g. `https://read.example.org`) and `TUNNEL_TOKEN`.
4. In Cloudflare, give the remotely managed tunnel the public hostname from `PUBLIC_URL` with service
   `http://localhost:8080`. The connector needs outbound port 7844.

Read starts in demo mode: two shared accounts (Yasmine, student; Mme Haddad, teacher) and a « Classe démo » with
code `DEMO01`, so it works with nothing else to set up. Set `READ_MODE` to `authentik` and fill the four Authentik
fields for school accounts; `egg-authentik.json` runs Authentik as a second server.

Everything else runs inside the container:

- PostgreSQL 17, data in `postgres/`. It listens only on a private socket, so it has no password and no port. Set
  `DATABASE_URL` to use an external server instead. Pelican's own databases are MySQL only, so they cannot be used.
- The auth secret, in `.auth-secret`, unless `AUTH_SECRET` is set.

Pelican file backups include all of it; stop the server first for a consistent database copy. Migrations run on every
start.

With a tunnel token, Read listens only on `127.0.0.1:8080` inside the container. Without one, it serves the allocation
port on `0.0.0.0`, so the server then needs one.
