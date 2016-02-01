#!/bin/bash

# /**
#  * @version		1.5.0
#  * @package		Engintron for cPanel/WHM
#  * @author    	Fotis Evangelou
#  * @copyright		Copyright (c) 2010 - 2016 Nuevvo Webware P.C. All rights reserved.
#  * @license		GNU/GPL license: http://www.gnu.org/copyleft/gpl.html
#  */



# Constants
APP_PATH="/usr/local/src/engintron"
APP_VERSION="1.5.0"
CPANEL_PLG_PATH="/usr/local/cpanel/whostmgr/docroot/cgi"
REPO_URL="https://raw.githubusercontent.com/nuevvo/engintron/master"

############################# HELPER FUCTIONS [start] #############################

function install_basics {

	echo ""
	echo "=== Let's upgrade our system first ==="
	yum -y update
	yum -y upgrade

	echo ""
	echo "=== Installing a few dependencies ==="
	yum -y install zip unzip bc htop pcre pcre-devel zlib-devel openssl-devel make curl nano tree

	# Cleanup
	yum clean all

}

function install_mod_rpaf {

	if [ ! -f /usr/local/apache/conf/includes/rpaf.conf ]; then

		echo ""
		echo "=== Installing mod_rpaf (v0.8.4) for Apache ==="
		cd /usr/local/src
		wget https://github.com/gnif/mod_rpaf/archive/v0.8.4.tar.gz
		tar xzf v0.8.4.tar.gz
		cd mod_rpaf-0.8.4
		chmod +x apxs.sh
		./apxs.sh -i -c -n mod_rpaf.so mod_rpaf.c

		cd /

		echo ""
		echo "=== Get system IPs ==="
		systemips=$(ip addr show | grep 'inet ' | grep ' brd ' | cut -d/ -f1 | cut -c10- | tr '\n' ' ');

		touch /usr/local/apache/conf/includes/rpaf.conf
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

		service httpd stop

		echo ""
		echo "=== Updating Apache configuration to include mod_rpaf ==="
		/bin/cp -f /usr/local/apache/conf/httpd.conf /usr/local/apache/conf/httpd.conf.bak
		sed -i 's:Include "/usr/local/apache/conf/includes/errordocument.conf":Include "/usr/local/apache/conf/includes/errordocument.conf"\nInclude "/usr/local/apache/conf/includes/rpaf.conf":' /usr/local/apache/conf/httpd.conf

		service httpd start

		echo ""
		echo "=== Distill changes in cPanel Apache configuration and restart Apache ==="
		/usr/local/cpanel/bin/apache_conf_distiller --update
		/scripts/rebuildhttpdconf --update

		service httpd restart

	fi

}

function install_mod_remoteip {

	if [ ! -f /usr/local/apache/conf/includes/remoteip.conf ]; then

		echo ""
		echo "=== Installing mod_remoteip for Apache ==="
		cd /usr/local/src
		wget https://svn.apache.org/repos/asf/httpd/httpd/trunk/modules/metadata/mod_remoteip.c
		apxs -i -c -n mod_remoteip.so mod_remoteip.c

		cd /

		echo ""
		echo "=== Get system IPs ==="
		systemips=$(ip addr show | grep 'inet ' | grep ' brd ' | cut -d/ -f1 | cut -c10- | tr '\n' ' ');

		touch /usr/local/apache/conf/includes/remoteip.conf
		cat > "/usr/local/apache/conf/includes/remoteip.conf" <<EOF
# RemoteIP
LoadModule remoteip_module modules/mod_remoteip.so
RemoteIPInternalProxy 127.0.0.1 $systemips
RemoteIPHeader X-Real-IP

EOF

		service httpd stop

		echo ""
		echo "=== Updating Apache configuration to include mod_remoteip ==="
		/bin/cp -f /usr/local/apache/conf/httpd.conf /usr/local/apache/conf/httpd.conf.bak
		sed -i 's:Include "/usr/local/apache/conf/includes/errordocument.conf":Include "/usr/local/apache/conf/includes/errordocument.conf"\nInclude "/usr/local/apache/conf/includes/remoteip.conf":' /usr/local/apache/conf/httpd.conf

		service httpd start

		echo ""
		echo "=== Distill changes in cPanel Apache configuration and restart Apache ==="
		/usr/local/cpanel/bin/apache_conf_distiller --update
		/scripts/rebuildhttpdconf --update

		service httpd restart

	fi

}

