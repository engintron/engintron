#!/bin/bash

# /**
#  * @version    2.5
#  * @package    Engintron for cPanel/WHM
#  * @author     Fotis Evangelou (https://kodeka.io)
#  * @url        https://engintron.com
#  * @copyright  Copyright (c) 2014 - 2023 Kodeka OÜ. All rights reserved.
#  * @license    GNU/GPL license: https://www.gnu.org/copyleft/gpl.html
#  */

# Constants
APP_PATH="/opt/engintron"
APP_VERSION="2.5"
APP_BUILD_ID="20240929"
APP_RELEASE_DATE="September 29th, 2024"

CPANEL_PLG_PATH="/usr/local/cpanel/whostmgr/docroot/cgi"

INITSYS=$(cat /proc/1/comm)
if [ -f "/etc/redhat-release" ]; then
    DISTRO="el"
    RELEASE=$(rpm -q --qf %{version} `rpm -q --whatprovides redhat-release` | cut -c 1)
else
    DISTRO="ubuntu"
    CODENAME=$(lsb_release -c -s)
    RELEASE=$(lsb_release -r -s)
fi



############################# HELPER FUCTIONS [start] #############################

function install_basics {

    echo "=== Let's upgrade our system first & install any required packages (incl. useful utilities) ==="

    if [ "$RELEASE" -gt "7" ]; then
        dnf -y update
        dnf -y install epel-release
        dnf -y update
        dnf -y install bash-completion bc bmon bzip2 curl dmidecode ethtool git htop httpie ifstat iftop iotop iptraf iptraf-ng jpegoptim libwebp make multitail mutt nano ncdu net-tools nload nmon openssl-devel optipng pcre pcre-devel psmisc redhat-lsb redhat-lsb-core rsync screen siege smartmontools sudo tree unzip wget yum-utils zip zlib-devel
        dnf -y install memcached libmemcached
        dnf -y install ea4-experimental
    else
        yum -y update
        if [ "$RELEASE" = "6" ]; then
            if [ "$(arch)" = "x86_64" ]; then
                yum -y install https://archives.fedoraproject.org/pub/archive/epel/6/x86_64/epel-release-6-8.noarch.rpm
            else
                yum -y install https://archives.fedoraproject.org/pub/archive/epel/6/i386/epel-release-6-8.noarch.rpm
            fi
        fi
        yum -y install epel-release
        yum -y update
        yum -y install apr-util bash-completion bc bmon bzip2 curl dmidecode ethtool git htop httpie ifstat iftop iotop iptraf iptraf-ng jpegoptim libwebp make multitail mutt nano ncdu net-tools nload nmon openssl-devel optipng pcre pcre-devel psmisc redhat-lsb redhat-lsb-core rename rsync screen screenfetch siege smartmontools sudo tree unzip wget yum-utils zip zlib-devel
        yum -y install memcached memcached-devel libmemcached libmemcached-devel
        yum -y install ea4-experimental
    fi

    echo ""
    echo ""

}

