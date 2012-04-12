#!/usr/bin/perl

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
# Portions created by Vyatta are Copyright (C) 2010 Vyatta, Inc.
# All Rights Reserved.
#
# Author: Bob Gilligan
# Date: April 30, 2010
# Description: Script to display disk storage used by images
#
# **** End License ****

use strict;
use warnings;
use Getopt::Long;


sub better_units {
    my $units = shift;

    $units =~ s/K/ KB/;
    $units =~ s/M/ MB/;
    $units =~ s/G/ GB/;
    $units =~ s/T/ TB/;
    return $units;
}

#
# Main section
#

# Figure out where the images live...
my $imagedir = "/live/image/boot";
my $livecd = "/live/image/live";
if (! -e $imagedir) {
    if (-d $livecd) {
        die "System running on Live-CD\n";
    } 
    # Must be running on Old non-image system.
    $imagedir = "/boot";
    if (! -e $imagedir) {
	printf("Can't locate system image directory!\n");
	exit 1;
    }
}

my $bootlist=`/opt/vyatta/bin/vyatta-boot-image.pl --list`;

my @bootlist_arr = split(/\n/, $bootlist);

printf("Image name                        Read-Only   Read-Write        Total\n");
printf("------------------------------ ------------ ------------ ------------\n");

foreach my $image (@bootlist_arr) {
    my $total;
    my $read_only;
    my $read_write;
    my $string;
    my $garbage;

    if ( -e "$imagedir/$image") {
	$string = `du -s -h $imagedir/$image`;
	($total, $garbage) = split(' ', $string);
	$total = better_units($total);

	$string = `du -s -h $imagedir/$image --exclude live-rw`;
	($read_only, $garbage) = split(' ', $string);
	$read_only = better_units($read_only);

	$string = `du -s -h $imagedir/$image/live-rw`;
	($read_write, $garbage) = split(' ', $string);
	$read_write = better_units($read_write);

	printf("%-30s %12s %12s %12s\n", $image, $read_only, $read_write,
	       $total);
    }
}
