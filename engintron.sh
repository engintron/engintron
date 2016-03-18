#!/bin/bash

# /**
#  * @version    1.6.1
#  * @package    Engintron for cPanel/WHM
#  * @author      Fotis Evangelou
#  * @url      https://engintron.com
#  * @copyright    Copyright (c) 2010 - 2016 Nuevvo Webware P.C. All rights reserved.
#  * @license    GNU/GPL license: http://www.gnu.org/copyleft/gpl.html
#  */

# Constants
APP_PATH="/usr/local/engintron"
APP_VERSION="1.6.1"

CPANEL_PLG_PATH="/usr/local/cpanel/whostmgr/docroot/cgi"




############################# HELPER FUCTIONS [start] #############################

function install_basics {

  echo "=== Let's upgrade our system first & install a few required packages ==="
  yum -y update
  yum -y upgrade
  yum -y install atop bash-completion bc cron curl htop ifstat iftop iotop make nano openssl-devel pcre pcre-devel sudo tree unzip zip zlib-devel
  yum clean all
  echo ""
  echo ""

}

function install_mod_rpaf {

  echo "=== Installing mod_rpaf (v0.8.4) for Apache ==="

  pushd $APP_PATH/apache
  unzip -o mod_rpaf-0.8.4.zip -d mod_rpaf-0.8.4
  cd mod_rpaf-0.8.4
  $APP_PATH/apache/apxs.sh -i -c -n mod_rpaf.so mod_rpaf.c
  popd

  /bin/rm -rf $APP_PATH/apache/mod_rpaf-0.8.4/

  if [ -f /usr/local/apache/modules/mod_rpaf.so ]; then

    systemips=$(ip addr show | grep 'inet ' | grep ' brd ' | cut -d/ -f1 | cut -c10- | tr '\n' ' ');

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

  echo "=== Installing mod_remoteip for Apache ==="

  pushd $APP_PATH/apache
  ./apxs.sh -i -c -n mod_remoteip.so mod_remoteip.c
  popd

  if [ -f /usr/local/apache/modules/mod_remoteip.so ]; then
    # Get system IPs
    systemips=$(ip addr show | grep 'inet ' | grep ' brd ' | cut -d/ -f1 | cut -c10- | tr '\n' ' ');

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
    echo ""
    echo ""
  fi

}

function remove_mod_remoteip {

  if [ -f /usr/local/apache/conf/includes/remoteip.conf ]; then
    echo "=== Removing mod_remoteip for Apache ==="
    rm -f /usr/local/apache/conf/includes/remoteip.conf
    sed -i 's:Include "/usr/local/apache/conf/includes/remoteip.conf"::' /usr/local/apache/conf/httpd.conf
    sed -i "s:LogFormat \"%h %a %l:LogFormat \"%h %l:" /usr/local/apache/conf/httpd.conf
    echo ""
    echo ""
  fi

}

function apache_change_port {

  echo "=== Switch Apache to port 8080 ==="
  if grep -Fxq "apache_port=" /var/cpanel/cpanel.config
  then
    sed -i 's/^apache_port=.*/apache_port=0.0.0.0:8080/' /var/cpanel/cpanel.config
    /usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings
  else
    echo "apache_port=0.0.0.0:8080" >> /var/cpanel/cpanel.config
  fi

  echo ""
  echo ""

  echo "=== Distill changes in Apache's configuration and restart Apache ==="
  /usr/local/cpanel/bin/apache_conf_distiller --update
  /scripts/rebuildhttpdconf --update

  service httpd restart

  echo ""
  echo ""

}

function apache_revert_port {

  echo "=== Switch Apache back to port 80 ==="
  if grep -Fxq "apache_port=" /var/cpanel/cpanel.config
  then
    sed -i 's/^apache_port=.*/apache_port=0.0.0.0:80/' /var/cpanel/cpanel.config
    /usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings
  else
    echo "apache_port=0.0.0.0:80" >> /var/cpanel/cpanel.config
  fi

  echo ""
  echo ""

  echo "=== Distill changes in Apache's configuration and restart Apache ==="
  /usr/local/cpanel/bin/apache_conf_distiller --update
  /scripts/rebuildhttpdconf --update

  service httpd restart

  echo ""
  echo ""

}

function install_nginx {

  echo "=== Install Nginx from official repositories ==="
  if [ -f /etc/yum.repos.d/nginx.repo ]; then
    touch /etc/yum.repos.d/nginx.repo
  fi
  cat > "/etc/yum.repos.d/nginx.repo" <<EOF
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=0
enabled=1

EOF

  yum -y install nginx

  # Copy Nginx config files
  if [ -f /etc/nginx/custom_rules ]; then
    /bin/cp -f /etc/nginx/custom_rules /etc/nginx/custom_rules.bak
  fi
  /bin/cp -f $APP_PATH/nginx/custom_rules /etc/nginx/

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

  if [ -f /sbin/chkconfig ]; then
    /sbin/chkconfig nginx on
  else
    systemctl enable nginx
  fi

  if [ "$(pstree | grep 'nginx')" ]; then
    service nginx stop
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

  echo ""
  echo ""

}

