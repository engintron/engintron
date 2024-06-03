#!/bin/bash

# /**
#  * @version    2.4
#  * @package    Engintron for cPanel/WHM
#  * @author     Fotis Evangelou (https://kodeka.io)
#  * @url        https://engintron.com
#  * @copyright  Copyright (c) 2014 - 2024 Kodeka OÜ. All rights reserved.
#  * @license    GNU/GPL license: https://www.gnu.org/copyleft/gpl.html
#  */

# ~ NOTES
# Port 6379 (by default)
# Binds to localhost (by default)
#
# Memory configuration documentation:
# https://redis.io/topics/lru-cache

INITSYS=$(cat /proc/1/comm)
RELEASE=$(rpm -q --qf %{version} `rpm -q --whatprovides redhat-release` | cut -c 1)

CACHE_SIZE="2gb"
if [[ $1 ]]; then
    CACHE_SIZE=$1
fi

clear

echo " **********************"
echo " *  Installing Redis  *"
echo " **********************"

echo ""

if [ "$RELEASE" -ge "8" ]; then
    dnf -y install https://rpms.remirepo.net/enterprise/remi-release-8.rpm
    dnf clean all
    dnf -y update
    dnf -y install redis --enablerepo=remi --disableplugin=priorities
elif [ "$RELEASE" = "7" ]; then
    yum -y install https://rpms.remirepo.net/enterprise/remi-release-7.rpm
    yum clean all
    yum -y update
    yum -y install redis --enablerepo=remi --disableplugin=priorities
else
    yum -y install https://rpms.remirepo.net/enterprise/remi-release-6.rpm
    yum clean all
    yum -y update
    yum -y install redis --enablerepo=remi --disableplugin=priorities
fi

echo ""
echo ""

for php in $(whmapi1 php_get_installed_versions|grep -oE '\bea-php.*'); do
    echo "************************************************"
    echo "*  Installing PHP PECL extension for \"$php\"  *"
    echo "************************************************"
    echo ""
    echo -e "\n\n\n" | /opt/cpanel/"$php"/root/usr/bin/pecl install igbinary igbinary-devel redis
    echo ""
    echo "******************************************************"
    echo "*  PHP PECL extension for \"$php\" is now installed  *"
    echo "******************************************************"
    echo ""
    echo ""
    sleep 1
done

# Restart Apache & PHP-FPM
if [ "$(pstree | grep 'httpd')" ]; then
    echo "~ Restarting Apache..."
    /scripts/restartsrv apache_php_fpm
    /scripts/restartsrv_httpd
    sleep 1
    echo ""
    echo ""
fi

# Restart Nginx (if it's installed via Engintron)
if [ "$(pstree | grep 'nginx')" ]; then
    echo "~ Restarting Nginx..."
    service nginx restart
    sleep 1
    echo ""
    echo ""
fi

echo "~ Adjusting configuration..."

cp -f /etc/redis.conf /etc/redis.conf.bak

sed -i "s/tcp-backlog 511/tcp-backlog 65535/" /etc/redis.conf

cat >> "/etc/redis.conf" <<EOF
# Custom
maxmemory $CACHE_SIZE
maxmemory-policy allkeys-lru
#maxmemory-policy allkeys-lfu
save ""

EOF

sleep 1

echo ""
echo ""

echo "~ Enable and restart Redis..."

if [ "$RELEASE" -ge "7" ]; then
    systemctl enable redis
    systemctl restart redis
else
    chkconfig redis on
    service redis restart
fi

sleep 1

echo ""
echo ""

# Print out useful info
echo ""
echo "********** Redis Info **********"
echo ""

echo "~ Check if Redis is installed..."
redis-cli ping
echo ""

sleep 1

echo "~ Show Redis version..."
redis-cli --version
echo ""

sleep 1

echo "~ Check Redis binds to localhost only (and port 6379)..."
netstat -lnp | grep redis
echo ""

sleep 1

echo "~ Show Redis memory configuration (\"maxmemory_human\" should report $CACHE_SIZE)..."
redis-cli info memory
echo ""

sleep 1

echo ""
echo "********** Redis PHP configuration **********"

echo ""

for php in $(whmapi1 php_get_installed_versions|grep -oE '\bea-php.*'); do
    echo "~ Confirm installation for PHP $php..."
    /opt/cpanel/"$php"/root/usr/bin/php -i | grep "Redis Support"
    echo ""
    echo ""
done

echo " ***********************************************"
echo " *         Redis installation complete         *"
echo " ***********************************************"

echo ""
