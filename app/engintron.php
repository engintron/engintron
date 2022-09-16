<?php
/**
 * @version    2.1
 * @package    Engintron for cPanel/WHM
 * @author     Fotis Evangelou (https://kodeka.io)
 * @url        https://engintron.com
 * @copyright  Copyright (c) 2014 - 2022 Kodeka OÜ. All rights reserved.
 * @license    GNU/GPL license: https://www.gnu.org/copyleft/gpl.html
 */

// WHM PHP API
require_once '/usr/local/cpanel/php/WHM.php';

// Utility functions
function checkacl()
{
    $user = $_ENV['REMOTE_USER'];
    if ($user == "root") {
        return 1;
    }
    if (file_exists('/var/cpanel/resellers') && is_readable('/var/cpanel/resellers')) {
        $reseller = file_get_contents('/var/cpanel/resellers');
        if (trim($reseller) != '') {
            foreach (preg_split('/\r\n|\r|\n/', $reseller) as $line) {
                if (preg_match("/^$user:/", $line)) {
                    $line = preg_replace("/^$user:/", "", $line);
                    foreach (explode(',', $line) as $perm) {
                        if ($perm == "all") {
                            return 1;
                        }
                    }
                }
            }
        }
    }
    return 0;
}

// A few constants to make updating easier
define('CPANEL_RELEASE', trim(shell_exec('/usr/local/cpanel/cpanel -V')));
define('CPANEL_VERSION', (int) CPANEL_RELEASE);
define('NGINX_VERSION', trim(str_replace('nginx version: nginx/', '', shell_exec('nginx -v 2>&1'))));
define('OS_RELEASE', trim(shell_exec('rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release)')));
define('PLG_BUILD', 'Build 20220916');
define('PLG_NAME_SHORT', 'Engintron');
define('PLG_NAME', 'Engintron for cPanel/WHM');
define('PLG_VERSION', '2.1');

if (file_exists("/opt/engintron/state.conf")) {
    define('ENGINTRON_STATE', trim(file_get_contents("/opt/engintron/state.conf")));
} else {
    define('ENGINTRON_STATE', 'missing');
}

// Permissions check
$grantAccess = false;
if (CPANEL_VERSION > 64) {
    if (checkacl()) {
        $grantAccess = true;
    }
} else {
    $checkPrivileges = trim(shell_exec("if whmapi1 myprivs | grep -q 'all: 1'; then echo 'all'; fi;"));
    $user = getenv('REMOTE_USER'); /* legacy check */
    if ($checkPrivileges=='all') {
        $grantAccess = true;
    }
    if ($user=="root") {
        $grantAccess = true;
    }
    if (strpos($user, 'cp')!==false) {
        $grantAccess = true;
    }
}
if ($grantAccess === false) {
    echo "You do not have sufficient permissions to access this page...";
    exit;
}

// Get params
$allowed_files = array(
    '/etc/crontab',
    '/etc/my.cnf',
    '/etc/nginx/common_http.conf',
    '/etc/nginx/common_https.conf',
    '/etc/nginx/conf.d/default.conf',
    '/etc/nginx/custom_rules.dist',
    '/etc/nginx/custom_rules',
    '/etc/nginx/nginx.conf',
    '/etc/nginx/proxy_params_common',
    '/etc/nginx/proxy_params_dynamic',
    '/etc/nginx/proxy_params_static'
);

$allowed_services = array(
    'apache',
    'cron',
    'mysql',
    'nginx',
);

$op = $_GET['op'];
$f = $_GET['f'];
$s = (isset($_GET['s']) && in_array($_GET['s'], $allowed_services)) ? $_GET['s'] : '';
$ps = (isset($_POST['s']) && in_array($_POST['s'], $allowed_services)) ? $_POST['s'] : '';
$state = $_GET['state'];

