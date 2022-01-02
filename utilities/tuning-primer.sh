#!/bin/bash

# vim: sw=2:et
#########################################################################
#                                                                       #
#       MySQL performance tuning primer script                          #
#       Writen by: Matthew Montgomery and Dan Reif                      #
#       Report bugs to: https://github.com/BMDan/tuning-primer.sh/issues#
#       Inspired by: MySQLARd (http://gert.sos.be/demo/mysqlar/)        #
#       Version: 1.99           Released: 2018-06-10                    #
#       Licenced under GPLv2                                            #
#                                                                       #
#########################################################################

#########################################################################
#                                                                       #
#       Usage: ./tuning-primer.sh [ mode ]                              #
#                                                                       #
#       Available Modes:                                                #
#               all :           perform all checks (default)            #
#               prompt :        prompt for login credentials and socket #
#                               and execution mode                      #
#               mem, memory :   run checks for tunable options which    #
#                               affect memory usage                     #
#               disk, file :    run checks for options which affect     #
#                               i/o performance or file handle limits   #
#               innodb :        run InnoDB checks /* to be improved */  #
#               misc :          run checks that don't fit categories    #
#                               well Slow Queries, Binary logs,         #
#                               Used Connections and Worker Threads     #
#########################################################################
#                                                                       #
# Set this socket variable ONLY if you have multiple instances running  #
# or we are unable to find your socket, and you don't want to to be     #
# prompted for input each time you run this script.                     #
#                                                                       #
#########################################################################
socket=

function colorize() {
  # As an explicit special case, "" yields sgr0 (i.e., black).
  local originalcolor="${1}"
  local basecolor="${originalcolor}"

  basecolor="${basecolor#bold}"
  basecolor="${basecolor#so}"

  case "$basecolor" in
    'red')
      tput setaf 1 ;;
    'green')
      tput setaf 2 ;;
    'yellow')
      tput setaf 3 ;;
    'blue')
      tput setaf 4 ;;
    'magenta')
      tput setaf 5 ;;
    'cyan')
      tput setaf 6 ;;
    'white')
      tput setaf 7 ;;
    *) # Also "black":
      [ "$basecolor" != "black" ] && [ -n "$basecolor" ] && echo "No such color '$basecolor'." >&2
      tput sgr0 ;;
  esac

  # bold, etc.
  if [ "$basecolor" != "$originalcolor" ]; then
    case $originalcolor in
      bold*)
        tput bold ;;
      so*)
        tput smso ;;
      *)
        echo "No such color modifier '${originalcolor%$basecolor}'." >&2 ;;
    esac
  fi
}

function cecho()
{
  if [ -z "${1-}" ]; then
    cecho "No message passed." "${2-}"
    return $?
  fi
  cechon "$1"$'\n' "${2-}"
  return $?
}

function cechon()
{
## -- Function to easily print colored text -- ##

        # Color-echo.
        # Argument $1 = message
        # Argument $2 = color
  local default_msg="No message passed."

  message=${1:-$default_msg}    # Defaults to default message.

  #change it for fun
  #We use pure names
  color=${2:-black}             # Defaults to black, if not specified.

  colorize "$color"
  printf "%s"  "$message"
  colorize ""                   # Reset to normal.

return
}

function write_mycnf() {
  # $1: Path to .my.cnf
  # $2: Path to socket (optional)
  # $3: username
  # $4: password
  local socketcomment=""
  [ -z "$2" ] && socketcomment="#"
  cat > "${1}" <<EOF
[client]
${socketcomment}socket=$2
user=$3
password=$4
EOF
}

function print_banner()
{
  cecho " -- MYSQL PERFORMANCE TUNING PRIMER --" boldblue
  cecho "      - By: Matthew Montgomery -" black
}

## -- Find the location of the mysql.sock file -- ##
function check_for_socket()
{
  if [ -n "$socket" ] && [ ! -S "$socket" ]; then
    # If you specify a socket but that socket doesn't exist, we exit.
    cecho "No valid socket file at '$socket'!" boldred
    cecho "You've explicitly specified a socket location, but that location either" red
    cecho "doesn't exist, or isn't a socket." red
    exit 1
  fi

  # Otherwise, try to find the socket.  Failure is now OK; we can always
  # try another way to connect.
  if [ -z "$socket" ] ; then
    # Use ~/.my.cnf version
    if [ -f ~/.my.cnf ] ; then
      # Use the last one we find in the file.  We could be smarter here and
      # parse section headers and so forth, but meh.
      cnf_socket="$(awk -F '=' '$1 == "socket" { s=$2 } END { print s }' ~/.my.cnf)"
    fi

    if [ -S "$cnf_socket" ] ; then
      socket=$cnf_socket
    elif [ -S /var/lib/mysql/mysql.sock ] ; then
      socket=/var/lib/mysql/mysql.sock
    elif [ -S /var/run/mysqld/mysqld.sock ] ; then
      socket=/var/run/mysqld/mysqld.sock
    elif [ -S /tmp/mysql.sock ] ; then
      socket=/tmp/mysql.sock
    else
      if [ -S "$ps_socket" ] ; then
      socket=$ps_socket
      fi
    fi
  fi

  if [ -S "$socket" ] ; then
    export MYSQL_COMMAND="${MYSQL_COMMAND} -S ${socket}"
    return 0
  fi

  return 1
}


check_for_plesk_passwords () {

## -- Check for the existance of plesk and login using its credentials -- ##

  if [ -f /etc/psa/.psa.shadow ] ; then
    MYSQL_COMMAND="mysql -S $socket -u admin -p$(cat /etc/psa/.psa.shadow)"
    MYSQLADMIN_COMMAND="mysqladmin -S $socket -u admin -p$(cat /etc/psa/.psa.shadow)"
  fi
}

check_mysql_login () {

## -- Try just connecting (i.e., via .my.cnf defaults, in practice) -- ##

  local is_up=$($MYSQLADMIN_COMMAND ping 2>&1)
  local print_defaults=$($MYSQLADMIN_COMMAND --print-defaults 2>/dev/null)

  if [ "$is_up" = "mysqld is alive" ]; then
    if [ "${print_defaults//*--host=*}" = "" ] &&
     ! [ "${print_defaults//*--host=127\.0\.0\.1*}" = "" ] &&
     ! [ "${print_defaults//*--host=::1*}" = "" ] &&
     ! [ "${print_defaults//*--host=localhost*}" = "" ]; then
      cecho "WARNING: you might be connecting to a remote server.  If so, some" boldred
      cecho "results may be based on incorrect assumptions.  See #13 on Github." boldred
    fi
    return 0
  fi
  printf "\n"
  cecho "Using login values from ~/.my.cnf"
  cecho "- INITIAL LOGIN ATTEMPT FAILED -" boldred
  if [ -z $prompted ] ; then
    find_webmin_passwords
  fi
  return 1
}

final_login_attempt () {
  is_up=$($MYSQLADMIN_COMMAND ping 2>&1)
  if [ "$is_up" = "mysqld is alive" ] ; then
    return 0
  else
    cecho "- FINAL LOGIN ATTEMPT FAILED -" boldred
    cecho "Unable to log into socket: $socket" boldred
    exit 1
  fi
}

