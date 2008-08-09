#!/usr/bin/perl
#
# Module: vyatta-op-dns-forwarding.pl
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
# Portions created by Vyatta are Copyright (C) 2008 Vyatta, Inc.
# All Rights Reserved.
#
# Author: Mohit Mehta
# Date: August 2008
# Description: Script to execute op-mode commands for DNS forwarding
#
# **** End License ****
#

use lib "/opt/vyatta/share/perl5/";
use Getopt::Long;
use VyattaConfig;
use strict;
use warnings;

my $show_stats_output="";
my $show_nameservers_output="";
my $dnsmasq_log='/var/log/dnsmasq.log';

sub get_cache_stats {
    my ($cache_size, $queries_forwarded, $queries_answered_locally, $entries_inserted, $entries_removed);

    my $grepped_line = `grep 'cache size' $dnsmasq_log`;
    my @split_line = split(/\s+/, $grepped_line);
    my @temp_split = split(/,/, $split_line[6]);
    $cache_size = $temp_split[0];
    @temp_split = split(/\//, $split_line[7]);
    $entries_removed = $temp_split[0];
    $entries_inserted = $temp_split[1];

    $grepped_line = `grep 'queries forwarded' $dnsmasq_log`;
    @split_line = split(/\s+/, $grepped_line);
    @temp_split = split(/,/, $split_line[6]);
    $queries_forwarded = $temp_split[0];
    $queries_answered_locally = $split_line[10];

    $show_stats_output .= "----------------\n";
    $show_stats_output .= "Cache statistics\n";
    $show_stats_output .= "----------------\n";
    $show_stats_output .= "Cache size: $cache_size\n";
    $show_stats_output .= "Queries forwarded: $queries_forwarded\n";
    $show_stats_output .= "Queries answered locally: $queries_answered_locally\n";
    $show_stats_output .= "Total DNS entries inserted into cache: $entries_inserted\n";
    $show_stats_output .= "DNS entries removed from cache before expiry: $entries_removed\n";

}

sub get_nameserver_stats {

    $show_stats_output .= "\n---------------------\n";
    $show_stats_output .= "Nameserver statistics\n";
    $show_stats_output .= "---------------------\n";

    my @grepped_lines = `grep 'server' $dnsmasq_log`;

    foreach my $lines (@grepped_lines) {
            my @each_line = split(/\s+/, $lines);
            my $nameserver_word = $each_line[5];
            my @nameserver_split = split(/#/, $nameserver_word);
            my $nameserver = $nameserver_split[0];
            my $queries_sent_word = $each_line[8];
            my @queries_sent_split = split(/,/, $queries_sent_word);
            my $queries_sent = $queries_sent_split[0];
            my $queries_retried_failed = $each_line[12];

            $show_stats_output .= "Server: $nameserver\nQueries sent: $queries_sent\nQueries retried or failed: $queries_retried_failed\n\n";

    }
}

sub print_stats {
    print $show_stats_output;
}

#
# main
#
my ($clear_cache, $show_statistics, $show_nameservers);

GetOptions("clear-cache!"               => \$clear_cache,
           "show-statistics!"           => \$show_statistics,
           "show-nameservers!"          => \$show_nameservers);

if (defined $clear_cache) {
    system("kill -1 `pidof dnsmasq`");
}

if (defined $show_statistics) {
    system("echo > /var/log/dnsmasq.log; kill -10 `pidof dnsmasq`");
    get_cache_stats;
    get_nameserver_stats;
    print_stats;
}

if (defined $show_nameservers) {

}

exit 0;

# end of file
