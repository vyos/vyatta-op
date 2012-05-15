# 
# Module: Vyatta::VRRP::OPMode
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

package Vyatta::VRRP::OPMode;
use strict;
use warnings;
our @EXPORT = qw(process_data process_stats print_summary print_stats print_sync print_detail check_intf);
use base qw(Exporter);

use Sort::Versions;

my $PIDFILE='/var/run/vrrp.pid';
my $DATAFILE='/tmp/keepalived.data';
my $STATSFILE='/tmp/keepalived.stats';

open my $PIDF, '<', $PIDFILE;
my $PID=<$PIDF>;
close $PIDF;

sub trim {
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string;
}

sub conv_name {
  my $name = shift;
  $name = trim $name;
  $name = lc $name;
  $name =~ s/\s/-/g; 
  return $name;
}

sub add_to_datahash {
  my ($dh, $interface, $instance, $in_sync, $name, $val) = @_;
  $name = conv_name $name;
  if ($in_sync) {
    if ($name eq 'monitor'){
      $dh->{'sync-groups'}->{$instance}->{$name} = 
        [ $dh->{'sync-groups'}->{$instance}->{$name} ? 
          @{$dh->{'sync-groups'}->{$instance}->{$name}} : (),
          $val
        ];
    } else {
      $dh->{'sync-groups'}->{$instance}->{$name} = $val;
    }
  } else {
     $dh->{'instances'}->{$interface}->{$instance}->{$name} = $val;
  }
}

sub process_data {
  my ($dh) = @_;
  my ($instance, $interface, $in_sync, $in_vip);
  kill 'SIGUSR1', $PID;
  open my $DATA, '<',  $DATAFILE;
  while (<$DATA>)
  {
    m/VRRP Instance = vyatta-(.*?)-(.*)/ && do {
      $interface = $1;
      $instance = $2;
      $in_sync = undef;
      $in_vip = undef;
      $dh->{'instances'}->{$interface}->{$instance} = {};
      next;
    };
    m/VRRP Sync Group = (.*?), (.*)/ && do {
      $instance = $1;
      $interface = undef;
      $in_vip = undef;
      my $state = $2;
      $in_sync = 1;
      add_to_datahash $dh, $interface, $instance, $in_sync, 'state', $state;
      next;
    };
    if ($in_vip){
      m/(.*?) dev (.*)/ && do {
        $dh->{'instances'}->{$interface}->{$instance}->{vips} = 
        [ $dh->{'instances'}->{$interface}->{$instance}->{vips} ? 
          @{$dh->{'instances'}->{$interface}->{$instance}->{vips}} : (),
          trim $1 ];
      };
    }
    m/(.*?) = (.*)/ && do {
      $in_vip = undef;
      add_to_datahash $dh, $interface, $instance, $in_sync, $1, $2;
      m/Virtual IP/ && do {$in_vip = 1};
      next;
    };
  }
  close $DATA;
}

sub elapse_time {
    my ($start, $stop) = @_;

    my $seconds   = $stop - $start;
    my $string    = '';
    my $secs_min  = 60;
    my $secs_hour = $secs_min  * 60;
    my $secs_day  = $secs_hour * 24;
    my $secs_week = $secs_day  * 7;

    my $weeks = int($seconds / $secs_week);
    if ($weeks > 0 ) {
        $seconds = int($seconds % $secs_week);
        $string .= $weeks . "w";
    }
    my $days = int($seconds / $secs_day);
    if ($days > 0) {
        $seconds = int($seconds % $secs_day);
        $string .= $days . "d";
    }
    my $hours = int($seconds / $secs_hour);
    if ($hours > 0) {
        $seconds = int($seconds % $secs_hour);
        $string .= $hours . "h";
    }
    my $mins = int($seconds / $secs_min);
    if ($mins > 0) {
        $seconds = int($seconds % $secs_min);
        $string .= $mins . "m";
    }
    $string .= $seconds . "s";

    return $string;
}

sub find_sync {
   my ($intf, $vrid, $dh)  = @_;
   my $instance = "vyatta-$intf-$vrid";
   foreach my $sync (sort versioncmp keys(%{$dh->{'sync-groups'}})){
     return $sync if (grep { $instance } @{$dh->{'sync-groups'}->{$sync}->{monitor}});
   }
   return;
}

sub check_intf {
  my ($hash, $intf, $vrid) = @_;
  if ($intf) {
    if (!exists($hash->{instances}->{$intf})){
      print "VRRP is not running on $intf\n";
      return 1;
    }
    if ($vrid){
      if (!exists($hash->{instances}->{$intf}->{$vrid})){
        print "No VRRP group $vrid exists on $intf\n";
        return 1;
      }
    }
  }
  return;
}