function install_update_apache {

	echo ""
	echo "=== Switch Apache to port 8080 ==="
	if grep -Fxq "apache_port=" /var/cpanel/cpanel.config
	then
		sed -i 's/^apache_port=.*/apache_port=0.0.0.0:8080/' /var/cpanel/cpanel.config
		/usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings
	else
		echo "apache_port=0.0.0.0:8080" >> /var/cpanel/cpanel.config
	fi

	echo ""
	echo "=== Distill changes in cPanel Apache configuration and restart Apache ==="
	/usr/local/cpanel/bin/apache_conf_distiller --update
	/scripts/rebuildhttpdconf --update

	service httpd restart

}

function install_nginx {

	echo ""
	echo "=== Adding official Nginx repos for CentOS ==="
	touch /etc/yum.repos.d/nginx.repo
	cat > "/etc/yum.repos.d/nginx.repo" <<EOF
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=0
enabled=1

EOF

	echo ""
	echo "=== Install Nginx from official repositories ==="
	yum -y install nginx

	if [ ! -f /etc/nginx/conf.d/default.conf ]; then
		echo ""
		echo ""
		echo "***************************************************"
		echo ""
		echo " IMPORTANT"
		echo " Nginx was not installed (perhaps due to conflicts)"
		echo " Exiting..."
		echo ""
		echo "***************************************************"
		echo ""
		echo ""
		exit 0
	fi

	echo ""
	echo "=== Updating Nginx configuration ==="

	# Copy Nginx config files
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

	echo ""
	echo "=== Register Nginx as a system service... ==="
	/sbin/chkconfig nginx on

	echo ""
	echo "=== Restart Nginx... ==="
	service nginx restart

}

function install_engintron_ui {

	echo ""
	echo "=== Preparing GUI files... ==="

	/bin/cp -f $APP_PATH/app/addon_engintron.cgi $CPANEL_PLG_PATH/
	/bin/cp -f $APP_PATH/app/engintron.php $CPANEL_PLG_PATH/

	chmod +x $CPANEL_PLG_PATH/addon_engintron.cgi
	chmod +x $CPANEL_PLG_PATH/engintron.php

	echo ""
	echo "=== Fix ACL requirements in newer cPanel releases ==="
	if grep -Fxq "permit_unregistered_apps_as_root=" /var/cpanel/cpanel.config
	then
		sed -i 's/permit_unregistered_apps_as_root=0$/permit_unregistered_apps_as_root=1/' /var/cpanel/cpanel.config
	else
		echo "permit_unregistered_apps_as_root=1" >> /var/cpanel/cpanel.config
	fi

	/usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings
	/usr/local/cpanel/etc/init/startcpsrvd

}

function install_munin_patch {

	if [ -f /etc/munin/plugin-conf.d/cpanel.conf ]; then
		echo ""
		echo "=== Updating Munin configuration ==="

		if grep -q "\[apache_status\]" /etc/munin/plugin-conf.d/cpanel.conf
		then
			echo "Munin patched already, nothing to do here"
		else
			cat >> "/etc/munin/plugin-conf.d/cpanel.conf" <<EOF

[apache_status]
env.ports 8080
env.label 8080

EOF
		fi

		ln -s /usr/local/cpanel/3rdparty/share/munin/plugins/nginx_* /etc/munin/plugins/

		service munin-node restart
	fi

}

function remove_munin_patch {

	if [ -f /etc/munin/plugin-conf.d/cpanel.conf ]; then
		echo ""
		echo "=== Updating Munin configuration ==="

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
	fi

}

function remove_mod_rpaf {

	if [ -f /usr/local/apache/conf/includes/rpaf.conf ]; then
		echo ""
		echo "=== Updating Apache configuration to remove mod_rpaf ==="
		rm -f /usr/local/apache/conf/includes/rpaf.conf
		sed -i 's:Include "/usr/local/apache/conf/includes/rpaf.conf":\n:' /usr/local/apache/conf/httpd.conf
		service httpd restart
	fi

}

