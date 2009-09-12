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
use Term::ANSIColor;
use Vyatta::Config;

use strict;
use warnings;

sub usage {
    print "Usage: $0 {type}\n";
    print " type := all | vyatta | locked | other | color\n";
    exit 1;
}

my %pw;
setpwent();
while ( my ($u, $p) = getpwent()) {
    $pw{$u} = $p;
}
endpwent();

my $cfg = new Vyatta::Config;
$cfg->setLevel('system login user');
$cfg->{_active_dir_base} = '/opt/vyatta/config/active/';
my %vuser = map { $_ => 1 } $cfg->listOrigNodes();

sub locked {
    return grep { length($pw{$_}) == 1 } @_;
}

sub nopasswd {
    return grep { length($pw{$_}) == 0 } @_;
}

sub all {
    return @_;
}

sub vyatta {
    return grep { $vuser{$_} } @_;
}

sub other {
    return grep { length($pw{$_}) > 1 && ! defined($vuser{$_}) } @_;
}

sub login_color {
    my $u = shift;
    my $p = $pw{$u};
    my $c;

    if (length($p) == 0) {
	$c = 'blink red';	# open no password!
    } elsif ($vuser{$u}) {
	$c = 'green';		# vyatta user
    } elsif (length($p) == 1) {
	$c = 'blue';		# locked account
    } else {
	$c = 'yellow';		# non vyatta account
    }
    return color($c) . $u . color('reset');
}

# show non-locked accounts in color
sub colorize {
    return map { login_color($_) } grep { length($pw{$_}) != 1 } @_;
}

my %filters = (
    'all'	=> \&all,
    'vyatta'	=> \&vyatta,
    'locked'	=> \&locked,
    'open'	=> \&nopasswd,
    'other'	=> \&other,
    'color'	=> \&colorize,
);

for (@ARGV) {
    my $func = $filters{$_};
    unless ($func) {
	warn "Unknown type $_\n";
	usage();
    }
    print join("\n", sort($func->(keys %pw))), "\n";
}
