#!/bin/bash

# Package		Engintron
# Version		1.0.1 Build 20130716
# Copyright	Nuevvo Webware Ltd. All right reserved.
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
proxy_cache_valid						1m;
proxy_cache									cpanel;
proxy_cache_key							\$scheme\$host\$request_method\$request_uri;
proxy_cache_use_stale				updating;

# Timeouts
proxy_connect_timeout				120s;
proxy_send_timeout		 			120s;
proxy_read_timeout		 			120s;

# Buffers
proxy_buffer_size			 			64k;
proxy_buffers								16 32k;
proxy_busy_buffers_size			64k;
proxy_temp_file_write_size 	64k;

# Proxy Headers
proxy_ignore_headers				Cache-Control Expires Set-Cookie;
proxy_set_header	 					Host \$host;
proxy_set_header	 					Referer \$http_referer;
proxy_set_header 						X-Forwarded-For \$proxy_add_x_forwarded_for;
proxy_set_header 						X-Forwarded-Host \$host;
proxy_set_header 						X-Forwarded-Server \$host;
proxy_set_header	 					X-Real-IP \$remote_addr;

EOF

	cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak

	cat > "/etc/nginx/nginx.conf" <<EOF
user nobody;

worker_processes			2; # set to the number of CPU cores on your server
#worker_rlimit_nofile	20480;

error_log							/var/log/nginx/error.log warn;
pid										/var/run/nginx.pid;

events {
	worker_connections 1024; # increase for busier servers
	use epoll; # you should use epoll for Linux kernels 2.6.x
}

http {
	include												/etc/nginx/mime.types;
	default_type									application/octet-stream;
	log_format	 									main	'\$remote_addr - \$remote_user [\$time_local] "\$request" '
																			'\$status \$body_bytes_sent "\$http_referer" '
																			'"\$http_user_agent" "\$http_x_forwarded_for"';
	access_log	 									/var/log/nginx/access.log	 main;
	client_max_body_size 					256M;
	client_body_buffer_size 			128k;
	client_body_in_file_only 			on;
	client_body_timeout 					3m;
	client_header_buffer_size 		256k;
	client_header_timeout					3m;
	connection_pool_size	 				256;
	ignore_invalid_headers 				on;
	keepalive_timeout							20;
	large_client_header_buffers 	4 256k;
	output_buffers								4 32k;
	postpone_output								1460;
	request_pool_size							32k;
	reset_timedout_connection			on;
	sendfile											on;
	send_timeout									3m;
	server_names_hash_bucket_size	1024;
	server_names_hash_max_size		10240;
	server_name_in_redirect				off;
	server_tokens									off;
	tcp_nodelay										on;
	tcp_nopush										on;

	# Proxy Settings
	proxy_cache_path							/tmp/nginx_cache
																levels=1:2
																keys_zone=cpanel:50m
																inactive=24h
																max_size=500m;
	proxy_temp_path								/tmp/nginx_temp;

	# Gzip Settings
	gzip 								on;
	gzip_vary 					on;
	gzip_disable 				"MSIE [1-6]\.";
	gzip_proxied 				any;
	gzip_http_version 	1.1;
	gzip_min_length			1000;
	gzip_comp_level			6;
	gzip_buffers	 			16 8k;
	gzip_types					application/atom+xml application/json application/x-javascript application/xml application/xml+rss text/css text/javascript text/plain text/xml;

	# Include site configurations
	include /etc/nginx/conf.d/*.conf;
}

EOF

	echo ""
	echo "=== Registering Nginx as a service... ==="
	/sbin/chkconfig nginx on

}

function sync_vhosts {

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

	access_log off;
	error_log /var/log/nginx/error.$DOMAIN.log warn;

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
		/usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings
		/usr/local/cpanel/etc/init/startcpsrvd
	else
		echo "permit_unregistered_apps_as_root=1" >> /var/cpanel/cpanel.config
	fi
	sleep 2
	
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
 * @version		1.0
 * @package		Engintron for WHM
 * @author		Fotis Evangelou (Nuevvo) - http://nuevvo.com
 * @copyright	Copyright (c) 2010 - 2012 Nuevvo Webware Ltd. All rights reserved.
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
define('PLG_VERSION','1.0');
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
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
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
				h1#ngTitle {background:url('data:image/png;base64,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') no-repeat 0 50%;font-size:20px;padding:36px 0 24px 352px;margin:0 0 8px 0;}
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
				<p><a target="_blank" href="http://nginx.org/">Nginx</a> is a free, open-source, high-performance HTTP server and reverse proxy, as well as an IMAP/POP3 proxy server. Igor Sysoev started development of Nginx in 2002, with the first public release in 2004. Nginx now hosts nearly 6.55% (13.5M) of all domains worldwide. Nginx is known for its high performance, stability, rich feature set, simple configuration, and low resource consumption.</p>
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
			<p><a target="_blank" href="http://nuevvo.com/"><?php echo PLG_NAME; ?> v<?php echo PLG_VERSION; ?></a> | Copyright &copy; 2010-<?php echo date('Y'); ?> <a target="_blank" href="http://nuevvo.com/">Nuevvo Webware Ltd</a>. Licensed under the <a target="_blank" href="http://www.gnu.org/licenses/gpl.html">GNU/GPL</a> license.</p>
		</div>
	</body>
</html>
EOF

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
	echo "====================================="
	echo "=== Installing Nginx on cPanel... ==="
	echo "====================================="

	install_basics
	install_mod_rpaf
	install_update_apache
	install_nginx
	sync_vhosts

	echo ""
	echo "=== Preparing GUI files... ==="
	install_gui_addon_engintron
	install_gui_engintron

	echo " ****************************************************"
	echo " *								Installation Complete							 *"
	echo " ****************************************************"
	echo ""
		;;
remove)
	remove_mod_rpaf
	remove_update_apache
	remove_nginx

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
	echo " *									Removal Complete								 *"
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
