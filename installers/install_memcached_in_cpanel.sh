#!/bin/bash

# /**
#  * @version    2.10
#  * @package    Engintron for cPanel/WHM
#  * @author     Fotis Evangelou (https://kodeka.io)
#  * @url        https://engintron.com
#  * @copyright  Copyright (c) 2014 - 2025 Kodeka OÜ. All rights reserved.
#  * @license    GNU/GPL license: https://www.gnu.org/copyleft/gpl.html
#  */

CACHE_SIZE="512M"

if [[ $1 ]]; then
    CACHE_SIZE=$1
fi

if [ -f "/etc/redhat-release" ]; then
    RELEASE=$(rpm -q --qf '%{version}' "$(rpm -q --whatprovides redhat-release)" | cut -c 1)
else
    RELEASE=$(lsb_release -r -s)
fi

clear

echo " ****************************************************"
echo " *               Installing Memcached               *"
echo " ****************************************************"

if [ "$RELEASE" -gt "7" ]; then
    # Let's update the system first
    dnf clean all
    dnf -y update

    # Install memcached & start it
    dnf -y install memcached libmemcached
    dnf -y install ea4-experimental
    systemctl enable memcached
    systemctl start memcached
else
    # Let's update the system first
    yum clean all
    yum -y update

    # Install memcached & start it
    yum -y install memcached memcached-devel libmemcached
    yum -y ea4-experimental
    chkconfig memcached on
    service memcached start
fi

# Adjust its cache size to 512M & restart
if [ -f "/etc/sysconfig/memcached" ]; then
    sed -i 's/CACHESIZE=.*/CACHESIZE="'"${CACHE_SIZE}"'"/' /etc/sysconfig/memcached
fi
service memcached restart

echo ""
echo ""

sleep 1

if [ "$RELEASE" -ge "9" ]; then
    echo "~ Installing related PHP modules for PHP versions 8.0 to 8.4..."
    dnf -y install ea-php80-php-memcached ea-php81-php-memcached ea-php82-php-memcached ea-php83-php-memcached ea-php84-php-memcached
elif [ "$RELEASE" = "8" ]; then
    echo "~ Installing related PHP modules for PHP versions 7.2 to 8.3..."
    dnf -y install ea-php72-php-memcached ea-php73-php-memcached ea-php74-php-memcached
    dnf -y install ea-php80-php-memcached ea-php81-php-memcached ea-php82-php-memcached ea-php83-php-memcached
elif [ "$RELEASE" = "7" ]; then
    echo "~ Installing related PHP modules for PHP versions 5.6 to 8.3..."
    yum -y install ea-php56-php-memcached
    yum -y install ea-php70-php-memcached ea-php71-php-memcached ea-php72-php-memcached ea-php73-php-memcached ea-php74-php-memcached
    yum -y install ea-php80-php-memcached ea-php81-php-memcached ea-php82-php-memcached ea-php83-php-memcached
elif [ "$RELEASE" = "6" ]; then
    echo "~ Installing related PHP modules for PHP versions 5.6 to 8.2..."
    yum -y install ea-php56-php-memcached
    yum -y install ea-php70-php-memcached ea-php71-php-memcached ea-php72-php-memcached ea-php73-php-memcached ea-php74-php-memcached
    yum -y install ea-php80-php-memcached ea-php81-php-memcached ea-php82-php-memcached
else
    echo "Unsupported version - exiting..."
    exit 1
fi

echo ""
echo ""

# Finish things up by restarting web services
service memcached restart

# Restart Apache & PHP-FPM
if pstree | grep -q 'httpd'; then
    echo "Restarting Apache..."
    /scripts/restartsrv apache_php_fpm
    /scripts/restartsrv_httpd
    echo ""
fi

# Restart Nginx (if it's installed via Engintron)
if pstree | grep -q 'nginx'; then
    echo "Restarting Nginx..."
    service nginx restart
    echo ""
fi

# Print out useful info
memcached -h
php -i | grep -i memcache

echo " ****************************************************"
echo " *         Memcached installation complete          *"
echo " ****************************************************"
