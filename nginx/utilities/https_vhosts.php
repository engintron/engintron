#!/usr/bin/php
<?php

/**
 * @version    1.8.0
 * @package    Engintron for cPanel/WHM
 * @author     Fotis Evangelou
 * @url        https://engintron.com
 * @copyright  Copyright (c) 2010 - 2017 Nuevvo Webware P.C. All rights reserved.
 * @license    GNU/GPL license: http://www.gnu.org/copyleft/gpl.html
 */

define('HTTPD_CONF_LAST_CHANGED', 10); /* In seconds */
define('HTTPD_CONF', '/usr/local/apache/conf/httpd.conf'); /* For EA4 the path is /etc/httpd/conf/httpd.conf */
define('HTTPD_HTTPS_PORT', '8443');
define('NGINX_DEFAULT_HTTPS_VHOST', '/etc/nginx/conf.d/default_https.conf');
define('NGINX_HTTPS_PORT', '443');

function generate_https_vhosts() {

    $hostnamePemFile = '';
    if (file_exists('/var/cpanel/ssl/cpanel/cpanel.pem') && is_readable('/var/cpanel/ssl/cpanel/cpanel.pem')) {
        $hostnamePemFile = '/var/cpanel/ssl/cpanel/cpanel.pem';
    }
    if (file_exists('/var/cpanel/ssl/cpanel/mycpanel.pem') && is_readable('/var/cpanel/ssl/cpanel/mycpanel.pem')) {
        $hostnamePemFile = '/var/cpanel/ssl/cpanel/mycpanel.pem';
    }

    // Initialize the output for default_https.conf
    $output = '
# Default definition block for HTTPS (Generated on '.date('Y.m.d H:i:s').') #
server {

    listen '.NGINX_HTTPS_PORT.' ssl http2 default_server;
    #listen [::]:'.NGINX_HTTPS_PORT.' ssl http2 default_server; # Uncomment if your server supports IPv6

    server_name localhost;

    # deny all; # DO NOT REMOVE OR CHANGE THIS LINE - Used when Engintron is disabled to block Nginx from becoming an open proxy

    ssl_certificate '.$hostnamePemFile.';
    ssl_certificate_key '.$hostnamePemFile.';
    ssl_trusted_certificate '.$hostnamePemFile.';

    include common_https.conf;

    location = /nginx_status {
        stub_status;
        access_log off;
        log_not_found off;
        # Uncomment the following 2 lines to make the Nginx status page private.
        # If you do this and you have Munin installed, graphs for Nginx will stop working.
        #allow 127.0.0.1;
        #deny all;
    }

    location = /whm-server-status {
        proxy_pass http://127.0.0.1:8080;
        # Comment the following 2 lines to make the Apache status page public
        allow 127.0.0.1;
        deny all;
    }

}
    ';

    // Process Apache vhosts
    $file = file_get_contents(HTTPD_CONF);
    $regex = "#\<VirtualHost [0-9\.]+\:".HTTPD_HTTPS_PORT."\>(.+?)\<\/VirtualHost\>#s";
    preg_match_all($regex, $file, $matches, PREG_PATTERN_ORDER);
    foreach ($matches[1] as $vhost) {
        $vhostBlock = array();
        preg_match("#ServerName (.+?)\n#s", $vhost, $name);
        preg_match("#ServerAlias (.+?)\n#s", $vhost, $aliases);
        $vhostBlock['domains'] = $name[1].' '.$aliases[1];
        preg_match("#\<IfModule ssl_module\>(.+?)\<\/IfModule\>#s", $vhost, $sslblock);
        $sslBlockContents = $sslblock[1];
        preg_match("#SSLCertificateFile (.+?)\n#s", $sslBlockContents, $certfile);
        preg_match("#SSLCertificateKeyFile (.+?)\n#s", $sslBlockContents, $certkey);
        preg_match("#SSLCACertificateFile (.+?)\n#s", $sslBlockContents, $certbundle);
        $vhostBlock['certificates'] = array(
            'SSLCertificateFile' => $certfile[1],
            'SSLCertificateKeyFile' => $certkey[1],
            'SSLCACertificateFile' => $certbundle[1]
        );

        $fullChainCertName = str_replace('/var/cpanel/ssl/installed/certs/', '/etc/ssl/engintron/', $vhostBlock['certificates']['SSLCertificateFile']);
        file_put_contents($fullChainCertName, file_get_contents($vhostBlock['certificates']['SSLCertificateFile'])."\n".file_get_contents($vhostBlock['certificates']['SSLCACertificateFile']));

        $output .= '
# Definition block for domain(s): '.$vhostBlock['domains'].' #
server {
    listen '.NGINX_HTTPS_PORT.' ssl http2;
    #listen [::]:'.NGINX_HTTPS_PORT.' ssl http2; # Uncomment if your server supports IPv6
    server_name '.$vhostBlock['domains'].';
    # deny all; # DO NOT REMOVE OR CHANGE THIS LINE - Used when Engintron is disabled to block Nginx from becoming an open proxy
    ssl_certificate '.$fullChainCertName.';
    ssl_certificate_key '.$vhostBlock['certificates']['SSLCertificateKeyFile'].';
    ssl_trusted_certificate '.$fullChainCertName.';
    include common_https.conf;
}
        ';
    }
    file_put_contents(NGINX_DEFAULT_HTTPS_VHOST, $output);
}

// Run the check
if (!file_exists(NGINX_DEFAULT_HTTPS_VHOST) || (file_exists(HTTPD_CONF) && is_readable(HTTPD_CONF) && (filemtime(HTTPD_CONF) + HTTPD_CONF_LAST_CHANGED) > time())) {
    generate_https_vhosts();
    echo "HTTPS vhosts for Nginx re-created.\n";
    exit(1);
} else {
    echo "No changes in Apache's vhosts configuration. HTTPS vhosts for Nginx unchanged.\n";
    exit(0);
}
