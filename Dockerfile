FROM debian:bookworm-slim

ARG GID=1001
ARG UID=1001
ARG TZ=UTC
ARG TARGETARCH
ARG SUPERVISORD_VERSION=0.7.4
# PHP version to build. Override at build time, e.g.:
#   docker build --build-arg PHP_VERSION=8.1 .
#   docker build --build-arg PHP_VERSION=8.5 .
ARG PHP_VERSION=8.5
ARG PHP_MODULES="php${PHP_VERSION}-bcmath php${PHP_VERSION}-cli php${PHP_VERSION}-common php${PHP_VERSION}-curl php${PHP_VERSION}-fpm php${PHP_VERSION}-gd php${PHP_VERSION}-imagick php${PHP_VERSION}-intl php${PHP_VERSION}-mbstring php${PHP_VERSION}-mcrypt php${PHP_VERSION}-mysql php${PHP_VERSION}-pgsql php${PHP_VERSION}-readline php${PHP_VERSION}-redis php${PHP_VERSION}-soap php${PHP_VERSION}-sqlite3 php${PHP_VERSION}-xml php${PHP_VERSION}-zip"
# Optional, space-separated Debian packages to install in the image.
ARG EXTRA_PACKAGES=""
ARG LARAVEL_SCHEDULER_AUTOSTART=false
ARG LARAVEL_QUEUE_AUTOSTART=false

ENV DEBIAN_FRONTEND=noninteractive
ENV PHP_VERSION=${PHP_VERSION}
ENV php_conf=/etc/php/fpm/php.ini
ENV fpm_www_conf=/etc/php/fpm/pool.d/www.conf
ENV php_fpm_conf=/etc/php/fpm/php-fpm.conf
ENV nginx_conf=/etc/nginx/nginx.conf
ENV COMPOSER_VERSION=2.8.6

