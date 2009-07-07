#!/usr/bin/perl
#
# Module: vyatta-show-interfaces.pl
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
# Author: Stephen Hemminger
# Date: September 2008
# Description: Script to display bonding information
#
# **** End License ****
#

use lib "/opt/vyatta/share/perl5/";
use Getopt::Long;
use Vyatta::Misc;
use Vyatta::Interface;

use strict;
use warnings;

sub usage {
    print "Usage: $0 --brief\n";
    print "       $0 interface(s)\n";
    exit 1;
}

sub get_state_link {
    my $intf = shift;
    my $state;
    my $link = 'down';
    my $flags = get_sysfs_value( $intf, 'flags' );

    my $hex_flags = hex($flags);
    if ( $hex_flags & 0x1 ) {    # IFF_UP
        $state = 'up';
        my $carrier = get_sysfs_value( $intf, 'carrier' );
        if ( $carrier eq '1' ) {
            $link = "up";
        }
    }
    else {
        $state = 'down';
    }

    return ( $state, $link );
}

my @modes = (	"round-robin",
	"active-backup",
	"xor-hash",
	"broadcast",
	"802.3ad",
	"transmit-load-balance",
	"adaptive-load-balance"
);

sub show_brief {
    my @interfaces = grep { /^bond[\d]+$/ } getInterfaces();
    my $format     = "%-12s %-22s %-8s %-6s %s\n";

    printf $format, 'Interface', 'Mode', 'State', 'Link', 'Slaves';
    foreach my $intf (sort @interfaces) {
	die "Invalid bonding interface: $intf\n"
	    unless (-d "/sys/class/net/$intf/bonding" );

        my $mode = get_sysfs_value( $intf, "bonding/mode" );
        my ( $name, $num ) =  split (/ /, $mode);
	$mode = $modes[$num] ? $modes[$num] : $name;

        my ( $state, $link ) = get_state_link($intf);
        my $slaves = get_sysfs_value( $intf, "bonding/slaves" );
        printf $format, $intf, $mode, $state, $link, 
		$slaves ? $slaves : '';
    }
    exit 0;
}

sub show {
    my @interfaces = @_;
    my $format     = "%-16s %-10s %-10s  %-10s %-10s\n";

    printf $format, "Interface", "RX: bytes", "packets", "TX: bytes", "packets";
    foreach my $intf (sort @interfaces) {
	die "Invalid bonding interface: $intf\n"
	    unless (-d "/sys/class/net/$intf/bonding" );

	my $slaves = get_sysfs_value( $intf, "bonding/slaves" );
	next unless $slaves;

        printf $format, $intf, get_sysfs_value( $intf, "statistics/rx_bytes" ),
          get_sysfs_value( $intf, "statistics/rx_packets" ),
          get_sysfs_value( $intf, "statistics/tx_bytes" ),
          get_sysfs_value( $intf, "statistics/tx_packets" );

        foreach my $slave (sort split( / /, $slaves)) {
            printf $format, '    ' . $slave,
              get_sysfs_value( $slave, "statistics/rx_bytes" ),
              get_sysfs_value( $slave, "statistics/rx_packets" ),
              get_sysfs_value( $slave, "statistics/tx_bytes" ),
              get_sysfs_value( $slave, "statistics/tx_packets" );
        }
    }
}

my $brief;
GetOptions( 'brief' => \$brief, ) or usage();

show_brief() if ($brief);
show(@ARGV);

