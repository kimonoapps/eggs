# Shawarma Sinbad on Pelican (Kimono Hosting)

Image: `ghcr.io/akramboussanni/shawarma-sinbad:pelican`. It wraps the upstream
`ghcr.io/mom0oo0/shawarmasinbad:main` image, so build from this `shawarma-sinbad/` folder; the
Sinbad repository needs no changes. Upstream is amd64-only:

```sh
docker buildx build --platform linux/amd64 -f Dockerfile.pelican -t ghcr.io/akramboussanni/shawarma-sinbad:pelican --push .
```

Rebuild whenever upstream `main` changes to pick up app updates.

1. Import `egg-shawarma-sinbad.json` from the repository root.
2. Create a server. With a tunnel, leave it without an allocation; Pelican
   allows that, and no host port is published.
3. As an admin, set `ADMIN_PASSWORD` and `TUNNEL_TOKEN`. Upstream's master
   key isn't needed: the first start generates `secret_key_base` into
   `/home/container/.secret_key_base`. Deleting that file signs everyone out.
4. In Cloudflare, give the remotely managed tunnel a public hostname with
   service `http://localhost:3000`. The connector needs outbound port 7844.

With a tunnel token, Rails listens only on `127.0.0.1:3000` inside the
container, so nothing is reachable from the host or LAN. Without a token,
Rails serves the allocation port on `0.0.0.0`, so the server then needs one.

SQLite databases and Active Storage uploads live in `/home/container/storage`,
which Pelican file backups include. Migrations run on every start.
