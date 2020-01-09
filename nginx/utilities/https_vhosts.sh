#!/bin/bash

# /**
#  * @version    1.12.0
#  * @package    Engintron for cPanel/WHM
#  * @author     Fotis Evangelou (https://kodeka.io)
#  * @url        https://engintron.com
#  * @copyright  Copyright (c) 2018 - 2020 Kodeka OÜ. All rights reserved.
#  * @license    GNU/GPL license: https://www.gnu.org/copyleft/gpl.html
#  */

INTERVAL="15" # Interval in seconds, must not exceed 60 (seconds)
COUNTER="0"

function generate_https_vhosts {
    if [ -f /etc/nginx/utilities/https_vhosts.php ]; then
        RUN_CHECK=$(/usr/local/cpanel/3rdparty/bin/php -c /dev/null -q /etc/nginx/utilities/https_vhosts.php; echo $?)
        if [[ $RUN_CHECK == 1 ]]; then
            #bash /usr/local/src/engintron/engintron.sh purgecache > /etc/nginx/utilities/https_vhosts.log
            bash /usr/local/src/engintron/engintron.sh reload > /etc/nginx/utilities/https_vhosts.log
        fi
    fi
}

while [ $COUNTER -lt 60 ]; do
    generate_https_vhosts
    sleep $INTERVAL
    COUNTER=$[$COUNTER+$INTERVAL]
done

exit 0
