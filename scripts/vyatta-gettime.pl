#!/usr/bin/perl
#
# Module: vyatta-gettime.pl
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
# Author: Stephen Hemminger
# Date: March 2009
# Description: Script to read time for shutdown
#
# **** End License ****
#

use strict;
use warnings;
use Date::Format;

sub gettime {
    my $t = shift;

    return time2str( "%R", time ) if ( $t eq 'now' );
    return $t if ( $t =~ /^[0-9]+:[0-9]+/ );
    $t = substr( $t, 1 ) if ( $t =~ /^\+/ );
    return time2str( "%R", time + ( $_ * 60 ) ) if ( $t =~ /^[0-9]+/ );

    die "invalid time format: $t\n";
}

# decode shutdown time
for (@ARGV) {
    print gettime($_), "\n";
}
