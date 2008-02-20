#!/usr/bin/perl
#
# Module: vyatta-show-dhclient.pl
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

    # todo: fix sorting for ethX > 9
    my @lease_files;
    my $LS;
    if ($intf eq "all") {
	my $file = "dhclient_eth";
	open($LS,"ls $lease_dir |grep '^$file.*\_lease\$' | sort |");
    } else {
	my $file = "dhclient_$intf";
	open($LS,"ls $lease_dir |grep '^$file\_lease\$' | sort |");
    }
    @lease_files = <$LS>;
    close($LS);
    foreach my $i (0 .. $#lease_files) {
	$lease_files[$i] = "$lease_dir/$lease_files[$i]";
    }
    chomp  @lease_files;
    return @lease_files;
}

sub dhclient_parse_vars {
    my ($file) = @_;

    my %var_list;
    if ( !(-f $file)) {
	return %var_list;
    }
	
    open(FD, "<$file");
    my $line;
    $line = <FD>;
    chomp $line;
    $var_list{'last_update'} = $line;
    while ($line = <FD>) {
	chomp $line;
	if ($line =~ m/(\w+)=\'([\w\s.]+)\'/) {
	    my $var = $1;
	    my $val = $2;
	    $var_list{$var} = $val;
	} 
    }
    close(FD);

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

    my $old_ip_address          = $var_list{'old_ip_address'};
    my $old_subnet_mask         = $var_list{'old_subnet_mask'};
    my $old_domain_name         = $var_list{'old_domain_name'};
    my $old_domain_name_servers = $var_list{'old_domain_name_servers'};
    my $old_routers             = $var_list{'old_routers'};

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
    print "domain name: $new_domain_name\n" if defined $new_domain_name;
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
foreach my $file (@dhclient_files) {
    dhclient_show_lease($file);
}

exit 0;

#end of file
