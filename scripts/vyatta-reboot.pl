#!/usr/bin/perl
#
# Module: vyatta-reboot.pl
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
# Author: Stig Thormodsrud
# Date: May 2008
# Description: Script to reboot or schedule a reboot
# 
# **** End License ****
#

use lib "/opt/vyatta/share/perl5/";
use Getopt::Long;
use POSIX;
use IO::Prompt;
use Sys::Syslog qw(:standard :macros);

use strict;
use warnings;

my $reboot_job_file = '/var/run/reboot.job';


sub parse_at_output {
    my @lines = @_;
    
    foreach my $line (@lines) {
	if ($line =~ /error/) {
	    return (1, '', '');
	} elsif ($line =~ /job (\d+) (.*)$/) {
	    return (0, $1, $2);
	} 
    }
    return (1, '', '');
}

sub is_reboot_pending {

    if ( ! -f $reboot_job_file) {
	return (0, '');
    }
    my $job = `cat $reboot_job_file`;
    chomp $job;
    my $line = `atq $job`;
    if ($line =~ /\d+\s+(.*)\sa root$/) {
	return (1, $1);
    } else {
	return (0, '');
    }
}

sub do_reboot {
    my $login = shift;

    syslog("warning", "Reboot now requested by $login");
    exec("sudo /sbin/reboot");
}

sub cancel_reboot {
    my ($login, $time) = @_;

    my $job = `cat $reboot_job_file`;
    chomp $job;
    system("atrm $job");
    system("rm $reboot_job_file");
    syslog("warning", "Reboot scheduled for [$time] - CANCELED by $login");
}

#
# main
#
my ($action, $at_time, $now);
GetOptions("action=s"  => \$action,
	   "at_time=s" => \$at_time,
           "now!"      => \$now,
);

if (! defined $action) {
    die "no action specified";
} 

openlog($0, "", LOG_USER);
my $login = getlogin() || getpwuid($<) || "unknown";

#
# reboot
#
if ($action eq "reboot") {

    my ($rc, $time) = is_reboot_pending();
    if ($rc) {
        if (defined $now) {
            cancel_reboot($login, $time);
            do_reboot($login);
        } else {
            print "Reboot already scheduled for [$time]\n";
            exit 1;
        }
    }

    if (defined $now) {
        do_reboot($login);
    } else {
        if (defined($ENV{VYATTA_PROCESS_CLIENT} && $ENV{VYATTA_PROCESS_CLIENT} eq 'gui2_rest') || 
	    prompt("Proceed with reboot? (Yes/No) [No] ", -ynd=>"n")) {
            do_reboot($login);
	} else {
	    print "Reboot canceled\n";
	    exit 1;
        }
    }
}

#
# reboot_at
#
if ($action eq "reboot_at") {
    if (! -f '/usr/bin/at') {
	die "Package [at] not installed";
    }

    if (! defined $at_time) {
	die "no at_time specified";
    }

    my ($rc, $rtime) = is_reboot_pending();
    if ($rc) {
	print "Reboot already scheduled for [$rtime]\n";
	exit 1;
    }

    #
    # check if the time format is valid, then
    # remove that job
    #
    my @lines = `echo true | at $at_time 2>&1`;
    my ($err, $job, $time) = parse_at_output(@lines);
    if ($err) {
	print "Invalid time format [$at_time]\n";
	exit 1;
    }
    system("atrm $job");

    print "\nReload scheduled for $time\n\n";
    if (!defined($ENV{VYATTA_PROCESS_CLIENT}) || $ENV{VYATTA_PROCESS_CLIENT} ne 'gui2_rest') {
	if (! prompt("Proceed with reboot schedule? [confirm]", -y1d=>"y")) {
	    print "Reboot canceled\n";
	    exit 1;
	}
    }

    @lines = `echo sudo /sbin/reboot | at $at_time 2>&1`;
    ($err, $job, $time) = parse_at_output(@lines);
    if ($err) {
	print "Error: unable to schedule reboot\n";
	exit 1;
    }
    system("echo $job > $reboot_job_file");
    print "\nReboot scheduled for $time\n";
    syslog("warning", "Reboot scheduled for [$time] by $login");

    exit 0;
}

#
# reboot_cancel
#
if ($action eq "reboot_cancel") {

    my ($rc, $time) = is_reboot_pending();
    if (! $rc) {
	print "No reboot currently scheduled\n";
	exit 1;
    }
    cancel_reboot($login, $time);
    print "Reboot canceled\n";
    exit 0;
}

#
# show_reboot
#
if ($action eq "show_reboot") {

    my ($rc, $time) = is_reboot_pending();
    if ($rc) {
	print "Reboot scheduled for [$time]\n";
	exit 0;
    } else {
	print "No reboot currently scheduled\n";
    }
    exit 1;
}

exit 1;

# end of file
