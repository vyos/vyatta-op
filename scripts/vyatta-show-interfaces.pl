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

use Vyatta::Interface;
use Vyatta::Misc;
use Getopt::Long;
use POSIX;
use NetAddr::IP;

use strict;
use warnings;

#
# valid actions
#
my %action_hash = (
    'show'       => \&run_show_intf,
    'show-brief' => \&run_show_intf_brief,
    'show-count' => \&run_show_counters,
    'clear'      => \&run_clear_intf,
    'reset'      => \&run_reset_intf,
    );


my $clear_stats_dir = '/var/run/vyatta';
my $clear_file_magic = 'XYZZYX';

my @rx_stat_vars = 
    qw/rx_bytes rx_packets rx_errors rx_dropped rx_over_errors multicast/; 
my @tx_stat_vars = 
    qw/tx_bytes tx_packets tx_errors tx_dropped tx_carrier_errors collisions/;


sub get_intf_description {
    my $name = shift;
    my $description = interface_description($name);

    return "" unless $description;
    return $description;
}

sub get_intf_stats {
    my $intf = shift;
    
    my %stats = ();
    foreach my $var (@rx_stat_vars, @tx_stat_vars) {
	$stats{$var} = get_sysfs_value($intf, "statistics/$var");
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

   my $filename = get_intf_statsfile($intf);

   open (my $f, '<', $filename)
    or return %stats;

   my $magic = <$f>;
   chomp $magic;
   if ($magic ne $clear_file_magic) {
       print "bad magic [$intf]\n";
       return %stats;
   }

   my $timestamp = <$f>;
   chomp $timestamp;
   $stats{'timestamp'} = $timestamp;

   while (<$f>) {
       chop;
       my ($var, $val) = split(/,/);
       $stats{$var} = $val;
   }
   close($f);
   return %stats;
}

sub get_ipaddr {
    my $name = shift;
    
    # Skip IPV6 default Link-local
    return grep { !/^fe80/ } Vyatta::Misc::getIP($name);
}

sub get_state_link {
    my $intf = shift;
    my $state;
    my $link = 'down';
    my $flags = get_sysfs_value($intf, 'flags');

    my $hex_flags = hex($flags);
    if ($hex_flags & 0x1) {	  # IFF_UP
	$state = 'up'; 
	my $carrier = get_sysfs_value($intf, 'carrier');
	if ($carrier eq '1') {
	    $link = "up"; 
	}
    } else {
	$state = "admin down";
    }

    return ($state, $link);
}

sub is_valid_intf {
    my $name = shift;
    return unless $name;

    my $intf = new Vyatta::Interface($name);
    return unless $intf;

    return $intf->exists();
}

sub get_intf_for_type {
    my $type = shift;
    my @interfaces = getInterfaces();
    my @list = ();
    foreach my $name (@interfaces) {
	if ($type) {
	    my $intf = new Vyatta::Interface($name);
	    next unless $intf;				# unknown type
	    next if ($type ne $intf->type());
	}
	push @list, $name;
    }

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
	if (scalar(@ip_addr) == 0) {
	    printf($format, $intf, "-", $state, $link, $description);
	} else {
	    foreach my $ip (@ip_addr) {
		printf($format, $intf, $ip, $state, $link, $description);
	    }
	}
    }
}

sub run_show_counters {
    my @intfs = @_;

    my $format = "%-12s %10s %10s     %10s %10s\n";
    printf($format, "Interface","Rx Packets","Rx Bytes","Tx Packets","Tx Bytes");
    foreach my $intf (@intfs) {
	my ($state, $link) = get_state_link($intf);
	next if $state ne 'up';
	my %clear = get_clear_stats($intf);
	my %stats = get_intf_stats($intf);
	printf($format, $intf,  
	       get_counter_val($clear{rx_packets}, $stats{rx_packets}),
	       get_counter_val($clear{rx_bytes},   $stats{rx_bytes}),
	       get_counter_val($clear{tx_packets}, $stats{tx_packets}),
	       get_counter_val($clear{tx_bytes},   $stats{tx_bytes})
	    );
    }
}

sub run_clear_intf {
    my @intfs = @_;

    foreach my $intf (@intfs) {
	my %stats = get_intf_stats($intf);
	my $filename = get_intf_statsfile($intf);

	mkdir $clear_stats_dir unless ( -d $clear_stats_dir );

	open(my $f, '>', $filename)
	    or die "Couldn't open $filename [$!]\n";

	print "Clearing $intf\n";
	print $f $clear_file_magic, "\n", time(), "\n";

	while (my ($var, $val) = each (%stats)) {
	    print $f $var, ",", $val, "\n";
	}

	close($f);
    }
}

sub run_reset_intf {
    my @intfs = @_;
    
    foreach my $intf (@intfs) {
	my $filename = get_intf_stats($intf);
	system("rm -f $filename");
    }
}

sub alphanum_split {
    my ($str) = @_;
    my @list = split m/(?=(?<=\D)\d|(?<=\d)\D)/, $str;
    return @list;
}

sub natural_order {
    my ($a, $b) = @_;
    my @a = alphanum_split($a);
    my @b = alphanum_split($b);
  
    while (@a && @b) {
	my $a_seg = shift @a;
	my $b_seg = shift @b;
	my $val;
	if (($a_seg =~ /\d/) && ($b_seg =~ /\d/)) {
	    $val = $a_seg <=> $b_seg;
	} else {
	    $val = $a_seg cmp $b_seg;
	}
	if ($val != 0) {
	    return $val;
	}
    }
    return @a <=> @b;
}

sub intf_sort {
    my @a = @_;
    my @new_a = sort { natural_order($a,$b) } @a;
    return @new_a;
}

sub usage {
    print "Usage: $0 [intf=NAME|intf-type=TYPE] action=ACTION\n";
    print "  NAME = ", join(' | ', get_intf_for_type()), "\n";
    print "  TYPE = ", join(' | ', Vyatta::Interface::interface_types()), "\n";
    print "  ACTION = ", join(' | ', keys %action_hash), "\n";
    exit 1;
}

#
# main
#
my @intf_list = ();
my ($intf_type, $intf);
my $action = 'show';

GetOptions("intf-type=s" => \$intf_type,
	   "intf=s"      => \$intf,
	   "action=s"    => \$action,
) or usage();

if ($intf) {
    die "Invalid interface [$intf]\n" 
	unless is_valid_intf($intf);

    push @intf_list, $intf;
} elsif ($intf_type) {
    @intf_list = get_intf_for_type($intf_type);
} else {
    # get all interfaces
    @intf_list = get_intf_for_type();
}

@intf_list = intf_sort(@intf_list);

my $func;
if (defined $action_hash{$action}) {
    $func = $action_hash{$action};
} else {
    print "Invalid action [$action]\n";
    usage();
}

#
# make it so...
#
&$func(@intf_list);

# end of file
