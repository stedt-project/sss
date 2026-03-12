# STEDT RootCanal – Container Deployment Guide

This guide explains how to build, configure, and run the STEDT RootCanal web
application inside a Docker container on an Ubuntu server.

---

## Overview

The container bundles everything the application needs:

| Component | Details |
|-----------|---------|
| Base OS | Ubuntu 22.04 LTS |
| Web server | Apache 2.4 with mod_cgi |
| Database | MariaDB 10.6 |
| Perl | 5.34 + all required CPAN modules |
| Process model | Apache as PID 1; MariaDB as a background daemon |

The database is persisted in a Docker named volume so it survives container
restarts and image re-builds.

---

## Prerequisites on the Ubuntu Host

### 1. Install Docker Engine

```bash
# Remove any old versions
sudo apt-get remove docker docker-engine docker.io containerd runc

# Install from Docker's official repo
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### 2. Add your user to the docker group (optional but convenient)

```bash
sudo usermod -aG docker $USER
newgrp docker          # take effect without logging out
```

### 3. Verify

```bash
docker --version       # Docker version 24.x or later
docker compose version # Docker Compose version 2.x or later
```

---

## Deployment Steps

### Step 1 – Get the code

```bash
git clone https://github.com/stedt-project/sss.git
cd sss/rootcanal
```

### Step 2 – Prepare the database dump directory

The entrypoint automatically loads any `.sql` or `.sql.gz` files found in
`docker-entrypoint-initdb.d/` on the **first** container run (i.e. when the
volume is empty). On subsequent runs the directory is ignored.

```bash
mkdir -p docker-entrypoint-initdb.d

# Copy your dump here.  The file can be plain SQL or gzip-compressed.
cp /path/to/your/stedt-backup.sql  docker-entrypoint-initdb.d/stedt.sql
# -- or --
cp /path/to/your/stedt-backup.sql.gz  docker-entrypoint-initdb.d/stedt.sql.gz
```

> **Tip:** If you have a mysqldump from the old server, run it like this:
> ```bash
> mysqldump -h old-server -u stedt -p stedt > docker-entrypoint-initdb.d/stedt.sql
> ```

### Step 3 – Configure credentials

```bash
cp docker/rootcanal.env.example rootcanal.env
$EDITOR rootcanal.env
```

Change at least `DB_PASS` to a strong password. The other defaults are fine
for a first test.

> **Security:** `rootcanal.env` is git-ignored. Never commit it.

### Step 4 – Build the image

The build downloads and compiles all CPAN dependencies, which takes
**5–15 minutes** on a fresh machine. Subsequent builds use Docker's layer
cache and are much faster.

```bash
docker compose build
```

### Step 5 – Start the container

```bash
docker compose up -d
```

On **first run** the entrypoint will:
1. Initialise the MariaDB data directory.
2. Create the `stedt` database and application user.
3. Load your SQL dump (this can take several minutes for large databases).
4. Write `rootcanal.conf` with the credentials from `rootcanal.env`.
5. Start Apache.

Monitor progress:

```bash
docker compose logs -f
```

You will see lines like:

```
[entrypoint] Initialising fresh MariaDB data directory …
[entrypoint] MariaDB is ready (after 3s).
[entrypoint] Loading SQL dump: stedt.sql …
[entrypoint] Database initialisation complete.
[entrypoint] Starting Apache2 …
```

### Step 6 – Verify

Open a browser and go to:

```
http://<server-ip>:8080/
```

You should see the STEDT search interface.

---

## Configuration Reference

### Environment variables (`rootcanal.env`)

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_NAME` | `stedt` | Database name |
| `DB_USER` | `stedt` | Application DB username |
| `DB_PASS` | `changeme` | Application DB password – **change this** |
| `DB_ROOT_PASS` | *(empty)* | MariaDB root password; blank = socket auth only |
| `IGNORE_SSL` | `1` | `1` = don't require HTTPS cookies (needed behind a proxy or for plain HTTP) |

### Port mapping

Edit `docker-compose.yml` to change the host port:

```yaml
ports:
  - "80:80"   # expose on port 80 directly
```

