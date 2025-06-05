#!/bin/bash

# /**
#  * @version    2.7
#  * @package    Engintron for cPanel/WHM
#  * @author     Fotis Evangelou (https://kodeka.io)
#  * @url        https://engintron.com
#  * @copyright  Copyright (c) 2014 - 2025 Kodeka OÜ. All rights reserved.
#  * @license    GNU/GPL license: https://www.gnu.org/copyleft/gpl.html
#  */

CACHE_SIZE="128M"
APCU_FOR_PHP5="APCu-4.0.11"
APCU_FOR_PHP7="APCu-5.1.24"

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

echo "**************************************"
echo "* Checking for required dependencies *"
echo "**************************************"
echo ""

if [ "$RELEASE" -gt "7" ]; then
    dnf -y install make pcre pcre-devel
else
    yum -y install make pcre pcre-devel
fi

echo ""
echo ""

# Setup APCu 4.x for PHP 5.6
if [ -f /opt/cpanel/ea-php56/root/usr/bin/pecl ]; then
    echo "*************************************"
    echo "*    Installing APCu for PHP 5.6    *"
    echo "*************************************"
    echo ""

    echo "\r" | /opt/cpanel/ea-php56/root/usr/bin/pecl install -f channel://pecl.php.net/$APCU_FOR_PHP5
    touch /opt/cpanel/ea-php56/root/etc/php.d/apcu.ini
    cat > "/opt/cpanel/ea-php56/root/etc/php.d/apcu.ini" <<EOF
[apcu]
extension=/opt/cpanel/ea-php56/root/usr/lib64/php/modules/apcu.so
apc.enabled = 1
apc.shm_size = $CACHE_SIZE

EOF

    echo ""
    echo "************************************************"
    echo "* APCu for PHP 5.6 is now installed"
    echo "* and configured with a $CACHE_SIZE cache pool"
    echo "************************************************"
    echo ""
    echo ""

fi

# Setup APCu 5.x for PHP 7.0
if [ -f /opt/cpanel/ea-php70/root/usr/bin/pecl ]; then
    echo "*************************************"
    echo "*    Installing APCu for PHP 7.0    *"
    echo "*************************************"
    echo ""

    echo "\r" | /opt/cpanel/ea-php70/root/usr/bin/pecl install -f channel://pecl.php.net/$APCU_FOR_PHP7
    touch /opt/cpanel/ea-php70/root/etc/php.d/apcu.ini
    cat > "/opt/cpanel/ea-php70/root/etc/php.d/apcu.ini" <<EOF
[apcu]
extension=/opt/cpanel/ea-php70/root/usr/lib64/php/modules/apcu.so
apc.enabled = 1
apc.shm_size = $CACHE_SIZE

EOF

    echo ""
    echo "************************************************"
    echo "* APCu for PHP 7.0 is now installed"
    echo "* and configured with a $CACHE_SIZE cache pool"
    echo "************************************************"
    echo ""
    echo ""

fi

# Setup APCu 5.x for PHP 7.1
if [ -f /opt/cpanel/ea-php71/root/usr/bin/pecl ]; then
    echo "*************************************"
    echo "*    Installing APCu for PHP 7.1    *"
    echo "*************************************"
    echo ""

    echo "\r" | /opt/cpanel/ea-php71/root/usr/bin/pecl install -f channel://pecl.php.net/$APCU_FOR_PHP7
    touch /opt/cpanel/ea-php71/root/etc/php.d/apcu.ini
    cat > "/opt/cpanel/ea-php71/root/etc/php.d/apcu.ini" <<EOF
[apcu]
extension=/opt/cpanel/ea-php71/root/usr/lib64/php/modules/apcu.so
apc.enabled = 1
apc.shm_size = $CACHE_SIZE

EOF

    echo ""
    echo "************************************************"
    echo "* APCu for PHP 7.1 is now installed"
    echo "* and configured with a $CACHE_SIZE cache pool"
    echo "************************************************"
    echo ""
    echo ""

fi

