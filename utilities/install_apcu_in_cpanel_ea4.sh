#!/bin/bash

# /**
#  * @version    1.12.0
#  * @package    Engintron for cPanel/WHM
#  * @author     Fotis Evangelou (https://kodeka.io)
#  * @url        https://engintron.com
#  * @copyright  Copyright (c) 2018 - 2020 Kodeka OÜ. All rights reserved.
#  * @license    GNU/GPL license: https://www.gnu.org/copyleft/gpl.html
#  */

CACHE_SIZE="128M"
APCU_FOR_PHP5="APCu-4.0.11"
APCU_FOR_PHP7="APCu-5.1.17"

if [[ $1 ]]; then
    CACHE_SIZE=$1
fi

clear

echo "**************************************"
echo "* Checking for required dependencies *"
echo "**************************************"
echo ""
yum -y install make pcre-devel

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
