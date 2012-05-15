#!/usr/bin/env perl
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
# Portions created by Vyatta are Copyright (C) 2007-2012 Vyatta, Inc.
# All Rights Reserved.
# 
# Author: John Southworth
# Date: May 2012  
# Description: Process operational data from keepalived
# 
# **** End License ****
#

use strict;
use lib "/opt/vyatta/share/perl5";

use Getopt::Long;
use Vyatta::VRRP::OPMode;
use Sort::Versions;
use v5.10;

my ($show, $intf, $vrid);
GetOptions("show=s" => \$show,
           "intf=s" => \$intf,
           "vrid=s" => \$vrid
          );

sub list_vrrp_intf {
  my $intf = shift; 
  my $hash = {};
  process_data $hash;
  if ($intf) {
    printf "%s\n", join " ", sort versioncmp keys(%{$hash->{instances}->{$intf}});
  } else {
    printf "%s\n", join " ", sort versioncmp keys(%{$hash->{instances}});
  }
}

sub list_vrrp_sync_groups {
    my $hash = {};
    process_data $hash;
    printf "%s\n", join " ", sort versioncmp keys(%{$hash->{'sync-groups'}});
}

sub show_vrrp_summary {
  my ($intf, $vrid) = @_;
  my $hash = {};
  process_data $hash;
  return if (check_intf($hash, $intf, $vrid));
  print_summary $hash, $intf, $vrid;
}

sub show_vrrp_stats {
  my ($intf, $vrid) = @_;
  my $hash = {};
  process_stats $hash;
  return if (check_intf($hash, $intf, $vrid));
  print_stats $hash, $intf, $vrid;
}

sub show_vrrp_detail {
  my ($intf, $vrid) = @_;
  my $hash = {};
  process_data $hash;
  return if (check_intf($hash, $intf, $vrid));
  print_detail $hash, $intf, $vrid;
}

sub show_vrrp_sync_groups {
  my $sync = shift;
  my $hash = {};
  process_data $hash;
  if ($sync && !exists($hash->{'sync-groups'}->{$sync})){
    print "Sync-group: $sync does not exist\n";
    return;
  }
  print_sync $hash, $intf;
}

given ($show) {
  when ('summary') {
    show_vrrp_summary $intf, $vrid;
  }
  when ('detail') {
    show_vrrp_detail $intf, $vrid;
  }
  when ('stats') {
    show_vrrp_stats $intf, $vrid;
  }
  when ('sync') {
    show_vrrp_sync_groups $intf;
  }
  when ('interface') {
    list_vrrp_intf $intf;
  }
  when ('syncs') {
    list_vrrp_sync_groups;
  }
  default {
    exit;
  }
}


