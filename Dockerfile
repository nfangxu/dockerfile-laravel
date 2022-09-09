FROM php:8.1.10-fpm-buster
ARG VERSION

# Copy the PHP configuration file
COPY ./php.ini /usr/local/etc/php/php.ini

# Supervisor Config
COPY ./supervisord.conf /etc/supervisord.conf
# Start Supervisord
COPY ./cmd.sh /

#COPY ./sources.list /etc/apt/sources.list

# Install PHP extensions
RUN apt-get update -yqq \
    # Install libs for building PHP exts
    && apt-get install -yqq --no-install-recommends \
        libcurl4-openssl-dev \
        pkg-config \
        libssl-dev \
        libzip-dev \
        libicu-dev \
        libpq-dev \
        libmcrypt-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        librdkafka-dev \
        unzip \
        nano \
        default-mysql-client \
        iputils-ping \
        curl \
        supervisor \
        cron \
        nginx \
        git \
        openssh-server \ 
        openssl \
    # Install PHP Exts
    && docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
    && docker-php-ext-install \
        intl \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        zip \
        bcmath \
        opcache \
    && docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && pecl install redis \
    && pecl install rdkafka \
    && pecl install mongodb \
    && pecl install grpc \
    && pecl install protobuf \
    && docker-php-ext-enable redis rdkafka mongodb grpc protobuf\
    # Remove dev packages
    && apt-get remove --purge -yyq libicu-dev \
        libpq-dev \
        libmcrypt-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
    && rm -r /var/lib/apt/lists/*

# Configure PHP
COPY ./www.conf /usr/local/etc/php-fpm.d/www.conf

# Nginx configuration
RUN sed -i -e"s/worker_processes  1/worker_processes 5/" /etc/nginx/nginx.conf && \
    sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf && \
    sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 128m;\n\tproxy_buffer_size 256k;\n\tproxy_buffers 4 512k;\n\tproxy_busy_buffers_size 512k/" /etc/nginx/nginx.conf && \
    echo "daemon off;" >> /etc/nginx/nginx.conf

# Add nginx and php config for Laravel
COPY ./nginx.conf /etc/nginx/sites-available/default.conf
RUN rm -f /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default

RUN chmod 755 /cmd.sh && \
    touch /var/log/cron.log && \
    touch /etc/cron.d/crontasks && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

EXPOSE 80

ENTRYPOINT ["/bin/bash", "/cmd.sh"]
CMD []
