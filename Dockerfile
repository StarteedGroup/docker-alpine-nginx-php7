FROM nginx:mainline-alpine

MAINTAINER prometherion <dario.tranchitella@starteed.com>

# Log variables
ENV ENABLE_LOG=1
ENV LOG_FILES='/var/log/php-fpm.log /var/log/nginx.log /var/www/storage/logs/laravel.log /var/www/storage/logs/lumen.log'
ENV PAPERTRAIL_DOMAIN=logs4.papertrailapp.com
ENV PAPERTRAIL_PORT=10100
ENV LOG_HOSTNAME=crowdfunding

# PHP variables
ENV MAX_FILESIZE=20M

# Updating Alpine repositories
RUN echo 'http://alpine.gliderlabs.com/alpine/edge/main' > /etc/apk/repositories && \
    echo 'http://alpine.gliderlabs.com/alpine/edge/community' >> /etc/apk/repositories && \
    echo 'http://alpine.gliderlabs.com/alpine/edge/testing' >> /etc/apk/repositories

# Configuring rsyslog, utilities, php and extensions
RUN sed -i -e "s/v3.4/edge/" /etc/apk/repositories && \
    apk update && \
    apk add -t build-dependencies ca-certificates \
    && apk add --update --no-cache \
    bash \
    rsyslog \
    supervisor \
    openssh-client \
    openssl-dev \
    git \
    wget \
    curl \
    php7-fpm \
    php7-pdo \
    php7-pdo_mysql \
    php7-mysqlnd \
    php7-mysqli \
    php7-mcrypt \
    php7-mbstring \
    php7-ctype \
    php7-zlib \
    php7-gd \
    php7-exif \
    php7-intl \
    php7-sqlite3 \
    php7-pdo_pgsql \
    php7-pgsql \
    php7-xml \
    php7-xsl \
    php7-curl \
    php7-openssl \
    php7-iconv \
    php7-json \
    php7-phar \
    php7-soap \
    php7-dom \
    php7-zip \
    php7-session \
    php7-redis

# Installing remote_syslog for PaperTrail log collection
RUN wget -q -O - https://github.com/papertrail/remote_syslog2/releases/download/v0.19/remote_syslog_linux_amd64.tar.gz | tar -zxf - \
    && apk del build-dependencies \
    && rm -rf /var/cache/apk/*

# Tweak PHP-FPM config
RUN sed -i -E \
        -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" \
        -e "s/upload_max_filesize = (.*)/upload_max_filesize = $MAX_FILESIZE/g" \
        -e "s/post_max_size\s*=\s*8M/post_max_size = $MAX_FILESIZE/g" \
        -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" \
         /etc/php7/php.ini && \
    sed -i \
        -e "s/;daemonize\s*=\s*yes/daemonize = no/g" \
        -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" \
        -e "s/pm.max_children = 4/pm.max_children = 4/g" \
        -e "s/pm.start_servers = 2/pm.start_servers = 3/g" \
        -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" \
        -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" \
        -e "s/pm.max_requests = 500/pm.max_requests = 200/g" \
        -e "s/user = nobody/user = nginx/g" \
        -e "s/group = nobody/group = nginx/g" \
        -e "s/;listen.mode = 0660/listen.mode = 0666/g" \
        -e "s/;listen.owner = nobody/listen.owner = nginx/g" \
        -e "s/;listen.group = nobody/listen.group = nginx/g" \
        -e "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g" \
        -e "s/^;clear_env = no$/clear_env = no/" \
        -e "s/request_terminate_timeout = (.*)/request_terminate_timeout = 300/g" \
        /etc/php7/php-fpm.d/www.conf && \
    ln -s /etc/php7/php.ini /etc/php7/conf.d/php.ini && \
    find /etc/php7/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# Symbolic link for naked PHP command from CLI
RUN ln -s /usr/bin/php7 /usr/bin/php

# Installing Composer with Prestissimo
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --install-dir=/usr/bin --filename=composer && \
    php -r "unlink('composer-setup.php');" && \
    composer global require "hirak/prestissimo:^0.3";

# Configuring supervisord
ADD conf/supervisord.conf /etc/supervisord.conf

# NGINX site conf
ADD nginx/default.conf /etc/nginx/conf.d/default.conf

# Add Script
ADD scripts/start.sh /start.sh
RUN chmod 755 /start.sh

WORKDIR /var/www

CMD ["/start.sh"]