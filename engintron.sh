#!/bin/bash

# Version		1.0.4 Build 20141223
# Package		Engintron
# Author		Fotis Evangelou
# Copyright		Nuevvo Webware P.C. All rights reserved.
# License		GNU/GPL license: http://www.gnu.org/copyleft/gpl.html



############################# HELPER FUCTIONS [start] #############################

function install_basics {

	echo ""
	echo "=== Let's upgrade our system first ==="

	echo ""
	yum -y update
	yum -y upgrade

	echo ""
	echo "=== Installing dependencies ==="
	yum install pcre pcre-devel zlib-devel openssl-devel

	echo ""
	echo "=== Adding official Nginx repos for CentOS ==="
	touch /etc/yum.repos.d/nginx.repo
	echo "[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=0
enabled=1" > /etc/yum.repos.d/nginx.repo

}

function install_mod_rpaf {

	if [ ! -f /usr/local/apache/conf/includes/rpaf.conf ]; then

		echo ""
		echo "=== Installing mod_rpaf (v0.8.4) for Apache ==="
		cd /usr/local/src
		#wget http://www.stderr.net/apache/rpaf/download/mod_rpaf-0.6.tar.gz - OFFLINE
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
		echo "
LoadModule              rpaf_module modules/mod_rpaf.so
RPAF_Enable             On
RPAF_ProxyIPs           127.0.0.1 $systemips
RPAF_SetHostName        On
RPAF_SetHTTPS           On
RPAF_SetPort            On
RPAF_ForbidIfNotProxy   Off
RPAF_Header             X-Forwarded-For
		" > /usr/local/apache/conf/includes/rpaf.conf
		sleep 2

		service httpd stop

		echo ""
		echo "=== Updating Apache configuration to include mod_rpaf ==="
		cp /usr/local/apache/conf/httpd.conf /usr/local/apache/conf/httpd.conf.bak
		sed -i 's:Include "/usr/local/apache/conf/includes/errordocument.conf":Include "/usr/local/apache/conf/includes/errordocument.conf"\nInclude "/usr/local/apache/conf/includes/rpaf.conf":' /usr/local/apache/conf/httpd.conf
		sleep 2

		service httpd start
		sleep 2

		echo ""
		echo "=== Merge changes in cPanel Apache configuration ==="
		/usr/local/cpanel/bin/apache_conf_distiller --update
		sleep 2

		/scripts/rebuildhttpdconf --update
		sleep 2
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
		echo "
LoadModule remoteip_module modules/mod_remoteip.so

RemoteIPHeader X-Real-IP
RemoteIPInternalProxy 127.0.0.1 $systemips
		" > /usr/local/apache/conf/includes/remoteip.conf
		sleep 2

		service httpd stop

		echo ""
		echo "=== Updating Apache configuration to include mod_remoteip ==="
		cp /usr/local/apache/conf/httpd.conf /usr/local/apache/conf/httpd.conf.bak
		sed -i 's:Include "/usr/local/apache/conf/includes/errordocument.conf":Include "/usr/local/apache/conf/includes/errordocument.conf"\nInclude "/usr/local/apache/conf/includes/remoteip.conf":' /usr/local/apache/conf/httpd.conf
		sleep 2

		service httpd start
		sleep 2

		echo ""
		echo "=== Merge changes in cPanel Apache configuration ==="
		/usr/local/cpanel/bin/apache_conf_distiller --update
		sleep 2

		/scripts/rebuildhttpdconf --update
		sleep 2
	fi

}

function install_update_apache {

	echo ""
	echo "=== Switch Apache to port 8081 ==="
	if grep -Fxq "apache_port=" /var/cpanel/cpanel.config
	then
		sed -i 's/apache_port=0.0.0.0:80$/apache_port=0.0.0.0:8081/' /var/cpanel/cpanel.config
		/usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings
	else
		echo "apache_port=0.0.0.0:8081" >> /var/cpanel/cpanel.config
	fi
	sleep 2

	echo ""
	echo "=== Distill changes in cPanel Apache configuration and restart Apache ==="
	/usr/local/cpanel/bin/apache_conf_distiller --update
	/scripts/rebuildhttpdconf --update

	service httpd restart
	sleep 2

}

