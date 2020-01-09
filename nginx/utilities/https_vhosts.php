#!/usr/local/cpanel/3rdparty/bin/php
<?php

/**
 * @version    1.12.0
 * @package    Engintron for cPanel/WHM
 * @author     Fotis Evangelou (https://kodeka.io)
 * @url        https://engintron.com
 * @copyright  Copyright (c) 2018 - 2020 Kodeka OÜ. All rights reserved.
 * @license    GNU/GPL license: https://www.gnu.org/copyleft/gpl.html
 */

if (file_exists('/etc/apache2/conf/httpd.conf') && is_readable('/etc/apache2/conf/httpd.conf')) {
    define('HTTPD_CONF', '/etc/apache2/conf/httpd.conf');
} elseif (file_exists('/etc/httpd/conf/httpd.conf') && is_readable('/etc/httpd/conf/httpd.conf')) {
    define('HTTPD_CONF', '/etc/httpd/conf/httpd.conf');
} else {
    define('HTTPD_CONF', '/usr/local/apache/conf/httpd.conf');
}
define('HTTPD_CONF_LAST_CHANGED', 15); /* In seconds */
define('HTTPD_HTTPS_PORT', '8443');
define('NGINX_HTTPS_PORT', '443');
define('NGINX_DEFAULT_HTTPS_VHOST', '/etc/nginx/conf.d/default_https.conf');

//date_default_timezone_set('UTC');
//ini_set('display_errors', 0);
//error_reporting(0);

function generate_https_vhosts()
{
    $hostnamePemFile = '';
    if (file_exists('/var/cpanel/ssl/cpanel/cpanel.pem') && is_readable('/var/cpanel/ssl/cpanel/cpanel.pem')) {
        $hostnamePemFile = '/var/cpanel/ssl/cpanel/cpanel.pem';
    }
    if (file_exists('/var/cpanel/ssl/cpanel/mycpanel.pem') && is_readable('/var/cpanel/ssl/cpanel/mycpanel.pem')) {
        $hostnamePemFile = '/var/cpanel/ssl/cpanel/mycpanel.pem';
    }

    // Initialize the output for default_https.conf
    $output = '
# /**
#  * @version    1.12.0
#  * @package    Engintron for cPanel/WHM
#  * @author     Fotis Evangelou (https://kodeka.io)
#  * @url        https://engintron.com
#  * @copyright  Copyright (c) 2018 - 2020 Kodeka OÜ. All rights reserved.
#  * @license    GNU/GPL license: https://www.gnu.org/copyleft/gpl.html
#  */

# Default definition block for HTTPS (Generated on '.@date('Y.m.d H:i:s').') #
server {
    #listen '.NGINX_HTTPS_PORT.' ssl http2 default_server;
    listen [::]:'.NGINX_HTTPS_PORT.' ssl http2 default_server ipv6only=off;
    server_name localhost;

    # deny all; # DO NOT REMOVE OR CHANGE THIS LINE - Used when Engintron is disabled to block Nginx from becoming an open proxy

    ssl_certificate '.$hostnamePemFile.';
    ssl_certificate_key '.$hostnamePemFile.';

    # OCSP Stapling
    #ssl_trusted_certificate '.$hostnamePemFile.';
    #ssl_stapling on;
    #ssl_stapling_verify on;

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
    if (file_exists(HTTPD_CONF) && is_readable(HTTPD_CONF)) {
        $file = file_get_contents(HTTPD_CONF);
        $regex = "#\<VirtualHost [0-9a-f\.\:\[\]\s]+\:".HTTPD_HTTPS_PORT."\>(.+?)\<\/VirtualHost\>#s";
        preg_match_all($regex, $file, $matches, PREG_PATTERN_ORDER);
        $vhosts = $matches[1];
        if (count($vhosts)) {
            foreach ($vhosts as $vhost) {
                if ($hostnamePemFile && strpos($vhost, $hostnamePemFile)!== false) {
                    continue;
                } // Skip the main hostname entry
                preg_match("#ServerName (.+?)\n#s", $vhost, $name);
                preg_match_all("#ServerAlias (.+?)\n#s", $vhost, $aliases);
                preg_match("#SSLCertificateFile (.+?)(\n|\r)#s", $vhost, $certfile);
                preg_match("#SSLCertificateKeyFile (.+?)(\n|\r)#s", $vhost, $certkeyfile);
                preg_match("#SSLCACertificateFile (.+?)(\n|\r)#s", $vhost, $certcafile);
                if ($aliases[1]) {
                    $vhostAliases = implode(' ', $aliases[1]);
                } else {
                    $vhostAliases = '';
                }
                $vhostDomains = trim($name[1].' '.$vhostAliases);
                $vhostDomainsForNginx = explode(' ', $vhostDomains);
                $vhostDomainsForNginx = implode(PHP_EOL.'        ', $vhostDomainsForNginx);
                $vhostDomainsAsComment = str_split($vhostDomains, 250);
                $vhostDomainsAsComment = implode(PHP_EOL.'# ', $vhostDomainsAsComment);
                $vhostCertFile = $certfile[1];
                $vhostCertKeyFile = $certkeyfile[1];
                if (strpos($vhostCertFile, '/combined') !== false) {
                    $fullChainCertName = $vhostCertFile;
                    $vhostCertKeyFile = $vhostCertFile;
                } else {
                    $fullChainCertName = str_replace('/var/cpanel/ssl/installed/certs/', '/etc/ssl/engintron/', $vhostCertFile);
                    if ($certcafile[1]) {
                        $vhostCertCAFile = $certcafile[1];
                        $vhostFullChainCert = file_get_contents($vhostCertFile)."\n".file_get_contents($vhostCertCAFile);
                        $ocspStapling = '
    # OCSP Stapling
    #ssl_trusted_certificate '.$fullChainCertName.';
    #ssl_stapling on;
    #ssl_stapling_verify on;
                    ';
                    } else {
                        $vhostFullChainCert = file_get_contents($vhostCertFile);
                        $ocspStapling = '';
                    }
                    file_put_contents($fullChainCertName, $vhostFullChainCert);
                }

                $output .= '
# Definition block for domain(s): '.$vhostDomainsAsComment.' #
server {
    #listen '.NGINX_HTTPS_PORT.' ssl http2;
    listen [::]:'.NGINX_HTTPS_PORT.' ssl http2;
    server_name '.$vhostDomainsForNginx.';
    # deny all; # DO NOT REMOVE OR CHANGE THIS LINE - Used when Engintron is disabled to block Nginx from becoming an open proxy
    ssl_certificate '.$fullChainCertName.';
    ssl_certificate_key '.$vhostCertKeyFile.';
    '.$ocspStapling.'
    include common_https.conf;
}
                ';
            }
        }
    }
    file_put_contents(NGINX_DEFAULT_HTTPS_VHOST, $output);
}

// Run the check
if (!file_exists(NGINX_DEFAULT_HTTPS_VHOST) || (file_exists(HTTPD_CONF) && is_readable(HTTPD_CONF) && (filemtime(HTTPD_CONF) + HTTPD_CONF_LAST_CHANGED) > time())) {
    generate_https_vhosts();
    exit(1);
} else {
    exit(0);
}
