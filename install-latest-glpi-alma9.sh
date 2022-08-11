#!/bin/bash
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Error: This script should be run as root"
    exit
fi

# Update system & install missing dependencies

dnf update -y

function isinstalled {
  if dnf list installed "$@" >/dev/null 2>&1; then
    true
  else
    false
  fi
}

if isinstalled $policycoreutils-python-utils; then echo "policycoreutils-python-utils package installed"; else dnf install -y policycoreutils-python-utils; fi
if isinstalled $tar; then echo "tar package installed"; else dnf install -y tar; fi
if isinstalled $wget; then echo "wget package installed"; else dnf install -y wget; fi

# Download glpi

function get_glpi_latest_release() {
 curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest \
  | grep "https://github.com/glpi-project/glpi/releases/download/.*tgz" \
  | cut -d : -f 2,3 \
  | tr -d \" \
  | wget -qi -
}

get_glpi_latest_release
tar xf glpi*.tgz -C /var/www/
rm -f glpi*
mkdir /etc/glpi/cert /var/log/glpi
mv /var/www/glpi/files/ /var/lib/glpi

echo "<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
        require_once GLPI_CONFIG_DIR . '/local_define.php';
}" > /var/www/glpi/inc/downstream.php

echo "<?php
define('GLPI_VAR_DIR', '/var/lib/glpi');
define('GLPI_LOG_DIR', '/var/log/glpi');" > /etc/glpi/local_define.php

chown -R apache: /var/www/glpi/ /etc/glpi/ /var/lib/glpi/ /var/log/glpi/

# Configuring Selinux

# Create Read/Write context with semanage
semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/glpi(/.*)?"
# Apply context to directories
restorecon -R /var/www/glpi/ /etc/glpi/ /var/lib/glpi/ /var/log/glpi/
# Allow network access to web service
setsebool -P httpd_can_network_connect on
# Allow database access
setsebool -P httpd_can_network_connect_db on
# Allow send mail
setsebool -P httpd_can_sendmail on

# Configureing php dependencies

if isinstalled $php81; then echo "php81 package installed"; else dnf install -y php81; fi
if isinstalled $php81-php-cli; then echo "php81-php-cli package installed"; else dnf install -y php81-php-cli; fi
if isinstalled $php81-php-common; then echo "php81-common package installed"; else dnf install -y php81-common; fi
if isinstalled $php81-php-fpm; then echo "php81-php-fpm package installed"; else dnf install -y php81-php-fpm; fi
if isinstalled $php81-php-gd; then echo "php81-php-gd package installed"; else dnf install -y php81-php-gd; fi
if isinstalled $php81-php-imap; then echo "php81-php-imap package installed"; else dnf install -y php81-php-imap; fi
if isinstalled $php81-php-intl; then echo "php81-php-intl package installed"; else dnf install -y php81-php-intl; fi
if isinstalled $php81-php-ldap; then echo "php81-php-ldap package installed"; else dnf install -y php81-php-ldap; fi
if isinstalled $php81-php-mbstring; then echo "php81-php-mbstring package installed"; else dnf install -y php81-php-mbstring; fi
if isinstalled $php81-php-mysqlnd; then echo "php81-php-mysqlnd package installed"; else dnf install -y php81-php-mysqlnd; fi
if isinstalled $php81-php-opcache; then echo "php81-php-opcache package installed"; else dnf install -y php81-php-opcache; fi
if isinstalled $php81-php-pdo; then echo "php81-php-pdo package installed"; else dnf install -y php81-php-pdo; fi
if isinstalled $php81-php-pecl-apcu; then echo "php81-php-pecl-apcu package installed"; else dnf install -y php81-php-pecl-apcu; fi
if isinstalled $php81-php-pecl-mysql; then echo "php81-php-pecl-mysql package installed"; else dnf install -y php81-php-pecl-mysql; fi
if isinstalled $php81-php-pecl-xmlrpc; then echo "php81-php-pecl-xmlrpc package installed"; else dnf install -y php81-php-pecl-xmlrpc; fi
if isinstalled $php81-php-pecl-zip; then echo "php81-php-pecl-zip package installed"; else dnf install -y php81-php-pecl-zip; fi
if isinstalled $php81-php-sodium; then echo "php81-php-sodium package installed"; else dnf install -y php81-php-sodium; fi
if isinstalled $php81-php-xml; then echo "php81-php-xml package installed"; else dnf install -y php81-php-xml; fi

# Following files are stored in /etc/httpd/conf.d/ and should be root:root

echo "Alias /glpi /var/www/glpi
<VirtualHost *:80>
 <Directory /var/www/glpi>
        AllowOverride all
 </Directory>
</VirtualHost>

# Uncomment only after copying certs to /etc/glpi/cert folder

#<VirtualHost *:443>
# SSLEngine on
# .pem or .crt
# SSLCertificateFile /etc/glpi/cert/<cert_name>.pem
# .pem or .key
# SSLCertificateKeyFile /etc/glpi/cert/<cert_key_name>.pem
# <Directory /var/www/glpi>
#        AllowOverride all
# </Directory>
#</VirtualHost>" > /etc/httpd/conf.d/glpi.conf

# Backup original welcome page to add redirect to /glpi

mv /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/welcome.conf.bk

echo "#
# This configuration file enables the default "Welcome" page if there
# is no default index page present for the root URL. To disable the
# Welcome page, comment out all the lines below.
#
# NOTE: if this file is removed, it will be restored on upgrades.
#
<LocationMatch "^/+$">
   Options -Indexes
   ErrorDocument 403 /.noindex.html
   Redirect 301 / /glpi
</LocationMatch>

<Directory /usr/share/httpd/noindex>
   AllowOverride none
   Require all granted
</Directory>

Alias /.noindex.html /usr/share/httpd/noindex/index.html
Alias /poweredby.png /usr/share/httpd/icons/apache_pb3.png
Alias /system_noindex_logo.png /usr/share/httpd/icons/system_noindex_logo.png" > /etc/httpd/conf.d/welcome.conf

systemctl reload httpd
