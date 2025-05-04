FROM debian:bookworm-slim

ARG GID=1001
ARG UID=1001
ARG TZ=UTC
ARG PHP_MODULES="php8.3-bcmath php8.3-cli php8.3-common php8.3-curl php8.3-fpm php8.3-gd php8.3-intl php8.3-mbstring php8.3-mcrypt php8.3-mysql php8.3-opcache php8.3-pgsql php8.3-readline php8.3-redis php8.3-soap php8.3-sqlite3 php8.3-xml php8.3-zip"

ENV DEBIAN_FRONTEND noninteractive
ENV php_conf /etc/php/8.3/fpm/php.ini
ENV fpm_www_conf /etc/php/8.3/fpm/pool.d/www.conf
ENV php_fpm_conf /etc/php/8.3/fpm/php-fpm.conf
ENV nginx_conf /etc/nginx/nginx.conf
ENV COMPOSER_VERSION 2.8.6

COPY --from=ochinchina/supervisord:latest /usr/local/bin/supervisord /usr/local/bin/supervisord

RUN set -eux; \
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone; \
    groupadd -g ${GID} nginx && useradd -u ${UID} -g ${GID} -r -s /usr/sbin/nologin nginx; \
    apt-get update && apt-get install --no-install-recommends -y \
        curl gnupg dirmngr apt-transport-https ca-certificates; \
    mkdir -p /run/php /run/nginx /var/cache/nginx; \
    curl -fsSL https://packages.sury.org/php/apt.gpg -o /etc/apt/trusted.gpg.d/php.gpg; \
    echo "deb https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/php.list; \
    apt-get update && apt-get install --no-install-recommends -y nano zip unzip nginx ${PHP_MODULES}; \
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
        -e "s/www-data/nginx/g" \
        -e "s/^;clear_env = no$/clear_env = no/" \
        "$fpm_www_conf"; \
    sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" "$php_fpm_conf"; \
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
