FROM php:8.3-apache AS dokuwiki-base

# additional extensions can be passed as build-arg
ARG PHP_EXTENSIONS=""

COPY root/build-deps.sh /
RUN /bin/bash /build-deps.sh

# --- Start Non-Root Modifications ---
# Create a non-root user and group
ARG APP_USER=dokuwiki
ARG APP_UID=1001
ARG APP_GID=1001

RUN groupadd -r -g ${APP_GID} ${APP_USER} && \
    useradd -r -m -u ${APP_UID} -g ${APP_USER} -s /sbin/nologin ${APP_USER}

# Ensure the web server's document root and storage are writable by the new user
# Apache's default document root is /var/www/html
RUN chown -R ${APP_USER}:${APP_USER} /var/www/html && \
    chmod -R ug+rwx /var/www/html
# --- End Non-Root Modifications ---


FROM dokuwiki-base

ARG DOKUWIKI_VERSION=stable

ENV PHP_UPLOADLIMIT=128M
ENV PHP_MEMORYLIMIT=256M
ENV PHP_TIMEZONE=UTC

COPY root /
RUN /bin/bash /build-setup.sh

# --- Start Non-Root Modifications (continued) ---
# Ensure the Dokuwiki storage volume is owned by the non-root user
VOLUME /storage
RUN chown -R ${APP_USER}:${APP_USER} /storage

# Ensure entrypoint and healthcheck scripts are executable by the non-root user
RUN chmod +x /dokuwiki-entrypoint.sh && \
    chmod +x /health.php # Assuming health.php is in /var/www/html and needs exec for curl

# Listen on a non-privileged port for OpenShift
EXPOSE 8080

HEALTHCHECK --timeout=5s \
    CMD curl --silent --fail-with-body http://localhost:8080/health.php || exit 1

# Switch to the non-root user for subsequent commands and when the container runs
USER ${APP_USER}

ENTRYPOINT ["/dokuwiki-entrypoint.sh"]
# --- End Non-Root Modifications (continued) ---