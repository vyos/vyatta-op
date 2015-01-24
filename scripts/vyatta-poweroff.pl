#!/usr/bin/perl
#
# Module: vyatta-poweroff.pl
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
# Based on the original vyatta-reboot script by Stig Thormodsrud
# 
# Author: Alex Harpin
# Date: Jan 2015
# Description: Script to shutdown or schedule a shutdown
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

my $poweroff_job_file = '/var/run/poweroff.job';

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

sub is_poweroff_pending {
    if ( ! -f $poweroff_job_file) {
        return (0, '');
    }
    my $job = `cat $poweroff_job_file`;
    chomp $job;
    my $line = `atq $job`;
    if ($line =~ /\d+\s+(.*)\sa root$/) {
        return (1, $1);
    } else {
        return (0, '');
    }
}

sub do_poweroff {
    my $login = shift;

    syslog("warning", "Poweroff now requested by $login");
    if (!system("sudo /sbin/shutdown -h now")) {
        exec("sudo /usr/bin/killall sshd");
    }
}

sub cancel_poweroff {
    my ($login, $time) = @_;

    my $job = `cat $poweroff_job_file`;
    chomp $job;
    system("atrm $job");
    system("rm $poweroff_job_file");
    syslog("warning", "Poweroff scheduled for [$time] - CANCELED by $login");
}

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

if ($action eq "poweroff") {

    my ($rc, $time) = is_poweroff_pending();
    if ($rc) {
        if (defined $now) {
            cancel_poweroff($login, $time);
            do_poweroff($login);
        } else {
            print "Poweroff already scheduled for [$time]\n";
            exit 1;
        }
    }

    if (defined $now) {
        do_poweroff($login);
    } else {
        if (prompt("Proceed with poweroff? (Yes/No) [No] ", -ynd=>"n")) {
            do_poweroff($login);
        } else {
            print "Poweroff canceled\n";
            exit 1;
        }
    }
}

if ($action eq "poweroff_at") {
    if (! -f '/usr/bin/at') {
        die "Package [at] not installed";
    }

    if (! defined $at_time) {
        die "no at_time specified";
    }

    my ($rc, $rtime) = is_poweroff_pending();
    if ($rc) {
        print "Poweroff already scheduled for [$rtime]\n";
        exit 1;
    }

    my @lines = `echo true | at $at_time 2>&1`;
    my ($err, $job, $time) = parse_at_output(@lines);
    if ($err) {
        print "Invalid time format [$at_time]\n";
        exit 1;
    }
    system("atrm $job");

    print "\nPoweroff scheduled for $time\n\n";
    if (!prompt("Proceed with poweroff schedule? [confirm] ", -y1d=>"y")) {
        print "Poweroff canceled\n";
        exit 1;
    }

    @lines = `echo "sudo /sbin/shutdown -h now && sudo /usr/bin/killall sshd" | at $at_time 2>&1`;
    ($err, $job, $time) = parse_at_output(@lines);
    if ($err) {
        print "Error: unable to schedule poweroff\n";
        exit 1;
    }
    system("echo $job > $poweroff_job_file");
    print "\nPoweroff scheduled for $time\n";
    syslog("warning", "Poweroff scheduled for [$time] by $login");

    exit 0;
}

if ($action eq "poweroff_cancel") {

    my ($rc, $time) = is_poweroff_pending();
    if (! $rc) {
        print "No poweroff currently scheduled\n";
        exit 1;
    }
    cancel_poweroff($login, $time);
    print "Poweroff canceled\n";
    exit 0;
}

if ($action eq "show_poweroff") {

    my ($rc, $time) = is_poweroff_pending();
    if ($rc) {
        print "Poweroff scheduled for [$time]\n";
        exit 0;
    } else {
        print "No poweroff currently scheduled\n";
    }
    exit 1;
}

exit 1;
