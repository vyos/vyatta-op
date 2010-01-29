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
# Author: Mohit Mehta
# Date: April 2008
# Description: tshark on a given port for a given interface from vyatta cli
#
# **** End License ****
#

use lib "/opt/vyatta/share/perl5/";

use strict;
use warnings;

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

my $intf = $ARGV[0];

check_if_interface_is_tsharkable($intf);

if ($#ARGV > 0){
    my $port = $ARGV[1];
    my $not_port = $ARGV[2];
    if ($port =~ /[a-zA-Z]/){
        print "Port number has to be numeric. Allowed values: <1-65535>\n";
        exit 1;
    } else {
           if (($port > 0) and ($port < 65536)){
              if ($not_port == 0){
                 print "Capturing traffic on $intf port $port ...\n";
                 exec "sudo /usr/bin/tshark -n -i $intf port $port 2> /dev/null";
              } else {
                 print "Capturing traffic on $intf excluding port $port ...\n";
                 exec "sudo /usr/bin/tshark -n -i $intf not port $port 2> /dev/null";
              }
           } else {
                print "Invalid port number. Allowed values: <1-65535>\n";
                exit 1;
           }

    }
} else {
       print "Capturing traffic on $intf ...\n";
       exec "sudo /usr/bin/tshark -n -i $intf 2> /dev/null";
}

exit 0;

#end of file