## -- create a ~/.my.cnf and exit when all else fails -- ##
function second_login_failed()
{
  cecho "Could not auto detect login info!"
  cecho "Found potential sockets: $found_socks"
  cecho "Using: $socket" red
  read -p "Would you like to provide a different socket?: [y/N] " REPLY
    case $REPLY in
      yes | y | Y | YES)
      read -p "Socket: " socket
      ;;
    esac
  read -p "Do you have your login handy ? [y/N] : " REPLY
  case $REPLY in
    yes | y | Y | YES)
    answer1='yes'
    read -p "User: " user
    read -rsp "Password: " pass

    local MYSQL_COMMAND_PARAMS="-S $socket -u$user"
    export MYSQL_COMMAND="mysql $MYSQL_COMMAND_PARAMS"
    export MYSQLADMIN_COMMAND="mysqladmin $MYSQL_COMMAND_PARAMS"

    ;;
    *)
    cecho "Please create a valid login to MySQL"
    cecho "Or, set correct values for 'user=' and 'password=' in ~/.my.cnf"
    ;;
  esac
  cecho " "
  echo "Would you like me to create a ~/.my.cnf file for you?  If you answer 'N',"
  read -p "then I'll create a secure, temporary one instead.  [y/N] : " REPLY
  case $REPLY in
    yes | y | Y | YES)
    answer2='yes'
    if [ ! -f ~/.my.cnf ] ; then
      umask 077
      write_mycnf "${HOME}/.my.cnf" "$socket" "$user" "$pass"
      if [ "$answer1" != 'yes' ] ; then
        exit 1
      else
        final_login_attempt
        return 0
      fi
    else
      printf "\n"
      cecho "~/.my.cnf already exists!" boldred
      printf "\n"
      read -p "Replace ? [y/N] : " REPLY
      if [ "$REPLY" = 'y' ] || [ "$REPLY" = 'Y' ] ; then
        write_mycnf "${HOME}/.my.cnf" "$socket" "$user" "$pass"
        if [ "$answer1" != 'yes' ] ; then
          exit 1
        else
          final_login_attempt
          return 0
        fi
      else
        cecho "Please set the 'user=' and 'password=' and 'socket=' values in ~/.my.cnf"
        exit 1
      fi
    fi
    ;;
    *)
    if [ "$answer1" != 'yes' ] ; then
      exit 1
    else
      local tempmycnf
      tempmycnf="$(mktemp)"
      write_mycnf "$tempmycnf" "$socket" "$user" "$pass"
      export MYSQL_COMMAND="mysql --defaults-extra-file=$tempmycnf $MYSQL_COMMAND_PARAMS"
      export MYSQLADMIN_COMMAND="mysqladmin --defaults-extra-file=$tempmycnf $MYSQL_COMMAND_PARAMS"
      final_login_attempt
      return 0
    fi
    ;;
  esac
}

find_webmin_passwords () {

## -- populate the .my.cnf file using values harvested from Webmin -- ##

        cecho "Testing for stored webmin passwords:"
        if [ -f /etc/webmin/mysql/config ] ; then
                user=$(grep ^login= /etc/webmin/mysql/config | cut -d "=" -f 2)
                pass=$(grep ^pass= /etc/webmin/mysql/config | cut -d "=" -f 2)
                if [  $user ] && [ $pass ] && [ ! -f ~/.my.cnf  ] ; then
                        cecho "Setting login info as User: $user Password: $pass"
                        touch ~/.my.cnf
                        chmod 600 ~/.my.cnf
                        write_mycnf "${HOME}/.my.cnf" "" "$user" "$pass"
                        cecho "Retrying login"
                        is_up=$($MYSQLADMIN_COMMAND ping 2>&1)
                        if [ "$is_up" = "mysqld is alive"  ] ; then
                                echo UP > /dev/null
                        else
                                second_login_failed
                        fi
                echo
                else
                        second_login_failed
                echo
                fi
        else
        cecho " None Found" boldred
                second_login_failed
        fi
}

#########################################################################
#                                                                       #
#  Function to pull MySQL status variable                               #
#                                                                       #
#  Call using :                                                         #
#       mysql_status \'Mysql_status_variable\' bash_dest_variable       #
#                                                                       #
#########################################################################

mysql_status () {
        local status=$($MYSQL_COMMAND -Bse "show /*!50000 global */ status like $1" | awk '{ print $2 }')
        export "$2"=$status
}

#########################################################################
#                                                                       #
#  Function to pull MySQL server runtime variable                       #
#                                                                       #
#  Call using :                                                         #
#       mysql_variable \'Mysql_server_variable\' bash_dest_variable     #
#       - OR -                                                          #
#       mysql_variableTSV \'Mysql_server_variable\' bash_dest_variable  #
#                                                                       #
#########################################################################

mysql_variable () {
  local variable=$($MYSQL_COMMAND -Bse "show /*!50000 global */ variables like $1" | awk '{ print $2 }')
  export "$2"=$variable
}
mysql_variableTSV () {
  local variable=$($MYSQL_COMMAND -Bse "show /*!50000 global */ variables like $1" | awk -F '\t' '{ print $2 }')
  export "$2"=$variable
}

# -- Divide two integers -- #
function divide()
{
  usage="$0 dividend divisor '$variable' scale"
  if [ $1 -ge 1 ] ; then
    dividend=$1
  else
    cecho "Invalid Dividend" red
    echo "$usage"
    exit 1
  fi
  if [ $2 -ge 1 ] ; then
    divisor=$2
  else
    cecho "Invalid Divisor" red
    echo "$usage"
    exit 1
  fi
  if [ ! -n $3 ] ; then
    cecho "Invalid variable name" red
    echo "$usage"
    exit 1
  fi
  if [ -z $4 ] ; then
    scale=2
  elif [ $4 -ge 0 ] ; then
    scale=$4
  else
    cecho "Invalid scale" red
    echo "$usage"
    exit 1
  fi
  export $3=$(echo "scale=$scale; $dividend / $divisor" | bc -l)
}

human_readable () {

#########################################################################
#                                                                       #
#  Convert a value in to human readable size and populate a variable    #
#  with the result.                                                     #
#                                                                       #
#  Call using:                                                          #
#       human_readable $value 'variable name' [ places of precision]    #
#                                                                       #
#########################################################################

        ## value=$1
        ## variable=$2
        scale=$3

        if [ $1 -ge 1073741824 ] ; then
                if [ -z $3 ] ; then
                        scale=2
                fi
                divide $1 1073741824 "$2" $scale
                unit="G"
        elif [ $1 -ge 1048576 ] ; then
                if [ -z $3 ] ; then
                        scale=0
                fi
                divide $1 1048576 "$2" $scale
                unit="M"
        elif [ $1 -ge 1024 ] ; then
                if [ -z $3 ] ; then
                        scale=0
                fi
                divide $1 1024 "$2" $scale
                unit="K"
        else
                export "$2"=$1
                unit="bytes"
        fi
        # let "$2"=$HR
}

function human_readable_time()
{
  # Produce human readable time from a duration in seconds.

  # Remove and save any fractional component
  local secs="${1%.*}"
  local subsecs="${1#$secs}"

  if [ -z $1 ] || [ -z $2 ] ; then
    cecho "${FUNCNAME[0]} seconds 'variable'" red
    exit 1
  fi

  export $2="$((secs/86400)) days $((secs/3600%24)) hrs $((secs/60%60)) min $((secs%60))$subsecs sec"
}

check_mysql_version () {

## -- Print Version Info -- ##

        mysql_variable \'version\' mysql_version
        mysql_variable \'version_compile_machine\' mysql_version_compile_machine

if [ "$mysql_version_num" -lt 050000 ]; then
        cecho "MySQL Version $mysql_version $mysql_version_compile_machine is EOL please upgrade to MySQL 4.1 or later" boldred
else
        cecho "MySQL Version $mysql_version $mysql_version_compile_machine"
fi


}

