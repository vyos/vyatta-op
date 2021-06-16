#!/bin/sh

if [ -e /var/log/user/"$1" ]
then
   echo -n "" > /var/log/user/"$1"
else
   echo "File does not exist"
fi