function install_engintron_ui {

  echo "=== Installing Engintron WHM plugin files... ==="

  /bin/ln -sf $APP_PATH/app/addon_engintron.cgi $CPANEL_PLG_PATH/addon_engintron.cgi
  /bin/ln -sf $APP_PATH/app/engintron.php $CPANEL_PLG_PATH/engintron.php
  /bin/ln -sf $APP_PATH/engintron.sh /usr/local/sbin/engintron

  chmod +x $APP_PATH/app/addon_engintron.cgi
  chmod +x $APP_PATH/app/engintron.php
  chmod +x $APP_PATH/engintron.sh

  echo ""
  echo "=== Fix ACL requirements in newer cPanel releases ==="
  if grep -Fxq "permit_unregistered_apps_as_root=" /var/cpanel/cpanel.config
  then
    sed -i 's/^permit_unregistered_apps_as_root=.*/permit_unregistered_apps_as_root=1/' /var/cpanel/cpanel.config
  else
    echo "permit_unregistered_apps_as_root=1" >> /var/cpanel/cpanel.config
  fi

  /usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings
  /usr/local/cpanel/etc/init/startcpsrvd

  echo ""
  echo ""

}

function remove_engintron_ui {

  echo "=== Removing Engintron WHM plugin files... ==="
  /bin/rm -f $CPANEL_PLG_PATH/addon_engintron.cgi
  /bin/rm -f $CPANEL_PLG_PATH/engintron.php
  /bin/rm -f /usr/local/sbin/engintron
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

############################# HELPER FUCTIONS [end] #############################



### Define actions ###
case $1 in
install)
  GET_EA3_VERSION=$(/scripts/easyapache --version | grep "Easy Apache v3")

  clear

  if [[ $GET_EA3_VERSION == "" ]]; then
    echo ""
    echo ""
    echo "***************************************************"
    echo ""
    echo " ENGINTRON ERROR:"
    echo " This server has EasyApache version 4 (beta)"
    echo " installed and Engintron is currently only compatible"
    echo " with EasyApache version 3 only!"
    echo " EasyApache version 4 will be supported"
    echo " in Engintron version 1.6."
    echo ""
    echo " --- Installation aborted ---"
    echo ""
    echo "***************************************************"
    echo ""
    echo ""
    exit 0
  fi

  echo "**************************************"
  echo "*        Installing Engintron        *"
  echo "**************************************"

  # Ensure engintron app directory is created
  if [[ ! -d $APP_PATH ]]; then
    mkdir -p $APP_PATH
  fi

  # Get the files
  wget --no-check-certificate -O $APP_PATH/engintron.tar.gz https://github.com/engintron/engintron/archive/master.tar.gz
  tar xzvf $APP_PATH/engintron.tar.gz --strip-components 1 -C $APP_PATH/
  /bin/rm -f $APP_PATH/engintron.tar.gz

  install_basics
  install_nginx

  GET_HTTPD_VERSION=$(httpd -v | grep "Server version")
  if [[ $GET_HTTPD_VERSION =~ "Apache/2.2." ]]; then
    install_mod_rpaf
  else
    install_mod_remoteip
  fi

  apache_change_port
  install_munin_patch
  install_engintron_ui

  echo ""
  echo "=== Restarting Apache & Nginx... ==="
  service httpd restart
  fuser -k 80/tcp
  service nginx start

  if [ -f $APP_PATH/state.conf ]; then
    touch $APP_PATH/state.conf
  fi
  echo "on" > $APP_PATH/state.conf

  echo ""
  echo "**************************************"
  echo "*       Installation Complete        *"
  echo "**************************************"
  echo ""
  ;;
remove)

  clear

  echo "**************************************"
  echo "*         Removing Engintron         *"
  echo "**************************************"

  GET_HTTPD_VERSION=$(httpd -v | grep "Server version")
  if [[ $GET_HTTPD_VERSION =~ "Apache/2.2." ]]; then
    remove_mod_rpaf
  else
    remove_mod_remoteip
  fi

  apache_revert_port
  remove_nginx
  remove_munin_patch
  remove_engintron_ui

  echo ""
  echo "=== Removing Engintron files... ==="
  /bin/rm -rvf $APP_PATH

  echo ""
  echo "=== Restarting Apache... ==="
  service httpd restart

  echo ""
  echo "**************************************"
  echo "*          Removal Complete          *"
  echo "**************************************"
  echo ""
  ;;
enable)
  clear

  echo "**************************************"
  echo "*         Enabling Engintron         *"
  echo "**************************************"

  if [ -f $APP_PATH/state.conf ]; then
    touch $APP_PATH/state.conf
  fi
  echo "on" > $APP_PATH/state.conf

  install_munin_patch
  service nginx stop
  sed -i 's:listen 8080 default_server:listen 80 default_server:' /etc/nginx/conf.d/default.conf
  sed -i 's:\:80; # Apache Status Page:\:8080; # Apache Status Page:' /etc/nginx/conf.d/default.conf
  sed -i 's:PROXY_DOMAIN_OR_IP\:80:PROXY_DOMAIN_OR_IP\:8080:' /etc/nginx/proxy_params_common
  apache_change_port
  service nginx start

  service httpd restart
  service nginx restart

  echo ""
  echo "**************************************"
  echo "*         Engintron Enabled          *"
  echo "**************************************"
  echo ""
  ;;
