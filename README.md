![Engintron](http://engintron.com/assets/logo/Engintron_Logo_316x98_24_black.png) **(v1.0.3)**
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
Engintron is (currently) not designed for resellers using cPanel. It's designed for agencies, freelancers or individuals that use and manage cPanel on their own, for their or their customers' needs. As such, there is one simple rule for running Engintron on any cPanel based server: whenever a domain is added, modified or deleted on the server via cPanel/WHM, you need to execute "virtual host" synchronization. In other words, you need to manually "tell" Nginx that new domains have been added and allow it to reconfigure for these new domains. This can be done very easily from the Engintron dashboard, under WHM (it's in the "Plugins" section). Just click "Sync Nginx with Apache vhosts" in there and Nginx will be reconfigured for any domain changes on your server.

![Engintron Backend](http://engintron.com/assets/screenshots/1.0.2_backend.png)

Alternatively, you can do this over SSH or via a cron. Assuming engintron.sh resides at the very root path of your server, just do this:

$ sh engintron.sh sync  


==
### cPanel Quick Configuration for Optimal Usage
Engintron will make your cPanel based server fly, but it's important to have cPanel properly configured already.

Here are some basic configuration steps after you get a fresh cPanel server ready for you:

- Set the server time under: Home » Server Configuration » Server Time
- Disable all statistics under: Home » Server Configuration » Statistics Software Configuration
- Set this if it's not already setup by your hosting company: Home » Networking Setup » Resolver Configuration
- Disable unneeded services (e.g. DNS or mail services or spamd)
- Enable shell fork bomb protection under: Home » Security Center » Shell Fork Bomb Protection
- Enable: Home » Security Center » cPHulk Brute Force Protection - make sure to whitelist the IPs through which you'll be logging into your server as root
- Install CSF (an IPTables frontend and more) and make sure port 8081 is open. More info at: http://www.configserver.com/free/csf/install.txt
- Update MySQL under Software » MySQL Upgrade
- Install this EasyApache build https://raw.githubusercontent.com/nuevvo/engintron/master/engintron.dtd under Software » EasyApache (Apache Update) - make sure to select FCGI in the PHP Handler option (if it's not already selected)
- Symlink for APC (run as root):  
     $ ln -s /usr/local/lib/php/extensions/no-debug-non-zts-20100525 /usr/lib/php/extensions/no-debug-non-zts-20100525
- Install APC under Software » Module Installers » PHP Pecl (manage) - search for APC and install it. The previous symlink you set will allow APC to function properly (I still wonder why cPanel hasn't solved this bug in ages!)
- Setup your user accounts and domains in cPanel/WHM
- Install Engintron and enjoy!


==
### Performance Notes
We have run various tests on various server configurations. Here's a typical test on a 2GB RAM VPS server running cPanel (Apache 2.2, FastCGI, APC enabled, MySQL query caching on) hosting a single Joomla! 3.x website (default installation).

Using Apache Benchmark (AB), we run the following test: $ ab -c 50 -n 5000 -k http://url/to/site

Apache 2.2 is able to handle 53.21 requests per second.

Because Nginx works in reverse caching proxy mode, when Engintron is installed, the results are simply stunning: 9086.38 requests per second - **that's 2000 times more serving capacity compared to Apache**!

If you run a busy site on a cPanel server, you can use the same AB test and see for yourself what you can gain from using Engintron.


==
### Roadmap - What next?
The next update of Engintron (v2) will feature a massively overhauled design. One that will possibly make Engintron your cPanel dashboard page.
![Engintron v2](http://i.imgur.com/8C5wfqk.png)

And I'll make every effort to include the following features:
- A way to automatically sync Apache with Nginx vhosts when a new domain is added in cPanel (ideal for resellers)
- A way to disable Nginx entirely on select domains (by way of adding an identifier file or an entry in .htaccess)
- "Smarter" caching for user generated content in the frontend
- Apply automated MySQL optimisations based on system CPU & RAM
- More handy tools to be added: cleanup Apache logs and other un-needed directories in order to free up space in your /usr partition - a common problem for cPanel users
- A small frontend monitoring mini-dashboard for your server, entirely independent from WHM.
- Distribute alternatively as a cPanel plugin
- Paid support for Engintron (geared for professionals and hosting companies)


==
### Feedback, bugs, feature requests
Please post your feedback and any issues or feature requests/suggestions in the project's issue tracker at:

https://github.com/nuevvo/engintron/issues


==
### CHANGELOG
**May 30th, 2014 - v1.0.3**
- Fixed compatibility with Munin, added Nginx tracking in Munin
- Enabled access logs for domains, but static file logging is disabled for performance reasons
- Switched default Nginx worker process to "auto" (aka CPU/core support), so it won't be required to be set manually
- Obsolete vhosts are now cleaned up whenever the sync process is performed
- Added some default Nginx files after setup in case they are not created during Nginx's installation
- Added default.conf vhost during installation


==
### License
Engintron is released under the GNU/GPL license. For more info, have a look here: http://www.gnu.org/copyleft/gpl.html


==
### More info
A proper website will be up soon, featuring short tutorials and videos, a forum and a commercial support channel.

The current backend in WHM is also under redesign.

More at: http://engintron.com


==
Copyright &copy; 2010-2014 [Nuevvo Webware P.C.](http://nuevvo.com)
