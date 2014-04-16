![Engintron](http://engintron.com/assets/logo/Engintron_Logo_316x98_24_black.png)
***

##Engintron is Nginx on cPanel

Nginx® is a powerful open source web server that was built to scale websites to millions of visitors. cPanel® is the leading hosting control panel worldwide.

Engintron integrates Nginx into cPanel so you can enjoy amazing performance for your sites, without having to sacrifice important hosting features found in cPanel or hiring a sysadmin.

First release features include: Nginx setup in reverse caching proxy (web acceleration) mode for any static or PHP based website, automated Nginx updates, amazingly simple dashboard to control Nginx, Apache, MySQL and PHP related day-to-day tasks in cPanel.

**And best of all? Engintron is totally free to use!**


==
### Install Engintron
Login as root user in your server using an SSH connection and execute the following commands:

$ cd /  
$ wget https://raw.githubusercontent.com/nuevvo/engintron/master/engintron.sh  
$ sh engintron.sh install  


==
### Uninstall Engintron
Login as root user in your server using an SSH connection and execute the following commands:

$ cd /  
$ sh engintron.sh remove  


==
### Using Engintron
Engintron is not designed for resellers using cPanel. It's designed for agencies, freelancers or individuals that use and manage cPanel on their own, for their or their customers' needs. As such, there is one simple rule for running Engintron on any cPanel based server: whenever a domain is added, modified or deleted on the server via cPanel/WHM, you need to execute virtual host synchronization. In other words, you need to manually "tell" Nginx that new domains have been added and allow it to reconfigure for these new domains. This can be done very easily from the Engintron dashboard, under WHM (it's in the "Plugins" section). Just click "Sync Nginx with Apache vhosts" in there and Nginx will be reconfigured for any domain changes on your server.

Alternatively, you can do this over SSH or via a cron. Assuming engintron.sh resides at the very root path of your server, just do this:

$ sh engintron.sh sync  


==
### More info
A proper website will be up soon, featuring short tutorials and videos, a forum and a commercial support channel.

More at: http://engintron.com


==
Copyright &copy; 2010-2014 [Nuevvo Webware P.C.](http://nuevvo.com)
