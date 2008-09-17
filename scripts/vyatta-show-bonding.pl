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
use Getopt::Long;

use strict;
use warnings;

sub usage {
    print "Usage: $0 --brief\n";
    print "       $0 interface(s)\n";
    exit 1;
}

sub get_sysfs_value {
    my ( $intf, $name ) = @_;

    open( my $statf, '<', "/sys/class/net/$intf/$name" )
      or die "Can't open file /sys/class/net/$intf/$name";

    my $value = <$statf>;
    chomp $value if defined $value;
    close $statf;
    return $value;
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

sub show_brief {
    my @interfaces = @_;
    my $format     = "%-12s %-10s %-8s %-6s %s\n";

    printf $format, 'Interface', 'Mode', 'State', 'Link', 'Slaves';
    foreach my $intf (@interfaces) {
        my $mode = get_sysfs_value( $intf, "bonding/mode" );
        $mode =~ s/ [0-9]+$//;
        my ( $state, $link ) = get_state_link($intf);
        my $slaves = get_sysfs_value( $intf, "bonding/slaves" );
        printf $format, $intf, $mode, $state, $link, 
		$slaves ? $slaves : '';
    }
}

sub show {
    my @interfaces = @_;
    my $format     = "%-16s %-10s %-10s  %-10s %-10s\n";

    printf $format, "Interface", "RX: bytes", "packets", "TX: bytes", "packets";
    foreach my $intf (@interfaces) {
        my @slaves = split( / /, get_sysfs_value( $intf, "bonding/slaves" ) );
        printf $format, $intf, get_sysfs_value( $intf, "statistics/rx_bytes" ),
          get_sysfs_value( $intf, "statistics/rx_packets" ),
          get_sysfs_value( $intf, "statistics/tx_bytes" ),
          get_sysfs_value( $intf, "statistics/tx_packets" );

        foreach my $slave (@slaves) {
            printf $format, '    ' . $slave,
              get_sysfs_value( $intf, "statistics/rx_bytes" ),
              get_sysfs_value( $intf, "statistics/rx_packets" ),
              get_sysfs_value( $intf, "statistics/tx_bytes" ),
              get_sysfs_value( $intf, "statistics/tx_packets" );
        }
    }
}

my $brief;
GetOptions( 'brief' => \$brief, ) or usage();

my @bond_intf = ();

if ( $#ARGV == -1 ) {
    my $sysfs = '/sys/class/net';
    opendir( my $sysdir, $sysfs ) || die "can't opendir $sysfs";
    foreach my $intf ( readdir($sysdir) ) {
        if ( -d "$sysfs/$intf/bonding" ) {
            unshift @bond_intf, $intf;
        }
    }
    close $sysdir;
}
else {
    @bond_intf = @ARGV;
}

if ($brief) {
    show_brief(@bond_intf);
}
else {
    show(@bond_intf);
}
