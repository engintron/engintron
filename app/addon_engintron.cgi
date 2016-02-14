#!/usr/local/cpanel/3rdparty/bin/perl
#WHMADDON:engintron:Engintron for cPanel/WHM

# /**
#  * @version		1.6.0
#  * @package		Engintron for cPanel/WHM
#  * @author    	Fotis Evangelou
#  * @url			https://engintron.com
#  * @copyright		Copyright (c) 2010 - 2016 Nuevvo Webware P.C. All rights reserved.
#  * @license		GNU/GPL license: http://www.gnu.org/copyleft/gpl.html
#  */

use lib '/usr/local/cpanel';
use Cpanel::cPanelFunctions ();
use Cpanel::Form ();
use Cpanel::Config ();
use Whostmgr::HTMLInterface ();
use Whostmgr::ACLS ();

print "Content-type: text/html\r\n\r\n";
BEGIN {
	 push(@INC,"/usr/local/cpanel");
	 push(@INC,"/usr/local/cpanel/whostmgr/docroot/cgi");
}
use whmlib;
require 'parseform.pl';
Whostmgr::ACLS::init_acls();
if ( !Whostmgr::ACLS::hasroot() ) {
	print "You do not have sufficient permissions to access this page...\n";
	exit();
}
print "<meta http-equiv=\"refresh\" content=\"0;url=engintron.php\" />";
1;
