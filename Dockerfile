FROM debian:12.5

LABEL org.opencontainers.image.authors="ndourbamba18@gmail.com"

ENV DEBIAN_FRONTEND=noninteractive \
    TIMEZONE=Africa/Dakar

# --- Installation de PHP et dépendances ---
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

# --- Installation de GLPI ---
RUN wget -q https://github.com/glpi-project/glpi/releases/download/11.0.1/glpi-11.0.1.tgz -O /tmp/glpi.tgz \
 && tar -xzf /tmp/glpi.tgz -C /var/www/html/ \
 && rm /tmp/glpi.tgz \
 && mv /var/www/html/glpi /var/www/html/glpi-original \
 && mkdir -p /var/www/html/glpi \
 && cp -r /var/www/html/glpi-original/* /var/www/html/glpi/ \
 && rm -rf /var/www/html/glpi-original

# --- Configuration Apache ---
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
 && echo "<VirtualHost *:8080>" > /etc/apache2/sites-available/000-default.conf \
 && echo "    DocumentRoot /var/www/html/glpi/public" >> /etc/apache2/sites-available/000-default.conf \
 && echo "    <Directory /var/www/html/glpi/public>" >> /etc/apache2/sites-available/000-default.conf \
 && echo "        Require all granted" >> /etc/apache2/sites-available/000-default.conf \
 && echo "        AllowOverride All" >> /etc/apache2/sites-available/000-default.conf \
 && echo "        Options FollowSymlinks" >> /etc/apache2/sites-available/000-default.conf \
 && echo "        RewriteEngine On" >> /etc/apache2/sites-available/000-default.conf \
 && echo "        RewriteCond %{REQUEST_FILENAME} !-f" >> /etc/apache2/sites-available/000-default.conf \
 && echo "        RewriteRule ^(.*)$ index.php [QSA,L]" >> /etc/apache2/sites-available/000-default.conf \
 && echo "    </Directory>" >> /etc/apache2/sites-available/000-default.conf \
 && echo "</VirtualHost>" >> /etc/apache2/sites-available/000-default.conf \
 && a2enmod rewrite

# --- Droits et permissions ---
RUN chown -R 1001:0 /var/www/html /etc/apache2 /etc/php /var/log/apache2 /var/run/apache2 \
 && chmod -R g+rwX /var/www/html /etc/apache2 /etc/php /var/log/apache2 /var/run/apache2

# --- Redirection par défaut ---
RUN echo "<?php header('Location: /glpi/'); ?>" > /var/www/html/index.php

# --- Volumes persistants pour OpenShift ---
VOLUME ["/var/www/html/glpi/files", "/var/www/html/glpi/config", "/var/www/html/glpi/plugins", "/var/www/html/glpi/marketplace"]

# --- Copie du script de démarrage ---
COPY glpi-start.sh /usr/local/bin/glpi-start.sh
RUN chmod +x /usr/local/bin/glpi-start.sh

# --- Utilisateur OpenShift ---
USER 1001

EXPOSE 8080

# --- Lancement via le script ---
CMD ["/usr/local/bin/glpi-start.sh"]
