#!/usr/bin/perl
#
# Module: vyatta-show-interfaces.pl
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
# Date: February 2008
# Description: Script to display interface information
# 
# **** End License ****
#

use lib "/opt/vyatta/share/perl5/";
use VyattaConfig;
use Getopt::Long;
use POSIX;

use strict;
use warnings;

#
# valid interfaces
#
my %intf_hash = (
    ethernet  => 'eth',
    serial    => 'wan',
    tunnel    => 'tun',
    bridge    => 'br',
    loopback  => 'lo',
    pppoe     => 'pppoe',
    multilink => 'ml',
    );

#
# valid actions
#
my %action_hash = (
    'show'       => \&run_show_intf,
    'show-brief' => \&run_show_intf_brief,
    'clear'      => \&run_clear_intf,
    'reset'      => \&run_reset_intf,
    );


my $clear_stats_dir = '/var/run/vyatta';
my $clear_file_magic = 'XYZZYX';

my @rx_stat_vars = 
    qw/rx_bytes rx_packets rx_errors rx_dropped rx_over_errors multicast/; 
my @tx_stat_vars = 
    qw/tx_bytes tx_packets tx_errors tx_dropped tx_carrier_errors collisions/;

sub get_intf_type {
    my $intf = shift;

    my $base;
    if ($intf =~ m/([a-zA-Z]+)\d*/) {
	$base = $1;
    } else {
	die "unknown intf type [$intf]\n";
    }
    
    foreach my $intf_type (keys(%intf_hash)) {
	if ($intf_hash{$intf_type} eq $base) {
	    return $intf_type;
	}
    }
    return undef;
}

sub get_intf_description {
    my $intf = shift;

    my $intf_type = get_intf_type($intf);
    if (!defined $intf_type) {
	return "";
    }
    my $config = new VyattaConfig; 
    my $path;
    if ($intf =~ m/([a-zA-Z]+\d+)\.(\d+)/) {
	$path = "interfaces $intf_type $1 vif $2";
    } else {
	$path = "interfaces $intf_type $intf";
    }
    $config->setLevel($path);
    my $description = $config->returnOrigValue("description"); 
    if (defined $description) {
	return $description;
    } else {
	return "";
    }
}

sub get_intf_stats {
    my $intf = shift;
    
    my %stats = ();
    foreach my $var (@rx_stat_vars, @tx_stat_vars) {
	$stats{$var} = `cat /sys/class/net/$intf/statistics/$var`;
    }
    return %stats;
}

sub get_intf_statsfile {
    my $intf = shift;

    return "$clear_stats_dir/$intf.stats";
}

sub get_clear_stats {
   my $intf = shift;

   my %stats = ();
   foreach my $var (@rx_stat_vars, @tx_stat_vars) {
       $stats{$var} = 0;
   }
   my $FILE;
   my $filename = get_intf_statsfile($intf);
   if (!open($FILE, "<", $filename)) {
       return %stats;
   }

   my $magic = <$FILE>; chomp $magic;
   if ($magic ne $clear_file_magic) {
       print "bad magic [$intf]\n";
       return %stats;
   }
   my $timestamp = <$FILE>; chomp $timestamp;
   $stats{'timestamp'} = $timestamp;
   my ($var, $val);
   while (<$FILE>) {
       chop;
       ($var, $val) = split(/,/);
       $stats{$var} = $val;
   }
   close($FILE);
   return %stats;
}

sub get_ipaddr {
    my $intf = shift;
    
    my @addr_list = ();
    my @lines = `ip addr show $intf | grep 'inet '`;
    foreach my $line (@lines) {
	if ($line =~ m/inet (\d+\.\d+\.\d+\.\d+)\/(\d+)/) {
	    push @addr_list, "$1/$2";
	}
    }
    chomp  @addr_list;
    return @addr_list;
}

sub get_state_link {
    my $intf = shift;

    my $IFF_UP = 0x1;
    my ($state, $link);
    my $flags = `cat /sys/class/net/$intf/flags 2> /dev/null`;
    my $carrier = `cat /sys/class/net/$intf/carrier 2> /dev/null`;
    chomp $flags; chomp $carrier;
    my $hex_flags = hex($flags);
    if ($hex_flags & $IFF_UP) {
	$state = "up"; 
    } else {
	$state = "admin down";
    }
    if ($carrier eq "1") {
	$link = "up"; 
    } else {
	$link = "down";
    }
    return ($state, $link);
}

sub is_valid_intf {
    my ($intf) = @_;

    if (-e "/sys/class/net/$intf") {
	return 1;
    } 
    return 0;
}

sub is_valid_intf_type {
    my $intf_type = shift;
    
    if (defined $intf_hash{$intf_type}) {
	return 1;
    }
    return 0;
}

sub get_intf_for_type {
    my $intf_type = shift;

    my $intf_prefix = $intf_hash{$intf_type};
    my @list = `cd /sys/class/net; ls -d $intf_prefix\* 2> /dev/null`;
    chomp @list;
    return @list;
}

