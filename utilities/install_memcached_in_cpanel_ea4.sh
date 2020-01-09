#!/bin/bash

# /**
#  * @version    1.12.0
#  * @package    Engintron for cPanel/WHM
#  * @author     Fotis Evangelou (https://kodeka.io)
#  * @url        https://engintron.com
#  * @copyright  Copyright (c) 2018 - 2020 Kodeka OÜ. All rights reserved.
#  * @license    GNU/GPL license: https://www.gnu.org/copyleft/gpl.html
#  */

CACHE_SIZE="512M"

if [[ $1 ]]; then
    CACHE_SIZE=$1
fi

clear

echo " ****************************************************"
echo " *               Installing Memcached               *"
echo " ****************************************************"

# Let's update the system first
yum clean all
yum -y update
yum -y upgrade

# Install memcached & start it
yum -y install memcached memcached-devel ea4-experimental
service memcached start
chkconfig memcached on

# Adjust its cache size to 512M & restart
if [ -e "/etc/sysconfig/memcached" ]; then
    sed -i 's/CACHESIZE=.*/CACHESIZE="'${CACHE_SIZE}'"/' /etc/sysconfig/memcached
fi
service memcached restart

# Install related PHP modules for PHP versions 5.6 to 7.3
yum -y install ea-php56-php-memcached ea-php70-php-memcached ea-php71-php-memcached ea-php72-php-memcached ea-php73-php-memcached

# Finish things up by restarting web services
service memcached restart

# Restart Apache & PHP-FPM
if [ "$(pstree | grep 'httpd')" ]; then
    echo "Restarting Apache..."
    /scripts/restartsrv apache_php_fpm
    /scripts/restartsrv_httpd
    echo ""
fi

# Restart Nginx (if it's installed via Engintron)
if [ "$(pstree | grep 'nginx')" ]; then
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
