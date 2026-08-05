FROM debian:bookworm-slim

ARG GID=1001
ARG UID=1001
ARG TZ=UTC
# PHP version to build. Override at build time, e.g.:
#   docker build --build-arg PHP_VERSION=8.1 .
#   docker build --build-arg PHP_VERSION=8.4 .
#   REMOVE  php${PHP_VERSION}-opcache for php 8.5
ARG PHP_VERSION=8.3
ARG PHP_MODULES="php${PHP_VERSION}-bcmath php${PHP_VERSION}-cli php${PHP_VERSION}-common php${PHP_VERSION}-curl php${PHP_VERSION}-fpm php${PHP_VERSION}-gd php${PHP_VERSION}-imagick php${PHP_VERSION}-intl php${PHP_VERSION}-mbstring php${PHP_VERSION}-mcrypt php${PHP_VERSION}-mysql php${PHP_VERSION}-opcache php${PHP_VERSION}-pgsql php${PHP_VERSION}-readline php${PHP_VERSION}-redis php${PHP_VERSION}-soap php${PHP_VERSION}-sqlite3 php${PHP_VERSION}-xml php${PHP_VERSION}-zip"
# Optional, space-separated Debian packages to install in the image.
ARG EXTRA_PACKAGES=""

ENV DEBIAN_FRONTEND=noninteractive
ENV PHP_VERSION=${PHP_VERSION}
ENV php_conf=/etc/php/${PHP_VERSION}/fpm/php.ini
ENV fpm_www_conf=/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
ENV php_fpm_conf=/etc/php/${PHP_VERSION}/fpm/php-fpm.conf
ENV nginx_conf=/etc/nginx/nginx.conf
ENV COMPOSER_VERSION=2.8.6

COPY --from=ochinchina/supervisord:latest /usr/local/bin/supervisord /usr/local/bin/supervisord

RUN set -eux; \
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone; \
    groupadd -g ${GID} nginx && useradd -u ${UID} -g ${GID} -r -s /usr/sbin/nologin nginx; \
    apt-get update && apt-get install --no-install-recommends -y \
        curl gnupg dirmngr apt-transport-https ca-certificates; \
    mkdir -p /run/php /run/nginx /var/cache/nginx; \
    # Nginx GPG
    curl -fsSL https://nginx.org/keys/nginx_signing.key \
      | gpg --dearmor \
      | tee /usr/share/keyrings/nginx.gpg > /dev/null; \
    echo "deb [signed-by=/usr/share/keyrings/nginx.gpg] \
      http://nginx.org/packages/mainline/debian bookworm nginx" > /etc/apt/sources.list.d/nginx.list; \
    curl -fsSL https://packages.sury.org/php/apt.gpg -o /etc/apt/trusted.gpg.d/php.gpg; \
    echo "deb https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/php.list; \
    apt-get update && apt-get install --no-install-recommends -y nano zip unzip nginx imagemagick ghostscript ${PHP_MODULES} ${EXTRA_PACKAGES}; \
    # Patch ImageMagick policy.xml to allow PDF conversions
    sed -i 's/<policy domain="coder" rights="none" pattern="PDF"/<policy domain="coder" rights="read|write" pattern="PDF"/' /etc/ImageMagick-6/policy.xml || true; \
    sed -i 's/<policy domain="coder" rights="none" pattern="PS"/<policy domain="coder" rights="read|write" pattern="PS"/' /etc/ImageMagick-6/policy.xml || true; \
    # PHP Configurations
    sed -i \
        -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" \
        -e "s/memory_limit\s*=.*/memory_limit = 256M/" \
        -e "s/upload_max_filesize\s*=.*/upload_max_filesize = 100M/" \
        -e "s/post_max_size\s*=.*/post_max_size = 100M/" \
        -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/" \
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
    sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" "$php_fpm_conf"; \
    \
    # Version-agnostic symlinks so supervisord/nginx configs don't hardcode the PHP version
    ln -snf /usr/sbin/php-fpm${PHP_VERSION} /usr/sbin/php-fpm; \
    ln -snf /etc/php/${PHP_VERSION} /etc/php/current; \
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

# set default config
COPY ./default.conf /etc/nginx/sites-available/default

WORKDIR /app

CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]
