#!/bin/bash
set -euo pipefail

# PHP version to build. Override as the first argument, e.g.:
#   ./build-and-deploy.sh 8.1
#   ./build-and-deploy.sh 8.4
# Pass optional Debian packages as the second argument, e.g.:
#   ./build-and-deploy.sh 8.4 "git jq"
PHP_VERSION="${1:-8.3}"
EXTRA_PACKAGES="${2:-}"
TAG="php${PHP_VERSION//./}"   # e.g. 8.3 -> php83
IMAGE="nginx-php-fpm:${TAG}"
ARTIFACT="nginx-php-fpm.${TAG}"

docker build . \
    --build-arg PHP_VERSION="${PHP_VERSION}" \
    --build-arg EXTRA_PACKAGES="${EXTRA_PACKAGES}" \
    -t "${IMAGE}"
docker save "${IMAGE}" > "${ARTIFACT}"
zip -9 "${ARTIFACT}.zip" "${ARTIFACT}"
scp "${ARTIFACT}.zip" dockers:/tmp
rm "${ARTIFACT}.zip" "${ARTIFACT}"

ssh dockers "cd /tmp \
    && unzip ${ARTIFACT}.zip \
    && docker load -i ${ARTIFACT} \
    && rm ${ARTIFACT} ${ARTIFACT}.zip"
