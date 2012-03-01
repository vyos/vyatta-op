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
use IO::Prompt;

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
  if ($proto eq 'scp' && ($rc >> 8) == 51){
      $save_file =~ m/scp:\/\/(.*?)\//;
      my $host = $1;
      if ($host =~ m/.*@(.*)/) {
        $host = $1;
      }
      my $rsa_key = `ssh-keyscan -t rsa $host 2>/dev/null`;
      print "The authenticity of host '$host' can't be established.\n";
      my $fingerprint = `ssh-keygen -lf /dev/stdin <<< \"$rsa_key\" | awk {' print \$2 '}`;
      chomp $fingerprint;
      print "RSA key fingerprint is $fingerprint.\n";
      if (prompt("Are you sure you want to continue connecting (yes/no) [Yes]? ", -tynd=>"y")) {
          mkdir "~/.ssh/";
          open(my $known_hosts, ">>", "$ENV{HOME}/.ssh/known_hosts") 
            or die "Cannot open known_hosts: $!";
          print $known_hosts "$rsa_key\n";
          close($known_hosts);
          $rc = system("curl -# -T $tmp_file $save_file");
          print "\n";
      }
  }
  system("rm -f $tmp_file");
  if ($rc) {
    print "Error saving $save_file\n";
    exit 1;
  }
}

print "Done\n";
exit 0;
