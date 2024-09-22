
#!/bin/bash

docker build . -t nginx-php-fpm:php83
docker save nginx-php-fpm:php83 > nginx-php-fpm.php83
zip -9 nginx-php-fpm.php83.zip nginx-php-fpm.php83
scp nginx-php-fpm.php83.zip dockers:/tmp
rm nginx-php-fpm.php83.zip nginx-php-fpm.php83

ssh dockers "cd /tmp \
    && unzip nginx-php-fpm.php83.zip \
    && docker load -i nginx-php-fpm.php83 \
    && rm nginx-php-fpm.php83 nginx-php-fpm.php83.zip"
