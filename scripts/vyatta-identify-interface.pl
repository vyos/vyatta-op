#!/usr/bin/perl
#
# Module: vyatta-identify-interface.pl
# 
# **** License ****
# Version: VPL 1.0
# 
# The contents of this file are subject to the Vyatta Public License
# Version 1.0 ("License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.vyatta.com/vpl
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
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
  exec("ethtool -p $intf");
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

