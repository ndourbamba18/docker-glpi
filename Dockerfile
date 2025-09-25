FROM debian:12.5

LABEL org.opencontainers.image.authors="github@diouxx.be"

ENV DEBIAN_FRONTEND=noninteractive \
    TIMEZONE=Africa/Dakar

RUN apt update \
 && apt install --yes ca-certificates apt-transport-https lsb-release wget curl \
 && curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg \
 && sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' \
 && apt update \
 && apt install --yes --no-install-recommends \
    apache2 \
    php8.3 \
    php8.3-mysql \
    php8.3-bcmath \
    php8.3-ldap \
    php8.3-xmlrpc \
    php8.3-imap \
    php8.3-curl \
    php8.3-gd \
    php8.3-mbstring \
    php8.3-xml \
    php-cas \
    php8.3-intl \
    php8.3-zip \
    php8.3-bz2 \
    php8.3-redis \
    cron \
    jq \
    libldap-2.5-0 \
    libldap-common \
    libsasl2-2 \
    libsasl2-modules \
    libsasl2-modules-db \
 && rm -rf /var/lib/apt/lists/*

# Télécharger et installer GLPI pendant le build
RUN wget -q https://github.com/glpi-project/glpi/releases/download/10.0.20/glpi-10.0.20.tgz -O /tmp/glpi.tgz \
 && tar -xzf /tmp/glpi.tgz -C /var/www/html/ \
 && rm /tmp/glpi.tgz \
 && mv /var/www/html/glpi /var/www/html/glpi-original \
 && mkdir -p /var/www/html/glpi \
 && cp -r /var/www/html/glpi-original/* /var/www/html/glpi/ \
 && rm -rf /var/www/html/glpi-original \
 && chown -R 1001:0 /var/www/html/glpi

# Configurer Apache pour servir GLPI depuis la racine
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
 && sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/glpi|' /etc/apache2/sites-available/000-default.conf \
 && sed -i 's|:80>|:8080>|' /etc/apache2/sites-available/000-default.conf \
 && echo "ServerName localhost" >> /etc/apache2/apache2.conf \
 && echo "<Directory /var/www/html/glpi>" >> /etc/apache2/apache2.conf \
 && echo "    Options FollowSymlinks" >> /etc/apache2/apache2.conf \
 && echo "    AllowOverride All" >> /etc/apache2/apache2.conf \
 && echo "    Require all granted" >> /etc/apache2/apache2.conf \
 && echo "</Directory>" >> /etc/apache2/apache2.conf \
 && a2enmod rewrite \
 && chown -R 1001:0 /etc/apache2 /etc/php /var/log/apache2 /var/run/apache2 /var/www/html \
 && chmod -R g+rwX /var/www/html /etc/apache2 /etc/php /var/log/apache2 /var/run/apache2

# Créer un fichier index.php redirigeant vers GLPI
RUN echo "<?php header('Location: /glpi/'); ?>" > /var/www/html/index.php

# L'utilisateur OpenShift
USER 1001

# Port 8080
EXPOSE 8080

# Lancer apache
CMD ["apache2ctl", "-D", "FOREGROUND"]
