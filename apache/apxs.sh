#!/bin/sh
APXS=`which apxs2 2>/dev/null`
if [ -z "$APXS" ]; then
  APXS=`which apxs 2>/dev/null`
fi

if [ -z "$APXS" ]; then
  if [ -f /usr/sbin/apxs2 ]; then
    APXS=/usr/sbin/apxs2
  elif [ -f /usr/sbin/apxs ]; then
    APXS=/usr/sbin/apxs
  fi
fi

$APXS $@
