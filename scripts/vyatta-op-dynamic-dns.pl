#!/usr/bin/perl
#
# Module: vyatta-op-dynamic-dns.pl
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
# Portions created by Vyatta are Copyright (C) 2008 Vyatta, Inc.
# All Rights Reserved.
#
# Author: Mohit Mehta
# Date: September 2008
# Description: Script to execute op-mode commands for Dynamic DNS
#
# **** End License ****
#

use lib "/opt/vyatta/share/perl5/";
use Getopt::Long;
use Vyatta::Config;
use strict;
use warnings;

sub print_ddns_stats {
    my $ddclient_cache_dir = '/var/cache/ddclient';
    my @ddns_interfaces = get_ddns_interfaces();

    if (@ddns_interfaces > 0){
     foreach my $configuredinterface (@ddns_interfaces) {
       my $no_interface = `ip addr show dev $configuredinterface 2>/dev/null`;
       my $no_ip = `ip addr show dev $configuredinterface 2>/dev/null | grep "inet "`;
       my @all_cached_entries = `grep "^atime" $ddclient_cache_dir/ddclient_$configuredinterface.cache 2>/dev/null`;
       if (@all_cached_entries > 0) {
        foreach my $each_entry (@all_cached_entries) {
         print "interface    : $configuredinterface";
         if ($no_interface eq ""){
          print " [ Interface does not exist ]";
         } elsif ($no_ip eq ""){
          print " [ Currently no IP address ]";
         }
         print "\n";
         my @split_on_ip = split(/ip=/, $each_entry);
         if (@split_on_ip > 1){
          my @ip = split(/,/, $split_on_ip[1]);
          print "ip address   : $ip[0]\n";
         }
         my @split_on_host = split(/host=/, $each_entry);
         my @host = split(/,/, $split_on_host[1]);
         print "host-name    : $host[0]\n";
         my @split_on_atime = split(/atime=/, $each_entry);
         my @atime = split(/,/, $split_on_atime[1]);
         my $prettytime = scalar(localtime($atime[0]));
         print "last update  : $prettytime\n";
         my @split_on_status = split(/status=/, $each_entry);
         my @status = split(/,/, $split_on_status[1]);
         print "update-status: $status[0]\n";
         print "\n";
        }
       } else {
         print "interface    : $configuredinterface";
         if ($no_interface eq ""){
          print " [ Interface does not exist ]";
         } elsif ($no_ip eq ""){
          print " [ Currently no IP address ]";
         } else {
          print " \n[ Status will be updated within 60 seconds ]";
         }
         print "\n\n";
       }
     }
    } else {
           print "Dynamic DNS not configured\n";
    }
    print "\n";
}

sub get_ddns_interfaces {

    my $vyatta_config = new Vyatta::Config;
    $vyatta_config->setLevel("service dns dynamic");
    my @ddns_interfaces = $vyatta_config->listOrigNodes("interface");
    @ddns_interfaces = sort(@ddns_interfaces);
    return (@ddns_interfaces);

}

#
# main
#

my ($show_status, $update_ddns, $interface, $show_interfaces);

GetOptions("show-status!"           => \$show_status,
           "update-ddns!"           => \$update_ddns,
           "interface=s"            => \$interface,
           "show-interfaces!"       => \$show_interfaces);

if (defined $show_status) {
    print_ddns_stats;
}

if (defined $update_ddns && defined $interface) {
    my @ddns_interfaces = get_ddns_interfaces();
    my $interface_configured = 0;
    foreach my $ddns_interface (@ddns_interfaces) {
       if ($ddns_interface eq $interface) {
           $interface_configured = 1;
       }
    }
    if ($interface_configured == 1) {
        system("sudo /opt/vyatta/sbin/vyatta-dynamic-dns.pl --op-mode-update-dynamicdns --interface $interface");
    } else {
        print "$interface has not been configured to send Dynamic DNS updates\n";
    }
}

if (defined $show_interfaces) {
    my @ddns_interfaces = get_ddns_interfaces();
    print "@ddns_interfaces\n";
}

exit 0;

# end of file
