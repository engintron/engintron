Engintron Changelog
===================

## 1.6.1 - Feb 19th, 2016

*   Engintron will now (be default) modify Apache's log format to allow for the proper inclusion of a visitor's IP in all systems. The change is merged with Apache's configuration so it's protected if Apache settings are modified via WHM. If you uninstall Engintron, Apache's log format is reverted to its previous state.

## 1.6.0 - Feb 14th, 2016

*   Introducing new "custom_rules" file (fully editable from within WHM) for you to store any custom Nginx rules or redirects. These include custom setup for CloudFlare or for certain domains. The only thing you need to edit to apply any rules from now on is "custom_rules" and that's why upon updates, we keep a copy of that file and display it within WHM so you can easily copy/paste your custom Nginx rules before the update to the new "custom_rules" file being installed. We could simply keep that file for you, but breaking changes may be introduced so it's always good to be able to keep up to date.
*   CloudFlare integration is now easier than ever. All you have to do is set your shared or any dedicated IPs. We also include some handy redirect rules for CloudFlare, for HTTP to HTTPS. Just uncomment whatever you want to use.
*   Introducing version update checker. If you already have v1.5.3, you'll see the first update notice when you visit Engintron in WHM. Upgrading is as simple as clicking a link in the app.

## 1.5.3 - Feb 12th, 2016

*   Micro-caching is now enabled by default. Extensive tests have shown that there are no issues caused when micro-caching is enabled. In fact, performance is exponentially increased when micro-caching is on, which is the reason why Engintron now ships with this option on.
*   Improvements to the installer - if any of the Apache modules (RPAF or RemoteIP) fail to install, we just skip that part without causing Apache to stop working because of missing .so files.
*   Increased default timeouts in nginx.conf to minimize 504 errors from slow backends.
*   Added a more reliable way to restart Nginx if another Nginx plugin for cPanel was previously uninstalled leaving Nginx still binding to port 80.

## 1.5.2 - Feb 7th, 2016

*   Added CentOS 7 support (installer worked fine since 1.5.0, however a few controls in the WHM app did not output the correct messages)
*   Added option to update or re-install Engintron from within WHM, via the Engintron app under "Plugins"

## 1.5.1 - Feb 6th, 2016

*   General installer/uninstaller improvements
*   Improved compatibility with CentOS 5
*   Added option to enable/disable Engintron without completely uninstalling it. You can control Engintron's state through the WHM app dashboard or via the terminal. Nginx switches to port 8080 and Apache switches to port 80 when you run "$ bash /engintron.sh disable". If you run "$ bash /engintron.sh enable" Nginx reclaims port 80 and Apache takes port 8080.
*   IPv6 support is now present but it has to be uncommented in order to work properly (in files /etc/nginx/nginx.conf for the resolver & /etc/nginx/conf.d/default.conf for the catch-all rule)
*   Improved help/instructions when executing engintron.sh via terminal
*   Added some terminal utilities like "restart Apache & Nginx", "restart all important services", "show server info", "show traffic on port 80" and more. From the terminal type "bash /engintron.sh" or just "/engintron.sh" if you have already installed Engintron.
*   Fixed /nginx_status page - info now also shown under "Nginx Status" option in the WHM app dashboard
*   Fixed /favicon.ico and /robots.txt loading - previously these files were blocked due to a mismatch in their respective definitions
*   Updated retrieval location for mod_rpaf to ensure proper installation on all CentOS releases

## 1.5.0 - Feb 1st, 2016

*   Complete re-write of the main installer script as well as the app dashboard
*   vhost sync'ing is no longer needed - you add new domains via cPanel and it just works
*   New, smarter, better proxying/caching approach - improves performance without the headaches of controlling exclusions for different CMSs - it just works
*   Proper client side caching for all types of content
*   Compatible with domains served via CloudFlare

## 1.0.4 Build 20141223 - Dec 23rd, 2014

*   Updated static asset loading from an HTTPS source

## 1.0.4 Build 20141203 - Dec 3rd, 2014

*   Since mod_rpaf was dropped from its original developer, it's now been updated with the fork that's been actively maintained here: https://github.com/gnif/mod_rpaf
*   Moved all static assets of the app dashboard onto GitHub's CDN. This simply results to a cleaner Engintron script.
*   Removed the line "proxy_hide_header Set-Cookie;" from proxy.conf as it was causing issues with WordPress websites not being properly cached (thank you @AgentGod)

## 1.0.3 - May 30th, 2014

*   Fixed compatibility with Munin, added Nginx tracking in Munin
*   Enabled access logs for domains, but static file logging is disabled for performance reasons
*   Switched default Nginx worker process to "auto" (aka CPU/core support), so it won't be required to be set manually
*   Obsolete vhosts are now cleaned up whenever the sync process is performed
*   Added some default Nginx files after setup in case they are not created during Nginx's installation
*   Added default.conf vhost during installation