# This function assumes 32-bit counters.  
sub get_counter_val {
    my ($clear, $now) = @_;

    return $now if $clear == 0;

    my $value;
    if ($clear > $now) {
	#
	# The counter has rolled.  If the counter has rolled
	# multiple times since the clear value, then this math
	# is meaningless.
	#
	$value = (4294967296 - $clear) + $now;
    } else {
	$value = $now - $clear;
    }
    return $value;
}


#
# The "action" routines
#

sub run_show_intf {
    my @intfs = @_;

    foreach my $intf (@intfs) {
	my %clear = get_clear_stats($intf);
	my $description = get_intf_description($intf);
	my $timestamp = $clear{'timestamp'};
	my $line = `ip addr show $intf | sed 's/^[0-9]*: //'`; chomp $line; 
	print "$line\n";
	if (defined $timestamp and $timestamp ne "") {
	    my $time_str = strftime("%a %b %d %R:%S %Z %Y", 
				    localtime($timestamp));
	    print "    Last clear: $time_str\n";
	}
	if (defined $description and $description ne "") {
	    print "    Description: $description\n";
	}
	print "\n";
	my %stats = get_intf_stats($intf);
	printf("    %10s %10s %10s %10s %10s %10s\n", "RX:  bytes", "packets",
	       "errors", "dropped", "overrun", "mcast");
	printf("    %10u %10u %10u %10d %10u %10u\n", 
	       get_counter_val($clear{'rx_bytes'}, $stats{'rx_bytes'}),
	       get_counter_val($clear{'rx_packets'}, $stats{'rx_packets'}),
	       get_counter_val($clear{'rx_errors'}, $stats{'rx_errors'}),
	       get_counter_val($clear{'rx_dropped'}, $stats{'rx_dropped'}),
	       get_counter_val($clear{'rx_over_errors'}, 
			       $stats{'rx_over_errors'}),
	       get_counter_val($clear{'multicast'}, $stats{'multicast'}));

	printf("    %10s %10s %10s %10s %10s %10s\n", "TX:  bytes", "packets",
	       "errors", "dropped", "carrier", "collisions");
	printf("    %10u %10u %10u %10u %10u %10u\n\n", 
	       get_counter_val($clear{'tx_bytes'}, $stats{'tx_bytes'}),
	       get_counter_val($clear{'tx_packets'}, $stats{'tx_packets'}),
	       get_counter_val($clear{'tx_errors'}, $stats{'tx_errors'}),
	       get_counter_val($clear{'tx_dropped'}, $stats{'tx_dropped'}),
	       get_counter_val($clear{'tx_carrier_errors'}, 
			       $stats{'tx_carrier_errors'}),
	       get_counter_val($clear{'collisions'}, $stats{'collisions'}));
    }
}

sub run_show_intf_brief {
    my @intfs = @_;

    my $format = "%-12s %-18s %-11s %-6s %-29s\n";
    printf($format, "Interface","IP Address","State","Link","Description");
    foreach my $intf (@intfs) {
	my @ip_addr = get_ipaddr($intf);
	my ($state, $link) = get_state_link($intf);
	my $description = get_intf_description($intf);
	$description = substr($description, 0, 29); # make it fit on 1 line
	if (scalar(@ip_addr) == 0) {
	    printf($format, $intf, "-", $state, $link, $description);
	} else {
	    foreach my $ip (@ip_addr) {
		printf($format, $intf, $ip, $state, $link, $description);
	    }
	}
    }
}

sub run_clear_intf {
    my @intfs = @_;

    foreach my $intf (@intfs) {
	my %stats = get_intf_stats($intf);
	my $FILE;
	my $filename = get_intf_statsfile($intf);
	if (!open($FILE, ">", $filename)) {
	    die "Couldn't open $filename [$!]\n";
	}
	print "Clearing $intf\n";
	print $FILE $clear_file_magic, "\n", time(), "\n";
	my ($var, $val);
	while (($var, $val) = each (%stats)) {
	    print $FILE $var, ",", $val;
	}
	close($FILE);
    }
}

sub run_reset_intf {
    my @intfs = @_;
    
    foreach my $intf (@intfs) {
	my $filename = get_intf_stats($intf);
	system("rm -f $filename");
    }
}


#
# main
#
my @intf_list = ();
my ($intf_type, $intf, $action);
GetOptions("intf-type=s" => \$intf_type,
	   "intf=s"      => \$intf,
	   "action=s"    => \$action,
);

if (defined $intf) {
    if (!is_valid_intf($intf)) {
	die "Invalid interface [$intf]\n";
    }
    push @intf_list, $intf;
} elsif (defined $intf_type) {
    if (!is_valid_intf_type($intf_type)) {
	die "Invalid interface type [$intf_type]\n";
    }
    @intf_list = get_intf_for_type($intf_type);
} else {
    #
    # get all interfaces
    #
    foreach my $type (sort(keys (%intf_hash))) {
	push @intf_list, get_intf_for_type($type);
    }
}

if (! defined $action) {
    $action = 'show';
} 

my $func;
if (defined $action_hash{$action}) {
    $func = $action_hash{$action};
} else {
    die "Invalid action [$action]\n";
}

#
# make it so...
#
&$func(@intf_list);

# end of file
