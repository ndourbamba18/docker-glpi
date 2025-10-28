#!/bin/bash
set -e

# --- Configuration du timezone PHP ---
if [[ -n "${TIMEZONE}" ]]; then
  echo "date.timezone = \"$TIMEZONE\"" > /etc/php/8.3/apache2/conf.d/timezone.ini
  echo "date.timezone = \"$TIMEZONE\"" > /etc/php/8.3/cli/conf.d/timezone.ini
fi

# --- Correction sécurité session ---
sed -i 's,session.cookie_httponly = *\(on\|off\|true\|false\|0\|1\)\?,session.cookie_httponly = on,gi' /etc/php/8.3/apache2/php.ini

# --- Vérification TLS_REQCERT ---
if ! grep -q "TLS_REQCERT" /etc/ldap/ldap.conf 2>/dev/null; then
  echo "TLS_REQCERT\tnever" >> /etc/ldap/ldap.conf
fi

# --- Initialisation des répertoires persistants ---
PERSIST_DIRS=(files config plugins marketplace)

for dir in "${PERSIST_DIRS[@]}"; do
  TARGET="/var/www/html/glpi/${dir}"
  if [ ! -d "$TARGET" ] || [ -z "$(ls -A "$TARGET" 2>/dev/null)" ]; then
    echo "Initializing persistent directory: $TARGET"
    mkdir -p "$TARGET"
    cp -r "/var/www/html/glpi-original/${dir}/." "$TARGET" 2>/dev/null || true
  fi
  chown -R 1001:0 "$TARGET"
  chmod -R g+rwX "$TARGET"
done

# --- Création tâche cron GLPI ---
echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" > /etc/cron.d/glpi
service cron start

# --- Démarrage Apache ---
echo "Starting Apache..."
exec /usr/sbin/apache2ctl -D FOREGROUND
