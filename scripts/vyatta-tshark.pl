#!/usr/bin/perl
#
# Module: vyatta-tshark-interface-port.pl
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
# Portions created by Vyatta are Copyright (C) 2006, 2007, 2008 Vyatta, Inc.
# All Rights Reserved.
#
# Author: John Southworth
# Date: Sept. 2011
# Description: run tshark on a given interface with options
#
# **** End License ****
#

use lib "/opt/vyatta/share/perl5/";

use strict;
use warnings;
use Getopt::Long;

sub check_if_interface_is_tsharkable {
    my $interface = shift;
    
    my @grep_tshark_interfaces = `sudo /usr/bin/tshark -D | grep $interface`;
    my $any_interface;

    for my $count (0 .. $#grep_tshark_interfaces) {
     my @temp = split(/ /,$grep_tshark_interfaces[$count]);
     chomp $temp[1];
     $grep_tshark_interfaces[$count] = $temp[1];
    }
    
    my $exact_match = 0;
    for my $count (0 .. $#grep_tshark_interfaces) {
        if ($grep_tshark_interfaces[$count] eq $interface) {
            $exact_match = 1;
            $any_interface = $grep_tshark_interfaces[$count];
        }
    }
    if ($exact_match == 0 || $any_interface eq 'any') {
        print "Unable to capture traffic on $interface\n";
        exit 1;
    }
}

#
# main
#
my ($detail,$filter,$intf,$unlimited,$save);

GetOptions("detail!"                => \$detail,
           "filter=s"               => \$filter,
           "save=s"                 => \$save,
           "intf=s"                 => \$intf,
           "unlimited!"             => \$unlimited);

check_if_interface_is_tsharkable($intf);

if (defined($save)){
  exec "sudo /usr/bin/tshark -i $intf -w '$save' | grep -v root"; 
  exit 0;
}

if (defined($filter)) {
  if (defined($detail)) { 
    if (defined($unlimited)){
      print "Capturing traffic on $intf ...\n";
      exec "sudo /usr/bin/tshark -n -i $intf -V $filter 2> /dev/null";
    } else {
      print "Capturing traffic on $intf ...\n";
      exec "sudo /usr/bin/tshark -n -i $intf -c 1000 -V $filter 2> /dev/null";
    }
  } elsif (defined($unlimited)) {
    print "Capturing traffic on $intf ...\n";
    exec "sudo /usr/bin/tshark -n -i $intf  $filter 2> /dev/null";
  } else {
    print "Capturing traffic on $intf ...\n";
    exec "sudo /usr/bin/tshark -n -i $intf -c 1000  $filter 2> /dev/null";
  }
} elsif (defined($detail)) {
    if (defined($unlimited)) {
      print "Capturing traffic on $intf ...\n";
      exec "sudo /usr/bin/tshark -n -i $intf -V 2> /dev/null";
    } else {
      print "Capturing traffic on $intf ...\n";
      exec "sudo /usr/bin/tshark -n -i $intf -c 1000 -V 2> /dev/null";
    }
} elsif (defined($unlimited)) {
  print "Capturing traffic on $intf ...\n";
  exec "sudo /usr/bin/tshark -n -i $intf 2> /dev/null";
} else {
  print "Capturing traffic on $intf ...\n";
  exec "sudo /usr/bin/tshark -n -i $intf -c 1000 2> /dev/null";
}

exit 0;

#end of file
