#!/bin/bash

# /**
#  * @version    1.8.0
#  * @package    Engintron for cPanel/WHM
#  * @author     Fotis Evangelou
#  * @url        https://engintron.com
#  * @copyright  Copyright (c) 2010 - 2017 Nuevvo Webware P.C. All rights reserved.
#  * @license    GNU/GPL license: https://www.gnu.org/copyleft/gpl.html
#  */

# Constants
APP_PATH="/usr/local/src/engintron"
APP_VERSION="1.8.0"

CPANEL_PLG_PATH="/usr/local/cpanel/whostmgr/docroot/cgi"
REPO_CDN_URL="https://cdn.rawgit.com/engintron/engintron/master"

GET_HTTPD_VERSION=$(httpd -v | grep "Server version")
GET_CENTOS_VERSION=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))
GET_CPANEL_VERSION=$(/usr/local/cpanel/cpanel -V)



############################# HELPER FUCTIONS [start] #############################

function install_basics {

    echo "=== Let's upgrade our system first & install a few required packages ==="
    yum -y update
    yum -y upgrade
    yum -y install atop bash-completion bc cronie curl htop ifstat iftop iotop make nano openssl-devel pcre pcre-devel sudo tree unzip zip zlib-devel
    yum clean all
    echo ""
    echo ""

}

