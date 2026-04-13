# Self-Hosting Philomena

This guide covers running Philomena in production using the prebuilt Docker images published to GitHub Container Registry.

## Prerequisites

- Docker with the Compose plugin (`docker compose version` should work)
- A domain name with DNS you control
- An external Caddy container on a Docker network named `caddy_net` (or adjust the network name to match yours)
- An SMTP relay for outgoing email

## Architecture Overview

```
Internet → your external Caddy (TLS) → philomena-web:80 (internal Caddy)
                                              ├── /img/*, /avatars/*, etc. → files (s3proxy)
                                              └── everything else → app:4000 (Elixir)
```

| Container    | Image                                        | Purpose                                    |
| ------------ | -------------------------------------------- | ------------------------------------------ |
| `postgres`   | `postgres:17.7-alpine`                       | Database                                   |
| `opensearch` | `opensearchproject/opensearch:3.2.0`         | Search index                               |
| `valkey`     | `valkey/valkey:8.1.3-alpine`                 | Job queue / pubsub                         |
| `files`      | `andrewgaul/s3proxy`                         | Local file storage (images, avatars, etc.) |
| `setup`      | `ghcr.io/philomena-dev/philomena:master`     | One-shot DB init + migrations              |
| `app`        | `ghcr.io/philomena-dev/philomena:master`     | HTTP endpoint                              |
| `worker`     | `ghcr.io/philomena-dev/philomena:master`     | Background job processor                   |
| `cron`       | `ghcr.io/philomena-dev/philomena:master`     | Hourly/daily maintenance                   |
| `web`        | `ghcr.io/philomena-dev/philomena-web:master` | Caddy: static assets + reverse proxy       |

On first boot, the `setup` container automatically initialises the database schema, seeds default data (tags, filters, forums, an admin user), and runs migrations. All other containers wait for it to finish before starting.

## Step 1 — DNS

Create two A records pointing at your server's IP:

| Record        | Example                       |
| ------------- | ----------------------------- |
| App domain    | `example.com` → `1.2.3.4`     |
| CDN subdomain | `cdn.example.com` → `1.2.3.4` |

Both point at the same server. Caddy routes between them using the `Host` header.

## Step 2 — Environment file

Copy the example file and open it in an editor:

```sh
cp .env.example .env
$EDITOR .env
```

### Required changes

**Secrets** — generate a unique value for each with `openssl rand -base64 48`:

```sh
openssl rand -base64 48  # paste into SECRET_KEY_BASE
openssl rand -base64 48  # paste into ANONYMOUS_NAME_SALT
openssl rand -base64 48  # paste into PASSWORD_PEPPER
openssl rand -base64 48  # paste into OTP_SECRET_KEY
```

**Database password** — pick a strong password and set it in _both_ places:

```env
POSTGRES_PASSWORD=your_strong_password
DATABASE_URL=ecto://postgres:your_strong_password@postgres/philomena_prod
```

> The password must be identical in both lines. `setup` uses `POSTGRES_PASSWORD`
> to connect via `psql`; the app uses `DATABASE_URL`.

**Domains** — replace `example.com` and `cdn.example.com` throughout:

```env
APP_HOSTNAME=example.com
CDN_HOST=cdn.example.com
SITE_DOMAINS=example.com
APP_URL=http://example.com
CDN_URL=http://cdn.example.com
SITE_DOMAIN=example.com
MAILER_ADDRESS=noreply@example.com
```

**SMTP**:

```env
SMTP_RELAY=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=your_smtp_user
SMTP_PASSWORD=your_smtp_password
```

**hCaptcha** — the `.env.example` ships with test keys that work for local testing. Replace them with real keys from [hcaptcha.com](https://www.hcaptcha.com/) before opening to the public:

```env
HCAPTCHA_SECRET_KEY=your_secret_key
HCAPTCHA_SITE_KEY=your_site_key
```

Everything else (S3, file roots, OpenSearch, Redis) is pre-configured for the local containers and does not need to change unless you are using external services.

## Step 3 — External Caddy network

Ensure the `caddy_net` Docker network exists. If your external Caddy was set up with it already, this is a no-op:

```sh
docker network create caddy_net
```

## Step 4 — External Caddy config

Add two reverse proxy entries to your external Caddy so it forwards traffic to the internal `philomena-web` container. The exact syntax depends on your Caddy setup, but the logic is:

```
example.com {
    reverse_proxy philomena-web:80
}

cdn.example.com {
    reverse_proxy philomena-web:80
}
```

> Both hostnames proxy to the same container. The internal Caddy distinguishes
> them by `Host` header and serves app traffic vs. media files accordingly.

## Step 5 — Start the stack

```sh
docker compose -f docker-compose.prod.yml up -d
```

Watch the first-boot setup:

```sh
docker compose -f docker-compose.prod.yml logs -f setup
```

You should see:

```
Waiting for database to start...
Waiting for OpenSearch...
database appears to be uninitialized (table public.schema_migrations is missing), setting up...
...
```

Once `setup` exits, the `app`, `worker`, and `cron` containers start automatically.

Confirm everything is running:

```sh
docker compose -f docker-compose.prod.yml ps
```

The `setup` service should show `Exited (0)`. All others should show `running`.

## Step 6 — Verify

Visit `https://example.com` in a browser. You should see the Philomena landing page.

To confirm media serving works, upload a test image and check that it loads from `https://cdn.example.com/img/...`.

## Default admin credentials

The seed data creates an initial admin account. Check the output of `setup` logs or look in `priv/repo/seeds.exs` for the default credentials. **Change the password immediately after first login.**

## Ongoing operations

### View logs

```sh
docker compose -f docker-compose.prod.yml logs -f app
docker compose -f docker-compose.prod.yml logs -f worker
```

### Run a one-off task

```sh
docker compose -f docker-compose.prod.yml exec app philomena eval 'Philomena.Release.migrate()'
```

### Enable downtime page

Set `DOWNTIME=true` in `.env` and restart the `web` container:

```sh
docker compose -f docker-compose.prod.yml up -d web
```

### Update to a new release

```sh
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

The `setup` container will run again on restart. It detects that the database is already initialised and only runs pending migrations — it will not re-seed or overwrite existing data.

### Backup

The only stateful volumes are:

| Volume            | Contents                                        |
| ----------------- | ----------------------------------------------- |
| `postgres_data`   | All site data (users, images, tags, etc.)       |
| `opensearch_data` | Search index (can be rebuilt from the database) |
| `s3_data`         | Uploaded image and media files                  |

Back up `postgres_data` and `s3_data`. The search index can be regenerated if lost.

To dump the database:

```sh
docker compose -f docker-compose.prod.yml exec postgres pg_dump -U postgres philomena_prod > backup.sql
```
