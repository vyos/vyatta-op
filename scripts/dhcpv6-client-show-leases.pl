#!/usr/bin/perl

# Module: dhcpv6-client-show-leases.pl
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
# A copy of the GNU General Public License is available as
# `/usr/share/common-licenses/GPL' in the Debian GNU/Linux distribution
# or on the World Wide Web at `http://www.gnu.org/copyleft/gpl.html'.
# You can also obtain it by writing to the Free Software Foundation,
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
# This code was originally developed by Vyatta, Inc.
# Portions created by Vyatta are Copyright (C) 2010 Vyatta, Inc.
# All Rights Reserved.
#
# Author: Bob Gilligan
# Date: April 2010
# Description: Script to display DHCPv6 client leases in a user-friendly form
#
# **** End License ****

use strict;
use lib "/opt/vyatta/share/perl5/";

use Getopt::Long;
use Vyatta::Config;


# Globals
my $debug_flag = 0;

GetOptions(
    "debug"     => \$debug_flag,
    );


sub log_msg {
    my $message = shift;

    print "DEBUG: $message" if $debug_flag;
}


#
# Main section.
#

opendir (my $dir, "/var/lib/dhcp3");
my @lease_files;
while (my $f = readdir $dir) {
    if ($f =~ /^dhclient_v6_(\w+).leases$/) {
	push (@lease_files, $f);
    }
}
closedir $dir;

if ($debug_flag) {
    print "lease files:", join(' ',@lease_files), "\n";
}

# Holds the most recent (last) entry for each interface
my %ghash = ();

foreach my $lease_filename (@lease_files) {
    my @lines=();

    open(my $f, '<', "/var/lib/dhcp3/$lease_filename")
	or die "Can't open lease file for reading:  $lease_filename\n";

    @lines = <$f>;
    close $f;
    chomp @lines;

    my $level = 0;
    my $s1;
    my $s2;
    my $ia_na;
    my $iaaddr;
    my $ends_day;
    my $ends_time;
    my $ifname;
    my $starts;
    my $pref_life;
    my $max_life;
    my $binding_state;

    # Parse the leases file into a hash keyed by IPv6 addr.
    foreach my $line (@lines) {
	log_msg("Line: $line\n");
	if ($line =~ /^lease6 \{/) {
	    if ($level != 0) {
		printf("Found lease6 at level $level\n");
		exit 1;
	    }
	    $level++;
	} elsif ($line =~ /^.*ia-na .*\{/) {
	    if ($level != 1) {
		printf("Found ia-na at level $level\n");
		exit 1;
	    }
	    log_msg("setting ia_na\n");
	    ($s1, $ia_na, $s2) = split(' ', $line);
	    $level++;
	} elsif ($line =~ /^.*interface /) {
	    if ($level != 1) {
		printf("Found interface at level $level\n");
		exit 1;
	    }
	    ($s1, $ifname) = split(' ', $line);
	    $ifname =~ s/;//;
	    $ifname =~ s/\"//g;
	    log_msg("Setting ifname to $ifname\n");
	} elsif ($line =~ /^.*iaaddr .*\{/) {
	    if ($level != 2) {
		printf("Found iaaddr at level $level\n");
		exit 1;
	    }
	    ($s1, $iaaddr, $s2) = split(' ', $line);
	    log_msg("Setting iaaddr to $iaaddr.\n");
	    log_msg("s1 $s1 s2 $s2\n");
	    $level++;
	} elsif ($line =~ /^.*starts /) {
	    ($s1, $starts) = split(' ', $line);
	    $starts =~ s/;//;
	} elsif ($line =~ /^.*preferred-life /) {
	    ($s1, $pref_life) = split(' ', $line);
	    $pref_life =~ s/;//;
	} elsif ($line =~ /^.*max-life /) {
	    ($s1, $max_life) = split(' ', $line);
	    $max_life =~ s/;//;
	} elsif ($line =~ /^.*ends /) {
	    if ($level != 2) {
		printf("Found ends at level $level\n");
		exit 1;
	    }
	    log_msg("Setting ends_day ends_time\n");
	    ($s1, $s2, $ends_day, $ends_time) = split(' ', $line);
	    $ends_time =~ s/;//;
	} elsif ($line =~ /^.*binding state /) {
	    if ($level != 2) {
		printf("Found binding state at level $level\n");
		exit 1;
	    }
	    log_msg("Setting binding state\n");
	    ($s1, $s2, $binding_state) = split(' ', $line);
	    $binding_state =~ s/;//;
	} elsif ($line =~ /^.*\{/) {
	    log_msg("Unknown clause: $line\n");
	    $level++;
	} elsif ($line =~ /\}$/) {
	    $level--;
	    if ($level == 0) {
		if (!defined($ia_na)) {
		    printf("ia_na not defined\n");
		    exit 1;
		}

		if (!defined($iaaddr)) {
		    printf("iaaddr not defined\n");
		    exit 1;
		}
	    }
	} else {
	    log_msg("Unknown parameter: $line\n");
	}
    }

    my @array = ($ia_na, $iaaddr, $starts, $max_life, $pref_life);
    $ghash{$ifname} = \@array;
}

# Display the leases...

my $num_entries = scalar(keys %ghash);
if ($num_entries == 0) {
    printf("There are no DHCPv6 leases.\n");
    exit 0;
} else {
    printf("DHCPv6 client leases:\n");
}

printf("\n");
printf("Interface IPv6 Address                            Expires\n");
printf("--------- --------------------------------------- ------------------------\n");
foreach my $key (keys %ghash) {
    my $entry = $ghash{$key};
    my ($ia_na, $iaaddr, $starts, $max_life, $pref_life) = @$entry;
    my $ts;
    if (defined ($starts) && defined ($max_life)) {
	my $exp_time = $starts + $max_life;
	$ts = localtime($exp_time);
    } else {
	$ts = "Unknown";
    }
    printf ("%-9s %-39s %s\n", $key, $iaaddr, $ts);
}