function install_nginx {

	echo ""
	echo "=== Install Nginx from official repositories ==="
	yum -y install nginx

	echo ""
	echo "=== Updating Nginx configuration ==="

	cat > "/etc/nginx/proxy.conf" <<EOF
# For more info on the settings below, see http://wiki.nginx.org/HttpProxyModule

# Proxy Cache Settings
# Change '2m' below to the time in minutes (e.g. '5m' for 5 minutes) you wish for all 200, 301 and 302 replies to be cached.
# More info here: http://wiki.nginx.org/HttpProxyModule#proxy_cache_valid
proxy_cache_valid				any 2m;
proxy_cache						cpanel;
proxy_cache_key					\$scheme\$host\$request_method\$request_uri;
proxy_cache_use_stale			updating;
proxy_cache_methods				GET HEAD;
proxy_cache_bypass				\$wordpress \$k2_for_joomla;
proxy_no_cache					\$wordpress \$k2_for_joomla;

# Timeouts
proxy_connect_timeout			120s;
proxy_send_timeout		 		120s;
proxy_read_timeout		 		120s;

# Buffers
proxy_buffer_size			 	64k;
proxy_buffers					16 32k;
proxy_busy_buffers_size			64k;
proxy_temp_file_write_size 		64k;

# Proxy Headers
proxy_hide_header				Cache-Control;
proxy_hide_header				Expires;
#proxy_hide_header				Set-Cookie;
proxy_ignore_headers			Cache-Control Expires Set-Cookie;
proxy_set_header	 			Host \$host;
proxy_set_header	 			Referer \$http_referer;
proxy_set_header 				X-Forwarded-For \$proxy_add_x_forwarded_for;
proxy_set_header 				X-Forwarded-Host \$host;
proxy_set_header 				X-Forwarded-Server \$host;
proxy_set_header	 			X-Real-IP \$remote_addr;

EOF

	cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak

	cat > "/etc/nginx/nginx.conf" <<EOF
user nobody;

worker_processes		auto;
#worker_rlimit_nofile	20480;

error_log				/var/log/nginx/error.log warn;
pid						/var/run/nginx.pid;

events {
	worker_connections	1024; # increase for busier servers
	use 				epoll; # you should use epoll for Linux kernels 2.6.x
}

http {
	include							/etc/nginx/mime.types;
	default_type					application/octet-stream;
	log_format	 					main	'\$remote_addr - \$remote_user [\$time_local] "\$request" '
											'\$status \$body_bytes_sent "\$http_referer" '
											'"\$http_user_agent" "\$http_x_forwarded_for"';
	access_log	 					/var/log/nginx/access.log	 main;
	client_max_body_size 			256M;
	client_body_buffer_size 		128k;
	client_body_in_file_only 		on;
	client_body_timeout 			3m;
	client_header_buffer_size 		256k;
	client_header_timeout			3m;
	connection_pool_size	 		256;
	ignore_invalid_headers 			on;
	keepalive_timeout				20;
	large_client_header_buffers 	4 256k;
	output_buffers					4 32k;
	postpone_output					1460;
	request_pool_size				32k;
	reset_timedout_connection		on;
	sendfile						on;
	send_timeout					3m;
	server_names_hash_bucket_size	1024;
	server_names_hash_max_size		10240;
	server_name_in_redirect			off;
	server_tokens					off;
	tcp_nodelay						on;
	tcp_nopush						on;

	# Proxy Settings
	proxy_cache_path			/tmp/nginx_cache
									levels=1:2
									keys_zone=cpanel:50m
									inactive=24h
									max_size=500m;
	proxy_temp_path				/tmp/nginx_temp;

	# Gzip Settings
	gzip 						on;
	gzip_vary 					on;
	gzip_disable 				"MSIE [1-6]\.";
	gzip_proxied 				any;
	gzip_http_version 			1.1;
	gzip_min_length				1000;
	gzip_comp_level				6;
	gzip_buffers	 			16 8k;
	gzip_types					application/atom+xml application/json application/x-javascript application/xml application/xml+rss text/css text/javascript text/plain text/xml;

	# Include site configurations
	include /etc/nginx/conf.d/*.conf;
}

EOF

	echo ""
	echo "=== Registering Nginx as a service... ==="
	/sbin/chkconfig nginx on

	echo ""
	echo "=== Check default Nginx webroot and fix if necessary... ==="
	if [ ! -d /usr/share/nginx/html ]; then
		mkdir -p /usr/share/nginx/html
		cd /usr/share/nginx/html
		wget https://raw.githubusercontent.com/nuevvo/engintron/master/usr/share/nginx/html/index.html
		wget https://raw.githubusercontent.com/nuevvo/engintron/master/usr/share/nginx/html/50x.html
	fi

	echo ""
	echo "=== Check if the default vhost exists and fix if necessary... ==="
	if [ ! -f /etc/nginx/conf.d/default.conf ]; then
		cd /etc/nginx/conf.d/
		wget https://raw.githubusercontent.com/nuevvo/engintron/master/etc/nginx/conf.d/default.conf
	fi

	echo ""
	echo "=== Restart Nginx... ==="
	service nginx reload

}

function sync_vhosts {

	echo ""
	echo "=== Let's cleanup old vhosts first... ===";
	echo ""

	cd /etc/nginx/conf.d/
	mv default.conf default
	rm -f *.conf
	mv default default.conf

	cd /var/cpanel/users

	for USER in *; do
	 for DOMAIN in `cat $USER | grep ^DNS | cut -d= -f2`; do
		 IP=`cat $USER|grep ^IP|cut -d= -f2`;
		 ROOT=`grep ^$USER: /etc/passwd|cut -d: -f6`;

		 echo "Generating Nginx vhost $DOMAIN (in IP $IP) for user $USER";

		 cat > "/etc/nginx/conf.d/$DOMAIN.conf" <<EOF
server {
	listen $IP:80;
	server_name $DOMAIN www.$DOMAIN;

	access_log /var/log/nginx/access.$DOMAIN.log;
	error_log /var/log/nginx/error.$DOMAIN.log;

	index index.php index.html index.htm;

	root /home/$USER/public_html/;

	set \$wordpress "";
	if (\$http_cookie ~* "wordpress_logged_in_[^=]*=([^%]+)%7C") {
		set \$wordpress wordpress_logged_in_\$1;
	}

	set \$k2_for_joomla "";
	if (\$sent_http_x_logged_in = "true") {
		set \$k2_for_joomla true;
	}

	location ~* ^/(login|logout|connect|admin|administrator|.*/administrator|.*/.*/administrator|wp-admin|.*/wp-admin|.*/.*/wp-admin) {
		add_header X-Cache \$upstream_cache_status;
		proxy_pass http://$IP:8081;
		proxy_set_header Host \$host;
	}

	location / {
		add_header X-Cache \$upstream_cache_status;
		proxy_pass http://$IP:8081;
		include proxy.conf;
	}

	# Proxy dynamic content to Apache
	location ~ \.(php|cgi|pl|py)?\$ {
		proxy_pass http://$IP:8081;
		include proxy.conf;
	}

	# Tell the browser to cache all images for 1 week
	location ~* \.(gif|ico|jpe?g|png|ico|bmp)(\?[0-9a-zA-Z]+)?\$ {
		expires				7d;
		access_log			off;
		log_not_found		off;
		try_files \$uri \$uri/ \$uri/$DOMAIN @backend;
	}

	# Tell the browser to cache all video, audio and doc files for 1 week
	location ~* \.(txt|mp3|mp4|m4v|mov|mpg|mpeg|flv|swf|ogg|ogv|wmv|wma|pdf|doc|docx|xls|xlsx|odf|ods|ppt|pptx|rtf|ttf|otf)\$ {
		expires				7d;
		access_log			off;
		log_not_found		off;
		try_files \$uri \$uri/ \$uri/$DOMAIN @backend;
	}

	# Tell the browser to cache all CSS and JS files for 1 day
	location ~* \.(htm|html|css|js)(\?[0-9a-zA-Z]+)?\$ {
		expires				1d;
		access_log			off;
		log_not_found		off;
		try_files \$uri \$uri/ \$uri/$DOMAIN @backend;
	}

	# Deny access to .htaccess files
	location ~ /\.ht {
		deny all;
	}

	location @backend {
		internal;
		proxy_pass http://$IP:8081;
		include proxy.conf;
	}

}

