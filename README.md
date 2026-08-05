[![Docker Hub; mahoor13/docker-nginx-php-fpm](https://img.shields.io/badge/docker%20hub-mahoor13%2Fdocker--nginx--php--fpm-blue.svg?&logo=docker&style=for-the-badge)](https://hub.docker.com/r/mahoor13/docker-nginx-php-fpm/) [![](https://badges.weareopensource.me/docker/pulls/mahoor13/docker-nginx-php-fpm?style=for-the-badge)](https://hub.docker.com/r/mahoor13/docker-nginx-php-fpm/) [![](https://img.shields.io/docker/image-size/mahoor13/docker-nginx-php-fpm/latest?style=for-the-badge)](https://hub.docker.com/r/mahoor13/docker-nginx-php-fpm/) [![nginx 1.25.2](https://img.shields.io/badge/nginx-1.25.2-brightgreen.svg?&logo=nginx&logoColor=white&style=for-the-badge)](https://nginx.org/en/CHANGES) [![php 8.3.11](https://img.shields.io/badge/php--fpm-8.3.11-blue.svg?&logo=php&logoColor=white&style=for-the-badge)](https://secure.php.net/releases/8_3_11.php) [![License MIT](https://img.shields.io/badge/license-MIT-blue.svg?&style=for-the-badge)](https://github.com/mahoor13/docker-nginx-php-fpm/blob/master/LICENSE)

## Introduction

This is a Dockerfile to build a debian based container image running nginx and php-fpm & Composer.

The PHP version is configurable at build time (defaults to 8.3.x), and the image ships with:

- **Selectable PHP version** via the `PHP_VERSION` build arg (e.g. `8.1`, `8.2`, `8.3`, `8.4`, `8.5`).
- **ImageMagick + Ghostscript** with `policy.xml` patched to allow **PDF/PS conversions**.
- **Supervisord-managed** `php-fpm`, `nginx`, plus optional **Laravel scheduler** (`schedule:work`) and **Laravel queue** (`queue:work`) workers.
- Long-running request support: nginx `proxy_*`/`send`/`fastcgi_read` timeouts set to `600s`.
- Automatic `composer install` on first start when `/app/composer.json` is present and `vendor/` is missing.

## Building from source

To build from source you need to clone the git repo and run docker build:

```
$ git clone https://github.com/mahoor13/docker-nginx-php-fpm.git
$ cd docker-nginx-php-fpm
```

followed by

```
$ docker buildx build . -t mahoor13/nginx-php-fpm:php83 --progress plain --build-arg UID=1001 --build-arg GID=1001 --build-arg TZ=Asia/Tehran # PHP 8.3.x (default)
```

### Building a different PHP version

Override the `PHP_VERSION` build arg to build any supported version:

```
$ docker buildx build . -t mahoor13/nginx-php-fpm:php81 --build-arg PHP_VERSION=8.1 # PHP 8.1.x
$ docker buildx build . -t mahoor13/nginx-php-fpm:php84 --build-arg PHP_VERSION=8.4 # PHP 8.4.x
$ docker buildx build . -t mahoor13/nginx-php-fpm:php85 --build-arg PHP_VERSION=8.5 # PHP 8.5.x
```

The image uses the Ondrej Sury repository for Debian. Do not add the Ubuntu-only `ppa:ondrej/php` repository or install `software-properties-common` for this purpose.

### Installing extra packages

Use the `EXTRA_PACKAGES` build arg to install additional Debian packages. Pass package names as a space-separated list:

```
$ docker buildx build . -t mahoor13/nginx-php-fpm:custom --build-arg EXTRA_PACKAGES="git jq"
```

Ghostscript (the `ghostscript` Debian package, which provides the `gs` command) is already included in the base image. If it were not bundled, it could be added in the same way:

```
$ docker buildx build . -t mahoor13/nginx-php-fpm:with-gs --build-arg EXTRA_PACKAGES="ghostscript"
```

Or use the helper script, which builds, saves and deploys the image (tag derived from the version):

```
$ ./build-and-deploy.sh 8.4   # builds nginx-php-fpm:php84
$ ./build-and-deploy.sh 8.4 "git jq"   # also installs git and jq
```

## Laravel scheduler & queue

The bundled `supervisord.conf` defines two optional Laravel workers:

- `laravel-scheduler` — runs `php /app/artisan schedule:work` (autostarts).
- `laravel-queue` — runs `php /app/artisan queue:work` with 8 processes (**disabled by default**; set `autostart=true` in `supervisord.conf` to activate).

## Pulling from Docker Hub

```
$ docker pull mahoor13/nginx-php-fpm:php83
```

## Running

To run the container:

```
$ sudo docker run -d mahoor13/nginx-php-fpm:php83
```

Mount your application at `/app`. The nginx web root points to:

```
/app/public
```