post_uptime_warning () {

#########################################################################
#                                                                       #
#  Present a reminder that mysql must run for a couple of days to       #
#  build up good numbers in server status variables before these tuning #
#  suggestions should be used.                                          #
#                                                                       #
#########################################################################

        mysql_status \'Uptime\' uptime
        mysql_status \'Threads_connected\' threads
        queries_per_sec=$(($questions/$uptime))
        human_readable_time $uptime uptimeHR

        cecho "Uptime = $uptimeHR"
        cecho "Avg. qps = $queries_per_sec"
        cecho "Total Questions = $questions"
        cecho "Threads Connected = $threads"
        echo

        if [ $uptime -gt 172800 ] ; then
                cecho "Server has been running for over 48hrs."
                cecho "It should be safe to follow these recommendations"
        else
                cechon "Warning: " boldred
                cecho "Server has not been running for at least 48hrs." boldred
                cecho "It may not be safe to use these recommendations" boldred

        fi
        echo ""
        cecho "To find out more information on how each of these" red
        cecho "runtime variables effects performance visit:" red
        if [ "$major_version" = '3.23' ] || [ "$major_version" = '4.0' ] || [ "$major_version" = '4.1' ] ; then
        cecho "http://dev.mysql.com/doc/refman/4.1/en/server-system-variables.html" boldblue
        elif [ "$major_version" = '5.0' ] || [ "$mysql_version_num" -gt '050100' ]; then
        cecho "http://dev.mysql.com/doc/refman/$major_version/en/server-system-variables.html" boldblue
        else
        cecho "UNSUPPORTED MYSQL VERSION" boldred
        exit 1
        fi
        cecho "Visit http://www.mysql.com/products/enterprise/advisors.html" boldblue
        cecho "for info about MySQL's Enterprise Monitoring and Advisory Service" boldblue
}

check_slow_queries () {

## -- Slow Queries -- ##
        cecho "SLOW QUERIES" boldblue

        mysql_status \'Slow_queries\' slow_queries
        mysql_variable \'long_query_time\' long_query_time
        mysql_variable \'log%queries\' log_slow_queries
        mysql_variable \'slow_query_log\' slow_query_log

        PREFERRED_QUERY_TIME=5
        if [ -z "$log_slow_queries" ] ; then
            log_slow_queries="$slow_query_log"
        fi

        if [ "$log_slow_queries" = 'ON' ] ; then
                cecho "The slow query log is enabled."
        elif [ "$log_slow_queries" = 'OFF' ] || [ -z "$log_slow_queries" ] ; then
                cechon "The slow query log is "
                cechon "NOT" boldred
                cecho " enabled."
                return
        else
            cecho "Slow query log check failed; error(s): $log_slow_queries/$slow_query_log" boldred
        fi

        cecho "Current long_query_time = $long_query_time sec."
        cechon "Since startup, "
        cechon "$slow_queries" boldred
        cechon " out of "
        cechon "$questions" boldred
        cecho " queries have taken longer than <long_query_time-when-they-were-executed> to complete."

        if [ "${long_query_time%%.*}" -ge $PREFERRED_QUERY_TIME ] ; then
                cecho "Your long_query_time may be too high, I typically set this under $PREFERRED_QUERY_TIME sec." red
        elif [ "${long_query_time/.}" -eq 0 ] ; then
                cechon "Your long_query_time is set to "
                cechon "zero" boldred
                cechon ", which will cause "
                cechon "ALL queries to be logged" red
                cecho "!"
                cecho "If you actually WANT to log all queries, use the query log, not the slow query log."
        else
                cecho "Your long_query_time seems reasonable." green
        fi
}

check_binary_log () {

## -- Binary Log -- ##

        cecho "BINARY UPDATE LOG" boldblue

        mysql_variable \'log_bin\' log_bin
        mysql_variable \'max_binlog_size\' max_binlog_size
        mysql_variable \'expire_logs_days\' expire_logs_days
        mysql_variable \'sync_binlog\' sync_binlog
        #  mysql_variable \'max_binlog_cache_size\' max_binlog_cache_size

        if [ "$log_bin" = 'ON' ] ; then
                cecho "The binary update log is enabled"
                if [ -z "$max_binlog_size" ] ; then
                        cecho "The max_binlog_size is not set. The binary log will rotate when it reaches 1GB." red
                fi
                if [ "$expire_logs_days" -eq 0 ] ; then
                        cecho "The expire_logs_days is not set." boldred
                        cechon "The mysqld will retain the entire binary log until " red
                        cecho "RESET MASTER or PURGE MASTER LOGS commands are run manually" red
                        cecho "Setting expire_logs_days will allow you to remove old binary logs automatically"  yellow
                        cecho "See http://dev.mysql.com/doc/refman/$major_version/en/purge-master-logs.html" yellow
                fi
                if [ "$sync_binlog" = 0 ] ; then
                        cecho "Binlog sync is not enabled, you could loose binlog records during a server crash" red
                fi
        else
                cechon "The binary update log is "
                cechon "NOT " boldred
                cecho "enabled."
                cecho "You will not be able to do point in time recovery" red
                cecho "See http://dev.mysql.com/doc/refman/$major_version/en/point-in-time-recovery.html" yellow
        fi
}

check_used_connections () {

## -- Used Connections -- ##

        mysql_variable \'max_connections\' max_connections
        mysql_status \'Max_used_connections\' max_used_connections
        mysql_status \'Threads_connected\' threads_connected

        connections_ratio=$(($max_used_connections*100/$max_connections))

        cecho "MAX CONNECTIONS" boldblue
        cecho "Current max_connections = $max_connections"
        cecho "Current threads_connected = $threads_connected"
        cecho "Historic max_used_connections = $max_used_connections"
        cechon "The number of used connections is "
        if [ $connections_ratio -ge 85 ] ; then
                txt_color=red
                error=1
        elif [ $connections_ratio -le 10 ] ; then
                txt_color=red
                error=2
        else
                txt_color=green
                error=0
        fi
        # cechon "$max_used_connections " $txt_color
        # cechon "which is "
        cechon "$connections_ratio% " $txt_color
        cecho "of the configured maximum."

        if [ $error -eq 1 ] ; then
                cecho "You should raise max_connections" $txt_color
        elif [ $error -eq 2 ] ; then
                cecho "You are using less than 10% of your configured max_connections." $txt_color
                cecho "Lowering max_connections could help to avoid an over-allocation of memory" $txt_color
                cecho "See \"MEMORY USAGE\" section to make sure you are not over-allocating" $txt_color
        else
                cecho "Your max_connections variable seems to be fine." $txt_color
        fi
        unset txt_color
}

check_threads() {

## -- Worker Threads -- ##

        cecho "WORKER THREADS" boldblue

        mysql_status \'Threads_created\' threads_created1
        sleep 1
        mysql_status \'Threads_created\' threads_created2

        mysql_status \'Threads_cached\' threads_cached
        mysql_status \'Uptime\' uptime
        mysql_variable \'thread_cache_size\' thread_cache_size

        historic_threads_per_sec=$(($threads_created1/$uptime))
        current_threads_per_sec=$(($threads_created2-$threads_created1))

        cecho "Current thread_cache_size = $thread_cache_size"
        cecho "Current threads_cached = $threads_cached"
        cecho "Current threads_per_sec = $current_threads_per_sec"
        cecho "Historic threads_per_sec = $historic_threads_per_sec"

        if [ $historic_threads_per_sec -ge 2 ] && [ $threads_cached -le 1 ] ; then
                cecho "Threads created per/sec are overrunning threads cached" red
                cecho "You should raise thread_cache_size" red
        elif [ $current_threads_per_sec -ge 2 ] ; then
                cecho "Threads created per/sec are overrunning threads cached" red
                cecho "You should raise thread_cache_size" red
        else
                cecho "Your thread_cache_size is fine" green
        fi
}