function install_mod_remoteip {

    # Get system IPs
    SYSTEM_IPS=$(ip addr show | grep -o "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | sed ':a;N;$!ba;s/\n/ /g');
    if [[ ! $(echo $SYSTEM_IPS | grep "127.0.0.1") ]]; then
        SYSTEM_IPS="127.0.0.1 $SYSTEM_IPS"
    fi

    echo "=== Installing mod_remoteip for Apache ==="

    # EL7+
    if [ -f /etc/apache2/conf/httpd.conf ]; then
        if [ "$RELEASE" -gt "7" ]; then
            dnf -y install ea-apache24-mod_remoteip
        else
            yum -y install ea-apache24-mod_remoteip
        fi

        if [ -f /etc/apache2/modules/mod_remoteip.so ]; then
            REMOTEIP_CONF=$(find /etc/apache2/conf.modules.d/ -iname "*_mod_remoteip.conf")
            if [ -f $REMOTEIP_CONF ]; then

                cat > $REMOTEIP_CONF <<EOF
# mod_remoteip (https://httpd.apache.org/docs/current/mod/mod_remoteip.html)
LoadModule remoteip_module modules/mod_remoteip.so
RemoteIPHeader        X-Forwarded-For
RemoteIPInternalProxy $SYSTEM_IPS
EOF
                sed -i "s:LogFormat \"%h %a %l:LogFormat \"%a %l:" /etc/apache2/conf/httpd.conf
                sed -i "s:LogFormat \"%h %l:LogFormat \"%a %l:" /etc/apache2/conf/httpd.conf
            fi
        fi
    # EL6
    else
        cd /usr/local/src
        rm -f mod_remoteip.c
        rm -f apxs.sh
        cp -f $APP_PATH/apache/mod_remoteip.c /usr/local/src/
        cp -f $APP_PATH/apache/apxs.sh /usr/local/src/
        chmod +x apxs.sh
        ./apxs.sh -i -c -n mod_remoteip.so mod_remoteip.c
        rm -f mod_remoteip.c
        rm -f apxs.sh

        if [ -f /usr/local/apache/modules/mod_remoteip.so ]; then
            if [ ! -f /usr/local/apache/conf/includes/remoteip.conf ]; then
                touch /usr/local/apache/conf/includes/remoteip.conf
            fi

            cat > "/usr/local/apache/conf/includes/remoteip.conf" <<EOF
# mod_remoteip (https://httpd.apache.org/docs/current/mod/mod_remoteip.html)
LoadModule remoteip_module modules/mod_remoteip.so
RemoteIPHeader        X-Forwarded-For
RemoteIPInternalProxy $SYSTEM_IPS
EOF

            cp -f /usr/local/apache/conf/httpd.conf /usr/local/apache/conf/httpd.conf.bak
            sed -i 's:Include "/usr/local/apache/conf/includes/remoteip.conf"::' /usr/local/apache/conf/httpd.conf
            sed -i 's:Include "/usr/local/apache/conf/includes/errordocument.conf":Include "/usr/local/apache/conf/includes/errordocument.conf"\nInclude "/usr/local/apache/conf/includes/remoteip.conf":' /usr/local/apache/conf/httpd.conf
            sed -i "s:LogFormat \"%h %a %l:LogFormat \"%a %l:" /usr/local/apache/conf/httpd.conf
            sed -i "s:LogFormat \"%h %l:LogFormat \"%a %l:" /usr/local/apache/conf/httpd.conf
        fi
    fi

    echo ""
    echo ""

}

function remove_mod_remoteip {

    # EL7+
    if [ -f /etc/apache2/conf/httpd.conf ]; then
        if [ "$RELEASE" -gt "7" ]; then
            dnf -y remove ea-apache24-mod_remoteip
        else
            yum -y remove ea-apache24-mod_remoteip
        fi
        sed -i "s:LogFormat \"%h %a %l:LogFormat \"%h %l:" /etc/apache2/conf/httpd.conf
        sed -i "s:LogFormat \"%a %l:LogFormat \"%h %l:" /etc/apache2/conf/httpd.conf
    # EL6
    else
        if [ -f /usr/local/apache/conf/includes/remoteip.conf ]; then
            echo "=== Removing mod_remoteip for Apache ==="
            rm -f /usr/local/apache/conf/includes/remoteip.conf
            sed -i 's:Include "/usr/local/apache/conf/includes/remoteip.conf"::' /usr/local/apache/conf/httpd.conf
            sed -i "s:LogFormat \"%h %a %l:LogFormat \"%h %l:" /usr/local/apache/conf/httpd.conf
            sed -i "s:LogFormat \"%a %l:LogFormat \"%h %l:" /usr/local/apache/conf/httpd.conf
        fi
    fi

    echo ""
    echo ""

}

function apache_change_port {

    echo "=== Switch Apache to ports 8080 & 8443, distill changes & restart Apache ==="

    if [ -f /usr/local/cpanel/bin/whmapi1 ]; then
        /usr/local/cpanel/bin/whmapi1 set_tweaksetting key=apache_port value=0.0.0.0:8080
        /usr/local/cpanel/bin/whmapi1 set_tweaksetting key=apache_ssl_port value=0.0.0.0:8443
    else
        if grep -Fxq "^apache_" /var/cpanel/cpanel.config; then
            sed -i 's/^apache_port=.*/apache_port=0.0.0.0:8080/' /var/cpanel/cpanel.config
            sed -i 's/^apache_ssl_port=.*/apache_ssl_port=0.0.0.0:8443/' /var/cpanel/cpanel.config
        else
            echo "apache_port=0.0.0.0:8080" >> /var/cpanel/cpanel.config
            echo "apache_ssl_port=0.0.0.0:8443" >> /var/cpanel/cpanel.config
        fi
        /usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings
    fi

    echo ""
    echo ""

    echo "=== Distill changes in Apache's configuration and restart Apache ==="
    if [ ! -f /usr/local/cpanel/bin/whmapi1 ]; then
        /usr/local/cpanel/bin/apache_conf_distiller --update
    fi
    /scripts/rebuildhttpdconf
    /scripts/restartsrv apache_php_fpm
    /scripts/restartsrv_httpd

    echo ""
    echo ""

}

function apache_revert_port {

    echo "=== Switch Apache back to ports 80 & 443 ==="

    if [ -f /usr/local/cpanel/bin/whmapi1 ]; then
        /usr/local/cpanel/bin/whmapi1 set_tweaksetting key=apache_port value=0.0.0.0:80
        /usr/local/cpanel/bin/whmapi1 set_tweaksetting key=apache_ssl_port value=0.0.0.0:443
    else
        if grep -Fxq "^apache_" /var/cpanel/cpanel.config; then
            sed -i 's/^apache_port=.*/apache_port=0.0.0.0:80/' /var/cpanel/cpanel.config
            sed -i 's/^apache_ssl_port=.*/apache_ssl_port=0.0.0.0:443/' /var/cpanel/cpanel.config
        else
            echo "apache_port=0.0.0.0:80" >> /var/cpanel/cpanel.config
            echo "apache_ssl_port=0.0.0.0:443" >> /var/cpanel/cpanel.config
        fi
        /usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings
    fi

    echo ""
    echo ""

    echo "=== Distill changes in Apache's configuration and restart Apache ==="
    if [ ! -f /usr/local/cpanel/bin/whmapi1 ]; then
        /usr/local/cpanel/bin/apache_conf_distiller --update
    fi
    /scripts/rebuildhttpdconf
    /scripts/restartsrv apache_php_fpm
    /scripts/restartsrv_httpd

    echo ""
    echo ""

}

function install_nginx {

    # Disable Nginx from the EPEL repo
    if [ -f /etc/yum.repos.d/epel.repo ]; then
        if ! grep -q "^exclude=nginx\*" /etc/yum.repos.d/epel.repo ; then
            if grep -Fq "#exclude=nginx*" /etc/yum.repos.d/epel.repo; then
                sed -i "s/\#exclude=nginx\*/exclude=nginx\*/" /etc/yum.repos.d/epel.repo
            else
                sed -i "s/enabled=1/enabled=1\nexclude=nginx\*/" /etc/yum.repos.d/epel.repo
            fi
            if [ "$RELEASE" -gt "7" ]; then
                dnf -y remove nginx
                dnf clean all
                dnf -y update
            else
                yum -y remove nginx
                yum clean all
                yum -y update
            fi
        fi
    fi

    # Disable Nginx from the Amazon Linux repo
    if [ -f /etc/yum.repos.d/amzn-main.repo ]; then
        if ! grep -q "^exclude=nginx\*" /etc/yum.repos.d/amzn-main.repo ; then
            if grep -Fq "#exclude=nginx*" /etc/yum.repos.d/amzn-main.repo; then
                sed -i "s/\#exclude=nginx\*/exclude=nginx\*/" /etc/yum.repos.d/amzn-main.repo
            else
                sed -i "s/enabled=1/enabled=1\nexclude=nginx\*/" /etc/yum.repos.d/amzn-main.repo
            fi
            if [ "$RELEASE" -gt "7" ]; then
                dnf -y remove nginx
                dnf clean all
                dnf -y update
            else
                yum -y remove nginx
                yum clean all
                yum -y update
            fi
        fi
    fi

    if [ ! -f /etc/yum.repos.d/nginx.repo ]; then
        touch /etc/yum.repos.d/nginx.repo
    fi

    # Allow switching from mainline to stable release
    if [[ ! $1 ]]; then
        if grep -iq "mainline" /etc/yum.repos.d/nginx.repo; then
            if [ "$RELEASE" -gt "7" ]; then
                dnf -y remove nginx
            else
                yum -y remove nginx
            fi
        fi
    fi

    # Setup Nginx repo
    RELEASE_VERSION="\$releasever"
    if grep -iq "Amazon Linux AMI" /etc/system-release; then
        RELEASE_VERSION=6
    fi
    if grep -iq "Amazon Linux release 2" /etc/system-release; then
        RELEASE_VERSION=7
    fi

    if [ "$1" = mainline ]; then
        echo "=== Install Nginx (mainline) from nginx.org ==="
        cat > "/etc/yum.repos.d/nginx.repo" <<EOFM
[nginx]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/$RELEASE_VERSION/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
priority=1

EOFM
    else
        echo "=== Install Nginx (stable) from nginx.org ==="
        cat > "/etc/yum.repos.d/nginx.repo" <<EOFS
[nginx]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/$RELEASE_VERSION/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
priority=1

EOFS
    fi

    # Install Nginx
    if [ "$RELEASE" -gt "7" ]; then
        dnf -y install nginx
    else
        yum -y install nginx
    fi

    # Copy Nginx config files
    if [ ! -d /etc/nginx/conf.d ]; then
        mkdir -p /etc/nginx/conf.d
    fi

    if [ -f /etc/nginx/custom_rules ]; then
        cp -f $APP_PATH/nginx/custom_rules /etc/nginx/custom_rules.dist
    else
        cp -f $APP_PATH/nginx/custom_rules /etc/nginx/
    fi

    if [ -f /etc/nginx/common_simple_protection.conf ]; then
        cp -f $APP_PATH/nginx/common_simple_protection.conf /etc/nginx/common_simple_protection.conf.dist
    else
        cp -f $APP_PATH/nginx/common_simple_protection.conf /etc/nginx/
    fi

    if [ -f /etc/nginx/proxy_params_common ]; then
        cp -f /etc/nginx/proxy_params_common /etc/nginx/proxy_params_common.bak
    fi
    cp -f $APP_PATH/nginx/proxy_params_common /etc/nginx/

    if [ -f /etc/nginx/proxy_params_dynamic ]; then
        cp -f /etc/nginx/proxy_params_dynamic /etc/nginx/proxy_params_dynamic.bak
    fi
    cp -f $APP_PATH/nginx/proxy_params_dynamic /etc/nginx/

    if [ -f /etc/nginx/proxy_params_static ]; then
        cp -f /etc/nginx/proxy_params_static /etc/nginx/proxy_params_static.bak
    fi
    cp -f $APP_PATH/nginx/proxy_params_static /etc/nginx/

    if [ -f /etc/nginx/mime.types ]; then
        cp -f /etc/nginx/mime.types /etc/nginx/mime.types.bak
    fi
    cp -f $APP_PATH/nginx/mime.types /etc/nginx/

    if [ -f /etc/nginx/nginx.conf ]; then
        cp -f /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    fi
    cp -f $APP_PATH/nginx/nginx.conf /etc/nginx/

    if [ -f /etc/nginx/conf.d/default.conf ]; then
        cp -f /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak
    fi
    rm -f /etc/nginx/conf.d/*.conf
    cp -f $APP_PATH/nginx/conf.d/default.conf /etc/nginx/conf.d/

    cp -f $APP_PATH/nginx/common_http.conf /etc/nginx/
    cp -f $APP_PATH/nginx/common_https.conf /etc/nginx/

    if [ ! -d /etc/nginx/utilities ]; then
        mkdir -p /etc/nginx/utilities
    fi
    cp -f $APP_PATH/nginx/utilities/https_vhosts.php /etc/nginx/utilities/
    cp -f $APP_PATH/nginx/utilities/https_vhosts.sh /etc/nginx/utilities/
    chmod +x /etc/nginx/utilities/*

    if [ ! -d /etc/ssl/engintron ]; then
        mkdir -p /etc/ssl/engintron
    fi

    if [ ! -d /var/cache/nginx ]; then
        mkdir -p /var/cache/nginx
    fi

    if [ -f /sbin/chkconfig ]; then
        /sbin/chkconfig nginx on
    else
        systemctl enable nginx
    fi

    if [ -f /usr/lib/systemd/system/nginx.service ]; then
        sed -i 's/PrivateTmp=true/PrivateTmp=false/' /usr/lib/systemd/system/nginx.service
        systemctl daemon-reload
    fi

    if [ "$(pstree | grep 'nginx')" ]; then
        service nginx stop
    fi

    # Adjust log rotation to 7 days
    if [ -f /etc/logrotate.d/nginx ]; then
        sed -i 's:rotate .*:rotate 7:' /etc/logrotate.d/nginx 
    fi

    echo ""
    echo ""

}

function remove_nginx {

    echo "=== Removing Nginx... ==="
    if [ -f /sbin/chkconfig ]; then
        /sbin/chkconfig nginx off
    else
        systemctl disable nginx
    fi

    if [ "$RELEASE" -gt "7" ]; then
        systemctl stop nginx
        dnf -y remove nginx
    else
        service nginx stop
        yum -y remove nginx
    fi

    rm -rf /etc/nginx/*
    rm -f /etc/yum.repos.d/nginx.repo
    rm -rf /etc/ssl/engintron/*

    # Enable Nginx from the EPEL repo
    if [ -f /etc/yum.repos.d/epel.repo ]; then
        sed -i "s/^exclude=nginx\*/#exclude=nginx\*/" /etc/yum.repos.d/epel.repo
    fi

    # Enable Nginx from the Amazon Linux repo
    if [ -f /etc/yum.repos.d/amzn-main.repo ]; then
        sed -i "s/^exclude=nginx\*/#exclude=nginx\*/" /etc/yum.repos.d/amzn-main.repo
    fi

    echo ""
    echo ""

}

function install_engintron_ui {

    echo "=== Installing Engintron WHM plugin files... ==="

    # Cleanup older installations from the obsolete addon_engintron.cgi file
    if [ -f $CPANEL_PLG_PATH/addon_engintron.cgi ]; then
        rm -f $CPANEL_PLG_PATH/addon_engintron.cgi
    fi

    ln -sf /opt/engintron/app/engintron.php $CPANEL_PLG_PATH/
    chmod +x $CPANEL_PLG_PATH/engintron.php

    echo ""
    echo "=== Register Engintron as a cPanel app ==="

    /usr/local/cpanel/bin/register_appconfig $APP_PATH/app/engintron.conf

    echo ""
    echo ""

}

function remove_engintron_ui {

    echo "=== Removing Engintron WHM plugin files... ==="
    rm -f $CPANEL_PLG_PATH/engintron.php

    echo ""
    echo "=== Unregister Engintron as a cPanel app ==="

    /usr/local/cpanel/bin/unregister_appconfig engintron

    echo ""
    echo ""

}

function install_munin_patch {

    if [ -f /etc/munin/plugin-conf.d/cpanel.conf ]; then
        echo "=== Updating Munin's configuration for Apache ==="

        if grep -q "\[apache_status\]" /etc/munin/plugin-conf.d/cpanel.conf; then
            echo "Munin configuration already updated, nothing to do here"
        else
            cat >> "/etc/munin/plugin-conf.d/cpanel.conf" <<EOF

[apache_status]
env.ports 8080
env.label 8080
EOF
        fi

        ln -sf /usr/local/cpanel/3rdparty/share/munin/plugins/nginx_* /etc/munin/plugins/

        service munin-node restart

        echo ""
        echo ""
    fi

}

function remove_munin_patch {

    if [ -f /etc/munin/plugin-conf.d/cpanel.conf ]; then
        echo ""
        echo "=== Updating Munin's configuration for Apache ==="

        if grep -q "\[apache_status\]" /etc/munin/plugin-conf.d/cpanel.conf; then
            sed -i 's:\[apache_status\]::' /etc/munin/plugin-conf.d/cpanel.conf
            sed -i 's:env\.ports 8080::' /etc/munin/plugin-conf.d/cpanel.conf
            sed -i 's:env\.label 8080::' /etc/munin/plugin-conf.d/cpanel.conf
        else
            echo "Munin was not found, nothing to do here"
        fi

        rm -f /etc/munin/plugins/nginx_*

        service munin-node restart

        echo ""
        echo ""
    fi

}

function csf_pignore_add {
    if [ -f /etc/csf/csf.pignore ]; then
        echo ""
        echo "=== Adding Nginx to CSF's process ignore list ==="

        if grep -q "exe\:\/usr\/sbin\/nginx" /etc/csf/csf.pignore; then
            echo "Nginx seems to be already configured with CSF..."
        else
            echo "exe:/usr/sbin/nginx" >> /etc/csf/csf.pignore
            csf -r
            service lfd restart
        fi

        echo ""
        echo ""

    fi
}

function csf_pignore_remove {
    if [ -f /etc/csf/csf.pignore ]; then
        echo ""
        echo "=== Removing Nginx from CSF's process ignore list ==="

        if grep -q "exe\:\/usr\/sbin\/nginx" /etc/csf/csf.pignore; then
            sed -i 's:^exe\:\/usr\/sbin\/nginx::' /etc/csf/csf.pignore
            csf -r
            service lfd restart
        fi

        echo ""
        echo ""

    fi
}

function cron_for_https_vhosts_add {
    if [ -f /etc/crontab ]; then
        if grep -q "https_vhosts\.sh" /etc/crontab; then
            echo "=== Skip adding cron job to generate Nginx's HTTPS vhosts ==="
        else
            echo ""
            echo "=== Adding cron job to generate Nginx's HTTPS vhosts ==="

            cat >> "/etc/crontab" <<EOF

* * * * * root /etc/nginx/utilities/https_vhosts.sh > /dev/null 2>&1

EOF

        fi
        echo ""
        echo ""
    fi
}

function cron_for_https_vhosts_remove {
    if [ -f /etc/crontab ]; then
        echo ""
        echo "=== Removing cron job used for generating Nginx's HTTPS vhosts ==="

        sed -i 's:* * * * * root /etc/nginx/utilities/https_vhosts.sh >> /dev/null 2>&1::' /etc/crontab
        sed -i 's:* * * * * root /etc/nginx/utilities/https_vhosts.sh > /dev/null 2>&1::' /etc/crontab

        echo ""
        echo ""
    fi
}

function chkserv_nginx_on {
    if [ -f /etc/chkserv.d/httpd ]; then
        echo ""
        echo "=== Enable TailWatch chkservd driver for Nginx ==="

        sed -i 's:service\[httpd\]=80,:service[httpd]=8080,:' /etc/chkserv.d/httpd
        echo "nginx:1" >> /etc/chkserv.d/chkservd.conf
        if [ ! -f /etc/chkserv.d/nginx ]; then
            touch /etc/chkserv.d/nginx
        fi
        echo "service[nginx]=80,GET / HTTP/1.0,HTTP/1..,killall -TERM nginx;sleep 2;killall -9 nginx;service nginx stop;service nginx start" > /etc/chkserv.d/nginx
        /scripts/restartsrv apache_php_fpm
        /scripts/restartsrv_chkservd
        echo ""
        echo ""
    fi
}

function chkserv_nginx_off {
    if [ -f /etc/chkserv.d/httpd ]; then
        echo ""
        echo "=== Disable TailWatch chkservd driver for Nginx ==="

        sed -i 's:service\[httpd\]=8080,:service[httpd]=80,:' /etc/chkserv.d/httpd
        sed -i 's:^nginx\:1::' /etc/chkserv.d/chkservd.conf
        if [ -f /etc/chkserv.d/nginx ]; then
            rm -f /etc/chkserv.d/nginx
        fi
        /scripts/restartsrv apache_php_fpm
        /scripts/restartsrv_chkservd
        echo ""
        echo ""
    fi
}

############################# HELPER FUCTIONS [end] #############################



### Define actions ###
case $1 in
install|update)
    clear

    echo "**************************************"
    echo "*        Installing Engintron        *"
    echo "**************************************"

    echo ""
    echo ""

    # Cleanup Engintron v1.x installation location
    if [ -f /engintron.sh ]; then
        rm -f /engintron.sh
    fi
    if [ -d /usr/local/src/engintron ]; then
        rm -rf /usr/local/src/engintron
    fi

    if [ "$2" = local ]; then
        # ~ Local (dev) installation from $APP_PATH ~
        echo -e "\033[36m=== Performing local installation from $APP_PATH... ===\033[0m"
    else
        # ~ Remote (production) installation ~
        # Set Engintron installation path
        if [ ! -d "$APP_PATH" ]; then
            mkdir -p $APP_PATH
        fi

        # Get the files
        cd $APP_PATH
        wget --no-check-certificate -O engintron.zip https://github.com/engintron/engintron/archive/master.zip
        unzip engintron.zip
        cp -rf $APP_PATH/engintron-master/* $APP_PATH/
        rm -rf $APP_PATH/engintron-master/*
        rm -f $APP_PATH/engintron.zip
    fi

    echo ""
    echo ""

    install_basics
    install_nginx $2
    install_mod_remoteip
    apache_change_port
    install_munin_patch
    install_engintron_ui

    if [ ! -f /etc/ssl/certs/dhparam.pem ]; then
        echo ""
        echo "=== Generating DHE ciphersuites (2048 bits)... ==="
        openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
    fi

    echo ""
    echo "=== Restarting Apache & Nginx... ==="
    /scripts/restartsrv apache_php_fpm
    /scripts/restartsrv_httpd
    fuser -k 80/tcp
    fuser -k 8080/tcp
    fuser -k 443/tcp
    fuser -k 8443/tcp

    if [ "$RELEASE" -gt "7" ]; then
        systemctl start nginx
    else
        service nginx start
    fi

    csf_pignore_add
    cron_for_https_vhosts_add
    chkserv_nginx_on

    if [ "$RELEASE" -gt "7" ]; then
        systemctl restart nginx
    else
        service nginx restart
    fi

    if [ ! -f $APP_PATH/state.conf ]; then
        touch $APP_PATH/state.conf
    fi
    echo "on" > $APP_PATH/state.conf

    if [ -f $APP_PATH/engintron.sh ]; then
        chmod +x $APP_PATH/engintron.sh
        $APP_PATH/engintron.sh purgecache
    fi

    /scripts/restartsrv apache_php_fpm
    /scripts/restartsrv_httpd

    sleep 5

    if [ "$RELEASE" -gt "7" ]; then
        systemctl restart httpd
        systemctl restart nginx
    else
        service httpd restart
        service nginx restart
    fi

    # Enable "engintron" shortcut
    if [ ! -f "/usr/local/sbin/engintron" ]; then
        ln -s $APP_PATH/engintron.sh /usr/local/sbin/engintron
    fi

    # Make installers executable
    if [ -d $APP_PATH/installers ]; then
        find $APP_PATH/installers/ -iname "*.sh" | xargs chmod +x
    fi

    # Make utilities executable
    if [ -d $APP_PATH/utilities ]; then
        find $APP_PATH/utilities/ -iname "*.sh" | xargs chmod +x
        find $APP_PATH/utilities/ -iname "*.pl" | xargs chmod +x
    fi

    echo ""
    echo "**************************************"
    echo "*       Installation Complete        *"
    echo "**************************************"
    echo ""
    echo ""
    ;;
remove|uninstall)
    clear

    echo "**************************************"
    echo "*         Removing Engintron         *"
    echo "**************************************"

    remove_mod_remoteip
    apache_revert_port
    remove_nginx
    remove_munin_patch
    remove_engintron_ui
    csf_pignore_remove
    cron_for_https_vhosts_remove
    chkserv_nginx_off

    echo ""
    echo "=== Removing Engintron files... ==="
    rm -rvf /opt/engintron

    echo ""
    echo "=== Restarting Apache... ==="
    /scripts/restartsrv apache_php_fpm
    /scripts/restartsrv_httpd

    # Remove "engintron" shortcut
    if [ -f "/usr/local/sbin/engintron" ]; then
        rm -f /usr/local/sbin/engintron
    fi

    echo ""
    echo "**************************************"
    echo "*          Removal Complete          *"
    echo "**************************************"
    echo ""
    echo ""
    ;;
enable)
    clear

    echo "**************************************"
    echo "*         Enabling Engintron         *"
    echo "**************************************"

    if [ ! -f $APP_PATH/state.conf ]; then
        touch $APP_PATH/state.conf
    fi
    echo "on" > $APP_PATH/state.conf

    install_munin_patch

    if [ "$RELEASE" -gt "7" ]; then
        systemctl stop nginx
    else
        service nginx stop
    fi

    sed -i 's:PROXY_TO_PORT 443;:PROXY_TO_PORT 8443;:' /etc/nginx/common_https.conf

    sed -i 's:listen 8080 default_server:listen 80 default_server:' /etc/nginx/conf.d/default.conf
    sed -i 's:listen \[\:\:\]\:8080 default_server:listen [\:\:]\:80 default_server:' /etc/nginx/conf.d/default.conf
    sed -i 's:deny all; #:# deny all; #:' /etc/nginx/conf.d/default.conf
    sed -i 's:PROXY_TO_PORT 80;:PROXY_TO_PORT 8080;:' /etc/nginx/conf.d/default.conf
    sed -i 's:\:80; # Apache Status Page:\:8080; # Apache Status Page:' /etc/nginx/conf.d/default.conf

    if [ -f /etc/nginx/conf.d/default_https.conf ]; then
        sed -i 's:listen 8443 ssl:listen 443 ssl:g' /etc/nginx/conf.d/default_https.conf
        sed -i 's:listen \[\:\:\]\:8443 ssl:listen [\:\:]\:443 ssl:g' /etc/nginx/conf.d/default_https.conf
        sed -i 's:deny all; #:# deny all; #:g' /etc/nginx/conf.d/default_https.conf
    fi

    sed -i 's:deny all; #:# deny all; #:g' /etc/nginx/utilities/https_vhosts.php
    sed -i 's:'HTTPD_HTTPS_PORT', '443':'HTTPD_HTTPS_PORT', '8443':' /etc/nginx/utilities/https_vhosts.php
    sed -i 's:'NGINX_HTTPS_PORT', '8443':'NGINX_HTTPS_PORT', '443':' /etc/nginx/utilities/https_vhosts.php

    apache_change_port

    if [ "$RELEASE" -gt "7" ]; then
        systemctl start nginx
    else
        service nginx start
    fi

    /scripts/restartsrv apache_php_fpm
    /scripts/restartsrv_httpd

    if [ "$RELEASE" -gt "7" ]; then
        systemctl restart nginx
    else
        service nginx restart
    fi

    chkserv_nginx_on

    echo ""
    echo "**************************************"
    echo "*         Engintron Enabled          *"
    echo "**************************************"
    echo ""
    echo ""
    ;;
disable)
    clear

    echo "**************************************"
    echo "*        Disabling Engintron         *"
    echo "**************************************"

    if [ ! -f $APP_PATH/state.conf ]; then
        touch $APP_PATH/state.conf
    fi
    echo "off" > $APP_PATH/state.conf

    remove_munin_patch

    if [ "$RELEASE" -gt "7" ]; then
        systemctl stop nginx
    else
        service nginx stop
    fi

    sed -i 's:PROXY_TO_PORT 8443;:PROXY_TO_PORT 443;:' /etc/nginx/common_https.conf

    sed -i 's:listen 80 default_server:listen 8080 default_server:' /etc/nginx/conf.d/default.conf
    sed -i 's:listen \[\:\:\]\:80 default_server:listen [\:\:]\:8080 default_server:' /etc/nginx/conf.d/default.conf
    sed -i 's:# deny all; #:deny all; #:' /etc/nginx/conf.d/default.conf
    sed -i 's:PROXY_TO_PORT 8080;:PROXY_TO_PORT 80;:' /etc/nginx/conf.d/default.conf
    sed -i 's:\:8080; # Apache Status Page:\:80; # Apache Status Page:' /etc/nginx/conf.d/default.conf

    if [ -f /etc/nginx/conf.d/default_https.conf ]; then
        sed -i 's:listen 443 ssl:listen 8443 ssl:g' /etc/nginx/conf.d/default_https.conf
        sed -i 's:listen \[\:\:\]\:443 ssl:listen [\:\:]\:8443 ssl:g' /etc/nginx/conf.d/default_https.conf
        sed -i 's:# deny all; #:deny all; #:g' /etc/nginx/conf.d/default_https.conf
    fi

    sed -i 's:# deny all; #:deny all; #:g' /etc/nginx/utilities/https_vhosts.php
    sed -i 's:'HTTPD_HTTPS_PORT', '8443':'HTTPD_HTTPS_PORT', '443':' /etc/nginx/utilities/https_vhosts.php
    sed -i 's:'NGINX_HTTPS_PORT', '443':'NGINX_HTTPS_PORT', '8443':' /etc/nginx/utilities/https_vhosts.php

    apache_revert_port

    if [ "$RELEASE" -gt "7" ]; then
        systemctl start nginx
    else
        service nginx start
    fi

    /scripts/restartsrv apache_php_fpm
    /scripts/restartsrv_httpd

    if [ "$RELEASE" -gt "7" ]; then
        systemctl restart nginx
    else
        service nginx restart
    fi

    chkserv_nginx_off

    echo ""
    echo "**************************************"
    echo "*         Engintron Disabled         *"
    echo "**************************************"
    echo ""
    echo ""
    ;;
resall)
    echo "========================================="
    echo "=== Restarting All Important Services ==="
    echo "========================================="
    echo ""

    #if [ -f "/usr/local/cpanel/cpanel" ]; then
    #   echo "Restarting cPanel..."
    #   service cpanel restart
    #   echo ""
    #fi

    if [ "$(pstree | grep 'crond')" ]; then
        echo "Restarting Cron..."
        if [ "$RELEASE" -gt "7" ]; then
            systemctl restart crond
        else
            service crond restart
        fi
        echo ""
    fi
    if [[ -f /etc/csf/csf.conf && "$(cat /etc/csf/csf.conf | grep 'TESTING = \"0\"')" ]]; then
        echo "Restarting CSF..."
        csf -r
        echo ""
    fi
    if [ "$(pstree | grep 'lfd')" ]; then
        echo "Restarting LFD..."
        if [ "$RELEASE" -gt "7" ]; then
            systemctl restart lfd
        else
            service lfd restart
        fi
        echo ""
    fi
    if [ "$(pstree | grep 'munin-node')" ]; then
        echo "Restarting Munin..."
        if [ "$RELEASE" -gt "7" ]; then
            systemctl restart munin-node
        else
            service munin-node restart
        fi
        echo ""
    fi
    if [ "$(pstree | grep 'mysql')" ]; then
        echo "Restarting the database..."
        /scripts/restartsrv_mysql
        echo ""
    fi
    if [ "$(pstree | grep 'httpd')" ]; then
        echo "Restarting Apache..."
        /scripts/restartsrv apache_php_fpm
        /scripts/restartsrv_httpd
        echo ""
    fi
    if [ "$(pstree | grep 'nginx')" ]; then
        echo "Restarting Nginx..."
        if [ "$RELEASE" -gt "7" ]; then
            systemctl restart nginx
        else
            service nginx restart
        fi
        echo ""
    fi
    echo ""
    ;;
res|restart)
    echo "====================================="
    echo "=== Restarting All Basic Services ==="
    echo "====================================="
    echo ""
    if [ "$(pstree | grep 'httpd')" ]; then
        echo "Restarting Apache..."
        /scripts/restartsrv apache_php_fpm
        /scripts/restartsrv_httpd
        echo ""
    fi
    if [ "$(pstree | grep 'nginx')" ]; then
        if [ "$2" = force ]; then
            echo "Kill all Nginx processes..."
            killall -9 nginx
            killall -9 nginx
            killall -9 nginx
        fi
        echo "Restarting Nginx..."
        if [ "$RELEASE" -gt "7" ]; then
            systemctl restart nginx
        else
            service nginx restart
        fi
        echo ""
    fi
    echo ""
    ;;
reload)
    echo "======================="
    echo "=== Reloading Nginx ==="
    echo "======================="
    echo ""
    if [ "$(pstree | grep 'nginx')" ]; then
        echo "Reloading Nginx..."
        if [ "$RELEASE" -gt "7" ]; then
            systemctl reload nginx
        else
            service nginx reload
        fi
        echo ""
    fi
    echo ""
    ;;
restoreipfwd)
    echo "======================================="
    echo "=== Restore IP Forwarding in Apache ==="
    echo "======================================="
    echo ""
    install_mod_remoteip
    /scripts/restartsrv apache_php_fpm
    /scripts/restartsrv_httpd
    if [ "$RELEASE" -gt "7" ]; then
        systemctl reload nginx
    else
        service nginx reload
    fi
    echo "Operation completed."
    echo ""
    echo ""
    ;;
upd)
    echo "================================"
    echo "=== Updating Server Software ==="
    echo "================================"
    echo ""
    if [ "$DISTRO" = "el" ]; then
        if [ "$RELEASE" -gt "7" ]; then
            echo "~ For EL8 (or newer) ~"
            echo ""
            echo "Flush all caches..."
            dnf clean all
            echo ""
            echo "Update packages..."
            dnf -y update
        else
            echo "~ For EL6 or EL7 ~"
            echo ""
            echo "Flush all caches..."
            yum clean all
            echo ""
            echo "Update packages..."
            yum -y update
        fi
    else
        echo ""
        echo "Flush all caches..."
        apt-get clean all
        echo ""
        echo "Update packages..."
        apt-get update
        apt-get -y dist-upgrade
        apt-get -y autoremove
    fi
    echo ""
    echo "Operation completed."
    ;;
info)
    echo "=================="
    echo "=== OS Version ==="
    echo "=================="
    echo ""
    if [ -f "/etc/redhat-release" ]; then
        cat /etc/redhat-release
        if [ -f "/usr/local/cpanel/cpanel" ]; then
            CPANEL_VERSION=$(/usr/local/cpanel/cpanel -V)
            echo ""
            echo "cPanel version: $CPANEL_VERSION"
        fi
    else
        lsb_release -drc
    fi
    echo ""
    echo ""

    echo "=================="
    echo "=== Disk Usage ==="
    echo "=================="
    echo ""
    df -hT
    echo ""
    echo ""

    echo "=============="
    echo "=== Uptime ==="
    echo "=============="
    echo ""
    uptime
    echo ""
    echo ""

    echo "==================="
    echo "=== System Date ==="
    echo "==================="
    echo ""
    date
    echo ""
    echo ""

    echo "======================="
    echo "=== Users Logged In ==="
    echo "======================="
    echo ""
    who
    ;;
tp)
    echo "=== Tuning Primer ==="
    echo ""
    bash $APP_PATH/utilities/tuning-primer.sh
    echo ""
    echo "Operation completed."
    ;;
mt)
    echo "=== MySQL Tuner ==="
    echo ""
    if [ -f /root/.my.cnf ]; then
        source /root/.my.cnf
        perl $APP_PATH/utilities/mysqltuner/mysqltuner.pl --user $user --pass $password
    else
        echo "Missing /root/.my.cnf credentials."
        echo "Can't connect to the server's database!"
    fi
    echo ""
    echo "Operation completed."
    ;;
purgecache)
    NOW=$(date +'%Y.%m.%d at %H:%M:%S')
    echo "==============================================================="
    echo "=== Purge Nginx cache/temp files and restart Apache & Nginx ==="
    echo "==============================================================="
    echo ""
    echo "--- Process started at $NOW ---"
    echo ""
    if [ "$(pstree | grep 'httpd')" ]; then
        echo "Restarting Apache..."
        /scripts/restartsrv apache_php_fpm
        /scripts/restartsrv_httpd
        echo ""
    fi
    if [ "$(pstree | grep 'nginx')" ]; then
        echo "Count Nginx cache/temp files..."
        du -shc /var/cache/nginx/engintron_*/
        sleep 1
        echo ""
        echo "Purging Nginx cache/temp files..."
        find /var/cache/nginx/engintron_dynamic/ -type f | xargs rm -rf
        find /var/cache/nginx/engintron_static/ -type f | xargs rm -rf
        find /var/cache/nginx/engintron_temp/ -type f | xargs rm -rf
        echo ""
        echo "Restarting Nginx..."
        if [ "$RELEASE" -gt "7" ]; then
            systemctl restart nginx
        else
            service nginx restart
        fi
        echo ""
    fi
    echo ""
    ;;
