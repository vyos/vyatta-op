#! /usr/bin/perl

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
# Author: Stephen Hemminger
# Date: January 2010
# Description: Script to display SNMP information
# 
# **** End License ****
#
use strict;
use warnings;
use Getopt::Long;
use NetAddr::IP;

my $SNMPDCFG   = '/etc/snmp/snmpd.conf';
my $SNMPSTATUS = '/usr/bin/snmpstatus';
my $password_file = '/config/snmp/superuser_pass';

# generate list of communities in configuration file
sub read_config {
    my %community;

    die "Service SNMP does not configured.\n" if (! -e $SNMPDCFG);

    open( my $cfg, '<', $SNMPDCFG )
      or die "Can't open $SNMPDCFG : $!\n";

    while (<$cfg>) {
        chomp;
        s/#.*$//;
        my @cols = split;
        next
          unless ( $#cols > 0
            && ( $cols[0] eq 'rocommunity' || $cols[0] eq 'rwcommunity' ) );

        my $addr = ( $#cols > 1 ) ? $cols[2] : "0.0.0.0/0";
        $community{ $cols[1] } = NetAddr::IP->new($addr);
    }
    close $cfg;

    return \%community;
}

# expand list of available communities for allowed: tag
sub show_all {
    my $community = read_config();

    print join( ' ', keys( %{$community} ) ), "\n";
    exit 0;
}

# check status of any accessible community on localhost
sub status_any {
    my $cref      = read_config();
    my %community = %{$cref};
    my $localhost = new NetAddr::IP('localhost');

    if (scalar(%community)) {
      foreach my $c ( keys %community ) {
        my $addr = $community{$c};
        status( $c, $localhost->addr() ) if ( $addr->contains($localhost) );
      }
    }
    status_v3();

}

sub status_v3 {
    open (my $file, '<' , $password_file) or die "Couldn't open $password_file - $!";
    my $superuser_pass = do { local $/; <$file> };
    close $file;
    open ($file, '<', $SNMPDCFG) or die "Couldn't open $SNMPDCFG - $!";
    my $superuser_login = '';
    while (my $line = <$file>) {
      if ($line =~ /^iquerySecName (.*)$/) {
	$superuser_login = $1;
      }
    }
    close $file;
    exec $SNMPSTATUS, '-v3', '-l', 'authNoPriv', '-u', $superuser_login, '-A', $superuser_pass, 'localhost';
}

# check status of one community
sub status {
    my ( $community, $host ) = @_;
    $host = 'localhost' unless defined($host);

    print "Status of SNMP community $community on $host\n";
    exec $SNMPSTATUS, '-v1', '-c', $community, $host;
    die "Can't exec $SNMPSTATUS : $!";
}

sub usage {
    print "usage: $0 [--community=name [--host=hostname]]\n";
    print "       $0 --allowed\n";
    exit 1;
}

my ( $host, $community, $allowed );

GetOptions(
    "host=s"      => \$host,
    "community=s" => \$community,
    "allowed"     => \$allowed,
) or usage();

show_all() if ($allowed);
status( $community, $host ) if ( defined($community) );
status_any();

