#!/bin/bash

# Update nginx to match worker_processes to no. of cpu's
procs=$(cat /proc/cpuinfo | grep processor | wc -l)
sed -i -e "s/worker_processes  1/worker_processes $procs/" /etc/nginx/nginx.conf

# Always chown webroot for better mounting
chown -Rf nginx:nginx /usr/share/nginx/html

# Run composer install if needed
if [ -f "/app/composer.json" ] && [ ! -d "/app/vendor" ]; then
    echo "composer.json found and vendor directory missing. Running composer install..."
    cd /app
    composer install --no-interaction --prefer-dist --optimize-autoloader
fi

set -eux
case "${LARAVEL_SCHEDULER_AUTOSTART:-}" in
true|false)
    sed -i \
        -e "/^\[program:laravel-scheduler\]$/,/^\[/ s/^autostart=.*/autostart=${LARAVEL_SCHEDULER_AUTOSTART}/" \
        /etc/supervisord.conf
    ;;
esac

case "${LARAVEL_QUEUE_AUTOSTART:-}" in
true|false)
    sed -i \
        -e "/^\[program:laravel-queue\]$/,/^\[/ s/^autostart=.*/autostart=${LARAVEL_QUEUE_AUTOSTART}/" \
        /etc/supervisord.conf
    ;;
esac

# Start supervisord and services
/usr/local/bin/supervisord -c /etc/supervisord.conf