RUN set -eux; \
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone; \
    groupadd -g ${GID} nginx && useradd -u ${UID} -g ${GID} -r -s /usr/sbin/nologin nginx; \
    apt-get update && apt-get install --no-install-recommends -y \
        curl gnupg dirmngr apt-transport-https ca-certificates; \
    case "${TARGETARCH}" in \
        amd64) SUPERVISORD_ASSET="supervisord_linux_amd64"; SUPERVISORD_SHA256="3b7cd54e24fdf473196224411cf06e14d245b95208ce56315713472b78c08e9a" ;; \
        arm64) SUPERVISORD_ASSET="supervisord_linux_arm64"; SUPERVISORD_SHA256="507ae471d96e19fab102151f75b2d52277283d0bdd3ae4137b1265f5ac867bb7" ;; \
        *) echo "Unsupported target architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/ochinchina/supervisord/releases/download/v${SUPERVISORD_VERSION}/${SUPERVISORD_ASSET}" \
        -o /usr/local/bin/supervisord; \
    printf '%s  %s\n' "${SUPERVISORD_SHA256}" /usr/local/bin/supervisord | sha256sum -c -; \
    chmod +x /usr/local/bin/supervisord; \
    mkdir -p /run/php /run/nginx /var/cache/nginx; \
    # Nginx GPG
    curl -fsSL https://nginx.org/keys/nginx_signing.key \
      | gpg --dearmor \
      | tee /usr/share/keyrings/nginx.gpg > /dev/null; \
    echo "deb [signed-by=/usr/share/keyrings/nginx.gpg] \
      http://nginx.org/packages/mainline/debian bookworm nginx" > /etc/apt/sources.list.d/nginx.list; \
    # Debian PHP packages from Ondrej Sury; do not use the Ubuntu-only ppa:ondrej/php here.
    curl -fsSL https://packages.sury.org/php/apt.gpg -o /etc/apt/trusted.gpg.d/php.gpg; \
    echo "deb https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/php.list; \
    apt-get update; \
    PHP_OPCACHE_PACKAGE="php${PHP_VERSION}-opcache"; \
    if ! apt-cache show "${PHP_OPCACHE_PACKAGE}" > /dev/null 2>&1; then \
        PHP_OPCACHE_PACKAGE=""; \
    fi; \
    apt-get install --no-install-recommends -y nano zip unzip nginx imagemagick ghostscript ${PHP_MODULES} ${PHP_OPCACHE_PACKAGE} ${EXTRA_PACKAGES}; \
    # Version-agnostic PHP-FPM paths for configuration and process startup
    ln -snf /etc/php/${PHP_VERSION}/fpm /etc/php/fpm; \
    ln -snf /usr/sbin/php-fpm${PHP_VERSION} /usr/sbin/php-fpm; \
    # Patch ImageMagick policy.xml to allow PDF conversions
    sed -i 's/<policy domain="coder" rights="none" pattern="PDF"/<policy domain="coder" rights="read|write" pattern="PDF"/' /etc/ImageMagick-6/policy.xml || true; \
    sed -i 's/<policy domain="coder" rights="none" pattern="PS"/<policy domain="coder" rights="read|write" pattern="PS"/' /etc/ImageMagick-6/policy.xml || true; \
    # PHP Configurations
    sed -Ei \
        -e 's/;?cgi\.fix_pathinfo\s*=.*/cgi.fix_pathinfo=0/' \
        -e 's/;?memory_limit\s*=.*/memory_limit = 256M/' \
        -e 's/;?upload_max_filesize\s*=.*/upload_max_filesize = 100M/' \
        -e 's/;?post_max_size\s*=.*/post_max_size = 100M/' \
        -e 's/;?max_input_nesting_level\s*=.*/max_input_nesting_level = 128/' \
        -e 's/;?max_input_vars\s*=.*/max_input_vars = 10000/' \
        -e 's/;?variables_order\s*=\s*"GPCS"/variables_order = "EGPCS"/' \
        "$php_conf"; \
    \
    # FPM Configurations
    sed -i \
        -e "s/;daemonize\s*=.*/daemonize = no/" \
        -e "s/;catch_workers_output\s*=.*/catch_workers_output = yes/" \
        -e "s/pm.max_children =.*/pm.max_children = 4/" \
        -e "s/pm.start_servers =.*/pm.start_servers = 3/" \
        -e "s/pm.min_spare_servers =.*/pm.min_spare_servers = 2/" \
        -e "s/pm.max_spare_servers =.*/pm.max_spare_servers = 4/" \
        -e "s/pm.max_requests =.*/pm.max_requests = 200/" \
        -e "s#^listen = .*#listen = /run/php/php-fpm.sock#" \
        -e "s/www-data/nginx/g" \
        -e "s/^;clear_env = no$/clear_env = no/" \
        "$fpm_www_conf"; \
    sed -i \
        -e "s/;daemonize\s*=\s*yes/daemonize = no/g" \
        -e "s#^pid[[:space:]]*=.*#pid = /run/php/php-fpm.pid#" \
        -e "s#^error_log[[:space:]]*=.*#error_log = /var/log/php-fpm.log#" \
        -e "s#^include[[:space:]]*=.*#include=/etc/php/fpm/pool.d/*.conf#" \
        "$php_fpm_conf"; \
    \
    # nginx Configuration
    sed -i -e "s/www-data/nginx/g" "$nginx_conf"; \
    \
    # Install Composer
    curl -fsSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION}; \
    \
    # Cleanup
    apt-get purge -y --auto-remove; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*; \
    touch /var/log/php-fpm.log /run/nginx.pid; \
    chown ${UID}:${GID} /etc/nginx /var/log/nginx /var/cache/nginx /run/nginx.pid /run/php /var/log/php-fpm.log -R

# Supervisor config
COPY ./supervisord.conf /etc/supervisord.conf
RUN set -eux; \
    case "${LARAVEL_SCHEDULER_AUTOSTART}" in true|false) ;; *) echo "LARAVEL_SCHEDULER_AUTOSTART must be true or false" >&2; exit 1 ;; esac; \
    case "${LARAVEL_QUEUE_AUTOSTART}" in true|false) ;; *) echo "LARAVEL_QUEUE_AUTOSTART must be true or false" >&2; exit 1 ;; esac; \
    sed -i \
        -e "/^\[program:laravel-scheduler\]$/,/^\[/ s/^autostart=.*/autostart=${LARAVEL_SCHEDULER_AUTOSTART}/" \
        -e "/^\[program:laravel-queue\]$/,/^\[/ s/^autostart=.*/autostart=${LARAVEL_QUEUE_AUTOSTART}/" \
        /etc/supervisord.conf

# nginx.org packages load virtual hosts from /etc/nginx/conf.d/*.conf.
COPY ./default.conf /etc/nginx/conf.d/default.conf

COPY ./start.sh /start.sh
RUN chmod a+x /start.sh

WORKDIR /app

CMD ["/start.sh"]