# Setup APCu 5.x for PHP 7.2
if [ -f /opt/cpanel/ea-php72/root/usr/bin/pecl ]; then
    echo "*************************************"
    echo "*    Installing APCu for PHP 7.2    *"
    echo "*************************************"
    echo ""

    echo "\r" | /opt/cpanel/ea-php72/root/usr/bin/pecl install -f channel://pecl.php.net/$APCU_FOR_PHP7
    touch /opt/cpanel/ea-php72/root/etc/php.d/apcu.ini
    cat > "/opt/cpanel/ea-php72/root/etc/php.d/apcu.ini" <<EOF
[apcu]
extension=/opt/cpanel/ea-php72/root/usr/lib64/php/modules/apcu.so
apc.enabled = 1
apc.shm_size = $CACHE_SIZE

EOF

    echo ""
    echo "************************************************"
    echo "* APCu for PHP 7.2 is now installed"
    echo "* and configured with a $CACHE_SIZE cache pool"
    echo "************************************************"
    echo ""
    echo ""

fi

# Setup APCu 5.x for PHP 7.3
if [ -f /opt/cpanel/ea-php73/root/usr/bin/pecl ]; then
    echo "*************************************"
    echo "*    Installing APCu for PHP 7.3    *"
    echo "*************************************"
    echo ""

    echo "\r" | /opt/cpanel/ea-php73/root/usr/bin/pecl install -f channel://pecl.php.net/$APCU_FOR_PHP7
    touch /opt/cpanel/ea-php73/root/etc/php.d/apcu.ini
    cat > "/opt/cpanel/ea-php73/root/etc/php.d/apcu.ini" <<EOF
[apcu]
extension=/opt/cpanel/ea-php73/root/usr/lib64/php/modules/apcu.so
apc.enabled = 1
apc.shm_size = $CACHE_SIZE

EOF

    echo ""
    echo "************************************************"
    echo "* APCu for PHP 7.3 is now installed"
    echo "* and configured with a $CACHE_SIZE cache pool"
    echo "************************************************"
    echo ""
    echo ""

fi

# Setup APCu 5.x for PHP 7.4
if [ -f /opt/cpanel/ea-php74/root/usr/bin/pecl ]; then
    echo "*************************************"
    echo "*    Installing APCu for PHP 7.4    *"
    echo "*************************************"
    echo ""

    echo "\r" | /opt/cpanel/ea-php74/root/usr/bin/pecl install -f channel://pecl.php.net/$APCU_FOR_PHP7
    touch /opt/cpanel/ea-php74/root/etc/php.d/apcu.ini
    cat > "/opt/cpanel/ea-php74/root/etc/php.d/apcu.ini" <<EOF
[apcu]
extension=/opt/cpanel/ea-php74/root/usr/lib64/php/modules/apcu.so
apc.enabled = 1
apc.shm_size = $CACHE_SIZE

EOF

    echo ""
    echo "************************************************"
    echo "* APCu for PHP 7.4 is now installed"
    echo "* and configured with a $CACHE_SIZE cache pool"
    echo "************************************************"
    echo ""
    echo ""

fi

# Setup APCu 5.x for PHP 8.0
if [ -f /opt/cpanel/ea-php80/root/usr/bin/pecl ]; then
    echo "*************************************"
    echo "*    Installing APCu for PHP 8.0    *"
    echo "*************************************"
    echo ""

    echo "\r" | /opt/cpanel/ea-php80/root/usr/bin/pecl install -f channel://pecl.php.net/$APCU_FOR_PHP7
    touch /opt/cpanel/ea-php80/root/etc/php.d/apcu.ini
    cat > "/opt/cpanel/ea-php80/root/etc/php.d/apcu.ini" <<EOF
[apcu]
extension=/opt/cpanel/ea-php80/root/usr/lib64/php/modules/apcu.so
apc.enabled = 1
apc.shm_size = $CACHE_SIZE

EOF

    echo ""
    echo "************************************************"
    echo "* APCu for PHP 8.0 is now installed"
    echo "* and configured with a $CACHE_SIZE cache pool"
    echo "************************************************"
    echo ""
    echo ""

fi

# Setup APCu 5.x for PHP 8.1
if [ -f /opt/cpanel/ea-php81/root/usr/bin/pecl ]; then
    echo "*************************************"
    echo "*    Installing APCu for PHP 8.1    *"
    echo "*************************************"
    echo ""

    echo "\r" | /opt/cpanel/ea-php81/root/usr/bin/pecl install -f channel://pecl.php.net/$APCU_FOR_PHP7
    touch /opt/cpanel/ea-php81/root/etc/php.d/apcu.ini
    cat > "/opt/cpanel/ea-php81/root/etc/php.d/apcu.ini" <<EOF
