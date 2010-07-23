#!/usr/bin/perl

# Author: Deepti Kulkarni 
# Date: May 2010 
# Description: script to save file remotely. 

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
# Portions created by Vyatta are Copyright (C) 2006, 2007, 2008 Vyatta, Inc.
# All Rights Reserved.
# **** End License ****

use strict;
use lib "/opt/vyatta/share/perl5";

my $save_file;

if (defined($ARGV[0])) {
  $save_file = $ARGV[0];
}
my $tmp_file = $ARGV[1];
my $flag = $ARGV[2];

my $mode = 'local';
my $proto;

if ($save_file =~ /^[^\/]\w+:\//) {
  
if ($save_file =~ /^(\w+):\/\/\w/) {
    $mode = 'url';
    $proto = lc($1);
    if ($proto eq 'ftp') {
    } 
    elsif ($proto eq 'scp') {
    } else {
      print "Invalid url protocol [$proto]\n";
      exit 1;
    }
  } else {
    print "Invalid url [$save_file]\n";
    exit 1;
  }
}
if ($flag == 0)
{
 $save_file=$save_file . ".gz" 
}
if ($flag == 2)
{
 $save_file=$save_file . ".tgz"
}
if ($mode eq 'url') {
  print "Saving output to $save_file\n"; 
  my $rc = system("curl -# -T $tmp_file $save_file");
  system("rm -f $tmp_file");
  if ($rc) {
    print "Error saving $save_file\n";
    exit 1;
  }
}

print "Done\n";
exit 0;