sub print_detail {
  my ($dh,$intf,$group) = @_;
  print "--------------------------------------------------\n";
  foreach my $interface (sort versioncmp keys(%{$dh->{instances}})) {
    next if ($intf && $interface ne $intf);
    printf "Interface: %s\n", $interface;
    printf "--------------\n";
    foreach my $vrid (sort versioncmp keys(%{$dh->{instances}->{$interface}})){
      next if ($group && $vrid ne $group);
      printf "  Group: %s\n", $vrid;
      printf "  ----------\n";
      printf "  State:\t\t\t%s\n", 
        $dh->{instances}->{$interface}->{$vrid}->{state};
      printf "  Last transition:\t\t%s\n", 
        elapse_time($dh->{instances}->{$interface}->{$vrid}->{'last-transition'}, time);
      printf "\n";
      if ( $dh->{instances}->{$interface}->{$vrid}->{state} eq 'BACKUP') {
        printf "  Master router:\t\t%s\n", 
          $dh->{instances}->{$interface}->{$vrid}->{'master-router'};
        printf "  Master priority:\t\t%s\n",
          $dh->{instances}->{$interface}->{$vrid}->{'master-priority'};
        printf "\n";
      }
      if ($dh->{instances}->{$interface}->{$vrid}->{'transmitting-device'} ne 
          $dh->{instances}->{$interface}->{$vrid}->{'listening-device'}){
        printf "  RFC 3768 Compliant\n";
        printf "  Virtual MAC interface:\t%s\n",
          $dh->{instances}->{$interface}->{$vrid}->{'transmitting-device'};
        printf "  Address Owner:\t\t%s\n", 
          ($dh->{instances}->{$interface}->{$vrid}->{priority} == 255) ? 'yes': 'no';
        printf "\n";
      }
      printf "  Source Address:\t\t%s\n",
        $dh->{instances}->{$interface}->{$vrid}->{'using-mcast-src_ip'};
      printf "  Priority:\t\t\t%s\n",
        $dh->{instances}->{$interface}->{$vrid}->{'priority'};
      printf "  Advertisement interval:\t%s\n",
        $dh->{instances}->{$interface}->{$vrid}->{'advert-interval'};
      printf "  Authentication type:\t\t%s\n",
        $dh->{instances}->{$interface}->{$vrid}->{'authentication-type'};
      printf "  Preempt:\t\t\t%s\n",
        $dh->{instances}->{$interface}->{$vrid}->{'preempt'};
      printf "\n";
      my $sync = find_sync($interface, $vrid, $dh);
      if ($sync) {
        printf "  Sync-group:\t\t\t%s\n", $sync;
        printf "\n";
      }
      printf "  VIP count:\t\t\t%s\n",
        $dh->{instances}->{$interface}->{$vrid}->{'virtual-ip'};
      foreach my $vip (@{$dh->{instances}->{$interface}->{$vrid}->{vips}}){
         printf "    %s\n", $vip;
      }
      printf "\n";
    }
  }
}

sub print_summary { 
  my ($dh, $intf, $group) = @_;
  my $format = "%-18s%-7s%-8s%-11s%-7s%-12s%s\n";
  printf $format, '','','','RFC','Addr','Last','Sync';
  printf $format, 'Interface','Group','State','Compliant','Owner','Transition','Group';
  printf $format, '---------','-----','-----','---------','-----','----------','-----';
  foreach my $interface (sort versioncmp keys(%{$dh->{instances}})) {
    next if ($intf && $interface ne $intf);
    foreach my $vrid (sort versioncmp keys(%{$dh->{instances}->{$interface}})){
      next if ($group && $vrid ne $group);
      my $state = $dh->{instances}->{$interface}->{$vrid}->{state};
      my $compliant = 
         ($dh->{instances}->{$interface}->{$vrid}->{'transmitting-device'} ne
          $dh->{instances}->{$interface}->{$vrid}->{'listening-device'}) ? 'yes': 'no';
      my $addr_owner = ($dh->{instances}->{$interface}->{$vrid}->{priority} == 255) ? 'yes': 'no';
      my $lt = elapse_time($dh->{instances}->{$interface}->{$vrid}->{'last-transition'}, time);
      my $sync = find_sync($interface, $vrid, $dh);
      $sync = "<none>" if (!defined($sync));
      printf $format, $interface, $vrid, $state, $compliant, $addr_owner, $lt, $sync;
    }
  }
  printf "\n";
}

