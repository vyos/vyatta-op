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

sub get_community {
    my $snmpcfg = '/etc/snmp/snmpd.conf';

    open (my $cfg, '<', $snmpcfg)
	or return;
    my $community;
    while (<$cfg>) {
	next unless m/^r[ow]community (\w+)/;
	$community = $1;
	last;
    }
    close $cfg;
    return $community;
}

my $community = get_community();
die "No SNMP communities configured\n"
    unless $community;

exec 'snmpstatus', '-c', $community, '-v', '1', 'localhost'
    or die "Can't exec snmpstatus: $!";
