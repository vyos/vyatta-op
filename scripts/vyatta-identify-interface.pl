#!/usr/bin/perl
#
# Module: vyatta-identify-interface.pl
# 
# **** License ****
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# This code was originally developed by Vyatta, Inc.
# Portions created by Vyatta are Copyright (C) 2007 Vyatta, Inc.
# All Rights Reserved.
# 
# Author: An-Cheng Huang
# Date: February 2008
# Description: Script to visually identify an interface
# 
# **** End License ****

use strict;

my $intf = shift;

if (!($intf =~ /^eth\d+/)) {
  print STDERR "This command only supports Ethernet interfaces\n";
  exit 1;
}

if (! -e "/sys/class/net/$intf") {
  print STDERR "\"$intf\" is not a valid interface\n";
  exit 1;
}

my $cpid = fork();
if ($cpid == 0) {
  # child
  print "Interface $intf should be blinking now.\n";
  print "Press Enter to stop...\n";
  exec("/sbin/ethtool -p $intf");
  # not reachable
  exit 0;
} else {
  # parent
  my $c = 0;
  while (($c = getc) ne "\n") {
  }
  kill 9, $cpid;
  waitpid $cpid, 0;
}

exit 0;