EOF
	 done
	done

	echo ""
	echo "Nginx and Apache vhosts synchronized!"

	echo ""
	echo "=== Restarting services... ==="
	service httpd restart
	service nginx start
	echo ""
	echo "Done!"

}

function install_gui_addon_engintron {

	if [ ! -f /usr/local/cpanel/whostmgr/docroot/cgi/addon_engintron.cgi ]; then
		touch /usr/local/cpanel/whostmgr/docroot/cgi/addon_engintron.cgi
		chmod +x /usr/local/cpanel/whostmgr/docroot/cgi/addon_engintron.cgi
	fi
	cat > "/usr/local/cpanel/whostmgr/docroot/cgi/addon_engintron.cgi" <<EOF
#!/usr/local/cpanel/3rdparty/bin/perl
#WHMADDON:engintron:Engintron for WHM

use lib '/usr/local/cpanel';
use Cpanel::cPanelFunctions ();
use Cpanel::Form						();
use Cpanel::Config					();
use Whostmgr::HTMLInterface ();
use Whostmgr::ACLS					();

print "Content-type: text/html\r\n\r\n";
BEGIN {
	 push(@INC,"/usr/local/cpanel");
	 push(@INC,"/usr/local/cpanel/whostmgr/docroot/cgi");
}

use whmlib;
require 'parseform.pl';

Whostmgr::ACLS::init_acls();
if ( !Whostmgr::ACLS::hasroot() ) {
	print "You do not have the right permissions to access this page...\n";
	exit();
}
print "<meta http-equiv=\"refresh\" content=\"0;url=engintron.php\">";
1;
EOF

	echo ""
	echo "=== Fix ACL requirements in newer cPanel releases ==="
	if grep -Fxq "permit_unregistered_apps_as_root=" /var/cpanel/cpanel.config
	then
		sed -i 's/permit_unregistered_apps_as_root=0$/permit_unregistered_apps_as_root=1/' /var/cpanel/cpanel.config
	else
		echo "permit_unregistered_apps_as_root=1" >> /var/cpanel/cpanel.config
	fi
	sleep 2

	/usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings
	/usr/local/cpanel/etc/init/startcpsrvd

	# Not needed?
	echo ""
	echo "=== Distill changes in cPanel Apache configuration and restart Apache ==="
	/usr/local/cpanel/bin/apache_conf_distiller --update
	/scripts/rebuildhttpdconf --update

	service httpd restart
	sleep 2

}

