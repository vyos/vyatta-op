#!/usr/bin/perl

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
# Portions created by Vyatta are Copyright (C) 2010 Vyatta, Inc.
# All Rights Reserved.
#
# Author: Bob Gilligan
# Date: April 30, 2010
# Description: Script to re-name a system image.
#
# **** End License ****

use strict;
use warnings;
use Getopt::Long;
use File::Temp qw/ tempfile tempdir /;

my $old_name;
my $new_name;

GetOptions(
    'old_name:s' => \$old_name,
    'new_name:s' => \$new_name,
    );
    
if (!defined($old_name) || !defined($new_name)) {
    printf("Must specify both old ane new name.\n");
    exit 1;
}

my $image_path = "/live/image/boot";

if (! -e "$image_path") {
    # must be running on old non-image installed system
    $image_path = "";
}

if (! -e "$image_path/$old_name") {
    printf("Old name $old_name does not exist.\n");
    exit 1;
}

if (("$new_name" eq "Old-non-image-installation") ||
    ("$new_name" eq "grub") ||
    ("$new_name" =~ /^initrd/) ||
    ("$new_name" =~ /^vmlinuz/) ||
    ("$new_name" =~ /^System\.map/) ||
    ("$new_name" =~ /^config-/)) {
    printf("Can't use reserved image name.\n");
    exit 1;
}

my $cmdline=`cat /proc/cmdline`;
my $cur_name;
($cur_name, undef) = split(' ', $cmdline);
$cur_name =~ s/BOOT_IMAGE=\/boot\///;
$cur_name =~ s/\/vmlinuz.*//;

if ($old_name eq $cur_name) {
    printf("Can't re-name the running image.\n");
    exit 1;
}

if (-e "$image_path/$new_name") {
    printf("New name $new_name already exists.\n");
    exit 1;
}

printf("Renaming image $old_name to $new_name.\n");

my $tmpfh;
my $tmpfilename;
($tmpfh, $tmpfilename) = tempfile();

if (!open (GRUBFH, "<${image_path}/grub/grub.cfg")) {
    printf("Can't open grub file.\n");
    exit 1;
}

# This is sensitive to the format of menu entries and boot paths
# in the grub config file.
#
my $line;
while ($line = <GRUBFH>) {
    $line =~ s/\/boot\/$old_name/\/boot\/$new_name/g;
    $line =~ s/Vyatta $old_name/Vyatta $new_name/;
    $line =~ s/Vyatta image $old_name/Vyatta image $new_name/;
    $line =~ s/Lost password change $old_name/Lost password change $new_name/;
    printf($tmpfh $line);
}

close($tmpfh);
close(GRUBFH);

system("mv $image_path/$old_name $image_path/$new_name");
system("cp $tmpfilename $image_path/grub/grub.cfg");

system("logger -p local3.warning -t 'SystemImage' 'System image $old_name has been renamed $new_name'");

printf("Done.\n");