check_key_buffer_size () {

## -- Key buffer Size -- ##

        cecho "KEY BUFFER" boldblue

        mysql_status \'Key_read_requests\' key_read_requests
        mysql_status \'Key_reads\' key_reads
        mysql_status \'Key_blocks_used\' key_blocks_used
        mysql_status \'Key_blocks_unused\' key_blocks_unused
        mysql_variable \'key_cache_block_size\' key_cache_block_size
        mysql_variable \'key_buffer_size\' key_buffer_size
        mysql_variable \'datadir\' datadir
        mysql_variable \'version_compile_machine\' mysql_version_compile_machine
        myisam_indexes=$($MYSQL_COMMAND -Bse "/*!50000 SELECT IFNULL(SUM(INDEX_LENGTH),0) from information_schema.TABLES where ENGINE='MyISAM' */")

        if [ -z $myisam_indexes ] ; then
                myisam_indexes=$(find $datadir -name '*.MYI' -exec du $duflags '{}' \; 2>&1 | awk '{ s += $1 } END { printf("%.0f\n", s )}')
        fi

        if [ $key_reads -eq 0 ] ; then
                cecho "No key reads?!" boldred
                cecho "Seriously look into using some indexes" red
                key_cache_miss_rate=0
                key_buffer_free=$(echo "$key_blocks_unused * $key_cache_block_size / $key_buffer_size * 100" | bc -l )
                key_buffer_freeRND=$(echo "scale=0; $key_buffer_free / 1" | bc -l)
        else
                key_cache_miss_rate=$(($key_read_requests/$key_reads))
                if [ ! -z $key_blocks_unused ] ; then
                        key_buffer_free=$(echo "$key_blocks_unused * $key_cache_block_size / $key_buffer_size * 100" | bc -l )
                        key_buffer_freeRND=$(echo "scale=0; $key_buffer_free / 1" | bc -l)
                else
                        key_buffer_free='Unknown'
                        key_buffer_freeRND=75
                fi
        fi

        human_readable $myisam_indexes myisam_indexesHR
        cecho "Current MyISAM index space = $myisam_indexesHR $unit"

        human_readable  $key_buffer_size key_buffer_sizeHR
        cecho "Current key_buffer_size = $key_buffer_sizeHR $unit"
        cecho "Key cache miss rate is 1 : $key_cache_miss_rate"
        cecho "Key buffer free ratio = $key_buffer_freeRND %"

        if [ "$major_version" = '5.1' ] && [ $mysql_version_num -lt 050123 ] ; then
                if [ $key_buffer_size -ge 4294967296 ] && ( echo "x86_64 ppc64 ia64 sparc64 i686" | grep -q $mysql_version_compile_machine ) ; then
                        cecho "Using key_buffer_size > 4GB will cause instability in versions prior to 5.1.23 " boldred
                        cecho "See Bug#5731, Bug#29419, Bug#29446" boldred
                fi
        fi
        if [ "$major_version" = '5.0' ] && [ $mysql_version_num -lt 050052 ] ; then
                if [ $key_buffer_size -ge 4294967296 ] && ( echo "x86_64 ppc64 ia64 sparc64 i686" | grep -q $mysql_version_compile_machine ) ; then
                        cecho "Using key_buffer_size > 4GB will cause instability in versions prior to 5.0.52 " boldred
                        cecho "See Bug#5731, Bug#29419, Bug#29446" boldred
                fi
        fi
        if [ "$major_version" = '4.1' -o "$major_version" = '4.0' ] && [ $key_buffer_size -ge 4294967296 ] && ( echo "x86_64 ppc64 ia64 sparc64 i686" | grep -q $mysql_version_compile_machine ) ; then
                cecho "Using key_buffer_size > 4GB will cause instability in versions prior to 5.0.52 " boldred
                cecho "Reduce key_buffer_size to a safe value" boldred
                cecho "See Bug#5731, Bug#29419, Bug#29446" boldred
        fi

        if [ $key_cache_miss_rate -le 100 ] && [ $key_cache_miss_rate -gt 0 ] && [ $key_buffer_freeRND -le 20 ]; then
                cecho "You could increase key_buffer_size" boldred
                cecho "It is safe to raise this up to 1/4 of total system memory;"
                cecho "assuming this is a dedicated database server."
        elif [ $key_buffer_freeRND -le 20 ] && [ $key_buffer_size -le $myisam_indexes ] ; then
                cecho "You could increase key_buffer_size" boldred
                cecho "It is safe to raise this up to 1/4 of total system memory;"
                cecho "assuming this is a dedicated database server."
        elif [ $key_cache_miss_rate -ge 10000 ] || [ $key_buffer_freeRND -le 50  ] ; then
                cecho "Your key_buffer_size seems to be too high." red
                cecho "Perhaps you can use these resources elsewhere" red
        else
                cecho "Your key_buffer_size seems to be fine" green
        fi
}

check_query_cache () {

## -- Query Cache -- ##

        cecho "QUERY CACHE" boldblue

        mysql_variable \'version\' mysql_version
        mysql_variable \'query_cache_size\' query_cache_size
        mysql_variable \'query_cache_limit\' query_cache_limit
        mysql_variable \'query_cache_min_res_unit\' query_cache_min_res_unit
        mysql_status \'Qcache_free_memory\' qcache_free_memory
        mysql_status \'Qcache_total_blocks\' qcache_total_blocks
        mysql_status \'Qcache_free_blocks\' qcache_free_blocks
        mysql_status \'Qcache_lowmem_prunes\' qcache_lowmem_prunes

        if [ -z $query_cache_size ] ; then
                cecho "Query cache is disabled or not supported." red
                #cecho "You are using MySQL $mysql_version, no query cache is supported." red
                #cecho "I recommend an upgrade to MySQL 4.1 or better" red
        elif [ $query_cache_size -eq 0 ] ; then
                cecho "Query cache is supported but not enabled" red
                cecho "Perhaps you should set the query_cache_size" red
        else
                qcache_used_memory=$(($query_cache_size-$qcache_free_memory))
                qcache_mem_fill_ratio=$(echo "scale=2; $qcache_used_memory * 100 / $query_cache_size" | bc -l)
                qcache_mem_fill_ratioHR=$(echo "scale=0; $qcache_mem_fill_ratio / 1" | bc -l)

                cecho "Query cache is enabled" green
                human_readable $query_cache_size query_cache_sizeHR
                cecho "Current query_cache_size = $query_cache_sizeHR $unit"
                human_readable $qcache_used_memory qcache_used_memoryHR
                cecho "Current query_cache_used = $qcache_used_memoryHR $unit"
                human_readable $query_cache_limit query_cache_limitHR
                cecho "Current query_cache_limit = $query_cache_limitHR $unit"
                cecho "Current Query cache Memory fill ratio = $qcache_mem_fill_ratio %"
                if [ -z $query_cache_min_res_unit ] ; then
                        cecho "No query_cache_min_res_unit is defined.  Using MySQL < 4.1 cache fragmentation can be inpredictable" %yellow
                else
                        human_readable $query_cache_min_res_unit query_cache_min_res_unitHR
                        cecho "Current query_cache_min_res_unit = $query_cache_min_res_unitHR $unit"
                fi
                if [ $qcache_free_blocks -gt 2 ] && [ $qcache_total_blocks -gt 0 ] ; then
                        qcache_percent_fragmented=$(echo "scale=2; $qcache_free_blocks * 100 / $qcache_total_blocks" | bc -l)
                        qcache_percent_fragmentedHR=$(echo "scale=0; $qcache_percent_fragmented / 1" | bc -l)
                        if [ $qcache_percent_fragmentedHR -gt 20 ] ; then
                                cecho "Query Cache is $qcache_percent_fragmentedHR % fragmented" red
                                cecho "Run \"FLUSH QUERY CACHE\" periodically to defragment the query cache memory" red
                                cecho "If you have many small queries lower 'query_cache_min_res_unit' to reduce fragmentation." red
                        fi
                fi

                if [ $qcache_mem_fill_ratioHR -le 25 ] ; then
                        cecho "Your query_cache_size seems to be too high." red
                        cecho "Perhaps you can use these resources elsewhere" red
                fi
                if [ $qcache_lowmem_prunes -ge 50 ] && [ $qcache_mem_fill_ratioHR -ge 80 ]; then
                        cechon "However, "
                        cechon "$qcache_lowmem_prunes " boldred
                        cecho "queries have been removed from the query cache due to lack of memory"
                        cecho "Perhaps you should raise query_cache_size" boldred
                fi
                cecho "MySQL won't cache query results that are larger than query_cache_limit in size" yellow
        fi

}