disable)
  clear

  echo "**************************************"
  echo "*        Disabling Engintron         *"
  echo "**************************************"

  if [ -f $APP_PATH/state.conf ]; then
    touch $APP_PATH/state.conf
  fi
  echo "off" > $APP_PATH/state.conf

  remove_munin_patch
  service nginx stop
  sed -i 's:listen 80 default_server:listen 8080 default_server:' /etc/nginx/conf.d/default.conf
  sed -i 's:\:8080; # Apache Status Page:\:80; # Apache Status Page:' /etc/nginx/conf.d/default.conf
  sed -i 's:PROXY_DOMAIN_OR_IP\:8080:PROXY_DOMAIN_OR_IP\:80:' /etc/nginx/proxy_params_common

  apache_revert_port
  service nginx start

  service httpd restart
  service nginx restart

  echo ""
  echo "**************************************"
  echo "*         Engintron Disabled         *"
  echo "**************************************"
  echo ""
  ;;
resall)
  echo "========================================="
  echo "=== Restarting All Important Services ==="
  echo "========================================="
  echo ""

  #if [ -f "/usr/local/cpanel/cpanel" ]; then
  #  service cpanel restart
  #  echo ""
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
    service httpd restart
    echo ""
  fi
  if [ "$(pstree | grep 'nginx')" ]; then
    echo "Restarting Nginx..."
    service nginx restart
    echo ""
  fi
  ;;
res)
  echo ""
  echo ""
  echo "====================================="
  echo "=== Restarting All Basic Services ==="
  echo "====================================="
  echo ""
  if [ "$(pstree | grep 'httpd')" ]; then
    echo "Restarting Apache..."
    service httpd restart
    echo ""
  fi
  if [ "$(pstree | grep 'nginx')" ]; then
    echo "Restarting Nginx..."
    service nginx restart
    echo ""
  fi
  ;;
clean)
  echo ""
  echo ""
  echo "==================================================================="
  echo "=== Clean Nginx cache & temp folders and restart Apache & Nginx ==="
  echo "==================================================================="
  echo ""
  find /tmp/engintron_dynamic/ -type f | xargs rm -rvf
  find /tmp/engintron_static/ -type f | xargs rm -rvf
  find /tmp/engintron_temp/ -type f | xargs rm -rvf
  if [ "$(pstree | grep 'httpd')" ]; then
    echo "Apache restarting..."
    service httpd restart
  fi
  if [ "$(pstree | grep 'nginx')" ]; then
    service nginx restart
  fi
  ;;
info)
  CPANEL_VERSION=$(/usr/local/cpanel/cpanel -V)
  OS_VERSION=$(cat /etc/redhat-release)

  echo "=================="
  echo "=== OS Version ==="
  echo "=================="
  echo ""
  echo $OS_VERSION
  echo ""

  echo "======================"
  echo "=== cPanel Version ==="
  echo "======================"
  echo ""
  echo $CPANEL_VERSION
  echo ""

  echo "=================="
  echo "=== Disk Usage ==="
  echo "=================="
  echo ""
  df -hT
  echo ""

  echo "=============="
  echo "=== Uptime ==="
  echo "=============="
  echo ""
  uptime
  echo ""

  echo "==================="
  echo "=== System Date ==="
  echo "==================="
  echo ""
  date
  echo ""

  echo "======================="
  echo "=== Users Logged In ==="
  echo "======================="
  echo ""
  who
  echo ""
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
  echo ""
  ;;
-h|--help|*)
  echo "    _______   _____________   ____________  ____  _   __"
  echo "   / ____/ | / / ____/  _/ | / /_  __/ __ \/ __ \/ | / /"
  echo "  / __/ /  |/ / / __ / //  |/ / / / / /_/ / / / /  |/ / "
  echo " / /___/ /|  / /_/ // // /|  / / / / _, _/ /_/ / /|  /  "
  echo "/_____/_/ |_/\____/___/_/ |_/ /_/ /_/ |_|\____/_/ |_/   "
  echo "                           https://engintron.com        "
  echo
  cat << EOF
Usage:
  engintron [command] [flags]

Main Commands:
  install       Install or update Engintron
  remove        Remove Engintron completely
  enable        Enable Engintron & switch Apache to port 8080
  disable       Disable Engintron & switch back to Apache
  clean         Clean up nginx's cache & temp folders (restarts nginx & apache)

Utility Commands:
  info          Show basic system info
  80            Show all connections on port 80 sorted by count & IP
  res           Restart basic services (nginx & apache)
  resall        Restart all services

~~ Enjoy Engintron! ~~
EOF
  ;;
esac

# END
