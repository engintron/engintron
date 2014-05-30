#!/bin/bash

# Package		Engintron
# Version		1.0.3 Build 20140530
# Copyright		Nuevvo Webware P.C. All rights reserved.
# License		Commercial

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
		echo "=== Installing mod_rpaf for Apache ==="
		cd /usr/local/src
		wget http://www.stderr.net/apache/rpaf/download/mod_rpaf-0.6.tar.gz
		tar xzf mod_rpaf-0.6.tar.gz
		cd mod_rpaf-0.6
		#/usr/sbin/apxs -i -c -n mod_rpaf-2.0.so mod_rpaf-2.0.c
		#/usr/local/apache/bin/apxs	 -i -c -n mod_rpaf-2.0.so mod_rpaf-2.0.c
		apxs -i -c -n mod_rpaf-2.0.so mod_rpaf-2.0.c

		cd /

		echo ""
		echo "=== Get system IPs ==="
		systemips=$(ip addr show | grep 'inet ' | grep ' brd ' | cut -d/ -f1 | cut -c10- | tr '\n' ' ');

		touch /usr/local/apache/conf/includes/rpaf.conf
		echo "
LoadModule rpaf_module modules/mod_rpaf-2.0.so

RPAFenable On
RPAFsethostname On
RPAFproxy_ips 127.0.0.1 $systemips
RPAFheader X-Real-IP
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
# Change '1m' below to the time in minutes (e.g. '5m' for 5 minutes) you wish for all 200, 301 and 302 replies to be cached.
# More info here: http://wiki.nginx.org/HttpProxyModule#proxy_cache_valid
proxy_cache_valid				1m;
proxy_cache						cpanel;
proxy_cache_key					\$scheme\$host\$request_method\$request_uri;
proxy_cache_use_stale			updating;

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

worker_processes			auto; # set to the number of CPU cores on your server
#worker_rlimit_nofile	20480;

error_log							/var/log/nginx/error.log warn;
pid									/var/run/nginx.pid;

events {
	worker_connections 1024; # increase for busier servers
	use epoll; # you should use epoll for Linux kernels 2.6.x
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

	location ~* ^/(administrator|.*/administrator|.*/.*/administrator|wp-admin|.*/wp-admin|.*/.*/wp-admin) {
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
		expires					7d;
		access_log			off;
		log_not_found		off;
		try_files \$uri \$uri/ \$uri/$DOMAIN @backend;
	}

	# Tell the browser to cache all video, audio and doc files for 1 week
	location ~* \.(txt|mp3|mp4|m4v|mov|mpg|mpeg|flv|swf|ogg|ogv|wmv|wma|pdf|doc|docx|xls|xlsx|odf|ods|ppt|pptx|rtf|ttf|otf)\$ {
		expires					7d;
		access_log			off;
		log_not_found		off;
		try_files \$uri \$uri/ \$uri/$DOMAIN @backend;
	}

	# Tell the browser to cache all CSS and JS files for 1 day
	location ~* \.(htm|html|css|js)(\?[0-9a-zA-Z]+)?\$ {
		expires					1d;
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
 * @version		1.0.3
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
define('PLG_VERSION','1.0.3');
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
		<script type="text/javascript">
			function confirm(id) {
				if(confirm('Are you sure?')) {
					document.getElementById(id).submit();
				}
				return false;
			}
			function clog() {
				document.getElementById('log').submit();
			}
		</script>
		<link rel="stylesheet" type="text/css" href="/themes/x/style_optimized.css" />
		<style type="text/css">
			body {margin:0;padding:0;}
			.clr {clear:both;display:block;height:0;line-height:0;padding:0;margin:0;}
			hr {line-height:0;height:0;border:none;border-bottom:1px dotted #ccc;padding:0;margin:8px 0;}

			div#ngContainer {margin:0;padding:0 16px 4px;position:relative;}
				h1#ngTitle {background:url('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAATwAAABiCAYAAADN9m81AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyNpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuNS1jMDIxIDc5LjE1NDkxMSwgMjAxMy8xMC8yOS0xMTo0NzoxNiAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENDIChNYWNpbnRvc2gpIiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOkU3RTU5OTdEQkQ4OTExRTM4QUNDQUUzMzgzNUMyMDREIiB4bXBNTTpEb2N1bWVudElEPSJ4bXAuZGlkOkU3RTU5OTdFQkQ4OTExRTM4QUNDQUUzMzgzNUMyMDREIj4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6RTdFNTk5N0JCRDg5MTFFMzhBQ0NBRTMzODM1QzIwNEQiIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6RTdFNTk5N0NCRDg5MTFFMzhBQ0NBRTMzODM1QzIwNEQiLz4gPC9yZGY6RGVzY3JpcHRpb24+IDwvcmRmOlJERj4gPC94OnhtcG1ldGE+IDw/eHBhY2tldCBlbmQ9InIiPz4kIKWEAAAumElEQVR42ux9C5wd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') no-repeat 0 50%;font-size:20px;padding:36px 0 24px 352px;margin:0 0 8px 0;}
				h1#ngTitle span {display:block;font-size:11px;font-weight:normal;color:#999;}
				div#ngOperations {float:left;width:30%;}
				div#ngOperations ul {padding:0 0 0 16px;margin:0;list-style:square;}
				div#ngOperations ul li {padding:1px 0;}
				div#ngOperations ul li.active {font-weight:bold;}
				div#ngOutput {float:right;width:68%;}
					div#ngOutputWindow {padding:2px;height:380px;overflow:auto;border:1px solid #ccc;font-family:monospace;}
					div#ngOutputWindow b {color:#009;}
					div#ngOutputWindow b.green {color:#0c0;}
					body.op_edit div#ngOutputWindow,
					body.op_editphpini div#ngOutputWindow,
					body.op_mysqleditcnf div#ngOutputWindow {background:#eee;}
					div.message {background:#fffff0;font-weight:bold;color:#009;text-align:right;padding:8px;border:1px solid #ccc;position:absolute;top:4px;right:4px;width:240px;opacity:0.9;}
					div#ngOutput form textarea {border:none;width:100%;padding:0;margin:0;}
					div#ngOutput form .editbox {border-top:1px solid #ccc;padding:8px;}
		</style>
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
							<input type="checkbox" name="c" />Restart Apache &amp Nginx? <small>(recommended if you want changes to take effect immediately)</small>
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
			<p><a target="_blank" href="http://nuevvo.com/"><?php echo PLG_NAME; ?> v<?php echo PLG_VERSION; ?></a> | Copyright &copy; 2010-<?php echo date('Y'); ?> <a target="_blank" href="http://nuevvo.com/">Nuevvo Webware P.C.</a> Licensed under the <a target="_blank" href="http://www.gnu.org/licenses/gpl.html">GNU/GPL</a> license.</p>
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

[nginx*]
env.url http://localhost/nginx_status

EOF
		fi

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
			sed -i 's:\[nginx\*\]::' /etc/munin/plugin-conf.d/cpanel.conf
			sed -i 's:env\.url http\:\/\/localhost\/nginx_status::' /etc/munin/plugin-conf.d/cpanel.conf
		else
			echo "Munin was not found, nothing to do here"
		fi

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
