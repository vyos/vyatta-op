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

    if ($intf eq "all") {
	opendir(my $dh, $lease_dir) or die "Can't open $lease_dir: $!";
	@lease_files = grep { /^dhclient_.*_lease$/ } readdir($dh);
	closedir $dh;
    } else {
	my $file = 'dhclient_'. $intf . '_lease';
	@lease_files = ( $file ) if -f "$lease_dir/$file";
    }

    return @lease_files;
}

sub dhclient_parse_vars {
    my $file = shift;

    open (my $f, '<', "$lease_dir/$file")
	or return;

    my %var_list;
    my $line;
    $line = <$f>;
    chomp $line;
    $var_list{'last_update'} = $line;

    while ($line = <$f>) {
	chomp $line;
	if ($line =~ m/(\w+)=\'([\w\s.]+)\'/) {
	    my $var = $1;
	    my $val = $2;
	    $var_list{$var} = $val;
	}
    }
    close $f;

    return %var_list;
}

sub dhclient_show_lease {
    my ($file) = @_;

    my %var_list = dhclient_parse_vars($file);

    my $last_update                = $var_list{'last_update'};
    my $reason                     = $var_list{'reason'};
    my $interface                  = $var_list{'interface'};
    my $new_expiry                 = $var_list{'new_expiry'};
    my $new_dhcp_lease_time        = $var_list{'new_dhcp_lease_time'};
    my $new_ip_address             = $var_list{'new_ip_address'};
    my $new_broadcast_address      = $var_list{'new_broadcast_address'};
    my $new_subnet_mask            = $var_list{'new_subnet_mask'};
    my $new_domain_name            = $var_list{'new_domain_name'};
    my $new_network_number         = $var_list{'new_network_number'};
    my $new_domain_name_servers    = $var_list{'new_domain_name_servers'};
    my $new_routers                = $var_list{'new_routers'};
    my $new_dhcp_server_identifier = $var_list{'new_dhcp_server_identifier'};
    my $new_dhcp_message_type      = $var_list{'new_dhcp_message_type'};

    my $new_expiry_str;
    if (defined $new_expiry) {
	$new_expiry_str = strftime("%a %b %d %R:%S %Z %Y",
				   localtime($new_expiry));
    }

    print "interface  : $interface\n" if defined $interface;
    if (defined $new_ip_address) {
	print "ip address : $new_ip_address\t";
	my $ip_active = `ip addr list $interface`;
	if ($ip_active =~ m/$new_ip_address/) {
	    print "[Active]\n";
	} else {
	    print "[Inactive]\n";
	}
    }
    print "subnet mask: $new_subnet_mask\n" if defined $new_subnet_mask;
    if (defined $new_domain_name) {
      print "domain name: $new_domain_name";
      my $cli_domain_overrides = 0;
      my $if_domain_exists = `grep domain /etc/resolv.conf 2> /dev/null | wc -l`;
      if ($if_domain_exists > 0) {
        my @domain = `grep domain /etc/resolv.conf`;
        for my $each_domain_text_found (@domain) {
               my @domain_text_split = split(/\t/, $each_domain_text_found, 2);
               my $domain_at_start_of_line = $domain_text_split[0];
               chomp $domain_at_start_of_line;
               if ($domain_at_start_of_line eq "domain") {
                   $cli_domain_overrides = 1;
               }
        }
      }
      if ($cli_domain_overrides == 1) {
        print "\t[overridden by domain-name set using CLI]\n";
      } else {
        print "\n";
      }
    }
    print "router     : $new_routers\n" if defined $new_routers;
    print "name server: $new_domain_name_servers\n" if
	defined $new_domain_name_servers;
    print "dhcp server: $new_dhcp_server_identifier\n" if
	defined $new_dhcp_server_identifier;
    print "lease time : $new_dhcp_lease_time\n" if defined $new_dhcp_lease_time;
    print "last update: $last_update\n" if defined $last_update;
    print "expiry     : $new_expiry_str\n" if defined $new_expiry_str;
    print "reason     : $reason\n" if defined $reason;
    print "\n";
}


#
# main
#

my $intf = 'all';
if ($#ARGV >= 0) {
    $intf = $ARGV[0];
}

my @dhclient_files = dhclient_get_lease_files($intf);
foreach my $file (sort @dhclient_files) {
    dhclient_show_lease($file);
}

exit 0;

#end of file