sub process_stats {
  my ($sh) = @_;
  my ($instance, $interface, $section);
  kill 'SIGUSR2', $PID;
  open my $STATS, '<', $STATSFILE;
  while (<$STATS>)
  {
    m/VRRP Instance: vyatta-(.*?)-(.*)/ && do {
      $interface = $1;
      $instance = $2;
      $sh->{'instances'}->{$interface}->{$instance} = {};
      next;
    };
    m/Released master: (.*)/ && do {
      $sh->{'instances'}->{$interface}->{$instance}->{'released-master'} = $1;
      next;
    };
    m/Became master: (.*)/ && do {
      $sh->{'instances'}->{$interface}->{$instance}->{'became-master'} = $1;
      next;
    };
    m/(.*?):$/ && do {
      $section = conv_name $1;
      $sh->{'instances'}->{$interface}->{$instance}->{$section} = {};
      next;
    };
    m/(.*?): (.*)/ && do {
      my $id = conv_name $1;
      $sh->{'instances'}->{$interface}->{$instance}->{$section}->{$id} = $2;
      next;
    }; 
    print $_;
  }
 
  close $STATS;
}

sub print_stats {
  my ($sh, $intf, $group) = @_;
  print "--------------------------------------------------\n";
  foreach my $interface (sort versioncmp keys(%{$sh->{instances}})) {
    next if ($intf && $interface ne $intf);
    printf "Interface: %s\n", $interface;
    printf "--------------\n";
    foreach my $vrid (sort versioncmp keys(%{$sh->{instances}->{$interface}})){
      next if ($group && $vrid ne $group);
      printf "  Group: %s\n", $vrid;
      printf "  ----------\n";
      printf "  Advertisements:\n";
      printf "    Received:\t\t\t%d\n", 
        $sh->{instances}->{$interface}->{$vrid}->{advertisements}->{received};
      printf "    Sent:\t\t\t%d\n",
        $sh->{instances}->{$interface}->{$vrid}->{advertisements}->{sent};
      printf "\n";
      printf "  Became master:\t\t%d\n",
        $sh->{instances}->{$interface}->{$vrid}->{'became-master'};
      printf "  Released master:\t\t%d\n",
        $sh->{instances}->{$interface}->{$vrid}->{'released-master'};
      printf "\n";
      printf "  Packet errors:\n";
      printf "    Length:\t\t\t%d\n", 
        $sh->{instances}->{$interface}->{$vrid}->{'packet-errors'}->{length};
      printf "    TTL:\t\t\t%d\n", 
        $sh->{instances}->{$interface}->{$vrid}->{'packet-errors'}->{ttl};
      printf "    Invalid type:\t\t%d\n", 
        $sh->{instances}->{$interface}->{$vrid}->{'packet-errors'}->{'invalid-type'};
      printf "    Advertisement interval:\t%d\n", 
        $sh->{instances}->{$interface}->{$vrid}->{'packet-errors'}->{'advertisement-interval'};
      printf "    Address List:\t\t%d\n", 
        $sh->{instances}->{$interface}->{$vrid}->{'packet-errors'}->{'address-list'};
      printf "\n";
      printf "  Authentication Errors:\n";
      printf "    Invalid type:\t\t%d\n",
        $sh->{instances}->{$interface}->{$vrid}->{'authentication-errors'}->{'invalid-type'};
      printf "    Type mismatch:\t\t%d\n",
        $sh->{instances}->{$interface}->{$vrid}->{'authentication-errors'}->{'type-mismatch'};
      printf "    Failure:\t\t\t%d\n",
        $sh->{instances}->{$interface}->{$vrid}->{'authentication-errors'}->{'failure'};
      printf "\n";
      printf "  Priority Zero Advertisements:\n";
      printf "    Received\t\t\t%d\n",
        $sh->{instances}->{$interface}->{$vrid}->{'priority-zero'}->{'received'};
      printf "    Sent\t\t\t%d\n",
        $sh->{instances}->{$interface}->{$vrid}->{'priority-zero'}->{'sent'};
      printf "\n";
    }
  }
}

sub print_sync {
  my ($dh, $sync_group) = @_;
  print "--------------------------------------------------\n";
  foreach my $sync (sort versioncmp keys(%{$dh->{'sync-groups'}})){
    next if ($sync_group && $sync ne $sync_group);
    printf "Group: %s\n", $sync; 
    printf "---------\n"; 
    printf "  State: %s\n", $dh->{'sync-groups'}->{$sync}->{state};
    printf "  Monitoring:\n";
    foreach my $mon (@{$dh->{'sync-groups'}->{$sync}->{monitor}}){
      my ($intf, $vrid) = $mon =~ m/vyatta-(.*?)-(.*)/;
      printf "    Interface: %s, Group: %s\n", $intf, $vrid;
    }
    printf "\n";
  }
}

1;