function install_mod_rpaf {

    echo "=== Installing mod_rpaf (v0.8.4) for Apache ==="
    cd /usr/local/src
    /bin/rm -f mod_rpaf-0.8.4.zip
    wget --no-check-certificate $REPO_CDN_URL/apache/mod_rpaf-0.8.4.zip
    unzip -o mod_rpaf-0.8.4.zip
    /bin/rm -f mod_rpaf-0.8.4.zip
    cd mod_rpaf-0.8.4
    chmod +x apxs.sh
    ./apxs.sh -i -c -n mod_rpaf.so mod_rpaf.c
    /bin/rm -rf /usr/local/src/mod_rpaf-0.8.4/

    if [ -f /usr/local/apache/modules/mod_rpaf.so ]; then

        # Get system IPs
        #systemips=$(ip addr show | grep 'inet ' | grep ' brd ' | cut -d/ -f1 | cut -c10- | tr '\n' ' ');
        systemips=$(ip addr show | grep -o "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | sed ':a;N;$!ba;s/\n/ /g');

        if [ ! -f /usr/local/apache/conf/includes/rpaf.conf ]; then
            touch /usr/local/apache/conf/includes/rpaf.conf
        fi

        cat > "/usr/local/apache/conf/includes/rpaf.conf" <<EOF
# RPAF
LoadModule              rpaf_module modules/mod_rpaf.so
RPAF_Enable             On
RPAF_ProxyIPs           127.0.0.1 $systemips
RPAF_SetHostName        On
RPAF_SetHTTPS           On
RPAF_SetPort            On
RPAF_ForbidIfNotProxy   Off
RPAF_Header             X-Real-IP
EOF

        /bin/cp -f /usr/local/apache/conf/httpd.conf /usr/local/apache/conf/httpd.conf.bak
        sed -i 's:Include "/usr/local/apache/conf/includes/rpaf.conf"::' /usr/local/apache/conf/httpd.conf
        sed -i 's:Include "/usr/local/apache/conf/includes/errordocument.conf":Include "/usr/local/apache/conf/includes/errordocument.conf"\nInclude "/usr/local/apache/conf/includes/rpaf.conf":' /usr/local/apache/conf/httpd.conf
        sed -i "s:LogFormat \"%h %l:LogFormat \"%h %a %l:" /usr/local/apache/conf/httpd.conf
        echo ""
        echo ""

    fi

}

function remove_mod_rpaf {

    if [ -f /usr/local/apache/conf/includes/rpaf.conf ]; then
        echo "=== Removing mod_rpaf (v0.8.4) for Apache ==="
        rm -f /usr/local/apache/conf/includes/rpaf.conf
        sed -i 's:Include "/usr/local/apache/conf/includes/rpaf.conf"::' /usr/local/apache/conf/httpd.conf
        sed -i "s:LogFormat \"%h %a %l:LogFormat \"%h %l:" /usr/local/apache/conf/httpd.conf
        echo ""
        echo ""
    fi

}

function install_mod_remoteip {

    # Get system IPs
    #systemips=$(ip addr show | grep 'inet ' | grep ' brd ' | cut -d/ -f1 | cut -c10- | tr '\n' ' ');
    systemips=$(ip addr show | grep -o "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | sed ':a;N;$!ba;s/\n/ /g');

    echo "=== Installing mod_remoteip for Apache ==="

    if [ -f /etc/apache2/conf/httpd.conf ]; then
        yum -y install ea-apache24-mod_remoteip

        if [ -f /etc/apache2/modules/mod_remoteip.so ]; then
            REMOTEIP_CONF=$(find /etc/apache2/conf.modules.d/ -iname "*_mod_remoteip.conf")
            if [ -f $REMOTEIP_CONF ]; then

                cat > $REMOTEIP_CONF <<EOF
# Enable mod_remoteip
LoadModule remoteip_module modules/mod_remoteip.so
RemoteIPInternalProxy 127.0.0.1 $systemips
RemoteIPHeader X-Real-IP
EOF
                sed -i "s:LogFormat \"%h %l:LogFormat \"%h %a %l:" /etc/apache2/conf/httpd.conf
            fi
        fi
    else
        cd /usr/local/src
        /bin/rm -f mod_remoteip.c
        #wget --no-check-certificate https://svn.apache.org/repos/asf/httpd/httpd/trunk/modules/metadata/mod_remoteip.c
        wget --no-check-certificate $REPO_CDN_URL/apache/mod_remoteip.c
        wget --no-check-certificate $REPO_CDN_URL/apache/apxs.sh
        chmod +x apxs.sh
        ./apxs.sh -i -c -n mod_remoteip.so mod_remoteip.c
        /bin/rm -f mod_remoteip.c
        /bin/rm -f apxs.sh

        if [ -f /usr/local/apache/modules/mod_remoteip.so ]; then

            if [ ! -f /usr/local/apache/conf/includes/remoteip.conf ]; then
                touch /usr/local/apache/conf/includes/remoteip.conf
            fi

            cat > "/usr/local/apache/conf/includes/remoteip.conf" <<EOF
# RemoteIP
LoadModule remoteip_module modules/mod_remoteip.so
RemoteIPInternalProxy 127.0.0.1 $systemips
RemoteIPHeader X-Real-IP
EOF

            /bin/cp -f /usr/local/apache/conf/httpd.conf /usr/local/apache/conf/httpd.conf.bak
            sed -i 's:Include "/usr/local/apache/conf/includes/remoteip.conf"::' /usr/local/apache/conf/httpd.conf
            sed -i 's:Include "/usr/local/apache/conf/includes/errordocument.conf":Include "/usr/local/apache/conf/includes/errordocument.conf"\nInclude "/usr/local/apache/conf/includes/remoteip.conf":' /usr/local/apache/conf/httpd.conf
            sed -i "s:LogFormat \"%h %l:LogFormat \"%h %a %l:" /usr/local/apache/conf/httpd.conf
        fi
    fi

    echo ""
    echo ""

}

function remove_mod_remoteip {

    if [ -f /etc/apache2/conf/httpd.conf ]; then
        yum -y remove ea-apache24-mod_remoteip
        sed -i "s:LogFormat \"%h %a %l:LogFormat \"%h %l:" /etc/apache2/conf/httpd.conf
    else
        if [ -f /usr/local/apache/conf/includes/remoteip.conf ]; then
            echo "=== Removing mod_remoteip for Apache ==="
            rm -f /usr/local/apache/conf/includes/remoteip.conf
            sed -i 's:Include "/usr/local/apache/conf/includes/remoteip.conf"::' /usr/local/apache/conf/httpd.conf
            sed -i "s:LogFormat \"%h %a %l:LogFormat \"%h %l:" /usr/local/apache/conf/httpd.conf
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
        if grep -Fxq "^apache_" /var/cpanel/cpanel.config
        then
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
    /usr/local/cpanel/bin/apache_conf_distiller --update
    /scripts/rebuildhttpdconf
    /scripts/restartsrv_httpd

    echo ""
    echo ""

}

function apache_revert_port {

    echo "=== Switch Apache back to port 80 ==="

    if [ -f /usr/local/cpanel/bin/whmapi1 ]; then
        /usr/local/cpanel/bin/whmapi1 set_tweaksetting key=apache_port value=0.0.0.0:80
        /usr/local/cpanel/bin/whmapi1 set_tweaksetting key=apache_ssl_port value=0.0.0.0:443
    else
        if grep -Fxq "^apache_" /var/cpanel/cpanel.config
        then
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
    /usr/local/cpanel/bin/apache_conf_distiller --update
    /scripts/rebuildhttpdconf
    /scripts/restartsrv_httpd

    echo ""
    echo ""

}

function install_nginx {

    if [ ! -f /etc/yum.repos.d/nginx.repo ]; then
        touch /etc/yum.repos.d/nginx.repo
    fi

    # Allow switching from mainline to stable release
    if [[ ! $1 ]]; then
        if grep -iq "mainline" /etc/yum.repos.d/nginx.repo; then
            yum -y remove nginx
        fi
    fi

    # Setup Nginx repo
    if [[ $1 == 'mainline' ]]; then
        echo "=== Install Nginx (mainline) from nginx.org ==="
        cat > "/etc/yum.repos.d/nginx.repo" <<EOFM
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=0
enabled=1
EOFM
    else
        echo "=== Install Nginx (stable) from nginx.org ==="
        cat > "/etc/yum.repos.d/nginx.repo" <<EOFS
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=0
enabled=1
EOFS
    fi

    # Install Nginx
    yum -y install nginx

    # Copy Nginx config files
    if [ -f /etc/nginx/custom_rules ]; then
        /bin/cp -f $APP_PATH/nginx/custom_rules /etc/nginx/custom_rules.dist
    else
        /bin/cp -f $APP_PATH/nginx/custom_rules /etc/nginx/
    fi

    if [ -f /etc/nginx/proxy_params_common ]; then
        /bin/cp -f /etc/nginx/proxy_params_common /etc/nginx/proxy_params_common.bak
    fi
    /bin/cp -f $APP_PATH/nginx/proxy_params_common /etc/nginx/

    if [ -f /etc/nginx/proxy_params_dynamic ]; then
        /bin/cp -f /etc/nginx/proxy_params_dynamic /etc/nginx/proxy_params_dynamic.bak
    fi
    /bin/cp -f $APP_PATH/nginx/proxy_params_dynamic /etc/nginx/

    if [ -f /etc/nginx/proxy_params_static ]; then
        /bin/cp -f /etc/nginx/proxy_params_static /etc/nginx/proxy_params_static.bak
    fi
    /bin/cp -f $APP_PATH/nginx/proxy_params_static /etc/nginx/

    if [ -f /etc/nginx/mime.types ]; then
        /bin/cp -f /etc/nginx/mime.types /etc/nginx/mime.types.bak
    fi
    /bin/cp -f $APP_PATH/nginx/mime.types /etc/nginx/

    if [ -f /etc/nginx/nginx.conf ]; then
        /bin/cp -f /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    fi
    /bin/cp -f $APP_PATH/nginx/nginx.conf /etc/nginx/

    if [ -f /etc/nginx/conf.d/default.conf ]; then
        /bin/cp -f /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak
    fi
    /bin/rm -f /etc/nginx/conf.d/*.conf
    /bin/cp -f $APP_PATH/nginx/conf.d/default.conf /etc/nginx/conf.d/

    /bin/cp -f $APP_PATH/nginx/common_https.conf /etc/nginx/

    if [ ! -d /etc/nginx/utilities ]; then
        mkdir -p /etc/nginx/utilities
    fi
    /bin/cp -f $APP_PATH/nginx/utilities/https_vhosts.php /etc/nginx/utilities/
    /bin/cp -f $APP_PATH/nginx/utilities/https_vhosts.sh /etc/nginx/utilities/
    chmod +x /etc/nginx/utilities/*

    if [ ! -d /etc/ssl/engintron ]; then
        mkdir -p /etc/ssl/engintron
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

    service nginx stop

    yum -y remove nginx
    /bin/rm -rf /etc/nginx/*
    /bin/rm -f /etc/yum.repos.d/nginx.repo
    /bin/rm -rf /etc/ssl/engintron/*

    echo ""
    echo ""
    echo "=== Removing Nginx from Cpanel TailWatch... ==="
    sed -i -- 's/=8080/=80/g' /etc/chkserv.d/httpd
    /bin/rm -f /etc/chkserv.d/nginx
    /bin/rm -f /var/run/chkservd/nginx
    sed -i '/nginx:1/d' /etc/chkserv.d/chkservd.conf
    /scripts/restartsrv_chkservd
    
}

function install_engintron_ui {

    echo "=== Installing Engintron WHM plugin files... ==="

    # Cleanup older installations from the obsolete addon_engintron.cgi file
    if [ -f $CPANEL_PLG_PATH/addon_engintron.cgi ]; then
        /bin/rm -f $CPANEL_PLG_PATH/addon_engintron.cgi
    fi

    /bin/cp -f $APP_PATH/app/engintron.php $CPANEL_PLG_PATH/
    chmod +x $CPANEL_PLG_PATH/engintron.php

    echo ""
    echo "=== Register Engintron as a cPanel app ==="

    /usr/local/cpanel/bin/register_appconfig $APP_PATH/app/engintron.conf

    echo ""
    echo ""

}

function remove_engintron_ui {

    echo "=== Removing Engintron WHM plugin files... ==="
    /bin/rm -f $CPANEL_PLG_PATH/engintron.php

    echo ""
    echo "=== Unregister Engintron as a cPanel app ==="

    /usr/local/cpanel/bin/unregister_appconfig engintron

    echo ""
    echo ""

}

function install_munin_patch {

    if [ -f /etc/munin/plugin-conf.d/cpanel.conf ]; then
        echo "=== Updating Munin's configuration for Apache ==="

        if grep -q "\[apache_status\]" /etc/munin/plugin-conf.d/cpanel.conf
        then
            echo "Munin configuration already updated, nothing to do here"
        else
            cat >> "/etc/munin/plugin-conf.d/cpanel.conf" <<EOF

[apache_status]
env.ports 8080
env.label 8080
EOF
        fi

        ln -s /usr/local/cpanel/3rdparty/share/munin/plugins/nginx_* /etc/munin/plugins/

        service munin-node restart

        echo ""
        echo ""
    fi

}

function remove_munin_patch {

    if [ -f /etc/munin/plugin-conf.d/cpanel.conf ]; then
        echo ""
        echo "=== Updating Munin's configuration for Apache ==="

        if grep -q "\[apache_status\]" /etc/munin/plugin-conf.d/cpanel.conf
        then
            sed -i 's:\[apache_status\]::' /etc/munin/plugin-conf.d/cpanel.conf
            sed -i 's:env\.ports 8080::' /etc/munin/plugin-conf.d/cpanel.conf
            sed -i 's:env\.label 8080::' /etc/munin/plugin-conf.d/cpanel.conf
        else
            echo "Munin was not found, nothing to do here"
        fi

        /bin/rm -f /etc/munin/plugins/nginx_*

        service munin-node restart

        echo ""
        echo ""
    fi

}

function csf_pignore_add {
    if [ -f /etc/csf/csf.pignore ]; then
        echo ""
        echo "=== Adding Nginx to CSF's process ignore list ==="

        if grep -q "exe\:\/usr\/sbin\/nginx" /etc/csf/csf.pignore
        then
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

        if grep -q "exe\:\/usr\/sbin\/nginx" /etc/csf/csf.pignore
        then
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
        if grep -q "https_vhosts\.sh" /etc/crontab
        then
            echo "=== Skip adding cron job to generate Nginx's HTTPS vhosts ==="
        else
            echo ""
            echo "=== Adding cron job to generate Nginx's HTTPS vhosts ==="

            cat >> "/etc/crontab" <<EOF

* * * * * root /etc/nginx/utilities/https_vhosts.sh >> /dev/null 2>&1

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

        echo ""
        echo ""
    fi
}

# Check SSH connections
# 0 */6 * * * root /root/kontrol/tools/check_ssh_connections.sh >> /dev/null 2>&1


############################# HELPER FUCTIONS [end] #############################



### Define actions ###
case $1 in
install)

    clear

    if [ ! -f /engintron.sh ]; then
        echo ""
        echo ""
        echo "***********************************************"
        echo ""
        echo " ENGINTRON NOTICE:"
        echo " You must place & execute engintron.sh"
        echo " from the root directory (/) of your server!"
        echo ""
        echo " --- Exiting ---"
        echo ""
        echo "***********************************************"
        echo ""
        echo ""
        exit 0
    fi

    echo "**************************************"
    echo "*        Installing Engintron        *"
    echo "**************************************"

    chmod +x /engintron.sh
    cd /

    # Set Engintron src file path
    if [[ ! -d $APP_PATH ]]; then
        mkdir -p $APP_PATH
    fi

    # Get the files
    cd $APP_PATH
    wget --no-check-certificate -O engintron.zip https://github.com/engintron/engintron/archive/master.zip
    unzip engintron.zip
    /bin/cp -rf $APP_PATH/engintron-master/* $APP_PATH/
    /bin/rm -rvf $APP_PATH/engintron-master/*
    /bin/rm -f $APP_PATH/engintron.zip

    cd /

    echo ""
    echo ""

    install_basics
    install_nginx $2

    if [[ $GET_HTTPD_VERSION =~ "Apache/2.2." ]]; then
        install_mod_rpaf
    else
        install_mod_remoteip
    fi

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
    /scripts/restartsrv_httpd
    fuser -k 80/tcp
    fuser -k 8080/tcp
    fuser -k 443/tcp
    fuser -k 8443/tcp
    service nginx start

    csf_pignore_add
    cron_for_https_vhosts_add

    service nginx restart

    if [ ! -f $APP_PATH/state.conf ]; then
        touch $APP_PATH/state.conf
    fi
    echo "on" > $APP_PATH/state.conf

    if [ -f $APP_PATH/engintron.sh ]; then
    	chmod +x $APP_PATH/engintron.sh
    	$APP_PATH/engintron.sh purgecache
    fi
    echo ""
    echo "=== Adding nginx to Cpanel TailWatch... ==="
    sed -i -- 's/=80/=8080/g' /etc/chkserv.d/httpd
    echo "service[nginx]=80,GET / HTTP/1.0,HTTP/1..,service nginx restart" > /etc/chkserv.d/nginx
    printf "$(cat /etc/chkserv.d/chkservd.conf)\nnginx:1"  | sort -o /etc/chkserv.d/chkservd.conf
    echo "+" > /var/run/chkservd/nginx
    /scripts/restartsrv_chkservd
    echo ""
    echo "**************************************"
    echo "*       Installation Complete        *"
    echo "**************************************"
    echo ""
    echo ""
    ;;
remove)

    clear

    echo "**************************************"
    echo "*         Removing Engintron         *"
    echo "**************************************"

    if [[ $GET_HTTPD_VERSION =~ "Apache/2.2." ]]; then
        remove_mod_rpaf
    else
        remove_mod_remoteip
    fi

    apache_revert_port
    remove_nginx
    remove_munin_patch
    remove_engintron_ui
    csf_pignore_remove
    cron_for_https_vhosts_remove

    echo ""
    echo "=== Removing Engintron files... ==="
    /bin/rm -rvf $APP_PATH

    echo ""
    echo "=== Restarting Apache... ==="
    /scripts/restartsrv_httpd

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
    service nginx stop
    sed -i 's:listen 8080 default_server:listen 80 default_server:' /etc/nginx/conf.d/default.conf
    sed -i 's:listen [\:\:]\:8080 default_server:listen [\:\:]\:80 default_server:' /etc/nginx/conf.d/default.conf
    sed -i 's:deny all; #:# deny all; #:' /etc/nginx/conf.d/default.conf
    sed -i 's:\:80; # Apache Status Page:\:8080; # Apache Status Page:' /etc/nginx/conf.d/default.conf
    if [ -f /etc/nginx/conf.d/default_https.conf ]; then
        sed -i 's:listen 8443 ssl:listen 443 ssl:g' /etc/nginx/conf.d/default_https.conf
        sed -i 's:listen [\:\:]\:8443 ssl:listen [\:\:]\:443 ssl:g' /etc/nginx/conf.d/default_https.conf
        sed -i 's:deny all; #:# deny all; #:g' /etc/nginx/conf.d/default_https.conf
    fi
    sed -i 's:deny all; #:# deny all; #:g' /etc/nginx/utilities/https_vhosts.php
    sed -i 's:'HTTPD_HTTPS_PORT', '443':'HTTPD_HTTPS_PORT', '8443':' /etc/nginx/utilities/https_vhosts.php
    sed -i 's:'NGINX_HTTPS_PORT', '8443':'NGINX_HTTPS_PORT', '443':' /etc/nginx/utilities/https_vhosts.php
    sed -i 's:PROXY_TO_PORT 443:PROXY_TO_PORT 8443:' /etc/nginx/common_https.conf
    sed -i 's:PROXY_DOMAIN_OR_IP\:80:PROXY_DOMAIN_OR_IP\:8080:' /etc/nginx/proxy_params_common
    apache_change_port
    service nginx start

    /scripts/restartsrv_httpd
    service nginx restart

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
    service nginx stop
    sed -i 's:listen 80 default_server:listen 8080 default_server:' /etc/nginx/conf.d/default.conf
    sed -i 's:listen [\:\:]\:80 default_server:listen [\:\:]\:8080 default_server:' /etc/nginx/conf.d/default.conf
    sed -i 's:# deny all; #:deny all; #:' /etc/nginx/conf.d/default.conf
    sed -i 's:\:8080; # Apache Status Page:\:80; # Apache Status Page:' /etc/nginx/conf.d/default.conf
    if [ -f /etc/nginx/conf.d/default_https.conf ]; then
        sed -i 's:listen 443 ssl:listen 8443 ssl:g' /etc/nginx/conf.d/default_https.conf
        sed -i 's:listen [\:\:]\:443 ssl:listen [\:\:]\:8443 ssl:g' /etc/nginx/conf.d/default_https.conf
        sed -i 's:# deny all; #:deny all; #:g' /etc/nginx/conf.d/default_https.conf
    fi
    sed -i 's:# deny all; #:deny all; #:g' /etc/nginx/utilities/https_vhosts.php
    sed -i 's:'HTTPD_HTTPS_PORT', '8443':'HTTPD_HTTPS_PORT', '443':' /etc/nginx/utilities/https_vhosts.php
    sed -i 's:'NGINX_HTTPS_PORT', '443':'NGINX_HTTPS_PORT', '8443':' /etc/nginx/utilities/https_vhosts.php
    sed -i 's:PROXY_TO_PORT 8443:PROXY_TO_PORT 443:' /etc/nginx/common_https.conf
    sed -i 's:PROXY_DOMAIN_OR_IP\:8080:PROXY_DOMAIN_OR_IP\:80:' /etc/nginx/proxy_params_common

    apache_revert_port
    service nginx start

    /scripts/restartsrv_httpd
    service nginx restart

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
    #   service cpanel restart
    #   echo ""
    #fi
    if [ "$(pstree | grep 'crond')" ]; then
        service crond restart
        echo ""
    fi
    if [[ -f /etc/csf/csf.conf && "$(cat /etc/csf/csf.conf | grep 'TESTING = \"0\"')" ]]; then
        csf -r
        echo ""
    fi
    if [ "$(pstree | grep 'lfd')" ]; then
        service lfd restart
        echo ""
    fi
    if [ "$(pstree | grep 'munin-node')" ]; then
        service munin-node restart
        echo ""
    fi
    if [ "$(pstree | grep 'mysql')" ]; then
        /scripts/restartsrv_mysql
        echo ""
    fi
    if [ "$(pstree | grep 'httpd')" ]; then
        echo "Restarting Apache..."
        /scripts/restartsrv_httpd
        echo ""
    fi
    if [ "$(pstree | grep 'nginx')" ]; then
        echo "Restarting Nginx..."
        service nginx restart
        echo ""
    fi
    echo ""
    ;;
res)
    echo "====================================="
    echo "=== Restarting All Basic Services ==="
    echo "====================================="
    echo ""
    if [ "$(pstree | grep 'httpd')" ]; then
        echo "Restarting Apache..."
        /scripts/restartsrv_httpd
        echo ""
    fi
    if [ "$(pstree | grep 'nginx')" ]; then
        echo "Restarting Nginx..."
        service nginx restart
        echo ""
    fi
    echo ""
    ;;
purgecache)
    echo "==================================================================="
    echo "=== Clean Nginx cache & temp folders and restart Apache & Nginx ==="
    echo "==================================================================="
    echo ""
    find /tmp/engintron_dynamic/ -type f | xargs rm -rvf
    find /tmp/engintron_static/ -type f | xargs rm -rvf
    find /tmp/engintron_temp/ -type f | xargs rm -rvf
    if [ "$(pstree | grep 'httpd')" ]; then
        echo "Apache restarting..."
        /scripts/restartsrv_httpd
        echo ""
    fi
    if [ "$(pstree | grep 'nginx')" ]; then
        service nginx restart
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
        echo "Apache restarting..."
        /scripts/restartsrv_httpd
        echo ""
    fi
    if [ "$(pstree | grep 'nginx')" ]; then
        service nginx restart
        echo ""
    fi
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
            chown -R $user:$user /home/$user/public_html/*
        fi
    done
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
info)
    echo "=================="
    echo "=== OS Version ==="
    echo "=================="
    echo ""
    cat /etc/redhat-release
    echo ""
    echo "cPanel version: $GET_CPANEL_VERSION"
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
    echo ""
    echo ""
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
-h|--help|*)
    echo "    _______   _____________   ____________  ____  _   __"
    echo "   / ____/ | / / ____/  _/ | / /_  __/ __ \/ __ \/ | / /"
    echo "  / __/ /  |/ / / __ / //  |/ / / / / /_/ / / / /  |/ / "
    echo " / /___/ /|  / /_/ // // /|  / / / / _, _/ /_/ / /|  /  "
    echo "/_____/_/ |_/\____/___/_/ |_/ /_/ /_/ |_|\____/_/ |_/   "
    echo "                                                        "
    echo "                  https://engintron.com                 "
    cat <<EOF

Engintron for cPanel/WHM is the easiest way to integrate Nginx on your cPanel/WHM server.

Usage: /engintron.sh [command] [flag]

Main commands:
    install          Install, re-install or update Engintron (enables Nginx by default).
                     Add optional flag "mainline" to install Nginx mainline release.
    remove           Remove Engintron completely.
    enable           Set Nginx to ports 80/443 & Apache to ports 8080/8443
    disable          Set Nginx to ports 8080/8443 & switch Apache to ports 80/443
    purgecache       Purge Nginx's "cache" & "temp" folders,
                     then restart both Apache & Nginx
    purgelogs        Purge Nginx's access & error log files

Utility commands:
    res              Restart web servers only (Apache & Nginx)
    resall           Restart Cron, CSF & LFD (if installed), Munin (if installed),
                     MySQL, Apache, Nginx
    80               Show active connections on port 80 sorted by connection count & IP,
                     including total concurrent connections count
    443              Show active connections on port 443 sorted by connection count & IP,
                     including total concurrent connections count
    fixaccessperms   Change file & directory access permissions to 644 & 755 respectively
                     in all user /public_html directories
    fixownerperms    Fix owner permissions in all user /public_html directories
    cleanup          Cleanup Mac or Windows specific metadata & Apache error_log files
                     in all user /public_html directories
    info             Show basic system info

~~ Enjoy Engintron! ~~

EOF
    ;;
esac

# END
