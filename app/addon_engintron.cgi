#!/usr/local/cpanel/3rdparty/bin/perl

# /**
#  * @version		1.6.1
#  * @package		Engintron for cPanel/WHM
#  * @author    	Fotis Evangelou
#  * @url			https://engintron.com
#  * @copyright		Copyright (c) 2010 - 2016 Nuevvo Webware P.C. All rights reserved.
#  * @license		GNU/GPL license: http://www.gnu.org/copyleft/gpl.html
#  */

#WHMADDON:engintron:Engintron for cPanel/WHM
#ACLS:all

use Whostmgr::ACLS ();
Whostmgr::ACLS::init_acls();

if ( !Whostmgr::ACLS::hasroot() ) {
    print "Content-type: text/html\r\n\r\n";
    print "Access Denied: You do not have permission to view this page.\n";
    exit;
}

print "Location: engintron.php\r\n\r\n";
