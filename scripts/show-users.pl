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
# Date: Sept 2009
# Description: Show password accounts
# 
# **** End License ****

use lib "/opt/vyatta/share/perl5";
use Vyatta::Config;
use IO::Seekable;

use strict;
use warnings;

sub usage {
    print "Usage: $0 {type}\n";
    print " type := all | vyatta | locked | other | color\n";
    exit 1;
}

use constant {
    VYATTA	=> 0x1,
    OTHER	=> 0x2,
    LOCKED	=> 0x4,
};

my %filters = (
    'vyatta'	=> VYATTA,
    'other'	=> OTHER,
    'locked'	=> OTHER|LOCKED,
    'all'	=> VYATTA|OTHER|LOCKED,
);

my $filter = 0;
for (@ARGV) {
    my $mask = $filters{$_};
    unless ($mask) {
	warn "Unknown type $_\n";
	usage();
    }
    $filter |= $mask;
}
# Default is everything but locked accounts
$filter |= VYATTA|OTHER if ($filter == 0);

# Read list of Vyatta users
my $cfg = new Vyatta::Config;
$cfg->setLevel('system login user');
my %vuser = map { $_ => 1 } $cfg->listOrigNodes();

# Setup to access lastlog
open (my $lastlog, '<', "/var/log/lastlog")
    or die "can't open /var/log/lastlog:$!";
# Magic values based on binary format of last log
# See /usr/include/bits/utm.h
my $typedef = 'L Z32 Z256';
my $reclen = length(pack($typedef));

sub lastlog {
    my $uid = shift;

    sysseek($lastlog, $uid * $reclen, SEEK_SET)
	or die "seek failed: $!";

    my ($rec, $line, $host, $time);
    if (sysread($lastlog, $rec, $reclen) == $reclen) {
	my ($time, $line, $host) = unpack($typedef, $rec);
	return scalar(localtime($time)), $line, $host
	    if ($time != 0);
    }

    return ("never logged in", "", "");
}


# Walk password file
# Note: this only works as root
my %users;
setpwent();
while ( my ($u, $p, $uid) = getpwent()) {
    my $l = length($p);
    my $status;
    my $flag = 0;

    my $type = defined($vuser{$u}) ? 'vyatta' : 'other';
    if ($type eq 'vyatta') {
	$flag |= VYATTA;
    } elsif ($l != 1) {
	$flag |= OTHER;
    }

    # only works as root, otherwise shadow file is inaccessible
    if ($l == 0) {
	$type .= '!';
    } if ($l == 1) {
	$flag |= LOCKED;
	$type .= '-';
    }

    next if (($flag & $filter) == 0);

    my ($time, $line, $host) = lastlog($uid);
    # fields to printf
    $users{$u} = [ $type, $line, $host, $time ];
}
endpwent();
close $lastlog;

my $fmt =    "%-15s %-7s %-8s %-19s %s\n";
printf $fmt, "Username","Type","Tty", "From","Last login";

foreach my $u (sort keys %users) {
    printf $fmt, $u, @{$users{$u}};
}