// Operations
switch ($op) {
    case "view":
        if (isset($f) && in_array($f, $allowed_files)) {
            $ret = file_get_contents($f);
        }
        break;

    case "edit":
        if (isset($_POST['data'])) {
            $data = $_POST['data'];
            if (isset($f) && in_array($f, $allowed_files)) {
                file_put_contents($f, str_replace("\r\n", "\n", $data)); // Convert new lines to LF
                $message = '<b>'.$f.'</b> has been updated';
                if (isset($_POST['c'])) {
                    $message .= '<br /><br />';
                    if ($ps) {
                        switch ($ps) {
                            case "nginx":
                                $message .= nl2br(shell_exec("service nginx reload; echo 'Done.';"));
                                break;
                            /*
                            case "apache":
                                $message .= strip_tags(nl2br(shell_exec("/scripts/restartsrv_httpd")));
                                break;
                            */
                            case "mysql":
                                $message .= nl2br(shell_exec("rm -rvf /var/lib/mysql/ib_logfile*; touch /var/lib/mysql/mysql.sock; touch /var/lib/mysql/mysql.pid; chown -R mysql:mysql /var/lib/mysql; /scripts/restartsrv_mysql"));
                                break;
                            case "cron":
                                $message .= nl2br(shell_exec("service crond restart"));
                                break;
                        }
                    }
                }
            }
        } else {
            $message = '';
        }
        break;

    case "nginx_status":
        $ret = "<b>Nginx Status:</b><br /><br />";
        $ret .= shell_exec("service nginx status 2>&1")."<br />";
        $ret .= shell_exec("curl http://localhost/nginx_status");
        break;

    case "nginx_reload":
        $ret = "<b>Reloading Nginx...</b><br />";
        $ret .= shell_exec("service nginx reload; echo 'Done.';");
        break;

    case "nginx_restart":
        $ret = "<b>Restarting Nginx...</b><br />";
        $ret .= shell_exec("service nginx restart; echo 'Done.';");
        break;

    case "nginx_forcerestart":
        $ret = "<b>Force restarting Nginx...</b><br />";
        $ret .= shell_exec("killall -9 nginx; killall -9 nginx; killall -9 nginx; service nginx restart; echo 'Done.';");
        break;

    case "nginx_config":
        $ret = "<b>Checking Nginx configuration...</b><br />";
        if (version_compare(OS_RELEASE, '7', '>=')) {
            $ret .= shell_exec("nginx -t 2>&1");
        } else {
            $ret .= shell_exec("service nginx configtest 2>&1");
        }
        break;

    case "nginx_errorlog":
        if (empty($_POST['access_entries'])) {
            $entries = 100;
        } else {
            $entries = (int) $_POST['access_entries'];
        }
        $ret = "<b>Showing last {$entries} entries from /var/log/nginx/error.log</b><br /><br />";
        $ret .= strip_tags(shell_exec("tail -{$entries} /var/log/nginx/error.log"));
        break;

    case "nginx_accesslog":
        if (empty($_POST['error_entries'])) {
            $entries = 100;
        } else {
            $entries = (int) $_POST['error_entries'];
        }
        $ret = "<b>Showing last {$entries} entries from /var/log/nginx/access.log</b><br /><br />";
        $ret .= strip_tags(shell_exec("tail -{$entries} /var/log/nginx/access.log"));
        break;

    case "nginx_modules":
        $ret = "<b>Show precompiled Nginx modules...</b><br /><br />";
        $ret .= shell_exec("nginx -V 2>&1");
        break;

    case "nginx_purgelogs":
        $ret = strip_tags(shell_exec("bash /opt/engintron/engintron.sh purgelogs"));
        break;

    case "nginx_purgecache":
        $ret = strip_tags(shell_exec("bash /opt/engintron/engintron.sh purgecache"));
        break;

    case "httpd_status":
        $ret = "<b>Apache Status:</b><br />";
        if (version_compare(OS_RELEASE, '7', '>=')) {
            $ret .= shell_exec("systemctl status httpd");
        } else {
            $ret .= shell_exec("service httpd status");
        }
        break;

    case "httpd_restart":
        $ret = "<b>Restarting Apache...</b><br />";
        $ret .= strip_tags(shell_exec("/scripts/restartsrv_httpd"));
        break;

    case "httpd_reload":
        $ret = "<b>Reloading Apache...</b><br />";
        $ret .= shell_exec("service httpd reload");
        $ret .= "Reloading Apache: [  OK  ]";
        break;

    case "httpd_config":
        $ret = "<b>Check configuration for errors...</b><br />";
        if (version_compare(OS_RELEASE, '7', '>=')) {
            $ret .= shell_exec("apachectl -t 2>&1");
        } else {
            $ret .= shell_exec("service httpd -t 2>&1");
        }
        break;

    case "httpd_modules_compiled":
        $ret = "<b>Show compiled modules...</b><br />";
        if (version_compare(OS_RELEASE, '7', '>=')) {
            $ret .= shell_exec("apachectl -l");
        } else {
            $ret .= shell_exec("service httpd -l");
        }
        break;

    case "httpd_modules_loaded":
        $ret = "<b>Show loaded modules...</b><br />";
        if (version_compare(OS_RELEASE, '7', '>=')) {
            $ret .= shell_exec("apachectl -M");
        } else {
            $ret .= shell_exec("service httpd -M");
        }
        break;

    case "httpd_parsed_settings":
        $ret = "<b>Show parsed settings...</b><br />";
        if (version_compare(OS_RELEASE, '7', '>=')) {
            $ret .= shell_exec("apachectl -S");
        } else {
            $ret .= shell_exec("service httpd -S");
        }
        break;

    case "httpd_restoreipfwd":
        $ret = "<b>Restore Nginx IP forwarding in Apache...</b><br />";
        $ret .= strip_tags(shell_exec("bash /opt/engintron/engintron.sh restoreipfwd"));
        break;

    case "mysql_restart":
        $ret = "<b>Restarting database...</b><br />";
        $ret .= shell_exec("/scripts/restartsrv_mysql");
        break;

    case "mysql_status":
        $ret = "<b>Database Status:</b><br />";
        if (exec("service mysqld status; echo \$?")) {
            $ret .= shell_exec("service mysql status");
        } else {
            $ret .= shell_exec("service mysqld status");
        }
        break;

    case "utils_mt":
        $ret = shell_exec("bash /opt/engintron/engintron.sh mt")."<br /><br />";
        break;

    case "utils_ip":
        $ret = shell_exec("bash /opt/engintron/engintron.sh ip")."<br /><br />";
        break;

    case "utils_80":
        $ret = shell_exec("bash /opt/engintron/engintron.sh 80")."<br /><br />";
        break;

    case "utils_443":
        $ret = shell_exec("bash /opt/engintron/engintron.sh 443")."<br /><br />";
        break;

    case "utils_80_443":
        $ret = shell_exec("bash /opt/engintron/engintron.sh 80-443")."<br /><br />";
        break;

    case "utils_pstree":
        $ret = "<b>$ pstree</b><br /><br />";
        $ret .= shell_exec("pstree");
        break;

    case "utils_top":
        $ret = "<b>$ top -b -n 1</b><br /><br />";
        $ret .= shell_exec("top -b -n 1");
        break;

    case "utils_top_php":
        $ret = "<b>$ top -b -n 1 | grep php | sort -k8,8</b><br /><br />";
        $ret .= shell_exec("top -b -n 1 | grep php | sort -k8,8");
        break;

    case "engintron_toggle":
        if (ENGINTRON_STATE=="on") {
            $ret = strip_tags(shell_exec("bash /opt/engintron/engintron.sh disable"));
        } elseif (ENGINTRON_STATE=="off") {
            $ret = strip_tags(shell_exec("bash /opt/engintron/engintron.sh enable"));
        } else {
            $ret = "Couldn't get state of Engintron - please try again.";
        }
        break;

    case "engintron_update":
    case "engintron_update_stable":
        $ret = strip_tags(shell_exec("bash /opt/engintron/engintron.sh install"), "<br><span>");
        break;

    case "engintron_update_mainline":
        $ret = strip_tags(shell_exec("bash /opt/engintron/engintron.sh install mainline"), "<br><span>");
        break;

    case "engintron_res":
        $ret = strip_tags(shell_exec("bash /opt/engintron/engintron.sh res 2>&1"));
        break;

    case "engintron_res_force":
        $ret = strip_tags(shell_exec("bash /opt/engintron/engintron.sh res force 2>&1"));
        break;

    case "engintron_resall":
        $ret = strip_tags(shell_exec("bash /opt/engintron/engintron.sh resall 2>&1"));
        break;

    case "utils_info":
    default:
        if (ENGINTRON_STATE=="on") {
            $ret = "<b class=\"green ngStatus\">*** Engintron is ENABLED ***</b><i class=\"ngSep\">########################################</i>";
        } elseif (ENGINTRON_STATE=="off") {
            $ret = "<b class=\"ngStatus\">*** Engintron is DISABLED ***</b><i class=\"ngSep\">########################################</i>";
        } else {
            $ret = "*** Couldn't get state of Engintron - please try again. ***<i class=\"ngSep\">########################################</i>";
        }
        $ret .= "<b class=\"green\">*** System Info ***</b><br /><br />";
        $ret .= "<b>Uptime:</b> ";
        $ret .= trim(shell_exec("uptime"))."<br /><br />";
        $ret .= "<b>OS:</b> ";
        $ret .= trim(shell_exec("cat /etc/redhat-release"))."<br /><br />";
        $ret .= "<b>Kernel:</b> ";
        $ret .= trim(shell_exec("uname -a"))."<br /><br />";
        $ret .= "<b>Processors:</b> ";
        $ret .= trim(shell_exec("grep processor /proc/cpuinfo | wc -l"))." CPU(s)<br /><br />";
        $ret .= "<b>RAM:</b> ";
        $ret .= round(trim(shell_exec("grep MemTotal /proc/meminfo | awk '{print $2}'")/(1024*1024)), 2)." GB<br /><br />";
        $ret .= "<b>Memory Usage:</b><br />";
        $ret .= shell_exec("free -mh")."<br />";
        $ret .= "<b>Disk Usage:</b><br />";
        $ret .= trim(shell_exec("df -hT"))."<br /><br />";
        $ret .= "<b>Nginx Cache/Temp Disk Usage:</b><br />";
        $ret .= trim(shell_exec("du -sh /var/cache/nginx/engintron_*"))."<br /><br />";
        $ret .= "<b>System Time:</b> ";
        $ret .= trim(shell_exec("date"))."<br /><br />";
        $ret .= "<b>System Users Connected:</b><br />";
        $ret .= trim(shell_exec("w"))."<br /><br />";
}