check_sort_operations () {

## -- Sort Operations -- ##

        cecho "SORT OPERATIONS" boldblue

        mysql_status \'Sort_merge_passes\' sort_merge_passes
        mysql_status \'Sort_scan\' sort_scan
        mysql_status \'Sort_range\' sort_range
        mysql_variable \'sort_buffer_size\' sort_buffer_size
        mysql_variable \'read_rnd_buffer_size\' read_rnd_buffer_size

        total_sorts=$(($sort_scan+$sort_range))
        if [ -z $read_rnd_buffer_size ] ; then
                mysql_variable \'record_buffer\' read_rnd_buffer_size
        fi

        ## Correct for rounding error in mysqld where 512K != 524288 ##
        sort_buffer_size=$(($sort_buffer_size+8))
        read_rnd_buffer_size=$(($read_rnd_buffer_size+8))

        human_readable $sort_buffer_size sort_buffer_sizeHR
        cecho "Current sort_buffer_size = $sort_buffer_sizeHR $unit"

        human_readable $read_rnd_buffer_size read_rnd_buffer_sizeHR
        cechon "Current "
        if [ "$major_version" = '3.23' ] ; then
                cechon "record_rnd_buffer "
        else
                cechon "read_rnd_buffer_size "
        fi
        cecho "= $read_rnd_buffer_sizeHR $unit"

        if [ $total_sorts -eq 0 ] ; then
                cecho "No sort operations have been performed"
                passes_per_sort=0
        fi
        if [ $sort_merge_passes -ne 0 ] ; then
                passes_per_sort=$(($sort_merge_passes/$total_sorts))
        else
                passes_per_sort=0
        fi

        if [ $passes_per_sort -ge 2 ] ; then
                cechon "On average "
                cechon "$passes_per_sort " boldred
                cecho "sort merge passes are made per sort operation"
                cecho "You should raise your sort_buffer_size"
                cechon "You should also raise your "
                if [ "$major_version" = '3.23' ] ; then
                        cecho "record_rnd_buffer_size"
                else
                        cecho "read_rnd_buffer_size"
                fi
        else
                cecho "Sort buffer seems to be fine" green
        fi
}

check_join_operations () {

## -- Joins -- ##

        cecho "JOINS" boldblue

        mysql_status \'Select_full_join\' select_full_join
        mysql_status \'Select_range_check\' select_range_check
        mysql_variable \'join_buffer_size\' join_buffer_size

        ## Some 4K is dropped from join_buffer_size adding it back to make sane ##
        ## handling of human-readable conversion ##

        join_buffer_size=$(($join_buffer_size+4096))

        human_readable $join_buffer_size join_buffer_sizeHR 2

        cecho "Current join_buffer_size = $join_buffer_sizeHR $unit"
        cecho "You have had $select_full_join queries where a join could not use an index properly"

        if [ $select_range_check -eq 0 ] && [ $select_full_join -eq 0 ] ; then
                cecho "Your joins seem to be using indexes properly" green
        fi
        if [ $select_full_join -gt 0 ] ; then
                print_error='true'
                raise_buffer='true'
        fi
        if [ $select_range_check -gt 0 ] ; then
                cecho "You have had $select_range_check joins without keys that check for key usage after each row" red
                print_error='true'
                raise_buffer='true'
        fi

        ## For Debuging ##
        # print_error='true'
        if [ $join_buffer_size -ge 4194304 ] ; then
                cecho "join_buffer_size >= 4 M" boldred
                cecho "This is not advised" boldred
                raise_buffer=
        fi

        if [ $print_error ] ; then
                if [ "$major_version" = '3.23' ] || [ "$major_version" = '4.0' ] ; then
                        cecho "You should enable \"log-long-format\" "
                elif [ "$mysql_version_num" -gt 040100 ]; then
                        cecho "You should enable \"log-queries-not-using-indexes\""
                fi
                cecho "Then look for non indexed joins in the slow query log."
                if [ $raise_buffer ] ; then
                cecho "If you are unable to optimize your queries you may want to increase your"
                cecho "join_buffer_size to accommodate larger joins in one pass."
                printf "\n"
                cecho "Note! This script will still suggest raising the join_buffer_size when" boldred
                cecho "ANY joins not using indexes are found." boldred
                fi
        fi

        # XXX Add better tests for join_buffer_size pending mysql bug #15088  XXX #
}

check_tmp_tables () {

## -- Temp Tables -- ##

        cecho "TEMP TABLES" boldblue

        mysql_status \'Created_tmp_tables\' created_tmp_tables
        mysql_status \'Created_tmp_disk_tables\' created_tmp_disk_tables
        mysql_variable \'tmp_table_size\' tmp_table_size
        mysql_variable \'max_heap_table_size\' max_heap_table_size


        if [ $created_tmp_tables -eq 0 ] ; then
                tmp_disk_tables=0
        else
                tmp_disk_tables=$((created_tmp_disk_tables*100/(created_tmp_tables+created_tmp_disk_tables)))
        fi
        human_readable $max_heap_table_size max_heap_table_sizeHR
        cecho "Current max_heap_table_size = $max_heap_table_sizeHR $unit"

        human_readable $tmp_table_size tmp_table_sizeHR
        cecho "Current tmp_table_size = $tmp_table_sizeHR $unit"

        cecho "Of $created_tmp_tables temp tables, $tmp_disk_tables% were created on disk"
        if [ $tmp_table_size -gt $max_heap_table_size ] ; then
                cecho "Effective in-memory tmp_table_size is limited to max_heap_table_size." yellow
        fi
        if [ $tmp_disk_tables -ge 25 ] ; then
                cecho "Perhaps you should increase your tmp_table_size and/or max_heap_table_size" boldred
                cecho "to reduce the number of disk-based temporary tables" boldred
                cecho "Note! BLOB and TEXT columns are not allow in memory tables." yellow
                cecho "If you are using these columns raising these values might not impact your " yellow
                cecho  "ratio of on disk temp tables." yellow
        else
                cecho "Created disk tmp tables ratio seems fine" green
        fi
}

check_open_files () {

## -- Open Files Limit -- ##
        cecho "OPEN FILES LIMIT" boldblue

        mysql_variable \'open_files_limit\' open_files_limit
        mysql_status   \'Open_files\' open_files

        if [ -z $open_files_limit ] || [ $open_files_limit -eq 0 ] ; then
                open_files_limit=$(ulimit -n)
                cant_override=1
        else
                cant_override=0
        fi
        cecho "Current open_files_limit = $open_files_limit files"

        open_files_ratio=$(($open_files*100/$open_files_limit))

        cecho "The open_files_limit should typically be set to at least 2x-3x" yellow
        cecho "that of table_cache if you have heavy MyISAM usage." yellow
        if [ $open_files_ratio -ge 75 ] ; then
                cecho "You currently have open more than 75% of your open_files_limit" boldred
                if [ $cant_override -eq 1 ] ; then
                        cecho "You should set a higer value for ulimit -u in the mysql startup script then restart mysqld" boldred
                        cecho "MySQL 3.23 users : This is just a guess based upon the current shell's ulimit -u value" yellow
                elif [ $cant_override -eq 0 ] ; then
                        cecho "You should set a higher value for open_files_limit in my.cnf" boldred
                else
                        cecho "ERROR can't determine if mysqld override of ulimit is allowed" boldred
                        exit 1
                fi
        else
                cecho "Your open_files_limit value seems to be fine" green
        fi



}