function install_gui_engintron {

	if [ ! -f /usr/local/cpanel/whostmgr/docroot/cgi/engintron.php ]; then
		touch /usr/local/cpanel/whostmgr/docroot/cgi/engintron.php
		chmod +x /usr/local/cpanel/whostmgr/docroot/cgi/engintron.php
	fi
	cat > "/usr/local/cpanel/whostmgr/docroot/cgi/engintron.php" <<EOF
<?php
/**
 * @version		1.0.4 Build 20141223
 * @package		Engintron for WHM
 * @author		Fotis Evangelou (Nuevvo) - http://nuevvo.com
 * @copyright	Copyright (c) 2010 - 2014 Nuevvo Webware P.C. All rights reserved.
 * @license		GNU/GPL license: http://www.gnu.org/copyleft/gpl.html
 */

// Permissions check
\$user = getenv('REMOTE_USER');
if(\$user != "root") {
	echo "You do not have the right permissions to access this page...";
	exit;
}

// *** Common variables to make updating easier ***
define('PLG_NAME','Engintron for WHM');
define('PLG_VERSION','1.0.4 Build 20141223');
define('NGINX_VERSION',str_replace('nginx version: nginx/','',shell_exec('nginx -v 2>&1')));

// The function to execute commands
function execute(\$act) {
	if(\$act == "restart") {
		\$command = shell_exec("/etc/init.d/nginx restart");
		if(empty(\$command)) {
			\$output = "<p>Nginx restarted successfully.</p>";
		} else {
			\$output = "<p>".nl2br(\$command)."</p>";
		}

	} elseif(\$act == "reload") {
		\$command = shell_exec("/etc/init.d/nginx reload");
		if(empty(\$command)) {
			\$output = "<p>Nginx restarted successfully.</p>";
		} else {
			\$output = "<p>".nl2br(\$command)."</p>";
		}

	} elseif(\$act == "httpdrestart") {
		\$command = shell_exec("/etc/init.d/httpd restart");
		if(empty(\$command)) {
			\$output = "<p>Apache restarted successfully.</p>";
		} else {
			\$output = "<p>".nl2br(\$command)."</p>";
		}

	} elseif(\$act == "mysqlrestart") {
		\$command = shell_exec("/scripts/resmysql");
		if(empty(\$command)) {
			\$output = "<p>MySQL restarted successfully.</p>";
		} else {
			\$output = "<p>".nl2br(\$command)."</p>";
		}

	} elseif(\$act == "rebuild") {
		\$command = shell_exec("cd /; ./engintron.sh sync;");
		if(empty(\$command)) {
			\$output = "<p>Uh, oh! No output generated.</p>";
		} else {
			\$output = "<p>".nl2br(\$command)."</p>";
		}

	} elseif(\$act == "httpd") {
		\$command = shell_exec("service httpd status");
		if(empty(\$command)) {
			\$output = "<p>No output generated by Apache.</p>";
		} else {
			\$output = "<p>".nl2br(\$command)."</p>";
		}

	} elseif(\$act == "cleanup") {
		\$command = shell_exec("rm -rvf /tmp/nginx_cache/*; rm -rvf /tmp/nginx_temp/*;");
		if(empty(\$command)) {
			\$output = "<p>No output generated. Nginx cache and temp folders are either empty or too full to be deleted using the \"rm\" command. You may want to try the \"Force cleanup Nginx cache &amp; temp files &amp; restart Nginx\" command.</p>";
		} else {
			\$output = "<p>".nl2br(\$command)."</p>";
		}

	} elseif(\$act == "forceCleanup") {
		\$command = shell_exec("find /tmp/nginx_cache/ -type f | xargs rm -rvf; find /tmp/nginx_temp/ -type f | xargs rm -rvf;");
		if(empty(\$command)) {
			\$output = "<p>No output generated. Nginx cache and temp folders are empty.</p>";
		} else {
			\$output = "<p>".nl2br(\$command)."</p>";
		}

	}

	return \$output;
}

\$op = &\$_GET['op'];

// Operations
switch(\$op) {
	case "restart":
		\$ret = "<b>Restarting Nginx...</b><br />";
		\$ret .= execute("restart");
		\$ret .= "<b>Done...</b>";
		break;

	case "reload":
		\$ret = "<b>Reloading Nginx configuration...</b><br />";
		\$ret .= execute("reload");
		\$ret .= "<b>Done...</b>";
		break;

	case "httpdrestart":
		\$ret = "<b>Restarting Apache...</b><br />";
		\$ret .= execute("httpdrestart");
		\$ret .= "<b>Done...</b>";
		break;

	case "mysqlrestart":
		\$ret = "<b>Restarting MySQL...</b><br />";
		\$ret .= execute("mysqlrestart");
		\$ret .= "<b>Done...</b>";
		break;

	case "edit":
		if(isset(\$_POST['conf'])) {
			\$conf = \$_POST['conf'];
			file_put_contents("/etc/nginx/nginx.conf", \$conf);
			\$message = '<p>Configuration has been updated.</p>';
			if(isset(\$_POST['c'])) \$message .= execute("restart");
		} else {
			\$message = '';
		}
		break;

	case "editproxyconf":
		if(isset(\$_POST['proxyconf'])) {
			\$conf = \$_POST['proxyconf'];
			file_put_contents("/etc/nginx/proxy.conf", \$conf);
			\$message = '<p>proxy.conf has been updated.</p>';
			if(isset(\$_POST['c'])) \$message .= execute("restart");
		} else {
			\$message = '';
		}
		break;

	case "editphpini":
		if(isset(\$_POST['phpini'])) {
			\$phpini = \$_POST['phpini'];
			file_put_contents("/usr/local/lib/php.ini", \$phpini);
			\$message = '<p>php.ini has been updated.</p>';
			if(isset(\$_POST['c'])) {
				\$message .= execute("httpdrestart");
				\$message .= execute("restart");
			}
		} else {
			\$message = '';
		}
		break;

	case "mysqleditcnf":
		if(isset(\$_POST['mycnf'])) {
			\$mycnf = \$_POST['mycnf'];
			file_put_contents("/etc/my.cnf", \$mycnf);
			\$message = '<p>my.cnf has been updated.</p>';
			if(isset(\$_POST['c'])) {
				\$message .= execute("mysqlrestart");
			}
		} else {
			\$message = '';
		}
		break;

	case "editphpconf":
		if(isset(\$_POST['phpconf'])) {
			\$phpconf = \$_POST['phpconf'];
			file_put_contents("/usr/local/apache/conf/php.conf", \$phpconf);
			\$message = '<p>php.conf has been updated.</p>';
			if(isset(\$_POST['c'])) {
				\$message .= nl2br(shell_exec("/usr/local/cpanel/bin/apache_conf_distiller --update"));
				\$message .= nl2br(shell_exec("/scripts/rebuildhttpdconf --update"));
				\$message .= execute("httpdrestart");
			}
		} else {
			\$message = '';
		}
		break;

	case "rebuild":
		\$ret = execute("rebuild");
		break;

	case "logs":
		if(empty(\$_POST['l'])) {
			\$command = shell_exec("cat /var/log/nginx/error.log");
			\$l = null;
		} else {
			\$l = ereg_replace("/[0-9]/","",\$_POST['l']);
			\$command = shell_exec("tail -{\$l} /var/log/nginx/error.log");
		}
		\$ret = "<b>Log Viewer: Showing last {\$l} lines</b><br /><pre>{\$command}</pre>";
		break;

	case "httpd":
		\$ret = "<b>Apache status:</b><br />";
		\$ret .= execute("httpd");
		break;

	case "mysqlstatus";
		\$ret = "<b>MySQL status:</b><br />";
		\$ret .= execute("mysqlstatus");
		break;

	case "cleanup":
		\$ret = execute("cleanup");
		\$ret .= execute("restart");
		break;

	case "forceCleanup":
		\$ret = execute("forceCleanup");
		\$ret .= execute("restart");
		break;

	default:
		\$run = "DOWN";
		\$command = shell_exec("ps -A");
		if(strstr(\$command,"nginx")) \$run = "UP";
		\$ret = "Nginx service status: <b class=\"green\">{\$run}</b>";
}

?>
<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="utf-8" />
		<title><?php echo PLG_NAME; ?></title>
		<script type="text/javascript" src="https://nuevvo.github.io/engintron.com/app/js/engintron.js"></script>
		<link rel="stylesheet" type="text/css" href="/themes/x/style_optimized.css" />
		<link rel="stylesheet" type="text/css" href="https://nuevvo.github.io/engintron.com/app/css/engintron.css" />
	</head>
	<body class="yui-skin-sam op_<?php echo \$op; ?>">
		<div id="pageheader">
			<div id="breadcrumbs">
				<p><a href="/scripts/command?PFILE=main">Main</a> &gt;&gt; <a href="engintron.php" class="active"><?php echo PLG_NAME; ?></a></p>
			</div>
		</div>
		<div id="ngContainer">
			<h1 id="ngTitle"><?php echo PLG_NAME; ?><span>(Nginx version: <?php echo NGINX_VERSION; ?>)</span></h1>
			<div id="ngOperations">
				<h2>Operations</h2>
				<ul>
					<li>
						<h3>Nginx</h3>
						<ul>
							<li<?php if(\$op=='status' || \$op=='') echo ' class="active"'; ?>><a href="engintron.php?op=status">Status</a></li>
							<li<?php if(\$op=='reload') echo ' class="active"'; ?>><a href="engintron.php?op=reload">Reload</a></li>
							<li<?php if(\$op=='restart') echo ' class="active"'; ?>><a href="engintron.php?op=restart">Restart</a></li>
							<li<?php if(\$op=='edit') echo ' class="active"'; ?>><a href="engintron.php?op=edit">nginx.conf editor</a></li>
							<li<?php if(\$op=='editproxyconf') echo ' class="active"'; ?>><a href="engintron.php?op=editproxyconf">proxy.conf editor</a></li>
							<li<?php if(\$op=='logs') echo ' class="active"'; ?>>
								<form action="engintron.php?op=logs" method="post" id="log">
									<a href="engintron.php?op=logs" onClick="clog();return false;">Error log entries: View the last</a> <input type="text" name="l" size="3" value="25" autocomplete="off" />
								</form>
							</li>
							<li<?php if(\$op=='rebuild') echo ' class="active"'; ?>><a href="engintron.php?op=rebuild">Sync Nginx with Apache vhosts</a></li>
							<li<?php if(\$op=='cleanup') echo ' class="active"'; ?>><a href="engintron.php?op=cleanup">Cleanup Nginx cache &amp; temp files, restart Nginx</a></li>
							<li<?php if(\$op=='forceCleanup') echo ' class="active"'; ?>><a href="engintron.php?op=forceCleanup">Force cleanup Nginx cache &amp; temp files, restart Nginx</a></li>
						</ul>
					</li>
					<li>
						<h3>Apache</h3>
						<ul>
							<li<?php if(\$op=='httpd') echo ' class="active"'; ?>><a href="engintron.php?op=httpd">Apache status</a></li>
							<li<?php if(\$op=='httpdrestart') echo ' class="active"'; ?>><a href="engintron.php?op=httpdrestart">Restart Apache</a></li>
							<li<?php if(\$op=='editphpconf') echo ' class="active"'; ?>><a href="engintron.php?op=editphpconf">php.conf editor</a></li>
						</ul>
					</li>
					<li>
						<h3>PHP</h3>
						<ul>
								<li<?php if(\$op=='editphpini') echo ' class="active"'; ?>><a href="engintron.php?op=editphpini">php.ini editor</a></li>
						</ul>
					</li>
					<li>
						<h3>MySQL</h3>
						<ul>
							<li<?php if(\$op=='mysqlrestart') echo ' class="active"'; ?>><a href="engintron.php?op=mysqlrestart">Restart MySQL</a></li>
							<li<?php if(\$op=='mysqleditcnf') echo ' class="active"'; ?>><a href="engintron.php?op=mysqleditcnf">my.cnf editor</a></li>
						</ul>
					</li>
				</ul>
				<h2>About</h2>
				<p><a target="_blank" href="http://nuevvo.com/labs/"><?php echo PLG_NAME; ?></a> is a cPanel plugin providing a GUI interface for the Nginx server on your cPanel server.</p>
				<p><a target="_blank" href="http://nginx.org/">Nginx</a> is a free, open-source, high-performance HTTP server and reverse proxy, as well as an IMAP/POP3 proxy server. Igor Sysoev started development of Nginx in 2002, with the first public release in 2004. Nginx now hosts 14% of the web, taking the 2nd position after Apache and putting IIS in the 3rd place (Netcraft April 2014 report). Nginx is known for its high performance, stability, rich feature set, simple configuration and low resource consumption.</p>
			</div>
			<div id="ngOutput">
				<h2>Output</h2>
				<div id="ngOutputWindow">

					<?php if(\$ret) echo \$ret; ?>
					<?php if(\$message) echo '<div class="message">'.\$message.'</div>'; ?>

					<?php if(\$op=='edit'): ?>
					<form action="engintron.php?op=edit" method="post" id="editNginxConf">
						<textarea name="conf" cols="80" rows="19"><?php echo file_get_contents("/etc/nginx/nginx.conf"); ?></textarea>
						<div class="editbox">
							<input type="checkbox" name="c" />Restart Nginx? <small>(recommended if you want changes to take effect immediately)</small>
							<br /><br />
							<input type="submit" value="Update nginx.conf" onClick="confirm('editNginxConf');return false;" />
						</div>
					</form>
					<?php endif; ?>

					<?php if(\$op=='editproxyconf'): ?>
					<form action="engintron.php?op=editproxyconf" method="post" id="editProxyConf">
						<textarea name="proxyconf" cols="80" rows="19"><?php echo file_get_contents("/etc/nginx/proxy.conf"); ?></textarea>
						<div class="editbox">
							<input type="checkbox" name="c" />Restart Nginx? <small>(recommended if you want changes to take effect immediately)</small>
							<br /><br />
							<input type="submit" value="Update proxy.conf" onClick="confirm('editProxyConf');return false;" />
						</div>
					</form>
					<?php endif; ?>

					<?php if(\$op=='editphpini'): ?>
					<form action="engintron.php?op=editphpini" method="post" id="editPhpIni">
						<textarea name="phpini" cols="80" rows="19"><?php echo file_get_contents("/usr/local/lib/php.ini"); ?></textarea>
						<div class="editbox">
							<input type="checkbox" name="c" />Restart Apache &amp; Nginx? <small>(recommended if you want changes to take effect immediately)</small>
							<br /><br />
							<input type="submit" value="Update php.ini" onClick="confirm('editPhpIni');return false;" />
						</div>
					</form>
					<?php endif; ?>

					<?php if(\$op=='mysqleditcnf'): ?>
					<form action="engintron.php?op=mysqleditcnf" method="post" id="editMyCnf">
						<textarea name="mycnf" cols="80" rows="19"><?php echo file_get_contents("/etc/my.cnf"); ?></textarea>
						<div class="editbox">
							<input type="checkbox" name="c" />Restart MySQL? <small>(recommended if you want changes to take effect immediately)</small>
							<br /><br />
							<input type="submit" value="Update my.cnf" onClick="confirm('editMyCnf');return false;" />
						</div>
					</form>
					<?php endif; ?>

					<?php if(\$op=='editphpconf'): ?>
					<form action="engintron.php?op=editphpconf" method="post" id="editPhpConf">
						<textarea name="phpconf" cols="80" rows="19"><?php echo file_get_contents("/usr/local/apache/conf/php.conf"); ?></textarea>
						<div class="editbox">
							<input type="checkbox" name="c" />Distill changes to Apache? <small>(recommended if you want changes to take effect immediately)</small>
							<br /><br />
							<input type="submit" value="Update php.conf" onClick="confirm('editPhpConf');return false;" />
						</div>
					</form>
					<?php endif; ?>

				</div>
			</div>
			<div class="clr"></div>
			<hr />
			<p><a target="_blank" href="http://nuevvo.com/"><?php echo PLG_NAME; ?> v<?php echo PLG_VERSION; ?></a> | Copyright &copy; 2010-<?php echo date('Y'); ?> <a target="_blank" href="http://nuevvo.com/">Nuevvo Webware P.C.</a> Released under the <a target="_blank" href="http://www.gnu.org/licenses/gpl.html">GNU/GPL</a> license.</p>
		</div>
	</body>
</html>
EOF

}

