#!/usr/bin/perl -W 


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
# Author: Deepti Kulkarni 
# Date: May 2010
# Description: Script to check if the node exists in the configuration 
#
# **** End License ****

use strict;
use warnings;
use lib "/opt/vyatta/share/perl5";
use Vyatta::Config;
use Vyatta::ConfigOutput; 
my $config = new Vyatta::Config;

if ($ARGV[0])
 {
   my $node = $ARGV[0];
   my $level = $ARGV[1];
   my $i=2;  
  while ($ARGV[$i])
   { 
     my $sublevel = $ARGV[$i];
     $level = $level . " " . $sublevel;
     $i++; 
   }
    
     $config->setLevel($level);   
  if ($config->existsOrig($node))
   { exit 0; }
  else { exit 1; }   
 }
