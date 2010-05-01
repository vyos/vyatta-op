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


#
# Main section
#

# Figure out where the images live...
my $imagedir = "/live/image/boot";
if (! -e $imagedir) {
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
	$string = `du -s $imagedir/$image`;
	($total, $garbage) = split(' ', $string);
	$string = `du -s $imagedir/$image/*.squashfs`;
	($read_only, $garbage) = split(' ', $string);
	$read_write = $total - $read_only;
	printf("%-30s %12d %12d %12d\n", $image, $read_only, $read_write,
	       $total);
    }
}
