# ============================================================================
# STEDT RootCanal – Dockerfile
# Single container: Apache2 (mod_cgi) + MariaDB + all Perl/CPAN dependencies
#
# Layout inside the container mirrors the original server:
#   /home/stedt-cgi/
#     public_html/     ← Apache DocumentRoot; CGI scripts live here
#     pm/STEDT/        ← Custom Perl modules (../pm relative to the CGI script)
#     rootcanal.conf   ← DB credentials (written at startup from env-vars)
# ============================================================================
FROM ubuntu:22.04

LABEL maintainer="STEDT Project"
LABEL description="STEDT RootCanal Perl/CGI web application"

# ── Build-time environment ────────────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive

# Apache runtime env (required by apache2ctl)
ENV APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_LOG_DIR=/var/log/apache2 \
    APACHE_PID_FILE=/var/run/apache2/apache2.pid \
    APACHE_RUN_DIR=/var/run/apache2 \
    APACHE_LOCK_DIR=/var/lock/apache2

# ── System packages ───────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        # Web server
        apache2 \
        # Database server
        mariadb-server \
        # Perl toolchain
        perl \
        cpanminus \
        make \
        gcc \
        g++ \
        # Required to build DBD::mysql / DBD::MariaDB
        default-libmysqlclient-dev \
        libssl-dev \
        # Useful for the entrypoint wait-loop
        mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# ── Apache: switch to prefork MPM so mod_cgi (not mod_cgid) is used ──────────
# mod_cgi (prefork) sets CWD to the script's directory, which the app requires
# for Template Toolkit to find .tt files relative to the DocumentRoot.
# mod_cgid (event/worker MPM) does NOT guarantee this, breaking TT lookups.
RUN a2dismod mpm_event && \
    a2enmod mpm_prefork cgi rewrite && \
    a2dissite 000-default

# ── Perl/CPAN modules ─────────────────────────────────────────────────────────
# Install in waves so that failures are easier to pinpoint.
# --notest speeds the build considerably; remove it if you want test coverage.

# Low-level DBI layer first (needs libmysqlclient-dev at build time)
RUN cpanm --notest --quiet \
        CGI \
        DBI \
        DBD::mysql

# CGI::Application core + dispatcher
RUN cpanm --notest --quiet \
        CGI::Application \
        CGI::Application::Dispatch

# Template Toolkit and all CGI::Application plugins used by RootCanal
RUN cpanm --notest --quiet \
        Template \
        CGI::Application::Plugin::TT \
        CGI::Application::Plugin::Session \
        CGI::Application::Plugin::AutoRunmode \
        CGI::Application::Plugin::DBH \
        CGI::Application::Plugin::ConfigAuto \
        CGI::Application::Plugin::Redirect \
        CGI::Application::Plugin::ValidateRM

# Remaining dependencies
RUN cpanm --notest --quiet \
        CGI::Session \
        CGI::Session::ExpireSessions \
        Data::FormValidator \
        Mail::Sendmail \
        JSON \
        Encode

# ── Directory layout ──────────────────────────────────────────────────────────
RUN mkdir -p \
        /home/stedt-cgi/public_html \
        /home/stedt-cgi/pm \
        /docker-entrypoint-initdb.d

# ── Copy application files ────────────────────────────────────────────────────
# Web root: templates, static assets, and the two CGI entry points
COPY web/               /home/stedt-cgi/public_html/

# Custom Perl modules
COPY perl/STEDT/        /home/stedt-cgi/pm/STEDT/

# Main CGI dispatcher (hardcodes cfg_file => '/home/stedt-cgi/rootcanal.conf')
COPY rootcanal.pl       /home/stedt-cgi/public_html/rootcanal.pl

# Keep the shipped conf as a template; entrypoint writes the real one at startup
COPY rootcanal.conf     /home/stedt-cgi/rootcanal.conf.template

# ── Permissions ───────────────────────────────────────────────────────────────
RUN chmod 755 \
        /home/stedt-cgi/public_html/rootcanal.pl \
        /home/stedt-cgi/public_html/lg_table.cgi \
    && chown -R www-data:www-data \
        /home/stedt-cgi/public_html \
        /home/stedt-cgi/pm

# ── Apache virtual host ───────────────────────────────────────────────────────
COPY docker/apache-rootcanal.conf /etc/apache2/sites-available/rootcanal.conf
RUN a2ensite rootcanal

# ── Container entry point ─────────────────────────────────────────────────────
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Persist the MariaDB data directory across container restarts
VOLUME ["/var/lib/mysql"]

# HTTP only; TLS termination should be handled upstream (nginx, load-balancer)
EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