check_table_cache () {

## -- Table Cache -- ##

        cecho "TABLE CACHE" boldblue

        mysql_variable \'datadir\' datadir
        mysql_variable \'table_cache\' table_cache

        ## /* MySQL +5.1 version of table_cache */ ##
        mysql_variable \'table_open_cache\' table_open_cache
        mysql_variable \'table_definition_cache\' table_definition_cache

        mysql_status \'Open_tables\' open_tables
        mysql_status \'Opened_tables\' opened_tables
        mysql_status \'Open_table_definitions\' open_table_definitions

        table_count=$($MYSQL_COMMAND -Bse "/*!50000 SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' */")

        if [ -z "$table_count" ] ; then
                if [ "$UID" != "$socket_owner" ] && [ "$UID" != "0" ] ; then
                        cecho "You are not '$socket_owner' or 'root'" red
                        cecho "I am unable to determine the table_count!" red
                else
                        table_count=$(find $datadir 2>&1 | grep -c .frm$)
                fi
        fi
        if [ $table_open_cache ] ; then
                table_cache=$table_open_cache
        fi

        if [ $opened_tables -ne 0 ] && [ $table_cache -ne 0 ] ; then
                table_cache_hit_rate=$(($open_tables*100/$opened_tables))
                table_cache_fill=$(($open_tables*100/$table_cache))
        elif [ $opened_tables -eq 0 ] && [ $table_cache -ne 0 ] ; then
                table_cache_hit_rate=100
                table_cache_fill=$(($open_tables*100/$table_cache))
        else
                cecho "ERROR no table_cache ?!" boldred
                exit 1
        fi
        if [ $table_cache ] && [ ! $table_open_cache ] ; then
                cecho "Current table_cache value = $table_cache tables"
        fi
        if [ $table_open_cache ] ; then
                cecho "Current table_open_cache = $table_open_cache tables"
                cecho "Current table_definition_cache = $table_definition_cache tables"
        fi
        if [ $table_count ] ; then
        cecho "You have a total of $table_count tables"
        fi

        if  [ $table_cache_fill -lt 95 ] ; then
                cechon "You have "
                cechon "$open_tables " green
                cecho "open tables."
                cecho "The table_cache value seems to be fine" green
        elif [ $table_cache_hit_rate -le 85 -o  $table_cache_fill -ge 95 ]; then
                cechon "You have "
                cechon "$open_tables " boldred
                cecho "open tables."
                cechon "Current table_cache hit rate is "
                cecho "$table_cache_hit_rate%" boldred
                cechon ", while "
                cechon "$table_cache_fill% " boldred
                cecho "of your table cache is in use"
                cecho "You should probably increase your table_cache" red
        else
                cechon "Current table_cache hit rate is "
                cechon "$table_cache_hit_rate%" green
                cechon ", while "
                cechon "$table_cache_fill% " green
                cecho "of your table cache is in use"
                cecho "The table cache value seems to be fine" green
        fi
        if [ $table_definition_cache ] && [ $table_definition_cache -le $table_count ] && [ $table_count -ge 100 ] ; then
                cecho "You should probably increase your table_definition_cache value." red
        fi
}

check_table_locking () {

## -- Table Locking -- ##

        cecho "TABLE LOCKING" boldblue

        mysql_status \'Table_locks_waited\' table_locks_waited
        mysql_status \'Table_locks_immediate\' table_locks_immediate
        mysql_variable \'concurrent_insert\' concurrent_insert
        mysql_variable \'low_priority_updates\' low_priority_updates
        if [ "$concurrent_insert" = 'ON' ]; then
                concurrent_insert=1
        elif [ "$concurrent_insert" = 'OFF' ]; then
                concurrent_insert=0
        fi

        cechon "Current Lock Wait ratio = "
        if [ $table_locks_waited -gt 0 ]; then
                immediate_locks_miss_rate=$(($table_locks_immediate/$table_locks_waited))
                cecho "1 : $immediate_locks_miss_rate" red
        else
                immediate_locks_miss_rate=99999 # perfect
                cecho "0 : $questions"
        fi
        if [ $immediate_locks_miss_rate -lt 5000 ] ; then
                cecho "You may benefit from selective use of InnoDB."
                if [ "$low_priority_updates" = 'OFF' ] ; then
                cecho "If you have long running SELECT's against MyISAM tables and perform"
                cecho "frequent updates consider setting 'low_priority_updates=1'"
                fi
                if [ "$mysql_version_num" -gt 050000 ] && [ "$mysql_version_num" -lt 050500 ]; then
                        if [ $concurrent_insert -le 1 ] ; then
                        cecho "If you have a high concurrency of inserts on Dynamic row-length tables"
                        cecho "consider setting 'concurrent_insert=2'."
                        fi
                elif [ "$mysql_version_num" -gt 050500 ] ; then
                        if [ "$concurrent_insert" = 'AUTO' ] || [ "$concurrent_insert" = 'NEVER' ] ; then
                        cecho "If you have a high concurrency of inserts on Dynamic row-length tables"
                        cecho "consider setting 'concurrent_insert=ALWAYS'."
                        fi
                fi
        else
                cecho "Your table locking seems to be fine" green
        fi
}

check_table_scans () {

## -- Table Scans -- ##

        cecho "TABLE SCANS" boldblue

        mysql_status \'Com_select\' com_select
        mysql_status \'Handler_read_rnd_next\' read_rnd_next
        mysql_variable \'read_buffer_size\' read_buffer_size

        if [ -z $read_buffer_size ] ; then
                mysql_variable \'record_buffer\' read_buffer_size
        fi

        human_readable $read_buffer_size read_buffer_sizeHR
        cecho "Current read_buffer_size = $read_buffer_sizeHR $unit"

        if [ $com_select -gt 0 ] ; then
                full_table_scans=$(($read_rnd_next/$com_select))
                cecho "Current table scan ratio = $full_table_scans : 1"
                if [ $full_table_scans -ge 4000 ] && [ $read_buffer_size -le 2097152 ] ; then
                        cecho "You have a high ratio of sequential access requests to SELECTs" red
                        cechon "You may benefit from raising " red
                        if [ "$major_version" = '3.23' ] ; then
                                cechon "record_buffer " red
                        else
                                cechon "read_buffer_size " red
                        fi
                        cecho "and/or improving your use of indexes." red
                elif [ $read_buffer_size -gt 8388608 ] ; then
                        cechon "read_buffer_size is over 8 MB " red
                        cecho "there is probably no need for such a large read_buffer" red

                else
                        cecho "read_buffer_size seems to be fine" green
                fi
        else
                cecho "read_buffer_size seems to be fine" green
        fi
}