purgelogs)
    echo "================================================================"
    echo "=== Clean Nginx access/error logs and restart Apache & Nginx ==="
    echo "================================================================"
    echo ""
    if [ -f /var/log/nginx/access.log ]; then
        echo "" > /var/log/nginx/access.log
    fi
    if [ -f /var/log/nginx/error.log ]; then
        echo "" > /var/log/nginx/error.log
    fi
    if [ "$(pstree | grep 'httpd')" ]; then
        echo "Restarting Apache..."
        /scripts/restartsrv apache_php_fpm
        /scripts/restartsrv_httpd
        echo ""
    fi
    if [ "$(pstree | grep 'nginx')" ]; then
        echo "Restarting Nginx..."
        if [ "$RELEASE" -gt "7" ]; then
            systemctl restart nginx
        else
            service nginx restart
        fi
        echo ""
    fi
    echo ""
    ;;
ip)
    echo "=== Get server's IP ==="
    echo ""
    echo "~ From the system..."
    ip a | grep global | grep "inet."
    echo ""
    echo ""
    echo "~ Externally from ifconfig.co..."
    echo "IPv4: $(curl -s -4 ifconfig.co)"
    echo "IPv6: $(curl -s -6 ifconfig.co)"
    echo "Default: $(curl -s ifconfig.co)"
    echo ""
    echo ""
    echo "~ Externally from ifconfig.io..."
    echo "IPv4: $(curl -s -4 ifconfig.io)"
    echo "IPv6: $(curl -s -6 ifconfig.io)"
    echo "Default: $(curl -s ifconfig.io)"
    echo ""
    echo ""
    echo "Operation completed."
    ;;
