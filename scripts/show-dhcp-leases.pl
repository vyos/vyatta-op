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
# Portions created by Vyatta are Copyright (C) 2007-2013 Vyatta, Inc.
# All Rights Reserved.
# 
# Author: Stephen Hemminger
# Date: January 2010
# Description: Show DHCP leases
# 
# **** End License ****

use strict;

opendir (my $dir, "/var/lib/dhcp3");
my @leases;
while (my $f = readdir $dir) {
    ($f =~ /^dhclient_([\w.]+)_lease$/) && push @leases, $1;
}
closedir $dir;

print join(' ',@leases), "\n";