function add_munin_patch {
	if [ -f /etc/munin/plugin-conf.d/cpanel.conf ]; then
		echo ""
		echo "=== Updating Munin configuration ==="

		if grep -q "\[apache_status\]" /etc/munin/plugin-conf.d/cpanel.conf
		then
			echo "Munin patched already, nothing to do here"
		else
			cat >> "/etc/munin/plugin-conf.d/cpanel.conf" <<EOF

[apache_status]
env.ports 8081
env.label 8081

EOF
		fi

		ln -s /usr/local/cpanel/3rdparty/share/munin/plugins/nginx_request /etc/munin/plugins/nginx_request
		ln -s /usr/local/cpanel/3rdparty/share/munin/plugins/nginx_status /etc/munin/plugins/nginx_status

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
			sed -i 's:env\.ports 8081::' /etc/munin/plugin-conf.d/cpanel.conf
			sed -i 's:env\.label 8081::' /etc/munin/plugin-conf.d/cpanel.conf
		else
			echo "Munin was not found, nothing to do here"
		fi

		rm -f /etc/munin/plugins/nginx_request
		rm -f /etc/munin/plugins/nginx_status

		service munin-node restart
	fi
}

function remove_mod_rpaf {

	if [ -f /usr/local/apache/conf/includes/rpaf.conf ]; then
		echo ""
		echo "=== Updating Apache configuration to remove mod_rpaf ==="
		rm -f /usr/local/apache/conf/includes/rpaf.conf
		sed -i 's:Include "/usr/local/apache/conf/includes/rpaf.conf":\n:' /usr/local/apache/conf/httpd.conf
		sleep 2
		service httpd restart
	fi

}

