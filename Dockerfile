FROM php:8.2-apache

ARG PHP_MEMORY_LIMIT=256M
ARG PHP_MAX_EXECUTION_TIME=30
ARG PHP_UPLOAD_MAX_FILESIZE=20M
ARG PHP_POST_MAX_SIZE=20M

# Usar configuración de producción de PHP
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Instalar dependencias del sistema y extensiones PHP en un solo bloque
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpng-dev \
        libzip-dev \
        zlib1g-dev \
        libonig-dev \
        curl \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install -j$(nproc) \
        mysqli \
        pdo \
        pdo_mysql \
        zip \
        mbstring \
        gd

# Personalizar directivas de PHP en un único fichero custom.ini
RUN { \
        echo "memory_limit = ${PHP_MEMORY_LIMIT}"; \
        echo "max_execution_time = ${PHP_MAX_EXECUTION_TIME}"; \
        echo "upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}"; \
        echo "post_max_size = ${PHP_POST_MAX_SIZE}"; \
    } > /usr/local/etc/php/conf.d/custom-php.ini

# Configuración de seguridad de Apache
RUN a2enmod rewrite headers ssl \
    && sed -i 's/ServerTokens OS/ServerTokens Prod/' /etc/apache2/conf-available/security.conf \
    && sed -i 's/ServerSignature On/ServerSignature Off/' /etc/apache2/conf-available/security.conf

# Configurar directorio de logs de PHP
RUN mkdir -p /var/log/php \
    && chown -R www-data:www-data /var/log/php

# Ajustar permisos por defecto de /var/www/html
RUN chown -R www-data:www-data /var/www/html

# Nota: Apache gestiona internamente los procesos worker cambiando al usuario www-data.
# Se mantiene el proceso principal (master) como root para poder hacer bind al puerto 80.

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD curl -f http://localhost/ || exit 1
