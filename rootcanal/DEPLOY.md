# STEDT RootCanal – Container Deployment Guide
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

## HTTPS / TLS

TLS is terminated by the AWS Application Load Balancer before traffic
reaches the EC2 instance. No certificate configuration is needed on the
server itself. The ALB forwards `X-Forwarded-Proto: https` to the host
Apache2, which passes it through to the container. The container's Apache
converts that header into `HTTPS=on` for the CGI process, so the app
generates correct `https://` links throughout.

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

---

## Deploying to AWS EC2 (JB's setup)

### Architecture on EC2

```
Browser → Route53 (CNAME) → ALB (HTTPS:443, SSL termination)
                                  ↓ HTTP
                             EC2 host Apache2 (:80)
                                  ↓ HTTP proxy
                             Docker container (127.0.0.1:8080)
                                  └─ MariaDB (Unix socket, internal)
```

SSL is handled entirely by the AWS Application Load Balancer.
The EC2 instance and Docker container deal only with plain HTTP.
The ALB forwards `X-Forwarded-Proto: https` so the app generates
correct `https://` links for things like password-reset emails.

### Step 1 – Provision the EC2 instance

Recommended: **Ubuntu 22.04 LTS**, t3.small or larger, at least 20 GB root volume.

**EC2 Security Group** — the instance only needs to be reachable by the ALB:
- Port **22** from your IP (SSH)
- Port **80** from the ALB's security group (or `0.0.0.0/0` if the ALB is internet-facing)

Port 443 does **not** need to be open on the EC2 instance — the ALB handles it.

**ALB Target Group** — point it at the EC2 instance on port **80**, HTTP protocol.

### Step 2 – Install Docker on the EC2 instance

```bash
ssh ubuntu@<ec2-public-ip>

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

sudo usermod -aG docker ubuntu
newgrp docker
```

### Step 3 – Install and configure the host Apache2

```bash
sudo apt-get install -y apache2

# Only these three modules are needed — no ssl, no rewrite
sudo a2enmod proxy proxy_http headers
```

Copy the virtual-host config from the repository:

```bash
git clone https://github.com/stedt-project/sss.git /home/ubuntu/stedtdb
cd /home/ubuntu/stedtdb/rootcanal

sudo cp docker/apache-host-stedtdb.conf /etc/apache2/sites-available/stedtdb.conf
sudo a2ensite stedtdb
sudo a2dissite 000-default          # remove the Apache placeholder page
sudo apache2ctl configtest          # should print "Syntax OK"
```

### Step 4 – Deploy the container

```bash
cd /home/ubuntu/stedtdb/rootcanal

# Put your database dump in place
cp /path/to/stedt.sql.gz docker-entrypoint-initdb.d/

# Create credentials file
cp docker/rootcanal.env.example rootcanal.env
$EDITOR rootcanal.env    # at minimum, change DB_PASS

# Build the image (~10 min on first run)
docker compose build

# Start detached
docker compose up -d

# Watch startup — wait for "Starting Apache2 …"
docker compose logs -f
```

Once you see `[entrypoint] Starting Apache2 …`, visit
**https://stedtdb.johnblowe.com** in your browser.

### Step 5 – Enable Docker to start on EC2 reboot

`restart: always` in `docker-compose.yml` handles the container, but
Docker itself must be enabled as a system service:

```bash
sudo systemctl enable docker
```

### Updating the application after a code push

```bash
cd /home/ubuntu/stedtdb/rootcanal
git pull
docker compose build
docker compose up -d
```

---

## Local Mac Testing vs EC2 Production

| Setting | Mac (local test) | EC2 (production) |
|---------|-----------------|------------------|
| `platform:` line | `linux/arm64` (uncomment) | commented out |
| Port binding | `"8080:80"` | `"127.0.0.1:8080:80"` |
| `restart:` | either | `always` |
| `IGNORE_SSL` | `1` | `1` (proxy handles TLS) |
| Host Apache | not needed | `apache-host-stedtdb.conf` |

To switch to local testing, temporarily change the port in `docker-compose.yml`
from `"127.0.0.1:8080:80"` to `"8080:80"` and uncomment the `platform` line.

---

## Files Added by This Deployment Setup

```
rootcanal/
├── docker/
│   ├── Dockerfile                    ← Ubuntu 22.04 image definition
│   ├── apache-rootcanal.conf         ← Container-internal Apache VirtualHost
│   ├── apache-host-stedtdb.conf      ← EC2 host Apache VirtualHost (HTTP proxy to container)
│   ├── entrypoint.sh                 ← Container startup script
│   └── rootcanal.env.example         ← Template for credentials
├── docker-compose.yml                ← Compose service definition
├── docker-entrypoint-initdb.d/       ← Drop your *.sql dump here (git-ignored)
└── DEPLOY.md                         ← This file
```

None of the original application files were modified.
