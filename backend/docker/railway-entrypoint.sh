#!/bin/sh
set -eu

if [ "$#" -gt 0 ] && [ "$1" != "apache2-foreground" ]; then
    exec docker-php-entrypoint "$@"
fi

port="${PORT:-8080}"
case "$port" in
    ''|*[!0-9]*)
        echo "PORT must be numeric." >&2
        exit 1
        ;;
esac

sed -ri "s/^Listen [0-9]+$/Listen ${port}/" /etc/apache2/ports.conf
sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${port}>/" /etc/apache2/sites-available/000-default.conf

exec docker-php-entrypoint apache2-foreground