80)
    echo "=== Connections on port 80 sorted by connection count & IP ==="
    echo ""
    netstat -anp | grep :80 | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -n
    echo ""
    echo ""
    echo "=== Concurrent connections on port 80 ==="
    echo ""
    netstat -an | grep :80 | wc -l
    echo ""
    echo "Operation completed."
    ;;
443)
    echo "=== Connections on port 443 sorted by connection count & IP ==="
    echo ""
    netstat -anp | grep :443 | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -n
    echo ""
    echo ""
    echo "=== Concurrent connections on port 443 ==="
    echo ""
    netstat -an | grep :443 | wc -l
    echo ""
    echo "Operation completed."
    ;;
80-443)
    echo "=== Concurrent connections on port 80 ==="
    echo ""
    netstat -an | grep :80 | wc -l
    echo ""
    echo ""
    echo "=== Concurrent connections on port 443 ==="
    echo ""
    netstat -an | grep :443 | wc -l
    echo ""
    echo "Operation completed."
    ;;

80)
    echo "=== Connections on port 80 (HTTP traffic) sorted by connection count & IP ==="
    echo ""
    netstat -anp | grep :80 | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -n
    echo ""
    echo ""
    echo "=== Concurrent connections on port 80 (HTTP traffic) ==="
    echo ""
    netstat -an | grep :80 | wc -l
    echo ""
    echo ""
    ;;
