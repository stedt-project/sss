#!/bin/bash
# ============================================================================
# STEDT RootCanal – container entrypoint
#
# Responsibilities (in order):
#   1. Initialise the MariaDB data directory if it is empty (first run).
#   2. Start MariaDB in the background.
#   3. Wait until the database accepts connections.
#   4. Create the 'stedt' database and application user (idempotent).
#   5. Load any *.sql / *.sql.gz dumps found in /docker-entrypoint-initdb.d/
#      (only on the very first run, guarded by a marker file).
#   6. Write /home/stedt-cgi/rootcanal.conf from environment variables.
#   7. Exec Apache2 in the foreground (becomes PID 1 from this point).
#
# Environment variables (all optional – safe defaults are shown):
#   DB_NAME       stedt               Name of the application database
#   DB_USER       stedt               MariaDB username for the application
#   DB_PASS       changeme            Password for DB_USER
#   DB_ROOT_PASS  (empty)             Root password; leave blank for socket auth
#   IGNORE_SSL    1                   Set to 0 if running behind HTTPS termination
# ============================================================================
set -euo pipefail

# ── Configuration from environment ───────────────────────────────────────────
DB_NAME="${DB_NAME:-stedt}"
DB_USER="${DB_USER:-stedt}"
DB_PASS="${DB_PASS:-changeme}"
DB_ROOT_PASS="${DB_ROOT_PASS:-}"
IGNORE_SSL="${IGNORE_SSL:-1}"

CONF_FILE="/home/stedt-cgi/rootcanal.conf"
INIT_MARKER="/var/lib/mysql/.stedt_initialized"

log() { echo "[entrypoint] $*"; }

# ── Step 1: initialise MariaDB data directory if empty ───────────────────────
if [ ! -d /var/lib/mysql/mysql ]; then
    log "Initialising fresh MariaDB data directory …"
    mysql_install_db --user=mysql --datadir=/var/lib/mysql --skip-test-db \
        > /dev/null 2>&1
    log "Data directory initialised."
fi

# ── Step 2: start MariaDB in the background ───────────────────────────────────
log "Starting MariaDB …"
# Run as the mysql user; --console sends logs to stderr so they appear in
# 'docker logs'.  The process is backgrounded so we can do setup below.
/usr/sbin/mysqld --user=mysql --console &
MYSQLD_PID=$!

# ── Step 3: wait for MariaDB to accept connections ────────────────────────────
log "Waiting for MariaDB to become ready …"
for i in $(seq 1 60); do
    if mysqladmin ping --silent 2>/dev/null; then
        log "MariaDB is ready (after ${i}s)."
        break
    fi
    if [ $i -eq 60 ]; then
        log "ERROR: MariaDB did not start within 60 seconds – aborting."
        kill "$MYSQLD_PID" 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

# ── Step 4: create database and application user (idempotent) ─────────────────
log "Ensuring database '${DB_NAME}' and user '${DB_USER}' exist …"

# Use socket authentication for root (no password needed inside the container)
mysql -u root <<-SQL
    CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
        CHARACTER SET utf8
        COLLATE utf8_unicode_ci;

    CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost'
        IDENTIFIED BY '${DB_PASS}';

    GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';

    -- CGI::Session stores sessions in a table called 'sessions'.
    -- The DBI driver creates it automatically, but we pre-create it here
    -- with the correct schema to avoid any first-request delay or error.
    CREATE TABLE IF NOT EXISTS \`${DB_NAME}\`.sessions (
        id           CHAR(32)     NOT NULL PRIMARY KEY,
        a_session    TEXT         NOT NULL,
        LastModified TIMESTAMP    NOT NULL
                     DEFAULT CURRENT_TIMESTAMP
                     ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

    FLUSH PRIVILEGES;
SQL

# Optional: set a root password if DB_ROOT_PASS is provided
if [ -n "${DB_ROOT_PASS}" ]; then
    log "Setting MariaDB root password …"
    mysql -u root -e \
        "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';"
fi

# ── Step 5: load SQL dump(s) on first run only ────────────────────────────────
if [ ! -f "${INIT_MARKER}" ]; then
    shopt -s nullglob   # don't error if no files match

    for f in /docker-entrypoint-initdb.d/*.sql; do
        log "Loading SQL dump: $(basename "$f") …"
        mysql -u root "${DB_NAME}" < "$f"
    done

    for f in /docker-entrypoint-initdb.d/*.sql.gz; do
        log "Loading gzipped SQL dump: $(basename "$f") …"
        zcat "$f" | mysql -u root "${DB_NAME}"
    done

    shopt -u nullglob
    touch "${INIT_MARKER}"
    log "Database initialisation complete."
else
    log "Database already initialised (marker found); skipping dump loading."
fi

# ── Step 6: write rootcanal.conf ──────────────────────────────────────────────
log "Writing ${CONF_FILE} …"
# The format is <tab-separated key/value> as expected by
# CGI::Application::Plugin::ConfigAuto in its 'conf' (not ini) mode.
cat > "${CONF_FILE}" <<EOF
login	${DB_USER}
pass	${DB_PASS}
ignore_ssl	${IGNORE_SSL}
EOF

chown www-data:www-data "${CONF_FILE}"
chmod 640 "${CONF_FILE}"

# ── Step 7: exec Apache in the foreground ─────────────────────────────────────
# Sourcing envvars sets APACHE_RUN_DIR etc. required by apache2ctl.
# shellcheck source=/dev/null
source /etc/apache2/envvars
mkdir -p "${APACHE_RUN_DIR}" "${APACHE_LOCK_DIR}"

log "Starting Apache2 …"
# 'exec' replaces this script with Apache, making it PID 1.
exec apache2 -D FOREGROUND
