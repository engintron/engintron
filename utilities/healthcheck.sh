#!/bin/bash

# /**
#  * @version    2.6
#  * @package    Engintron for cPanel/WHM
#  * @author     Fotis Evangelou (https://kodeka.io)
#  * @url        https://engintron.com
#  * @copyright  Copyright (c) 2014 - 2024 Kodeka OÜ. All rights reserved.
#  * @license    GNU/GPL license: https://www.gnu.org/copyleft/gpl.html
#  */

########################################################################
#
# === Basic Usage ===
# $ cd /opt/engintron/utilities/
# $ chmod +x healthcheck.sh
# $ ./healthcheck.sh "https://domain.tld"
#
# === Cron Example ===
# Check health (uptime) for domain.tld (make the script executable first)
# */3 * * * * root /opt/engintron/utilities/healthcheck.sh "https://domain.tld" > /dev/null 2>&1
#
# === If you don't get emails when a restart occurs ===
# $ yum install mailx
#
########################################################################



# BASIC CONFIGURATION
EMAIL_TO="alerts@domain.tld" # Email address to receive alerts when a health check fails
TIME_TO_WAIT_IN_SECONDS=20   # Time for curl to wait for a response
FORCE_RESTART_NGINX="no"     # Default: "no" - Set to "yes" to force-restart Nginx by killing all previous Nginx processes



########################################################################
################### Nothing to change below this line ##################
########################################################################

# Constants
DOMAIN=$1
URL=$1/?timestamp=$(date +'%Y%m%d_%H%M%S')
HOSTNAME=$(hostname -f)
NOW=$(date +'%Y.%m.%d at %H:%M:%S')
RESPONSE=$(curl -s -o /dev/null -m $TIME_TO_WAIT_IN_SECONDS -w "Responded with status code %{http_code} after %{time_total} seconds" $URL)

if [[ $RESPONSE == "Responded with status code 200"* ]] || [[ $RESPONSE == "Responded with status code 30"* ]]; then
    echo $RESPONSE
    echo "Site requested at URL $URL is online"
else
    echo $RESPONSE
    echo "Site requested at URL $URL is down!"

    if [ -f /opt/engintron/engintron.sh ]; then
        # Restart services
        if [[ $FORCE_RESTART_NGINX == "yes" ]]; then
            /opt/engintron/engintron.sh res force
        else
            /opt/engintron/engintron.sh res
        fi

        # Send email
        mail -s "$(echo -e "Apache & Nginx on $HOSTNAME restarted\nContent-Type: text/html")" "$EMAIL_TO" <<EOF
<!DOCTYPE html>
<html>
    <head>
        <meta charset="utf-8">
        <title>Apache &amp; Nginx on $HOSTNAME restarted</title>
    </head>
    <body style="margin:0;padding:0;background:#eee;font-size:14px;color:#333;">
        <div id="container" style="width:80%;margin:20px auto;padding:20px;background:#fff;">
            <h1>Apache &amp; Nginx on $HOSTNAME restarted</h1>
            <p>The domain <b>$DOMAIN</b> did not respond within $TIME_TO_WAIT_IN_SECONDS seconds when requested through:</p>
            <pre>$URL</pre>
            <p>Apache &amp; Nginx running on server $HOSTNAME were restarted on $NOW.</p>
        </div>
        <div style="font-size:12px;color:#999;text-align:center;margin-bottom:20px;">powered by <a href="https://engintron.com">Engintron for cPanel/WHM</a></div>
    </body>
</html>
EOF
    fi
fi

exit 0