function check_innodb_status()
{
  ## See http://bugs.mysql.com/59393

  mysql_variable \'have_innodb\' have_innodb

  if [ "$mysql_version_num" -lt 050500 ] && [ "$have_innodb" = "YES" ] ; then
    innodb_enabled=1
  fi

  if [ "${mysql_version//Maria}" != "${mysql_version}" ] || \
     [ "${mysql_version_num}" -ge 050700 ]; then
    # In MariaDB and MySQL >=5.7, InnoDB is always present, excepting Rocks and the like.
    mysql_variable \'ignore_builtin_innodb\' ignore_builtin_innodb
    # MariaDB gives you a lovely option for disabling InnoDB that doesn't _technically_
    # necessitate setting ignore_builtin_innodb.  Thanks for that.  Very cute.  See
    # https://github.com/BMDan/tuning-primer.sh/issues/12 .
    if [ "$ignore_builtin_innodb" = "ON" ] || [ "$have_innodb" = "DISABLED" ] || [ "$have_innodb" = "NO" ]; then
      innodb_enabled=0
    else
      innodb_enabled=1
    fi
  elif [ "$mysql_version_num" -ge 050500 ] && [ "$mysql_version_num" -lt 050512 ] ; then
    mysql_variable \'ignore_builtin_innodb\' ignore_builtin_innodb
    if [ "$ignore_builtin_innodb" = "ON" ] || [ $have_innodb = "NO" ] ; then
      innodb_enabled=0
    else
      innodb_enabled=1
    fi
  elif [ "$major_version"  = '5.5' ] && [ "$mysql_version_num" -ge 050512 ] ; then
    mysql_variable \'ignore_builtin_innodb\' ignore_builtin_innodb
    if [ "$ignore_builtin_innodb" = "ON" ] ; then
      innodb_enabled=0
    else
      innodb_enabled=1
    fi
  elif [ "$mysql_version_num" -ge 050600 ] && [ "$mysql_version_num" -lt 050603 ] ; then
    mysql_variable \'ignore_builtin_innodb\' ignore_builtin_innodb
    if [ "$ignore_builtin_innodb" = "ON" ] || [ $have_innodb = "NO" ] ; then
      innodb_enabled=0
    else
      innodb_enabled=1
    fi
  elif [ "$major_version" = '5.6' ] && [ "$mysql_version_num" -ge 050603 ] ; then
    mysql_variable \'ignore_builtin_innodb\' ignore_builtin_innodb
    if [ "$ignore_builtin_innodb" = "ON" ] ; then
      innodb_enabled=0
    else
      innodb_enabled=1
    fi
  fi

  if [ "$innodb_enabled" = 1 ] ; then
    mysql_variable \'innodb_buffer_pool_size\' innodb_buffer_pool_size
    mysql_variable \'innodb_additional_mem_pool_size\' innodb_additional_mem_pool_size
    mysql_variable \'innodb_fast_shutdown\' innodb_fast_shutdown
    mysql_variable \'innodb_flush_log_at_trx_commit\' innodb_flush_log_at_trx_commit
    mysql_variable \'innodb_locks_unsafe_for_binlog\' innodb_locks_unsafe_for_binlog
    mysql_variable \'innodb_log_buffer_size\' innodb_log_buffer_size
    mysql_variable \'innodb_log_file_size\' innodb_log_file_size
    mysql_variable \'innodb_log_files_in_group\' innodb_log_files_in_group
    mysql_variable \'innodb_safe_binlog\' innodb_safe_binlog
    mysql_variable \'innodb_thread_concurrency\' innodb_thread_concurrency

    cecho "INNODB STATUS" boldblue
    innodb_indexes=$($MYSQL_COMMAND -Bse "/*!50000 SELECT IFNULL(SUM(INDEX_LENGTH),0) from information_schema.TABLES where ENGINE='InnoDB' */")
    innodb_data=$($MYSQL_COMMAND -Bse "/*!50000 SELECT IFNULL(SUM(DATA_LENGTH),0) from information_schema.TABLES where ENGINE='InnoDB' */")

    if [ ! -z "$innodb_indexes" ] ; then
      mysql_status \'Innodb_buffer_pool_pages_data\' innodb_buffer_pool_pages_data
      mysql_status \'Innodb_buffer_pool_pages_misc\' innodb_buffer_pool_pages_misc
      mysql_status \'Innodb_buffer_pool_pages_free\' innodb_buffer_pool_pages_free
      mysql_status \'Innodb_buffer_pool_pages_total\' innodb_buffer_pool_pages_total

      mysql_status \'Innodb_buffer_pool_read_ahead_seq\' innodb_buffer_pool_read_ahead_seq
      mysql_status \'Innodb_buffer_pool_read_requests\' innodb_buffer_pool_read_requests

      mysql_status \'Innodb_os_log_pending_fsyncs\' innodb_os_log_pending_fsyncs
      mysql_status \'Innodb_os_log_pending_writes\'   innodb_os_log_pending_writes
      mysql_status \'Innodb_log_waits\' innodb_log_waits

      mysql_status \'Innodb_row_lock_time\' innodb_row_lock_time
      mysql_status \'Innodb_row_lock_waits\' innodb_row_lock_waits

      human_readable $innodb_indexes innodb_indexesHR
      cecho "Current InnoDB index space = $innodb_indexesHR $unit"
      human_readable $innodb_data innodb_dataHR
      cecho "Current InnoDB data space = $innodb_dataHR $unit"
      percent_innodb_buffer_pool_free=$(($innodb_buffer_pool_pages_free*100/$innodb_buffer_pool_pages_total))
      cecho "Current InnoDB buffer pool free = ${percent_innodb_buffer_pool_free} %"

    else
      cecho "Cannot parse InnoDB stats prior to 5.0.x" red
      $MYSQL_COMMAND -s -e "SHOW /*!50000 ENGINE */ INNODB STATUS\G"
    fi

    human_readable $innodb_buffer_pool_size innodb_buffer_pool_sizeHR
    cecho "Current innodb_buffer_pool_size = $innodb_buffer_pool_sizeHR $unit"
    cecho "Depending on how much space your innodb indexes take up it may be safe"
    cecho "to increase this value to up to 2 / 3 of total system memory"
  else
    cecho "No InnoDB Support Enabled!" boldred
  fi
}

total_memory_used () {

## -- Total Memory Usage -- ##
        cecho "MEMORY USAGE" boldblue

        mysql_variable \'read_buffer_size\' read_buffer_size
        mysql_variable \'read_rnd_buffer_size\' read_rnd_buffer_size
        mysql_variable \'sort_buffer_size\' sort_buffer_size
        mysql_variable \'thread_stack\' thread_stack
        mysql_variable \'max_connections\' max_connections
        mysql_variable \'join_buffer_size\' join_buffer_size
        mysql_variable \'tmp_table_size\' tmp_table_size
        mysql_variable \'max_heap_table_size\' max_heap_table_size
        mysql_variable \'log_bin\' log_bin
        mysql_status \'Max_used_connections\' max_used_connections

        if [ "$major_version" = "3.23" ] ; then
                mysql_variable \'record_buffer\' read_buffer_size
                mysql_variable \'record_rnd_buffer\' read_rnd_buffer_size
                mysql_variable \'sort_buffer\' sort_buffer_size
        fi

        if [ "$log_bin" = "ON" ] ; then
                mysql_variable \'binlog_cache_size\' binlog_cache_size
        else
                binlog_cache_size=0
        fi

        if [ $max_heap_table_size -le $tmp_table_size ] ; then
                effective_tmp_table_size=$max_heap_table_size
        else
                effective_tmp_table_size=$tmp_table_size
        fi


        per_thread_buffers=$(echo "($read_buffer_size+$read_rnd_buffer_size+$sort_buffer_size+$thread_stack+$join_buffer_size+$binlog_cache_size)*$max_connections" | bc -l)
        per_thread_max_buffers=$(echo "($read_buffer_size+$read_rnd_buffer_size+$sort_buffer_size+$thread_stack+$join_buffer_size+$binlog_cache_size)*$max_used_connections" | bc -l)

        mysql_variable \'innodb_buffer_pool_size\' innodb_buffer_pool_size
        if [ -z $innodb_buffer_pool_size ] ; then
        innodb_buffer_pool_size=0
        fi

        mysql_variable \'innodb_additional_mem_pool_size\' innodb_additional_mem_pool_size
        if [ -z $innodb_additional_mem_pool_size ] ; then
        innodb_additional_mem_pool_size=0
        fi

        mysql_variable \'innodb_log_buffer_size\' innodb_log_buffer_size
        if [ -z $innodb_log_buffer_size ] ; then
        innodb_log_buffer_size=0
        fi

        mysql_variable \'key_buffer_size\' key_buffer_size

        mysql_variable \'query_cache_size\' query_cache_size
        if [ -z $query_cache_size ] ; then
        query_cache_size=0
        fi

        global_buffers=$(echo "$innodb_buffer_pool_size+$innodb_additional_mem_pool_size+$innodb_log_buffer_size+$key_buffer_size+$query_cache_size" | bc -l)


        max_memory=$(echo "$global_buffers+$per_thread_max_buffers" | bc -l)
        total_memory=$(echo "$global_buffers+$per_thread_buffers" | bc -l)

        pct_of_sys_mem=$(echo "scale=0; $total_memory*100/$physical_memory" | bc -l)

        if [ $pct_of_sys_mem -gt 90 ] ; then
                txt_color=boldred
                error=1
        else
                txt_color=
                error=0
        fi

        human_readable $max_memory max_memoryHR
        cecho "Max Memory Ever Allocated : $max_memoryHR $unit" $txt_color
        human_readable $per_thread_buffers per_thread_buffersHR
        cecho "Configured Max Per-thread Buffers : $per_thread_buffersHR $unit" $txt_color
        human_readable $global_buffers global_buffersHR
        cecho "Configured Max Global Buffers : $global_buffersHR $unit" $txt_color
        human_readable $total_memory total_memoryHR
        cecho "Configured Max Memory Limit : $total_memoryHR $unit" $txt_color
#       human_readable $effective_tmp_table_size effective_tmp_table_sizeHR
#       cecho "Plus $effective_tmp_table_sizeHR $unit per temporary table created"
        human_readable $physical_memory physical_memoryHR
        cecho "Physical Memory : $physical_memoryHR $unit" $txt_color
        if [ $error -eq 1 ] ; then
                printf "\n"
                cecho "Max memory limit exceeds 90% of physical memory" $txt_color
        else
                cecho "Max memory limit seem to be within acceptable norms" green
        fi
        unset txt_color
}