443)
    echo "=== Connections on port 443 (HTTPS traffic) sorted by connection count & IP ==="
    echo ""
    netstat -anp | grep :443 | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -n
    echo ""
    echo ""
    echo "=== Concurrent connections on port 443 (HTTPS traffic) ==="
    echo ""
    netstat -an | grep :443 | wc -l
    echo ""
    echo ""
    ;;
fixownerperms)
    echo "==================================================="
    echo "=== Fix user file & directory owner permissions ==="
    echo "==================================================="
    echo ""
    cd /home
    for user in $( ls -d * )
    do
        if [ -d /home/$user/public_html ]; then
            echo "=== Fixing permissions for user $user ==="
            chown -R $user:$user /home/$user/public_html
            chown $user:nobody /home/$user/public_html
        fi
    done
    echo "Operation completed."
    echo ""
    echo ""
    ;;
fixaccessperms)
    echo "===================================================="
    echo "=== Fix user file & directory access permissions ==="
    echo "===================================================="
    echo ""
    echo "Changing directory permissions to 755..."
    find /home/*/public_html/ -type d -exec chmod 755 {} \;
    echo ""
    echo "Changing file permissions to 644..."
    find /home/*/public_html/ -type f -exec chmod 644 {} \;
    echo ""
    echo "Operation completed."
    echo ""
    echo ""
    ;;
