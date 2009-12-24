#!/usr/bin/perl
#
# Module: vyatta-show-dhclient.pl
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
# Author: Stig Thormodsrud
# Date: January 2008
# Description: Script to display dhcp client lease info
#
# **** End License ****
#

use lib "/opt/vyatta/share/perl5/";
use POSIX;
use strict;
use warnings;

my $lease_dir = '/var/lib/dhcp3';

sub dhclient_get_lease_files {
    my ($intf) = @_;
    my @lease_files;

    if ( $intf eq "all" ) {
        opendir( my $dh, $lease_dir ) or die "Can't open $lease_dir: $!";
        @lease_files = grep { /^dhclient_.*_lease$/ } readdir($dh);
        closedir $dh;
    }
    else {
        my $file = 'dhclient_' . $intf . '_lease';
        @lease_files = ($file) if -f "$lease_dir/$file";
    }

    return @lease_files;
}

sub dhclient_parse_vars {
    my $file = shift;

    open( my $f, '<', "$lease_dir/$file" )
      or return;

    my %var_list;
    my $line;
    $line = <$f>;
    chomp $line;
    $var_list{'last_update'} = $line;

    while ( $line = <$f> ) {
        chomp $line;
        if ( $line =~ m/(\w+)=\'([\w\s.]+)\'/ ) {
            my $var = $1;
            my $val = $2;
            $var_list{$var} = $val;
        }
    }
    close $f;

    return %var_list;
}

# Get current domain (if any) defined in resolv.conf
sub resolve_domain {
    open( my $rc, '<', '/etc/resolv.conf' )
      or return;

    while (<$rc>) {
        next unless m/^domain (\S+)/;
        return $1;
    }
}

sub dhclient_show_lease {
    my ($file) = @_;

    my %var_list = dhclient_parse_vars($file);

    my $interface = $var_list{'interface'};
    print "interface  : $interface\n" if defined $interface;

    my $new_ip_address = $var_list{'new_ip_address'};
    if ($new_ip_address) {
        print "ip address : $new_ip_address\t";
        my $ip_active = `ip addr list $interface`;
        if ( $ip_active =~ m/$new_ip_address/ ) {
            print "[Active]\n";
        }
        else {
            print "[Inactive]\n";
        }
    }

    my $new_subnet_mask = $var_list{'new_subnet_mask'};
    print "subnet mask: $new_subnet_mask\n" if defined $new_subnet_mask;

    my $new_domain_name = $var_list{'new_domain_name'};
    if ($new_domain_name) {
        print "domain name: $new_domain_name";
        my $cur_domain = resolve_domain();
        print "\t[overridden by domain-name set using CLI]"
          if ( defined $cur_domain && $cur_domain ne $new_domain_name );
        print "\n";
    }

    my $new_routers = $var_list{'new_routers'};
    print "router     : $new_routers\n" if defined $new_routers;

    my $new_domain_name_servers = $var_list{'new_domain_name_servers'};
    print "name server: $new_domain_name_servers\n"
      if defined $new_domain_name_servers;

    my $new_dhcp_server_identifier = $var_list{'new_dhcp_server_identifier'};
    print "dhcp server: $new_dhcp_server_identifier\n"
      if defined $new_dhcp_server_identifier;

    my $new_dhcp_lease_time = $var_list{'new_dhcp_lease_time'};
    print "lease time : $new_dhcp_lease_time\n" if defined $new_dhcp_lease_time;

    my $last_update = $var_list{'last_update'};
    print "last update: $last_update\n"    if defined $last_update;

    my $new_expiry = $var_list{'new_expiry'};
    my $new_expiry_str;
    if ($new_expiry) {
        $new_expiry_str =
          strftime( "%a %b %d %R:%S %Z %Y", localtime($new_expiry) );
    }

    print "expiry     : $new_expiry_str\n" if defined $new_expiry_str;

    my $reason = $var_list{'reason'};
    print "reason     : $reason\n" if defined $reason;
    print "\n";
}

#
# main
#

my $intf = 'all';
if ( $#ARGV >= 0 ) {
    $intf = $ARGV[0];
}

my @dhclient_files = dhclient_get_lease_files($intf);
foreach my $file ( sort @dhclient_files ) {
    dhclient_show_lease($file);
}

exit 0;
