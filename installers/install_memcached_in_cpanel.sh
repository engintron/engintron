#!/bin/bash

# /**
#  * @version    2.1
#  * @package    Engintron for cPanel/WHM
#  * @author     Fotis Evangelou (https://kodeka.io)
#  * @url        https://engintron.com
#  * @copyright  Copyright (c) 2014 - 2022 Kodeka OÜ. All rights reserved.
#  * @license    GNU/GPL license: https://www.gnu.org/copyleft/gpl.html
#  */

CACHE_SIZE="512M"

if [[ $1 ]]; then
    CACHE_SIZE=$1
fi

INITSYS=$(cat /proc/1/comm)
if [ -f "/etc/redhat-release" ]; then
    DISTRO="el"
    RELEASE=$(rpm -q --qf %{version} `rpm -q --whatprovides redhat-release` | cut -c 1)
else
    DISTRO="ubuntu"
    CODENAME=$(lsb_release -c -s)
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
    sed -i 's/CACHESIZE=.*/CACHESIZE="'${CACHE_SIZE}'"/' /etc/sysconfig/memcached
fi
service memcached restart

echo ""
echo ""

sleep 1

if [ "$RELEASE" -gt "7" ]; then
    # Install related PHP modules for PHP versions 7.2 to 8.1
    echo "~ Installing related PHP modules for PHP versions 7.2 to 8.1..."
    dnf -y install ea-php72-php-memcached ea-php73-php-memcached ea-php74-php-memcached
    dnf -y install ea-php80-php-memcached ea-php81-php-memcached
else
    # Install related PHP modules for PHP versions 5.6 to 8.1
    echo "~ Installing related PHP modules for PHP versions 5.6 to 8.1..."
    yum -y install ea-php56-php-memcached
    yum -y install ea-php70-php-memcached ea-php71-php-memcached ea-php72-php-memcached ea-php73-php-memcached ea-php74-php-memcached
    yum -y install ea-php80-php-memcached ea-php81-php-memcached
fi

echo ""
echo ""

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
