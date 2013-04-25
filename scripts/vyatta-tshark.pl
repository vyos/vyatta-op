#!/usr/bin/perl
#
# Module: vyatta-tshark-interface-port.pl
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
# Portions created by Vyatta are Copyright (C) 2006, 2007, 2008 Vyatta, Inc.
# All Rights Reserved.
#
# Author: John Southworth
# Date: Sept. 2011
# Description: run tshark on a given interface with options
#
# **** End License ****
#

use lib "/opt/vyatta/share/perl5/";

use strict;
use warnings;
use Getopt::Long;

sub check_if_interface_is_tsharkable {
    my $interface = shift;
    
    my @grep_tshark_interfaces = `/usr/bin/tshark -D | grep $interface`;
    my $any_interface;

    for my $count (0 .. $#grep_tshark_interfaces) {
     my @temp = split(/ /,$grep_tshark_interfaces[$count]);
     chomp $temp[1];
     $grep_tshark_interfaces[$count] = $temp[1];
    }
    
    my $exact_match = 0;
    for my $count (0 .. $#grep_tshark_interfaces) {
        if ($grep_tshark_interfaces[$count] eq $interface) {
            $exact_match = 1;
            $any_interface = $grep_tshark_interfaces[$count];
        }
    }
    if ($exact_match == 0 || $any_interface eq 'any') {
        print "Unable to capture traffic on $interface\n";
        exit 1;
    }
}

my ($detail,$filter,$intf,$unlimited,$save,$files,$size);

#
# The size parameter can have one of the following
# unit suffixes:
#
# - [kK] KiB (1024 bytes)
# - [mM] MiB (1048576 bytes)
# - [gG] GiB (1073741824 bytes)
# - [tT] TiB (109951162778 bytes)
#
# Note: tshark's default size unit is KiB
sub parse_size {
    my ( $name, $parm ) = @_;
    my %mult = ('T' => 1073741824, 't' => 1073741824,
                'G' => 1048576,    'g' => 1048576,
                'M' => 1024,       'm' => 1024,
                'K' => 1,          'k' => 1);

    die "Invalid parameter: $name" if ($name ne "size");
    my ( $value, $unit ) = $parm =~ m/^([0-9]+)([kKmMgGtT])?$/;
    die "Invalid size specified" unless $value;
    $unit = "K" unless $unit;
    $size = $value * $mult{$unit};
}

#
# main
#

my $result = GetOptions("detail!"                => \$detail,
                        "filter=s"               => \$filter,
                        "save=s"                 => \$save,
                        "intf=s"                 => \$intf,
                        "unlimited!"             => \$unlimited,
                        "files=i"                => \$files,
                        "size=s"                 => \&parse_size);

if (! $result) {
    print "Invalid option specifications\n";
    exit 1;
}

check_if_interface_is_tsharkable($intf);

if (defined($save)){
  if (!($save =~ /.*\.pcap/)) {
    print("Please name your file <filename>.pcap\n");
    exit 1;
  }
  my $options = "";

  # the CLI will make sure that files is not defined w/o size also
  $options .= " -a filesize:$size" if defined($size);
  $options .= " -b files:$files" if defined($files);
  exec "/usr/bin/tshark -i $intf -w '$save' $options";
  exit 0;
}

if (defined($filter)) {
  if (defined($detail)) { 
    if (defined($unlimited)){
      print "Capturing traffic on $intf ...\n";
      exec "/usr/bin/tshark -n -i $intf -V $filter 2> /dev/null";
    } else {
      print "Capturing traffic on $intf ...\n";
      exec "/usr/bin/tshark -n -i $intf -c 1000 -V $filter 2> /dev/null";
    }
  } elsif (defined($unlimited)) {
    print "Capturing traffic on $intf ...\n";
    exec "/usr/bin/tshark -n -i $intf  $filter 2> /dev/null";
  } else {
    print "Capturing traffic on $intf ...\n";
    exec "/usr/bin/tshark -n -i $intf -c 1000  $filter 2> /dev/null";
  }
} elsif (defined($detail)) {
    if (defined($unlimited)) {
      print "Capturing traffic on $intf ...\n";
      exec "/usr/bin/tshark -n -i $intf -V 2> /dev/null";
    } else {
      print "Capturing traffic on $intf ...\n";
      exec "/usr/bin/tshark -n -i $intf -c 1000 -V 2> /dev/null";
    }
} elsif (defined($unlimited)) {
  print "Capturing traffic on $intf ...\n";
  exec "/usr/bin/tshark -n -i $intf 2> /dev/null";
} else {
  print "Capturing traffic on $intf ...\n";
  exec "/usr/bin/tshark -n -i $intf -c 1000 2> /dev/null";
}

exit 0;

#end of file
