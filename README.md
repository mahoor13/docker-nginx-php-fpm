[![Docker Hub; mahoor13/docker-nginx-php-fpm](https://img.shields.io/badge/docker%20hub-wyveo%2Fnginx--php--fpm-blue.svg?&logo=docker&style=for-the-badge)](https://hub.docker.com/r/mahoor13/docker-nginx-php-fpm/) [![](https://badges.weareopensource.me/docker/pulls/mahoor13/docker-nginx-php-fpm?style=for-the-badge)](https://hub.docker.com/r/mahoor13/docker-nginx-php-fpm/) [![](https://img.shields.io/docker/image-size/mahoor13/docker-nginx-php-fpm/latest?style=for-the-badge)](https://hub.docker.com/r/mahoor13/docker-nginx-php-fpm/) [![nginx 1.25.2](https://img.shields.io/badge/nginx-1.25.2-brightgreen.svg?&logo=nginx&logoColor=white&style=for-the-badge)](https://nginx.org/en/CHANGES) [![php 8.3.11](https://img.shields.io/badge/php--fpm-8.3.11-blue.svg?&logo=php&logoColor=white&style=for-the-badge)](https://secure.php.net/releases/8_3_11.php) [![License MIT](https://img.shields.io/badge/license-MIT-blue.svg?&style=for-the-badge)](https://github.com/mahoor13/docker-nginx-php-fpm/blob/master/LICENSE)

## Introduction

This is a Dockerfile to build a debian based container image running nginx and php-fpm 8.3.x & Composer.

## Building from source

To build from source you need to clone the git repo and run docker build:

```
$ git clone https://github.com/mahoor13/docker-nginx-php-fpm.git
$ cd docker-nginx-php-fpm
```

followed by

```
$ docker buildx build . -t mahoor13/nginx-php-fpm:php83 --progress plain --build-arg UID=1001 --build-arg GID=1001 --build-arg TZ=Asia/Tehran # PHP 8.3.x
```

## Pulling from Docker Hub

```
$ docker pull mahoor13/nginx-php-fpm:php83
```

## Running

To run the container:

```
$ sudo docker run -d mahoor13/nginx-php-fpm:php83
```

Default web root:

```
/app
```