### Changing the host port after first run

Stop, edit `docker-compose.yml`, then restart:

```bash
docker compose down
# edit docker-compose.yml
docker compose up -d
```

---

## Day-2 Operations

### View logs

```bash
docker compose logs -f                    # all logs
docker exec rootcanal tail -f /var/log/apache2/rootcanal-error.log
docker exec rootcanal tail -f /var/log/apache2/rootcanal-access.log
```

### Open a shell inside the container

```bash
docker exec -it rootcanal bash
```

### Connect to MariaDB inside the container

```bash
docker exec -it rootcanal mysql -u stedt -p stedt
```

### Restart the container

```bash
docker compose restart
```

### Stop and remove the container (data volume is preserved)

```bash
docker compose down
```

### Completely reset (WARNING: destroys all database data)

```bash
docker compose down -v    # -v removes the named volume
```

### Update the application code (no database change)

```bash
git pull
docker compose build --no-cache
docker compose up -d
```

### Back up the database

```bash
docker exec rootcanal \
    mysqldump -u stedt -p"${DB_PASS}" stedt \
    > stedt-backup-$(date +%Y%m%d).sql
```

---

## Putting HTTPS in Front (Recommended for Production)

The container serves plain HTTP on port 8080. For production, put a
TLS-terminating reverse proxy in front of it on the same host:

### nginx example (`/etc/nginx/sites-available/rootcanal`)

```nginx
server {
    listen 443 ssl;
    server_name your-domain.example.com;

    ssl_certificate     /etc/letsencrypt/live/your-domain.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.example.com/privkey.pem;

    location / {
        proxy_pass         http://127.0.0.1:8080;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}

# Redirect HTTP → HTTPS
server {
    listen 80;
    server_name your-domain.example.com;
    return 301 https://$host$request_uri;
}
```

When running behind HTTPS set `IGNORE_SSL=0` in `rootcanal.env` so that the
application correctly marks session cookies as `Secure`.

---

## Troubleshooting

### Container exits immediately

```bash
docker compose logs rootcanal
```

Common causes:
- MariaDB failed to start – check for "Can't open and lock privilege tables"
  (data directory permissions issue).
- Apache configuration error – look for "Syntax error" lines.

### "Can't locate STEDT/RootCanal/Dispatch.pm"

The `PERL5LIB` environment variable passed to Apache is wrong.
Check `docker/apache-rootcanal.conf`: `SetEnv PERL5LIB /home/stedt-cgi/pm`

### "DBI connect failed"

The database hasn't started yet or the credentials in `rootcanal.env` don't
match what was written when the volume was first initialised.
Either correct the env file and `docker compose down -v && docker compose up -d`
(which resets the database), or fix the credentials inside the container:

```bash
docker exec -it rootcanal mysql -u root
ALTER USER 'stedt'@'localhost' IDENTIFIED BY 'newpassword';
FLUSH PRIVILEGES;
```
Then update `rootcanal.env` and restart.

### "500 Internal Server Error" on the first page load

Look at the Apache error log:

```bash
docker exec rootcanal tail -50 /var/log/apache2/rootcanal-error.log
```

### `lg_table.cgi` fails with "Can't locate STEDTUser.pm"

`lg_table.cgi` depends on a `STEDTUser.pm` module that is **not** included in
this repository. You will need to recover it from the original server and place
it in `perl/` (it will then be copied to `/home/stedt-cgi/pm/` during the
build). The main `rootcanal.pl` application is not affected by this.

---

## Files Added by This Deployment Setup

```
rootcanal/
├── docker/
│   ├── Dockerfile                 ← Ubuntu 22.04 image definition
│   ├── apache-rootcanal.conf      ← Apache VirtualHost
│   ├── entrypoint.sh              ← Container startup script
│   └── rootcanal.env.example      ← Template for credentials
├── docker-compose.yml             ← Compose service definition
├── docker-entrypoint-initdb.d/    ← Drop your *.sql dump here (git-ignored)
└── DEPLOY.md                      ← This file
```

None of the original application files were modified.
