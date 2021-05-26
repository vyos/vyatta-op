#!/bin/sh

if [ -e /var/log/"$1" ]
then
   rm -f /var/log/"$1"
else
   echo "File does not exist"
fi
