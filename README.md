![Engintron](http://engintron.com/assets/logo/Engintron_Logo_316x98_24_black.png) **(v1.5.0 - released Feb 1st, 2016)**
***

##Engintron is Nginx on cPanel

Nginx® is a powerful open source web server that was built to scale websites to millions of visitors. cPanel® is the leading hosting control panel worldwide.

Engintron integrates Nginx into cPanel so you can enjoy amazing performance for your sites, without having to sacrifice important hosting features found in cPanel.

Installation is easy and features include (among others): Nginx setup in reverse caching proxy mode for all static assets & optionally for dynamic content using a 1 second micro-cache, automated updates for Nginx using official repos, amazingly simple app dashboard in cPanel to control Nginx, Apache, MySQL and PHP configuration files and tasks & a few handy utilities for day-to-day sysadmin tasks.

**And best of all? Engintron is totally free to use!**


==
### Before you install Engintron
Please note that if you currently use EasyApache 4 in your cPanel server, Nginx will fail to install via Engintron. You must be using EasyApache 3 in order to proceed.


==
### Install Engintron
Login as root user in your server using an SSH connection and execute the following commands:

$ cd /  
$ wget https://raw.githubusercontent.com/nuevvo/engintron/master/engintron.sh  
$ bash engintron.sh install  


==
### Uninstall Engintron
Login as root user in your server using an SSH connection and execute the following commands:

$ cd /  
$ bash engintron.sh remove  


==
### Using Engintron
![Engintron Backend](http://engintron.com/assets/screenshots/1.5.0_20160106.png)
**PREFACE**

Unlike version 1.0.x of Engintron, the new 1.5.x version uses a different approach for proxying and caching, which now makes Engintron a perfect fit for any cPanel server - operated by freelancers, agencies or even large hosting companies. Engintron will now cache only static assets by default and if you wish to cache dynamic content as well (for further optimization), it uses the micro-caching concept to significantly boost a site's performance, even if it has user generated content that should not be cached.

By using a different proxying & caching strategy altogether, the previous use of vhost synchronization between Apache and Nginx is now unnecessary. You essentially set and forget Engintron. New domains added in cPanel will work just fine with Nginx and without restarting any service.

**DAY TO DAY TASKS**

After you install Engintron, you will notice it has enabled its own app dashboard in WHM, under the Plugins section. From now on you can fully operate Engintron & Nginx related tasks entirely from the Engintron app dashboard. And we have included controls for Apache, PHP & MySQL as well. The most important configuration files from these services can be directly edited via Engintron's app dashboard and you can even control the status of the 3 main services (Nginx, Apache, MySQL).

You can also check Nginx's main logs (access and error) and we have bundled a few tiny tools for common day-to-day sysadmin tasks, e.g. resource or HTTP traffic monitoring.

**TROUBLESHOOTING**

If something happens, the two Nginx logs are your first source of information. If you edit any of the default Nginx files and you're worried if things may "break", you can choose to save any of its configuration files without reloading Nginx and then run the option "Check configuration for errors" to verify if everything is OK.


==
### Performance Notes
**(pending update for v1.5.0)**
We have run various tests on various server configurations. Here's a typical test on a 2GB RAM VPS server running cPanel (Apache 2.2, FastCGI, APC enabled, MySQL query caching on) hosting a single Joomla! 3.x website (default installation).

Using Apache Benchmark (AB), we run the following test: $ ab -c 50 -n 5000 -k http://url/to/site

Apache 2.2 is able to handle 53.21 requests per second.

Because Nginx works in reverse caching proxy mode, when Engintron is installed, the results are simply stunning: 9086.38 requests per second - **that's 2000 times more serving capacity compared to Apache**!

If you run a busy site on a cPanel server, you can use the same AB test and see for yourself what you can gain from using Engintron.


==
### Why is Engintron a better solution compared to other Nginx installers for cPanel
There are 7 key differences when comparing Engintron with other Nginx installers for cPanel.

First, Engintron is a single shell script (weighing only a few KBs) that installs all required software (to make Nginx work as intended) from the official software package vendors' repositories. Both installation and updates are very fast (they take only a few seconds).

Second, since we're using the official repositories for Nginx, all Engintron software is updated whenever cPanel (or the server's software) is updated. So you essentially set it and forget it. Whenever you perform "yum update/upgrade" or upgrade the server software from within WHM, Nginx will be updated if a new release is available. If something is changed on Engintron and you need to re-install it, you simply install it on top of the previous installation. You don't need to uninstall it first!

Third, you can safely uninstall Engintron and it will revert your entire system to how it was before. That means you can try Engintron and if you don't like it or you find it doesn't fit your needs, you can simply uninstall it. Your system will revert to how it was before.

Fourth, it has a simple dashboard with some handy utilities that make Engintron your day-to-day dashboard for cPanel.

Fifth, it's CloudFlare friendly. Because both CloudFlare and Engintron use Nginx as reverse caching proxy, unless we properly configure Nginx in cPanel, the use of a secondary proxy (after CloudFlare) causes problems to CloudFlare. If you have domains that use CloudFlare, you can simply uncomment a few lines from "proxy_params_common" and restart Nginx for the changes to take effect. If additionally you use CloudFlare's SSL, by choosing "flexible SSL" in CloudFlare's dashboard you can direct HTTPS traffic to HTTP (=Nginx) thus further improving web serving over HTTPS as well.

Six, it doesn't require Nginx/Apache vhost synchronization when adding new domains via cPanel. That's why you essentially "set it and forget it". 'Nough said :)

And finally, Engintron is open source. You can tear it apart or contribute back to its development. You can fork it, knife it, do whatever you want with it. It's not a black box :)


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
- Install CSF (an IPTables frontend and more) and make sure ports 8080 & 8443 are open. More info at: http://www.configserver.com/free/csf/install.txt
- Update MySQL under Software » MySQL Upgrade
- Install this EasyApache build http://engintron.com/files/cpanel/engintron.dtd under Software » EasyApache (Apache Update) - make sure you select FCGI in the PHP Handler option (if it's not already selected) and definitely go for Apache 2.4.
- Install APC(u) by following this guide: http://www.joomlaworks.net/blog/item/153-install-apc-apcu-on-a-whm-cpanel-server (don't bother installing APC(u) via cPanel's PECL modules installer, it's just broken)
- Setup your user accounts and domains in cPanel/WHM
- Install Engintron and watch CPU & RAM usage drop!


==
### Roadmap - What next?
The next update of Engintron (v2) will feature a massively overhauled design. One that will possibly make Engintron your cPanel dashboard page.
![Engintron v2](http://i.imgur.com/8C5wfqk.png)

These are some of the features which I'm considering to add:
- SSL support for proxying, using either a shared SSL certificate or "Let's Encrypt" for issuing new (and free) SSL certificates
- Apply automated optimizations based on system CPU & RAM for MySQL, Apache and PHP
- Include more handy tools, e.g. cleanup Apache logs and other un-needed directories in order to free up space in your /usr partition - a common problem for cPanel users
- Make editing configurations easier by offloading option handling to the app dashboard via dedicated controls


==
### Feedback, bugs, feature requests & rating
Please post your feedback and any issues or feature requests/suggestions in the project's issue tracker at:

https://github.com/nuevvo/engintron/issues


If you use Engintron, please take a moment to post a review in the official cPanel Apps directory here:

https://applications.cpanel.com/listings/view/Engintron-Nginx-on-cPanel


==
### CHANGELOG
**Feb 1st, 2016 - v1.5.0**
- Complete re-write of the main installer script as well as the app dashboard
- vhost sync'ing is no longer needed - you add new domains via cPanel and it just works
- New, smarter, better proxying/caching approach - improves performance without the headaches of controlling exclusions for different CMSs - it just works
- Proper client side caching for all types of content
- Compatible with domains served via CloudFlare

**Dec 23rd, 2014 - v1.0.4 Build 20141223**
- Updated static asset loading from an HTTPS source

**Dec 3rd, 2014 - v1.0.4 Build 20141203**
- Since mod_rpaf was dropped from its original developer, it's now been updated with the fork that's been actively maintained here: https://github.com/gnif/mod_rpaf
- Moved all static assets of the app dashboard onto GitHub's CDN. This simply results to a cleaner Engintron script.
- Removed the line "proxy_hide_header Set-Cookie;" from proxy.conf as it was causing issues with WordPress websites not being properly cached (thank you @AgentGod)

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
### Sponsor
The development & testing cPanel server for Engintron is kindly sponsored by the awesome folks at EuroVPS: https://www.eurovps.com/


==
### More info
A proper website is on its way, featuring short tutorials and videos, a forum and a commercial support channel.

If however you require commercial support now, you can contact us via Engintron's app dashboard.

http://engintron.com


==
Copyright &copy; 2010-2016 [Nuevvo Webware P.C.](http://nuevvo.com)

![](https://ga-beacon.appspot.com/UA-16375363-18/engintron/github/readme?pixel)