function remove_mod_remoteip {

	if [ -f /usr/local/apache/conf/includes/remoteip.conf ]; then
		echo ""
		echo "=== Updating Apache configuration to remove mod_remoteip ==="
		rm -f /usr/local/apache/conf/includes/remoteip.conf
		sed -i 's:Include "/usr/local/apache/conf/includes/remoteip.conf":\n:' /usr/local/apache/conf/httpd.conf
		sleep 2
		service httpd restart
	fi

}

function remove_update_apache {

	echo ""
	echo "=== Switch Apache back to port 80 ==="
	sed -i 's/apache_port=0.0.0.0:8081$//' /var/cpanel/cpanel.config
	/usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings
	sleep 2

	echo ""
	echo "=== Distill changes in cPanel Apache configuration and restart Apache ==="
	/usr/local/cpanel/bin/apache_conf_distiller --update
	/scripts/rebuildhttpdconf --update

	service httpd restart
	sleep 2

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

}

############################# HELPER FUCTIONS [end] #############################



### Define actions ###
case $1 in
install)
	chmod +x /engintron.sh
	clear
	cd /

	echo ""
	echo " ****************************************************"
	echo " *               Installing Engintron               *"
	echo " ****************************************************"

	install_basics

	GET_HTTPD_VERSION=`httpd -v | grep "Server version"`;
	if [[ $GET_HTTPD_VERSION =~ "Apache/2.2." ]];
	then
		install_mod_rpaf
	else
		install_mod_remoteip
	fi

	install_update_apache
	install_nginx
	sync_vhosts
	add_munin_patch

	echo ""
	echo "=== Preparing GUI files... ==="
	install_gui_addon_engintron
	install_gui_engintron

	echo " ****************************************************"
	echo " *               Installation Complete              *"
	echo " ****************************************************"
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

	echo ""
	echo "=== Deleting GUI files... ==="
	rm -f /usr/local/cpanel/whostmgr/docroot/cgi/addon_engintron.cgi
	rm -f /usr/local/cpanel/whostmgr/docroot/cgi/engintron.php

	sleep 2

	echo ""
	echo "=== Restarting Apache... ==="
	service httpd restart

	echo ""
	echo " ****************************************************"
	echo " *               Removal Complete                   *"
	echo " ****************************************************"
	echo ""
	;;
sync)
	sync_vhosts
	;;
*)
	echo ""
	echo -e "\033[35;1m Please define an action: install | remove | sync \033[0m"
	echo -e "\033[35;1m For example: sh engintron.sh install \033[0m"
	echo ""
	;;
esac