[apcu]
extension=/opt/cpanel/ea-php81/root/usr/lib64/php/modules/apcu.so
apc.enabled = 1
apc.shm_size = $CACHE_SIZE

EOF

    echo ""
    echo "************************************************"
    echo "* APCu for PHP 8.1 is now installed"
    echo "* and configured with a $CACHE_SIZE cache pool"
    echo "************************************************"
    echo ""
    echo ""

fi

# Setup APCu 5.x for PHP 8.2
if [ -f /opt/cpanel/ea-php82/root/usr/bin/pecl ]; then
    echo "*************************************"
    echo "*    Installing APCu for PHP 8.2    *"
    echo "*************************************"
    echo ""

    echo "\r" | /opt/cpanel/ea-php82/root/usr/bin/pecl install -f channel://pecl.php.net/$APCU_FOR_PHP7
    touch /opt/cpanel/ea-php82/root/etc/php.d/apcu.ini
    cat > "/opt/cpanel/ea-php82/root/etc/php.d/apcu.ini" <<EOF
[apcu]
extension=/opt/cpanel/ea-php82/root/usr/lib64/php/modules/apcu.so
apc.enabled = 1
apc.shm_size = $CACHE_SIZE

EOF

    echo ""
    echo "************************************************"
    echo "* APCu for PHP 8.2 is now installed"
    echo "* and configured with a $CACHE_SIZE cache pool"
    echo "************************************************"
    echo ""
    echo ""

fi

# Setup APCu 5.x for PHP 8.3
if [ -f /opt/cpanel/ea-php83/root/usr/bin/pecl ]; then
    echo "*************************************"
    echo "*    Installing APCu for PHP 8.3    *"
    echo "*************************************"
    echo ""

    echo "\r" | /opt/cpanel/ea-php83/root/usr/bin/pecl install -f channel://pecl.php.net/$APCU_FOR_PHP7
    touch /opt/cpanel/ea-php83/root/etc/php.d/apcu.ini
    cat > "/opt/cpanel/ea-php83/root/etc/php.d/apcu.ini" <<EOF
[apcu]
extension=/opt/cpanel/ea-php83/root/usr/lib64/php/modules/apcu.so
apc.enabled = 1
apc.shm_size = $CACHE_SIZE

EOF

    echo ""
    echo "************************************************"
    echo "* APCu for PHP 8.3 is now installed"
    echo "* and configured with a $CACHE_SIZE cache pool"
    echo "************************************************"
    echo ""
    echo ""

fi

# Setup APCu 5.x for PHP 8.4
if [ -f /opt/cpanel/ea-php84/root/usr/bin/pecl ]; then
    echo "*************************************"
    echo "*    Installing APCu for PHP 8.4    *"
    echo "*************************************"
    echo ""

    echo "\r" | /opt/cpanel/ea-php84/root/usr/bin/pecl install -f channel://pecl.php.net/$APCU_FOR_PHP7
    touch /opt/cpanel/ea-php84/root/etc/php.d/apcu.ini
    cat > "/opt/cpanel/ea-php84/root/etc/php.d/apcu.ini" <<EOF
[apcu]
extension=/opt/cpanel/ea-php84/root/usr/lib64/php/modules/apcu.so
apc.enabled = 1
apc.shm_size = $CACHE_SIZE

EOF

    echo ""
    echo "************************************************"
    echo "* APCu for PHP 8.4 is now installed"
    echo "* and configured with a $CACHE_SIZE cache pool"
    echo "************************************************"
    echo ""
    echo ""

fi

# Cleanup apsu.so entries in cPanel's PHP config files
find /opt/cpanel/ -name "local.ini" | xargs grep -l "apcu.so" | xargs sed -i "s/(\;)extension.*apcu\.so//"
find /opt/cpanel/ -name "*pecl.ini" | xargs grep -l "apcu.so" | xargs sed -i "s/.*\"apcu\.so\"//"

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

exit 0