function remove_mod_remoteip {

	if [ -f /usr/local/apache/conf/includes/remoteip.conf ]; then
		echo ""
		echo "=== Updating Apache configuration to remove mod_remoteip ==="
		rm -f /usr/local/apache/conf/includes/remoteip.conf
		sed -i 's:Include "/usr/local/apache/conf/includes/remoteip.conf":\n:' /usr/local/apache/conf/httpd.conf
		service httpd restart
	fi

}

function remove_update_apache {

	echo ""
	echo "=== Switch Apache back to port 80 ==="
	if grep -Fxq "apache_port=" /var/cpanel/cpanel.config
	then
		sed -i 's/^apache_port=.*/apache_port=0.0.0.0:80/' /var/cpanel/cpanel.config
		/usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings
	else
		echo "apache_port=0.0.0.0:80" >> /var/cpanel/cpanel.config
	fi

	echo ""
	echo "=== Distill changes in cPanel Apache configuration and restart Apache ==="
	/usr/local/cpanel/bin/apache_conf_distiller --update
	/scripts/rebuildhttpdconf --update

	service httpd restart

}

function remove_nginx {

	echo ""
	echo "=== Unregistering Nginx as a service... ==="
	/sbin/chkconfig nginx off

	echo ""
	echo "=== Stopping Nginx... ==="
	service nginx stop

	echo ""
	echo "=== Removing Nginx... ==="
	yum -y remove nginx
	/bin/rm -rf /etc/nginx/*
	/bin/rm -f /etc/yum.repos.d/nginx.repo

}

function remove_engintron_ui {

	echo ""
	echo "=== Deleting GUI files... ==="
	/bin/rm -f $CPANEL_PLG_PATH/addon_engintron.*
	/bin/rm -f $CPANEL_PLG_PATH/engintron.*

}

############################# HELPER FUCTIONS [end] #############################



### Define actions ###
case $1 in
install)

	if [ ! -f /engintron.sh ]; then
		echo ""
		echo ""
		echo "***********************************************"
		echo ""
		echo " IMPORTANT"
		echo " You must place & execute engintron.sh"
		echo " from the root directory (/) of your server!"
		echo " Exiting..."
		echo ""
		echo "***********************************************"
		echo ""
		echo ""
		exit 0
	fi

	chmod +x /engintron.sh
	clear
	cd /

	# Set Engintron src file path
	if [[ ! -d $APP_PATH ]]; then
		mkdir -p $APP_PATH
	fi

	# Get the files
	cd $APP_PATH
	wget https://github.com/nuevvo/engintron/archive/master.zip
	unzip master.zip
	/bin/cp -rf $APP_PATH/engintron-master/* $APP_PATH/
	rm -rvf $APP_PATH/engintron-master/*
	rm -f master.zip

	cd /

	echo ""
	echo "**************************************"
	echo "*        Installing Engintron        *"
	echo "**************************************"

	install_basics

	GET_HTTPD_VERSION=`httpd -v | grep "Server version"`;
	if [[ $GET_HTTPD_VERSION =~ "Apache/2.2." ]]; then
		install_mod_rpaf
	else
		install_mod_remoteip
	fi

	install_update_apache
	install_nginx
	install_munin_patch
	install_engintron_ui

	echo "***************************************"
	echo "*        Installation Complete        *"
	echo "***************************************"
	echo ""
		;;
remove)

	GET_HTTPD_VERSION=`httpd -v | grep "Server version"`;
	if [[ $GET_HTTPD_VERSION =~ "Apache/2.2." ]];
	then
		remove_mod_rpaf
	else
		remove_mod_remoteip
	fi

	remove_update_apache
	remove_nginx
	remove_munin_patch
	remove_engintron_ui

	echo ""
	echo "=== Removing Engintron files... ==="
	/bin/rm -rvf $APP_PATH
	/bin/rm /engintron.sh

	echo ""
	echo "=== Restarting Apache... ==="
	service httpd restart

	echo ""
	echo "****************************************************"
	echo "*               Removal Complete                   *"
	echo "****************************************************"
	echo ""
	;;
*)
	echo ""
	echo -e "\033[35;1m Please specify an action: install | remove \033[0m"
	echo -e "\033[35;1m For example: bash engintron.sh install \033[0m"
	echo ""
	;;
esac