// UI string changes based on app state
if (ENGINTRON_STATE!="missing") {
    if ($state=="on") {
        $ng_state_toggler = "off";
        $ng_lang_state_toggler = "Disable";
    } elseif ($state=="off") {
        $ng_state_toggler = "on";
        $ng_lang_state_toggler = "Enable";
    } else {
        if (ENGINTRON_STATE=="on") {
            $ng_state_toggler = "off";
            $ng_lang_state_toggler = "Disable";
        } else {
            $ng_state_toggler = "on";
            $ng_lang_state_toggler = "Enable";
        }
    }
}

$head_includes = '
    <!-- Engintron [start] -->
    <link rel="stylesheet" type="text/css" href="https://fonts.googleapis.com/css?family=Montserrat:400,700|Source+Code+Pro:400,700&display=swap" />
    <style type="text/css">
        #sidebar {position:relative;background:#eaeaea;border-right:1px solid #d0d0d0;} /* Fix cPanel sidebar layer stacking */
        #sidebar .commandContainer {background:#eaeaea;}
        #survey-tab {display:none;}
        #contentContainer {padding:0 !important;}

        #ngContainer {margin:0;padding:0;display:grid;grid-template-columns:360px auto;}
            #ngContainer a {color:#08c;text-decoration:none;}
            #ngContainer a:hover {text-decoration:underline;}
            #ngContainer p {margin:0 0 15px 0;}
            #ngContainer input[type=submit] {padding:8px;border:0;font-size:13px;border-radius:4px;cursor:pointer;color:#fff;background-color:#179541;background-image:-webkit-gradient(linear, left top, left bottom, from(#179541), to(#007f2a));background-image:-webkit-linear-gradient(top, #179541, #007f2a);background-image:-moz-linear-gradient(top, #179541, #007f2a);background-image:-o-linear-gradient(top, #179541, #007f2a);background-image:linear-gradient(to bottom, #179541, #007f2a);-webkit-transition:all 500ms cubic-bezier(0.000, 0.685, 0.205, 0.995);-moz-transition:all 500ms cubic-bezier(0.000, 0.685, 0.205, 0.995);-ms-transition:all 500ms cubic-bezier(0.000, 0.685, 0.205, 0.995);-o-transition:all 500ms cubic-bezier(0.000, 0.685, 0.205, 0.995);transition:all 500ms cubic-bezier(0.000, 0.685, 0.205, 0.995);}
            #ngContainer .clr {clear:both;display:block;height:0;line-height:0;padding:0;margin:0;}
            #ngContainer .ngViewDefault {font-size:11px;}
            #ngContainer hr {line-height:0;height:0;border:none;border-bottom:1px solid #d0d0d0;padding:0;margin:8px 0;}
            h1#ngTitle {margin:0 0 15px;padding:0;text-align:center;}
            h1#ngTitle a {background:url(\'https://engintron.com/app/images/v1.1/engintron_logo.svg\') no-repeat 50% 50%;background-size:auto 80px;padding:0;margin:0 auto;width:100%;max-width:340px;height:90px;display:block;position:relative;text-decoration:none;}
            h1#ngTitle a span {position:absolute;display:block;bottom:5px;left:0;right:0;text-align:right;font-size:14px;color:#333;}
            h2 {border-bottom:2px solid #eaeaea;padding:5px 0;margin:0 0 10px 0;text-transform:uppercase;font-family:\'Montserrat\',sans-serif;font-weight:700;font-size:24px;color:#008d23;}
            #ngContainer #ngMenuTrigger {display:none;}
            #ngOperations {background:#fafafa;padding:15px;}
            #ngOperations ul li h3 span,
            #ngOperations ul li ul li span {display:inline-block;font-size:11px;font-weight:normal;color:#999;margin:0 0 0 5px;padding:0;}
            #ngOperations ul li ul li span a {color:#999;}
            #ngOperations ul {padding:0;margin:0;list-style:none;}
            #ngOperations ul li {padding:1px 0;}
            #ngOperations ul li h3 {padding:0;margin:0 0 4px 0;font-weight:bold;}
            #ngOperations ul li h3::before {content:"~";margin:0 5px 0 0;}
            #ngOperations ul li ul {padding:0;margin:0 0 15px 0;list-style:none;}
            #ngOperations ul li ul li {padding:5px 10px;margin:1px 0;}
            #ngOperations ul li ul li:hover {border-radius:5px;background:#eaeaea;}
            #ngOperations ul li ul li:hover a {color:#008d23;}
            #ngOperations ul li ul li a {color:#333;font-size:13px;}
            #ngOperations ul li ul li a:hover {color:#008d23;text-decoration:none;}
            #ngOperations ul li ul li.active {border-radius:10px;background:#008d23;padding:10px;}
            #ngOperations ul li ul li.active a {color:#fff;}
            #ngOperations ul li ul li.active span,
            #ngOperations ul li ul li.active span a {color:#eee;}
            #ngOperations ul li form.displayLogs a:hover {text-decoration:none;}
            #ngOperations ul li form.displayLogs input {border:none;border-bottom:1px solid #008d23;text-align:center;color:#008d23;font-size:13px;padding:1px 5px;}
            #ngOperations ul li.active form.displayLogs input {font-weight:bold;}
            #ngOperations ul li.ngUpdate span {font-size:11px;font-weight:normal;font-style:italic;color:#999;display:none;}
            #ngOutput {background:#fff;padding:15px;height:calc(100vh - 120px);position:sticky;top:0;}
                #ngOutput h2 {border:0;margin:0;padding:0 0 10px 0;}
                #ngTerminalWindow {text-align:left;width:100%;border-radius:10px;margin:0 auto;}
                #ngTerminalWindow header {background:#eaeaea;height:30px;border-radius:8px 8px 0 0;padding:0 10px;margin:0;text-align:center;}
                    #ngTerminalWindow header .button {width:12px;height:12px;margin:10px 6px 0 0;border-radius:8px;float:left;}
                    #ngTerminalWindow header .button.green {background:#3BB662;}
                    #ngTerminalWindow header .button.yellow {background:#E5C30F;}
                    #ngTerminalWindow header .button.red {background:#E75448;}
                    #ngTerminalWindow header span {line-height:30px;display:block;width:100px;margin:0 auto;}
                #ngOutputWindow {padding:0;margin:0 auto;}
                #ngOutputWindow pre {font-family:\'Source Code Pro\',monospace;font-size:12px;white-space:pre-wrap;color:#fff;background:#000;padding:8px;margin:0;overflow:auto;border:0;border-radius:0;height:calc(100vh - 202px);}
                    #ngOutputWindow pre b {color:red;}
                    #ngOutputWindow pre b.green,
                    #ngOutputWindow pre span {color:green;}
                    #ngOutputWindow pre b.ngStatus {font-size:18px;}
                    #ngOutputWindow pre i.ngSep {color:#aaa;font-size:12px;display:block;padding:0;margin:20px 0;}
                #ngOutputWindow #ngSeriously {text-align:center;padding:40px;background:#000;}
                #ngOutputWindow #ngSeriously h3 {color:#fff;font-size:40px;padding:20px 0 0;margin:0 auto;}
                    body.op_edit #ngOutputWindow {border:1px solid #d0d0d0;border-top:0;padding:0;margin:0;}
                #ngAceEditor {box-sizing:border-box;border:none;width:100%;padding:8px;margin:0;font-family:\'Source Code Pro\',monospace;font-size:12px;overflow:auto;color:#fff;background:#000;outline:0;height:calc(100vh - 250px);}
                #ngOutput form#fileEditor textarea#data {display:none;}
                #ngOutput form#fileEditor .editbox {background:#fafafa;padding:8px;margin:-3px 0 0 0;display:grid;grid-template-columns:3fr 2fr;grid-gap:10px;align-items:center;}
                #ngOutput form#fileEditor .editbox input[type=checkbox] {margin:0 5px 0 0;display:inline-block;vertical-align:middle;}
                #ngOutput form#fileEditor .editbox div small {display:block;font-size:11px;font-weight:normal;color:#999;margin:0 0 0 20px;}
                #ngOutput form#fileEditor .editbox .action {text-align:right;}
        #ngAbout {padding:15px;margin:0;}
            #ngAboutSections {display:grid;grid-template-columns:1fr 1fr;grid-gap:15px;}
                a#twitterLink {background:#1d9bf0;color:#fff;padding:5px 10px;margin:0 15px 0 0;border-radius:5px;font-weight:bold;font-size:12px;line-height:12px;display:inline-block;vertical-align:middle;text-decoration:none;}
                a#twitterLink:hover {background:#0c7abf;}
                a#cpAppsLink {background:#f26b32;color:#fff;padding:5px 10px;margin:0;border-radius:5px;font-weight:bold;font-size:12px;line-height:12px;display:inline-block;vertical-align:middle;text-decoration:none;}
                a#cpAppsLink:hover {background:#e34806;}
                a#twitterLink svg,
                a#cpAppsLink svg {display:inline-block;vertical-align:-4px;}
                p#ngSocialIcons a {color:#333;text-decoration:none;margin:0 20px 0 0;display:inline-block;vertical-align:middle;line-height:20px;}
                p#ngSocialIcons a:hover {}
                p#ngSocialIcons a svg {fill:#333;display:inline-block;vertical-align:middle;}
                p#ngSocialIcons a:hover svg {fill:#08c;}
                p#ngSocialIcons a svg.cpanel {vertical-align:-2px;}
                p#commercialSupport b {}
        #ngFooter {text-align:center;border-top:1px solid #d0d0d0;background:#eaeaea;padding:12px;margin:0;}
            #ngFooter p {margin:0;padding:0;font-size:12px;color:#666;}
            #ngFooter a {color:#333;font-weight:bold;text-decoration:none;}
            #ngFooter a:hover {text-decoration:underline;}
        #ngMessage {position:fixed;z-index:9999;top:136px;right:24px;background:#fff;font-size:12px;line-height:12px;text-align:center;margin:0;padding:16px;border-radius:4px;box-shadow:0 1px 4px 0 #999;}
            #ngMessage .ngMsgState {width:16px;height:16px;margin:0 10px 0 0;padding:0;display:inline-block;background:#5fca4a;vertical-align:text-top;}
        .hidden {opacity:0;transition:opacity 2s linear;}
        @media only screen and (max-width:800px) {
            #ngContainer,
            #ngAboutSections,
            #ngOutput form#fileEditor .editbox {grid-template-columns:1fr;}
            #ngOutput {height:auto;position:static;}
            #ngOutputWindow pre,
            #ngAceEditor {height:400px;}
            #ngOutput form#fileEditor .editbox div,
            #ngOutput form#fileEditor .editbox .action {text-align:center;}
            #ngOutput form#fileEditor .editbox div small {margin:0;}
            #ngOperations {position:relative;}
            #ngContainer #ngMenuTrigger {display:block;font-size:18px;text-decoration:none;}
            #ngContainer #ngMenuTrigger span {color:#333;}
            .ngOn svg,
            .ngOff svg {vertical-align:-6px;}
            .ngOff {display:none;}
            #ngMenuTarget {display:none;position:absolute;top:145px;left:0;right:0;padding:15px;z-index:100001;background:#fafafa;}
        }
    </style>
    <!-- Engintron [finish] -->
';

$body_class = 'op_'.$op;

$output_find = array(
    '<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />',
    '</head>',
    '<body class="">'
);

$output_replace = array(
    '<meta charset="utf-8" />',
    $head_includes.'</head>',
    '<body class="'.$body_class.'">'
);

// Output WHM Header
//echo str_replace($output_find, $output_replace, WHM::getHeaderString('Engintron for cPanel/WHM', 1, 1));
ob_start();
WHM::header('Engintron for cPanel/WHM', 1, 1);
$output = ob_get_contents();
ob_end_clean();
echo str_replace($output_find, $output_replace, $output);

?>

    <!-- Engintron [start] -->
    <div id="ngContainer">
        <div id="ngOperations">
            <h1 id="ngTitle">
                <a href="engintron.php" title="<?php echo PLG_NAME; ?>"><span>v<?php echo PLG_VERSION; ?></span></a>
            </h1>
            <a id="ngMenuTrigger" href="#ngMenuTarget">
                <span class="ngOn">
                    <svg role="img" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" aria-labelledby="hamburgerIconTitle" stroke="#231f20" stroke-width="1" stroke-linecap="square" stroke-linejoin="miter" fill="none" color="#231f20"><title id="hamburgerIconTitle">Menu</title><path d="M6 7L18 7M6 12L18 12M6 17L18 17"/></svg>
                    <b>MENU</b>
                </span>
                <span class="ngOff">
                    <svg role="img" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" aria-labelledby="closeIconTitle" stroke="#231f20" stroke-width="1" stroke-linecap="square" stroke-linejoin="miter" fill="none" color="#231f20"><title id="closeIconTitle">Close</title><path d="M6.34314575 6.34314575L17.6568542 17.6568542M6.34314575 17.6568542L17.6568542 6.34314575"/></svg>
                    <b>Close</b>
                </span>
            </a>
            <div id="ngMenuTarget">
                <h2>Operations</h2>
                <ul>
                    <li>
                        <h3>System</h3>
                        <ul>
                            <li><a href="engintron.php">System Status &amp; Info</a></li>
                            <li><a href="engintron.php?op=engintron_res">Restart Apache &amp; Nginx</a></li>
                            <li><a href="engintron.php?op=engintron_res_force">Restart Apache &amp; force restart Nginx</a></li>
                            <li><a href="engintron.php?op=engintron_resall">Restart all essential services</a></li>
                        </ul>
                    </li>
                    <li>
                        <h3>Nginx <span>(v<?php echo NGINX_VERSION; ?>)</span></h3>
                        <ul>
                            <li><a href="engintron.php?op=nginx_status">Status</a></li>
                            <li><a href="engintron.php?op=nginx_reload">Reload</a></li>
                            <li><a href="engintron.php?op=nginx_restart">Restart</a></li>
                            <li><a href="engintron.php?op=nginx_forcerestart">Force Restart</a></li>
                            <li><a href="engintron.php?op=edit&f=/etc/nginx/custom_rules&s=nginx">Edit your custom_rules for Nginx</a><?php if (file_exists('/etc/nginx/custom_rules.dist')): ?><span>(<a class="ngViewDefault" href="engintron.php?op=view&f=/etc/nginx/custom_rules.dist">view default</a>)</span><?php endif; ?></li>
                            <li><a href="engintron.php?op=edit&f=/etc/nginx/conf.d/default.conf&s=nginx">Edit default.conf</a></li>
                            <li><a href="engintron.php?op=edit&f=/etc/nginx/proxy_params_common&s=nginx">Edit proxy_params_common</a></li>
                            <li><a href="engintron.php?op=edit&f=/etc/nginx/proxy_params_dynamic&s=nginx">Edit proxy_params_dynamic</a></li>
                            <li><a href="engintron.php?op=edit&f=/etc/nginx/proxy_params_static&s=nginx">Edit proxy_params_static</a></li>
                            <li><a href="engintron.php?op=edit&f=/etc/nginx/common_http.conf&s=nginx">Edit common_http.conf</a></li>
                            <li><a href="engintron.php?op=edit&f=/etc/nginx/common_https.conf&s=nginx">Edit common_https.conf</a></li>
                            <li><a href="engintron.php?op=edit&f=/etc/nginx/nginx.conf&s=nginx">Edit nginx.conf</a></li>
                            <li><a href="engintron.php?op=nginx_config">Check configuration for errors</a></li>
                            <li><a href="engintron.php?op=nginx_modules">Show compiled modules</a></li>
                            <li>
                                <form action="engintron.php?op=nginx_accesslog" method="post" id="accesslog" class="displayLogs">
                                    <a href="engintron.php?op=nginx_accesslog" onClick="ngSaveFile('accesslog')">Show last</a> <input type="text" name="access_entries" size="4" value="100" autocomplete="off" /> <a href="engintron.php?op=nginx_accesslog" onClick="ngSaveFile('accesslog')">access log entries</a>
                                </form>
                            </li>
                            <li>
                                <form action="engintron.php?op=nginx_errorlog" method="post" id="errorlog" class="displayLogs">
                                    <a href="engintron.php?op=nginx_errorlog" onClick="ngSaveFile('errorlog')">Show last</a> <input type="text" name="error_entries" size="4" value="100" autocomplete="off" /> <a href="engintron.php?op=nginx_errorlog" onClick="ngSaveFile('errorlog')">error log entries</a>
                                </form>
                            </li>
                            <li><a href="engintron.php?op=nginx_purgelogs">Purge access &amp; error log files</a></li>
                            <li><a href="engintron.php?op=nginx_purgecache">Purge cache &amp; temp files</a></li>
                        </ul>
                    </li>
                    <li>
                        <h3>Apache</h3>
                        <ul>
                            <li><a href="engintron.php?op=httpd_status">Status</a></li>
                            <li><a href="engintron.php?op=httpd_reload">Reload</a></li>
                            <li><a href="engintron.php?op=httpd_restart">Restart</a></li>
                            <li><a href="engintron.php?op=httpd_config">Check configuration for errors</a></li>
                            <li><a href="engintron.php?op=httpd_modules_compiled">Show compiled modules</a></li>
                            <li><a href="engintron.php?op=httpd_modules_loaded">Show loaded modules</a></li>
                            <li><a href="engintron.php?op=httpd_parsed_settings">Show parsed settings</a></li>
                            <li><a href="engintron.php?op=httpd_restoreipfwd">Restore Nginx IP forwarding in Apache</a></li>
                        </ul>
                    </li>
                    <li>
                        <h3>Database<span>(MySQL or MariaDB)</span></h3>
                        <ul>
                            <li><a href="engintron.php?op=mysql_status">Status</a></li>
                            <li><a href="engintron.php?op=mysql_restart">Restart</a></li>
                            <li><a href="engintron.php?op=edit&f=/etc/my.cnf&s=mysql">Edit my.cnf</a></li>
                            <li><a href="engintron.php?op=utils_mt">MySQL Tuner<span>(DB diagnostics)</span></a></li>
                        </ul>
                    </li>
                    <li>
                        <h3>System Configuration</h3>
                        <ul>
                            <li><a href="engintron.php?op=edit&f=/etc/crontab&s=cron">Edit /etc/crontab</a></li>
                        </ul>
                    </li>
                    <li>
                        <h3>Utilities</h3>
                        <ul>
                            <li><a href="engintron.php?op=utils_top">Show all processes (top)</a></li>
                            <li><a href="engintron.php?op=utils_top_php">Show top PHP processes</a></li>
                            <li><a href="engintron.php?op=utils_pstree">Show current process tree</a></li>
                            <li><a href="engintron.php?op=utils_ip">Server IP report</a></li>
                            <li><a href="engintron.php?op=utils_80">Current connections on port 80 (per IP &amp; total)</a></li>
                            <li><a href="engintron.php?op=utils_443">Current connections on port 443 (per IP &amp; total)</a></li>
                            <li><a href="engintron.php?op=utils_80_443">Total connections on ports 80 &amp; 443</a></li>
                        </ul>
                    </li>
                    <li>
                        <h3>Engintron<span>(v<?php echo PLG_VERSION; ?>)</span></h3>
                        <ul>
                            <li><a href="engintron.php?op=engintron_toggle&state=<?php echo $ng_state_toggler; ?>"><?php echo $ng_lang_state_toggler; ?> Engintron</a></li>
                            <li id="ngUpdateStable" class="ngUpdate">
                                <a href="engintron.php?op=engintron_update_stable">Update (or re-install) Engintron [with Nginx "stable"]</a>
                                <span>[please wait a few minutes...]</span>
                            </li>
                            <li id="ngUpdateMainline" class="ngUpdate">
                                <a href="engintron.php?op=engintron_update_mainline">Update (or re-install) Engintron [with Nginx "mainline"]</a>
                                <span>[please wait a few minutes...]</span>
                            </li>
                        </ul>
                    </li>
                </ul>
            </div>
        </div>
        <div id="ngOutput">
            <h2>&gt; Output</h2>
            <div id="ngTerminalWindow">
              <header>
                <div class="button green"></div>
                <div class="button yellow"></div>
                <div class="button red"></div>
                <span>$ engintron</span>
              </header>
              <div id="ngOutputWindow">
                <?php if ($ret): ?>
                <pre><?php echo $ret; ?></pre>
                <?php endif; ?>
                <?php if ($op=='edit'): ?>
                <?php if (isset($f) && in_array($f, $allowed_files)): ?>
                <form action="engintron.php?op=edit&f=<?php echo $f; ?><?php echo ($s) ? '&s='.$s : ''; ?>" method="post" id="fileEditor">
                    <div id="ngAceEditor"></div>
                    <textarea id="data" name="data"><?php echo file_get_contents($f); ?></textarea>
                    <div class="editbox">
                        <div class="check">
                            <input type="checkbox" name="c" checked /> Reload or restart related services (<?php echo ($ps) ? ucfirst($ps) : ucfirst($s); ?>)?
                            <small>(recommended if you want changes to take effect immediately)</small>
                        </div>
                        <div class="action">
                            <input type="submit" value="Update <?php echo $f; ?>" onClick="ngSaveFile('fileEditor')" />
                        </div>
                        <input type="hidden" name="s" value="<?php echo $s; ?>" />
                    </div>
                </form>
                <?php else: ?>
                <div id="ngSeriously">
                    <img src="https://engintron.com/app/images/galifianakis_santa.gif" alt="Seriously?" />
                    <h3>Seriously?</h3>
                </div>
                <?php endif; ?>
                <?php endif; ?>
                </div>
            </div>
        </div>
    </div>

    <div id="ngAbout">
        <h2>About</h2>
        <div id="ngAboutSections">
            <div>
                <p><a rel="noopener" target="_blank" href="https://engintron.com/"><?php echo PLG_NAME; ?></a> integrates the popular <a rel="noopener" target="_blank" href="https://nginx.org/">Nginx</a><sup>&reg;</sup> web server as a "reverse caching proxy" in front of Apache in cPanel<sup>&reg;</sup>.</p>
                <p>Nginx will cache &amp; serve static assets like CSS, JavaScript, images etc. as well as dynamic HTML with a 1 second micro-cache. This process will reduce CPU &amp; RAM usage on your server, while increasing your overall serving capacity. The result is a faster performing cPanel server.</p>
                <p>Engintron is both free &amp; open source.</p>
            </div>
            <div>
                <p><a rel="noopener" target="_blank" href="https://github.com/engintron/engintron/issues">Report issues/bugs</a> or <a rel="noopener" target="_blank" href="https://github.com/engintron/engintron/pulls">help us improve it</a>.</p>
                <p class="ngSocialSharing">
                    <a rel="noopener" target="_blank" aria-label="Twitter" href="https://twitter.com/intent/tweet/?text=Just%20installed%20%40engintron%20for%20cPanel%2FWHM%20to%20improve%20my%20%23cPanel%20server%27s%20performance&amp;url=https://engintron.com" id="twitterLink" class="ngPopup"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor"><path d="M5.026 15c6.038 0 9.341-5.003 9.341-9.334 0-.14 0-.282-.006-.422A6.685 6.685 0 0 0 16 3.542a6.658 6.658 0 0 1-1.889.518 3.301 3.301 0 0 0 1.447-1.817 6.533 6.533 0 0 1-2.087.793A3.286 3.286 0 0 0 7.875 6.03a9.325 9.325 0 0 1-6.767-3.429 3.289 3.289 0 0 0 1.018 4.382A3.323 3.323 0 0 1 .64 6.575v.045a3.288 3.288 0 0 0 2.632 3.218 3.203 3.203 0 0 1-.865.115 3.23 3.23 0 0 1-.614-.057 3.283 3.283 0 0 0 3.067 2.277A6.588 6.588 0 0 1 .78 13.58a6.32 6.32 0 0 1-.78-.045A9.344 9.344 0 0 0 5.026 15z"/></svg> Tweet #Engintron</a>
                    <a rel="noopener" target="_blank" aria-label="cPanel Apps" href="https://applications.cpanel.com/listings/view/Engintron-Nginx-on-cPanel" id="cpAppsLink"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 358 240" class="cpanel"><path d="m89.69 59.1h67.8l-10.49 40.2a25.38 25.38 0 0 1 -9 13.5 24.32 24.32 0 0 1 -15.3 5.1h-31.51a30.53 30.53 0 0 0 -19 6.3 33 33 0 0 0 -11.55 17.1 31.91 31.91 0 0 0 -.45 15.3 33.1 33.1 0 0 0 5.81 12.75 30.29 30.29 0 0 0 10.8 8.85 31.74 31.74 0 0 0 14.4 3.3h19.2a10.8 10.8 0 0 1 8.85 4.35 10.4 10.4 0 0 1 2 9.75l-12 44.4h-21a84.77 84.77 0 0 1 -39.75-9.45 89.78 89.78 0 0 1 -30.21-25.05 88.4 88.4 0 0 1 -16.35-35.5 87.51 87.51 0 0 1 1.06-41l1.2-4.5a88.69 88.69 0 0 1 31.64-47.25 89.91 89.91 0 0 1 25-13.35 87 87 0 0 1 28.85-4.8z"/><path d="m123.89 240 59.11-221.4a25.38 25.38 0 0 1 9-13.5 24.28 24.28 0 0 1 15.29-5.1h62.71a84.8 84.8 0 0 1 39.75 9.45 89.21 89.21 0 0 1 46.65 60.6 83.8 83.8 0 0 1 -1.2 41l-1.2 4.5a89.88 89.88 0 0 1 -12 26.55 87.65 87.65 0 0 1 -73.2 39.15h-54.3l10.8-40.5a25.38 25.38 0 0 1 9-13.2 24.32 24.32 0 0 1 15.3-5.1h17.4a31.56 31.56 0 0 0 30.6-23.7 29.5 29.5 0 0 0 .4-14.75 33.1 33.1 0 0 0 -5.85-12.75 31.85 31.85 0 0 0 -10.8-9 30.61 30.61 0 0 0 -14.35-3.45h-33.6l-43.8 162.9a25.38 25.38 0 0 1 -9 13.2 23.88 23.88 0 0 1 -15 5.1z"/></svg> Rate on cPApps</a>
                </p>
                <p id="ngSocialIcons">
                    <a rel="noopener" target="_blank" href="https://engintron.com/"><svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor"><path d="M0 8a8 8 0 1 1 16 0A8 8 0 0 1 0 8zm7.5-6.923c-.67.204-1.335.82-1.887 1.855-.143.268-.276.56-.395.872.705.157 1.472.257 2.282.287V1.077zM4.249 3.539c.142-.384.304-.744.481-1.078a6.7 6.7 0 0 1 .597-.933A7.01 7.01 0 0 0 3.051 3.05c.362.184.763.349 1.198.49zM3.509 7.5c.036-1.07.188-2.087.436-3.008a9.124 9.124 0 0 1-1.565-.667A6.964 6.964 0 0 0 1.018 7.5h2.49zm1.4-2.741a12.344 12.344 0 0 0-.4 2.741H7.5V5.091c-.91-.03-1.783-.145-2.591-.332zM8.5 5.09V7.5h2.99a12.342 12.342 0 0 0-.399-2.741c-.808.187-1.681.301-2.591.332zM4.51 8.5c.035.987.176 1.914.399 2.741A13.612 13.612 0 0 1 7.5 10.91V8.5H4.51zm3.99 0v2.409c.91.03 1.783.145 2.591.332.223-.827.364-1.754.4-2.741H8.5zm-3.282 3.696c.12.312.252.604.395.872.552 1.035 1.218 1.65 1.887 1.855V11.91c-.81.03-1.577.13-2.282.287zm.11 2.276a6.696 6.696 0 0 1-.598-.933 8.853 8.853 0 0 1-.481-1.079 8.38 8.38 0 0 0-1.198.49 7.01 7.01 0 0 0 2.276 1.522zm-1.383-2.964A13.36 13.36 0 0 1 3.508 8.5h-2.49a6.963 6.963 0 0 0 1.362 3.675c.47-.258.995-.482 1.565-.667zm6.728 2.964a7.009 7.009 0 0 0 2.275-1.521 8.376 8.376 0 0 0-1.197-.49 8.853 8.853 0 0 1-.481 1.078 6.688 6.688 0 0 1-.597.933zM8.5 11.909v3.014c.67-.204 1.335-.82 1.887-1.855.143-.268.276-.56.395-.872A12.63 12.63 0 0 0 8.5 11.91zm3.555-.401c.57.185 1.095.409 1.565.667A6.963 6.963 0 0 0 14.982 8.5h-2.49a13.36 13.36 0 0 1-.437 3.008zM14.982 7.5a6.963 6.963 0 0 0-1.362-3.675c-.47.258-.995.482-1.565.667.248.92.4 1.938.437 3.008h2.49zM11.27 2.461c.177.334.339.694.482 1.078a8.368 8.368 0 0 0 1.196-.49 7.01 7.01 0 0 0-2.275-1.52c.218.283.418.597.597.932zm-.488 1.343a7.765 7.765 0 0 0-.395-.872C9.835 1.897 9.17 1.282 8.5 1.077V4.09c.81-.03 1.577-.13 2.282-.287z"/></svg></a>
                    <a rel="noopener" target="_blank" href="https://github.com/engintron/engintron"><svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.012 8.012 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg></a>
                    <a rel="noopener" target="_blank" href="https://www.facebook.com/engintron"><svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor"><path d="M16 8.049c0-4.446-3.582-8.05-8-8.05C3.58 0-.002 3.603-.002 8.05c0 4.017 2.926 7.347 6.75 7.951v-5.625h-2.03V8.05H6.75V6.275c0-2.017 1.195-3.131 3.022-3.131.876 0 1.791.157 1.791.157v1.98h-1.009c-.993 0-1.303.621-1.303 1.258v1.51h2.218l-.354 2.326H9.25V16c3.824-.604 6.75-3.934 6.75-7.951z"/></svg></a>
                    <a rel="noopener" target="_blank" href="https://twitter.com/engintron"><svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor"><path d="M5.026 15c6.038 0 9.341-5.003 9.341-9.334 0-.14 0-.282-.006-.422A6.685 6.685 0 0 0 16 3.542a6.658 6.658 0 0 1-1.889.518 3.301 3.301 0 0 0 1.447-1.817 6.533 6.533 0 0 1-2.087.793A3.286 3.286 0 0 0 7.875 6.03a9.325 9.325 0 0 1-6.767-3.429 3.289 3.289 0 0 0 1.018 4.382A3.323 3.323 0 0 1 .64 6.575v.045a3.288 3.288 0 0 0 2.632 3.218 3.203 3.203 0 0 1-.865.115 3.23 3.23 0 0 1-.614-.057 3.283 3.283 0 0 0 3.067 2.277A6.588 6.588 0 0 1 .78 13.58a6.32 6.32 0 0 1-.78-.045A9.344 9.344 0 0 0 5.026 15z"/></svg></a>
                    <a rel="noopener" target="_blank" href="https://tinyletter.com/engintron"><svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor"><path d="M0 2.5A1.5 1.5 0 0 1 1.5 1h11A1.5 1.5 0 0 1 14 2.5v10.528c0 .3-.05.654-.238.972h.738a.5.5 0 0 0 .5-.5v-9a.5.5 0 0 1 1 0v9a1.5 1.5 0 0 1-1.5 1.5H1.497A1.497 1.497 0 0 1 0 13.5v-11zM12 14c.37 0 .654-.211.853-.441.092-.106.147-.279.147-.531V2.5a.5.5 0 0 0-.5-.5h-11a.5.5 0 0 0-.5.5v11c0 .278.223.5.497.5H12z"/><path d="M2 3h10v2H2V3zm0 3h4v3H2V6zm0 4h4v1H2v-1zm0 2h4v1H2v-1zm5-6h2v1H7V6zm3 0h2v1h-2V6zM7 8h2v1H7V8zm3 0h2v1h-2V8zm-3 2h2v1H7v-1zm3 0h2v1h-2v-1zm-3 2h2v1H7v-1zm3 0h2v1h-2v-1z"/></svg></a>
                    <a rel="noopener" target="_blank" href="https://applications.cpanel.com/listings/view/Engintron-Nginx-on-cPanel"><svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" viewBox="0 0 358 240" class="cpanel"><path d="m89.69 59.1h67.8l-10.49 40.2a25.38 25.38 0 0 1 -9 13.5 24.32 24.32 0 0 1 -15.3 5.1h-31.51a30.53 30.53 0 0 0 -19 6.3 33 33 0 0 0 -11.55 17.1 31.91 31.91 0 0 0 -.45 15.3 33.1 33.1 0 0 0 5.81 12.75 30.29 30.29 0 0 0 10.8 8.85 31.74 31.74 0 0 0 14.4 3.3h19.2a10.8 10.8 0 0 1 8.85 4.35 10.4 10.4 0 0 1 2 9.75l-12 44.4h-21a84.77 84.77 0 0 1 -39.75-9.45 89.78 89.78 0 0 1 -30.21-25.05 88.4 88.4 0 0 1 -16.35-35.5 87.51 87.51 0 0 1 1.06-41l1.2-4.5a88.69 88.69 0 0 1 31.64-47.25 89.91 89.91 0 0 1 25-13.35 87 87 0 0 1 28.85-4.8z"/><path d="m123.89 240 59.11-221.4a25.38 25.38 0 0 1 9-13.5 24.28 24.28 0 0 1 15.29-5.1h62.71a84.8 84.8 0 0 1 39.75 9.45 89.21 89.21 0 0 1 46.65 60.6 83.8 83.8 0 0 1 -1.2 41l-1.2 4.5a89.88 89.88 0 0 1 -12 26.55 87.65 87.65 0 0 1 -73.2 39.15h-54.3l10.8-40.5a25.38 25.38 0 0 1 9-13.2 24.32 24.32 0 0 1 15.3-5.1h17.4a31.56 31.56 0 0 0 30.6-23.7 29.5 29.5 0 0 0 .4-14.75 33.1 33.1 0 0 0 -5.85-12.75 31.85 31.85 0 0 0 -10.8-9 30.61 30.61 0 0 0 -14.35-3.45h-33.6l-43.8 162.9a25.38 25.38 0 0 1 -9 13.2 23.88 23.88 0 0 1 -15 5.1z"/></svg></a>
                    <a rel="noopener" target="_blank" href="https://github.com/engintron/engintron#commercial-support--server-optimization-services"><svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor"><path d="M.05 3.555A2 2 0 0 1 2 2h12a2 2 0 0 1 1.95 1.555L8 8.414.05 3.555zM0 4.697v7.104l5.803-3.558L0 4.697zM6.761 8.83l-6.57 4.027A2 2 0 0 0 2 14h12a2 2 0 0 0 1.808-1.144l-6.57-4.027L8 9.586l-1.239-.757zm3.436-.586L16 11.801V4.697l-5.803 3.546z"/></svg></a>
                </p>
                <p id="commercialSupport"><b>Looking for commercial support?</b> <a rel="noopener" target="_blank" href="https://github.com/engintron/engintron#commercial-support--server-optimization-services">Get in touch with us</a>.</p>
            </div>
        </div>
    </div>

    <div id="ngFooter">
        <p><a rel="noopener" target="_blank" href="https://engintron.com/"><?php echo PLG_NAME; ?> - v<?php echo PLG_VERSION; ?></a> (<?php echo PLG_BUILD; ?>) | Copyright &copy; 2014 - <?php echo date('Y'); ?> <a rel="noopener" target="_blank" href="https://kodeka.io/">Kodeka OÜ.</a> Released under the <a rel="noopener" target="_blank" href="https://www.gnu.org/licenses/gpl.html">GNU/GPL</a> license.</p>
    </div>
    <?php if ($message): ?>
    <div id="ngMessage"><div class="ngMsgState"></div><?php echo $message; ?></div>
    <?php endif; ?>

    <!-- JS -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.4.13/ace.js"></script>
    <script>

        // Fix cPanel UI issues
        document.addEventListener('DOMContentLoaded', function() {
            var sidebarMenu = document.querySelectorAll('ul#mainCommand li.category');
            if (sidebarMenu.length) {
                sidebarMenu.forEach(function(el) {
                    el.className = 'category collapsed';
                    if (el.id == 'Plugins') {
                        el.className = 'category expanded';
                        el.querySelector('#PluginsContent li[searchtext*="Engintron"]').className = 'highlighted activePage';
                    }
                });
            }
            if (document.querySelector('#cp-analytics-whm')) {
                document.querySelector('#cp-analytics-whm').remove();
            }
        });

        // Ace
        if (document.getElementById('ngAceEditor')) {
            var editor = ace.edit('ngAceEditor');
            editor.$blockScrolling = Infinity;
            editor.setTheme('ace/theme/twilight');
            editor.getSession().setMode('ace/mode/sh');
            editor.getSession().setUseWrapMode(true);
            editor.resize();
            var t = document.getElementById('data');
            var tVal = t.value;
            editor.getSession().setValue(tVal);
            editor.getSession().on('change', function() {
                t.value = editor.getSession().getValue();
            });
        }

        // Engintron
        var ENGINTRON_VERSION = '<?php echo PLG_VERSION; ?>';
        var CENTOS_VERSION = '<?php echo OS_RELEASE; ?>';
        var OS_RELEASE = '<?php echo OS_RELEASE; ?>';

        function ngSaveFile(el) {
            document.getElementById(el).submit();
            return false;
        }
        function ngUpdate(el) {
            var updContainer = document.getElementById(el);
            if (updContainer) {
                var updLink = updContainer.getElementsByTagName('a')[0];
                updLink.onclick = function() {
                    updContainer.getElementsByTagName('span')[0].setAttribute('style', 'display:inline;');
                    if (this.className != 'clicked') {
                        this.className = 'clicked';
                        return true;
                    } else {
                        return false;
                    }
                };
            }
        }
        function ngUtils() {
            // Highlight menu
            var i = 0,
                menuItems = document.getElementById('ngOperations').getElementsByTagName('a');
            for(; i < menuItems.length; ++i) {
                if (window.location.href === menuItems[i].href) {
                    if (menuItems[i].parentNode.nodeName.toLowerCase() == 'form') {
                        menuItems[i].parentNode.parentNode.className = 'active';
                    } else {
                        menuItems[i].parentNode.className = 'active';
                    }
                }
            }
            // Disable the update/re-install links when clicked
            ngUpdate('ngUpdateStable');
            ngUpdate('ngUpdateMainline');
            // Hide message after 3 seconds
            var ngMsgContainer = document.getElementById('ngMessage');
            if (ngMsgContainer) {
                setTimeout(function() {
                    ngMsgContainer.className += 'hidden';
                    setTimeout(function() {
                        ngMsgContainer.parentNode.removeChild(ngMsgContainer);
                    }, 3000);
                }, 3000);
            }
        }
        ngUtils();

        // Toggler
        function ngToggler(trigger, target, bodyClass) {
            const srcBodyClass = document.body.className;
            // The trigger should wrap 2 elements with .on & .off classes
            document.querySelector(trigger).onclick = function(e) {
                var ta = document.querySelector(target),
                    trOn = this.querySelector('.ngOn'),
                    trOff = this.querySelector('.ngOff');
                ta.style.display = (ta.style.display == '' || ta.style.display == 'none') ? 'block' : 'none';
                if (bodyClass) {
                    if (ta.style.display == 'block') {
                        document.body.className += ' ' + bodyClass;
                    } else {
                        document.body.className = srcBodyClass;
                    }
                }
                if (trOn && trOff) {
                    if (trOn.style.display == '' || trOn.style.display == 'block') {
                        trOn.style.display = 'none';
                        trOff.style.display = 'block';
                    } else {
                        trOn.style.display = 'block';
                        trOff.style.display = 'none';
                    }
                }
                e.preventDefault();
            };
        }
        ngToggler('#ngMenuTrigger', '#ngMenuTarget');

        // Social Sharing
        function classicPopup(url) {
            var left = (screen.width - 720) / 2;
            var top = (screen.height - 620) / 4;
            popupWindow = window.open(url, 'popUpWindow', 'width=720,height=620,left=' + left + ',top=' + top + ',resizable=yes,scrollbars=yes,toolbar=yes,menubar=no,location=no,directories=no,status=yes');
            popupWindow.focus();
        }
        if (document.querySelectorAll('.ngSocialSharing').length) {
            document.querySelectorAll('.ngSocialSharing a[href^="http"].ngPopup').forEach(function(l) {
                l.onclick = function(e) {
                    e.preventDefault();
                    classicPopup(this.getAttribute('href'));
                };
            });
        }

    </script>
    <script src="https://engintron.com/app/js/services.js?t=<?php echo date('Ymd'); ?>"></script>
    <script>(function(i,s,o,g,r,a,m) {i['GoogleAnalyticsObject'] = r;i[r] = i[r] || function() {(i[r].q = i[r].q || []).push(arguments)},i[r].l = 1 * new Date();a = s.createElement(o),m = s.getElementsByTagName(o)[0];a.async = 1;a.src = g;m.parentNode.insertBefore(a,m)})(window,document,'script','//www.google-analytics.com/analytics.js','ga');ga('create','UA-16375363-18','auto');ga('send','pageview','/engintron_whm_app');</script>
    <script type="text/javascript" >(function(m,e,t,r,i,k,a){m[i]=m[i]||function(){(m[i].a=m[i].a||[]).push(arguments)};m[i].l=1*new Date();k=e.createElement(t),a=e.getElementsByTagName(t)[0],k.async=1,k.src=r,a.parentNode.insertBefore(k,a)})(window,document,"script","https://cdn.jsdelivr.net/npm/yandex-metrica-watch/tag.js","ym");ym(87045362,"init",{clickmap:false,trackLinks:true,accurateTrackBounce:false});</script><noscript><img src="https://mc.yandex.ru/watch/87045362" style="position:absolute;left:-9999px;" alt="" /></noscript>
    <!-- Engintron [finish] -->

<?php

// WHM Footer
WHM::footer();
