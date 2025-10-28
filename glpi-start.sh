#!/bin/bash

# Contrôle du choix de version ou prise de la latest
[[ ! "$VERSION_GLPI" ]] \
	&& VERSION_GLPI=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | grep tag_name | cut -d '"' -f 4)

# Configuration du fuseau horaire PHP
if [[ -z "${TIMEZONE}" ]]; then 
    echo "TIMEZONE is unset"
else 
    echo "date.timezone = \"$TIMEZONE\"" > /etc/php/8.3/apache2/conf.d/timezone.ini
    echo "date.timezone = \"$TIMEZONE\"" > /etc/php/8.3/cli/conf.d/timezone.ini
fi

# Activation de session.cookie_httponly
sed -i 's,session.cookie_httponly = *\(on\|off\|true\|false\|0\|1\)\?,session.cookie_httponly = on,gi' /etc/php/8.3/apache2/php.ini

FOLDER_GLPI=glpi/
FOLDER_WEB=/var/www/html/

# --- Correction OpenShift-safe pour le fichier LDAP ---
LDAP_CONF="/var/www/html/glpi/config/ldap.conf"
if [ ! -f "$LDAP_CONF" ]; then
    echo "Creating local LDAP configuration: $LDAP_CONF"
    mkdir -p /var/www/html/glpi/config
    echo -e "TLS_REQCERT\tnever" > "$LDAP_CONF"
fi
export LDAPCONF="$LDAP_CONF"

# --- Téléchargement et extraction des sources de GLPI ---
if [ "$(ls ${FOLDER_WEB}${FOLDER_GLPI}/bin 2>/dev/null)" ]; then
	echo "GLPI is already installed"
else
	SRC_GLPI=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/tags/${VERSION_GLPI} | jq .assets[0].browser_download_url | tr -d \")
	TAR_GLPI=$(basename ${SRC_GLPI})

	wget -P ${FOLDER_WEB} ${SRC_GLPI}
	tar -xzf ${FOLDER_WEB}${TAR_GLPI} -C ${FOLDER_WEB}
	rm -Rf ${FOLDER_WEB}${TAR_GLPI}
	chown -R www-data:www-data ${FOLDER_WEB}${FOLDER_GLPI}
fi

# --- Adaptation du VirtualHost selon la version GLPI ---
LOCAL_GLPI_VERSION=$(ls ${FOLDER_WEB}/${FOLDER_GLPI}/version)
LOCAL_GLPI_MAJOR_VERSION=$(echo $LOCAL_GLPI_VERSION | cut -d. -f1)
LOCAL_GLPI_VERSION_NUM=${LOCAL_GLPI_VERSION//./}

TARGET_GLPI_VERSION="11.0.1"
TARGET_GLPI_VERSION_NUM=${TARGET_GLPI_VERSION//./}
TARGET_GLPI_MAJOR_VERSION=$(echo $TARGET_GLPI_VERSION | cut -d. -f1)

if [[ $LOCAL_GLPI_VERSION_NUM -lt $TARGET_GLPI_VERSION_NUM || $LOCAL_GLPI_MAJOR_VERSION -lt $TARGET_GLPI_MAJOR_VERSION ]]; then
  echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi\n\n\t<Directory /var/www/html/glpi>\n\t\tAllowOverride All\n\t\tOrder Allow,Deny\n\t\tAllow from all\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf
else
  set +H
  echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi/public\n\n\t<Directory /var/www/html/glpi/public>\n\t\tRequire all granted\n\t\tRewriteEngine On\n\t\tRewriteCond %{REQUEST_FILENAME} !-f\n\t\tRewriteRule ^(.*)$ index.php [QSA,L]\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf
fi

# --- Tâche cron GLPI ---
echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" > /etc/cron.d/glpi
service cron start

# --- Activation du module rewrite ---
a2enmod rewrite && service apache2 restart && service apache2 stop

# --- Fix pour vraiment stopper Apache ---
pkill -9 apache || true

# --- Lancement d'Apache en avant-plan ---
/usr/sbin/apache2ctl -D FOREGROUND
