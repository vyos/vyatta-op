#!/bin/sh

if [ -e /var/log/user/"$1" ]
then
   rm -f /var/log/user/"$1"
else
   echo "File does not exist"
fi