cleanup)
    echo "========================================================================="
    echo "=== Cleanup Mac or Windows specific metadata & Apache error_log files ==="
    echo "========================================================================="
    echo ""
    find /home/*/public_html/ -iname 'error_log' | xargs rm -rvf
    find /home/*/public_html/ -iname '.DS_Store' | xargs rm -rvf
    find /home/*/public_html/ -iname 'thumbs.db' | xargs rm -rvf
    find /home/*/public_html/ -iname '__MACOSX' | xargs rm -rvf
    find /home/*/public_html/ -iname '._*' | xargs rm -rvf
    echo ""
    echo "Operation completed."
    echo ""
    echo ""
    ;;
w|weather)
    if [ "$2" != "" ]; then
        curl wttr.in/$2
    else
        curl wttr.in
    fi
    ;;
-h|--help|*)
    echo "    _______   _____________   ____________  ____  _   __"
    echo "   / ____/ | / / ____/  _/ | / /_  __/ __ \/ __ \/ | / /"
    echo "  / __/ /  |/ / / __ / //  |/ / / / / /_/ / / / /  |/ / "
    echo " / /___/ /|  / /_/ // // /|  / / / / _, _/ /_/ / /|  /  "
    echo "/_____/_/ |_/\____/___/_/ |_/ /_/ /_/ |_|\____/_/ |_/   "
    echo "                                                        "
    echo "                 https://engintron.com                  "
    cat <<EOF

Engintron is the easiest way to integrate Nginx on your cPanel/WHM server.

Current version: $APP_VERSION
Released: $APP_RELEASE_DATE

Usage: engintron [command] [flag]

~ Deployment Commands:
    install         Install, re-install or update Engintron (enables Nginx by default).
                    Add optional flag "mainline" to install Nginx mainline release.
    remove          Remove Engintron completely.
    enable          Set Nginx to ports 80/443 & Apache to ports 8080/8443
    disable         Set Nginx to ports 8080/8443 & switch Apache to ports 80/443
    restoreipfwd    Restore Nginx IP forwarding in Apache

~ Service Commands:
    res             Restart web servers only (Apache & Nginx)
    res force       Restart Apache & force restart Nginx (kills all previous Nginx processes)
    resall          Restart Cron, CSF & LFD (if installed), Munin (if installed),
                    MySQL/MariaDB, Apache & Nginx
    upd             Update server software
    info            Show basic system information

~ Database Utilities:
    tp              Run Tuning Primer diagnostics for MySQL or MariaDB
    mt              Run MySQL Tuner diagnostics for MySQL or MariaDB

~ Purge Caches:
    purgecache      Purge Nginx's "cache" & "temp" folders,
                    then restart both Apache & Nginx
    purgelogs       Purge Nginx's access & error log files

~ Network Utilities:
    ip              Display server's main IP
    80              Show active connections on port 80 sorted by connection count & IP,
                    including total concurrent connections count
    443             Show active connections on port 443 sorted by connection count & IP,
                    including total concurrent connections count
    80-443          Show totals for concurrent connections on ports 80 & 443

~ Filesystem Utilities:
    fixownerperms   Fix owner permissions in all user /public_html directories.
                    Use with caution! If you have add-on domains or subdomains within any /public_html folder
                    you are advised NOT to use this option as it will break website service for these
                    add-on domains or subdomains!
    fixaccessperms  Change file & directory access permissions to 644 & 755 respectively
                    in all user /public_html directories.
                    Use with caution! If you have add-on domains or subdomains within any /public_html folder
                    you are advised NOT to use this option as it will break website service for these
                    add-on domains or subdomains!
    cleanup         Cleanup Mac or Windows specific metadata & Apache error_log files
                    in all user /public_html directories

~ Fun Utilities:
    w (or weather)  Show the current weather forecast - add 3-letter airport code for
                    exact weather forecast (e.g. muc, ath etc.)

~ Help:
    -h OR --help    Show this help page


~~ Enjoy Engintron! ~~

EOF
    ;;
esac

# END
