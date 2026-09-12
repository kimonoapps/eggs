# Read on Kimono Hosting / Pelican

Import `egg-read.json` and `egg-authentik.json`. Use your existing PostgreSQL egg
(PostgreSQL 17 recommended). These are three Pelican servers: Read, Authentik
(server and worker managed together), PostgreSQL.

## Database connections

Yes, eggs can connect to other servers. Use the PostgreSQL Wings VM's private
LAN IP and its assigned PostgreSQL allocation port, not `localhost`, `db`, or
the PostgreSQL server UUID. Wings firewall/network isolation must permit this
traffic. Across VMs, allow the app VMs to reach that private IP and port. On the
same VM, host-port hairpin access can depend on Docker/firewall configuration;
verify access before starting the apps. Do not expose PostgreSQL through the
public router or HTTP tunnel. Configure PostgreSQL listen_addresses and
pg_hba.conf to permit these authenticated connections.

Using PostgreSQL's administrator connection, create two independent databases
and users (replace the example passwords):

```sql
CREATE USER read WITH PASSWORD 'REPLACE_READ_PASSWORD';
CREATE DATABASE read OWNER read;
CREATE USER authentik WITH PASSWORD 'REPLACE_AUTHENTIK_PASSWORD';
CREATE DATABASE authentik OWNER authentik;
```

Set Read's DATABASE_URL to
`postgres://read:URL_ENCODED_PASSWORD@PRIVATE_VM_IP:PG_ALLOCATION_PORT/read`.
Set Authentik's PostgreSQL host, port, name, user and password fields accordingly.
Secrets are administrator-only egg variables; enter them in the admin panel.
Generate distinct AUTH_SECRET and AUTHENTIK_SECRET_KEY values with
`openssl rand -hex 32`. Keep them stable on reinstall/update.

## Images

GitHub Actions builds and publishes these images from the Read repository:

- `ghcr.io/akramboussanni/read-pelican:latest`
- `ghcr.io/akramboussanni/authentik-pelican:2026.5.6`

The first workflow must finish before importing/starting the eggs. Set both GHCR
packages to public if Wings is not configured with registry credentials.
Alternatively build on each Wings host from the Read repository root:

```sh
docker build -t read:pelican-base .
docker build -f infra/pelican/Dockerfile.read -t read-pelican:local .
docker build -f infra/pelican/Dockerfile.authentik -t authentik-pelican:2026.5.6 .
```

For local builds, replace the egg's image with the corresponding local tag.
Read is compiled into the image; update by pulling a newly built image and
restarting, rather than reinstalling server files. Migrations run on startup.
Authentik files live under `/home/container/data` and are included in its server
file backups. Back up PostgreSQL separately: Pelican file backups of Read or
Authentik do not include their databases.

## Authentik and public URLs

Start PostgreSQL, then Authentik. Set its bootstrap admin password and email
before the first boot. Assign each app a unique Pelican port; both listen on
SERVER_PORT automatically. Start a Cloudflare Tunnel connector on a machine
that can reach those allocated ports and add these public hostname routes:

```text
read.example.org -> http://READ_VM_PRIVATE_IP:READ_ALLOCATION_PORT
auth.example.org -> http://AUTH_VM_PRIVATE_IP:AUTH_ALLOCATION_PORT
```

These tunnels publish the web apps, not Wings' management/SFTP endpoints.

In Authentik's admin interface create an OAuth2/OpenID provider and application:

- Application slug / client ID: `read`
- Confidential client; copy its client secret to Read's AUTH_AUTHENTIK_SECRET
- Strict redirect: `https://read.example.org/api/auth/callback/authentik`
- Signing key: Authentik Self-signed Certificate (RS256)
- Scope mappings: openid, profile, email (stock profile includes groups)
- Group: `read-teachers`; add teachers to it

Set Read's AUTH_URL to `https://read.example.org` and issuer to
`https://auth.example.org/application/o/read/`. Create student accounts in this
Authentik instance. Then start Read. No Caddy or router port forwarding is
needed for the app hostnames when using the tunnel.

The Authentik wrapper stops both components when either fails or the server is
stopped. This is a custom Pelican packaging of the upstream server/worker pair,
not Authentik's standard two-container Compose deployment.