## Required Functions  ##

login_validation () {
        export MYSQL_COMMAND="mysql"
        export MYSQLADMIN_COMMAND="mysqladmin"

        if [ -n "${socket-}" ]; then
          # First, we look for a socket.  Then, we try to find old Plesk
          # login creds (is this still needed?).  Then, we try the truly
          # revolutionary approach of just trying to connect and seeing
          # what happens.
          check_for_socket ||
          check_for_plesk_passwords ||
          check_mysql_login ||
          exit 1
        else
          # If the user didn't specify a socket for us (and they usually
          # won't), let's try to just connect and see if that works.  If
          # it doesn't, try to guess at a socket path, and then break out
          # the ol' Plesk trick if things get really desperate.
          check_mysql_login ||
          check_for_socket ||
          check_for_plesk_passwords ||
          exit 1
        fi
        export major_version=$($MYSQL_COMMAND -Bse "SELECT SUBSTRING_INDEX(VERSION(), '.', +2)")
#       export mysql_version_num=$($MYSQL_COMMAND -Bse "SELECT LEFT(REPLACE(SUBSTRING_INDEX(VERSION(), '-', +1), '.', ''),4)" )
        export mysql_version_num=$($MYSQL_COMMAND -Bse "SELECT VERSION()" |
                awk -F \. '{ printf "%02d", $1; printf "%02d", $2; printf "%02d", $3 }')

}

shared_info () {
        export major_version=$($MYSQL_COMMAND -Bse "SELECT SUBSTRING_INDEX(VERSION(), '.', +2)")
        # export mysql_version_num=$($MYSQL_COMMAND -Bse "SELECT LEFT(REPLACE(SUBSTRING_INDEX(VERSION(), '-', +1), '.', ''),4)" )
        export mysql_version_num=$($MYSQL_COMMAND -Bse "SELECT VERSION()" |
                awk -F \. '{ printf "%02d", $1; printf "%02d", $2; printf "%02d", $3 }')
        mysql_status \'Questions\' questions
#       socket_owner=$(find -L $socket -printf '%u\n')
        socket_owner=$(ls -nH $socket | awk '{ print $3 }')
}


get_system_info () {

    export OS=$(uname)

    # Get information for various UNIXes
    if [ "$OS" = 'Darwin' ]; then
        ps_socket=$(netstat -ln | awk '/mysql(.*)?\.sock/ { print $9 }' | head -1)
        found_socks=$(netstat -ln | awk '/mysql(.*)?\.sock/ { print $9 }')
        export physical_memory=$(sysctl -n hw.memsize)
        export duflags=''
    elif [ "$OS" = 'FreeBSD' ] || [ "$OS" = 'OpenBSD' ]; then
        ## On FreeBSD must be root to locate sockets.
        ps_socket=$(netstat -ln | awk '/mysql(.*)?\.sock/ { print $9 }' | head -1)
        found_socks=$(netstat -ln | awk '/mysql(.*)?\.sock/ { print $9 }')
        export physical_memory=$(sysctl -n hw.realmem)
        export duflags=''
    elif [ "$OS" = 'Linux' ] ; then
        ## Includes SWAP
        ## export physical_memory=$(free -b | grep -v buffers |  awk '{ s += $2 } END { printf("%.0f\n", s ) }')
        ps_socket=$(netstat -ln | awk '/mysql(.*)?\.sock/ { print $9 }' | head -1)
        found_socks=$(netstat -ln | awk '/mysql(.*)?\.sock/ { print $9 }')
        export physical_memory=$(awk '/^MemTotal/ { printf("%.0f", $2*1024 ) }' < /proc/meminfo)
        export duflags='-b'
    elif [ "$OS" = 'SunOS' ] ; then
        ps_socket=$(netstat -an | awk '/mysql(.*)?.sock/ { print $5 }' | head -1)
        found_socks=$(netstat -an | awk '/mysql(.*)?.sock/ { print $5 }')
        export physical_memory=$(prtconf | awk '/^Memory\ size:/ { print $3*1048576 }')
    fi
    if [ -z "$(which bc)" ] ; then
        echo "Error: Command line calculator 'bc' not found!"
        exit
    fi
}


## Optional Components Groups ##

banner_info () {
        shared_info
        print_banner            ; echo
        check_mysql_version     ; echo
        post_uptime_warning     ; echo
}

misc () {
        shared_info
        check_slow_queries      ; echo
        check_binary_log        ; echo
        check_threads           ; echo
        check_used_connections  ; echo
        check_innodb_status     ; echo
}

memory () {
        shared_info
        total_memory_used       ; echo
        check_key_buffer_size   ; echo
        check_query_cache       ; echo
        check_sort_operations   ; echo
        check_join_operations   ; echo
}

file () {
        shared_info
        check_open_files        ; echo
        check_table_cache       ; echo
        check_tmp_tables        ; echo
        check_table_scans       ; echo
        check_table_locking     ; echo
}

all () {
        banner_info
        misc
        memory
        file
}

prompt () {
        prompted='true'
        read -p "Username [anonymous] : " user
        read -rsp "Password [<none>] : " pass
        cecho " "
        read -p "Socket [ /var/lib/mysql/mysql.sock ] : " socket
        if [ -z $socket ] ; then
                export socket='/var/lib/mysql/mysql.sock'
        fi

        local tempmycnf
        tempmycnf="$(mktemp)"
        write_mycnf "$tempmycnf" "$socket" "$user" "$pass"

        export MYSQL_COMMAND="mysql --defaults-extra-file=$tempmycnf -S $socket -u$user"
        export MYSQLADMIN_COMMAND="mysqladmin --defaults-extra-file=$tempmycnf -S $socket -u$user"

        check_for_socket || \
        check_mysql_login

        if [ $? = 1 ] ; then
                exit 1
        fi
        read -p "Mode to test - banner, file, misc, mem, innodb, [all] : " REPLY
        if [ -z $REPLY ] ; then
                REPLY='all'
        fi
        case $REPLY in
                banner | BANNER | header | HEADER | head | HEAD)
                banner_info
                ;;
                misc | MISC | miscelaneous )
                misc
                ;;
                mem | memory |  MEM | MEMORY )
                memory
                ;;
                file | FILE | disk | DISK )
                file
                ;;
                innodb | INNODB )
                innodb
                ;;
                all | ALL )
                cecho " "
                all
                ;;
                * )
                cecho "Invalid Mode!  Valid options are 'banner', 'misc', 'memory', 'file', 'innodb' or 'all'" boldred
                exit 1
                ;;
        esac
}

## Address environmental differences ##
get_system_info
# echo $ps_socket

mode="$1"
if [ -z "${1-}" ] ; then
  login_validation
  mode='ALL'
elif [ "$1" != "prompt" ] && [ "$1" != "PROMPT" ] ; then
  login_validation
fi

case $mode in
  all | ALL )
    cecho " "
    all
    ;;
  mem | memory |  MEM | MEMORY )
    cecho " "
    memory
    ;;
  file | FILE | disk | DISK )
    cecho " "
    file
    ;;
  banner | BANNER | header | HEADER | head | HEAD )
    banner_info
    ;;
  misc | MISC | miscelaneous )
    cecho " "
    misc
    ;;
  innodb | INNODB )
    banner_info
    check_innodb_status ; echo
    ;;
  prompt | PROMPT )
    prompt
    ;;
  debug | DEBUG )
    # Run everything, then dump state.
    all >/dev/null
    env
    ;;
  *)
    cecho "usage: $0 [ all | banner | file | innodb | memory | misc | prompt ]" boldred
    exit 1
    ;;
esac
