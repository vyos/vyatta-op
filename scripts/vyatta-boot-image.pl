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
# Portions created by Vyatta are Copyright (C) 2007 Vyatta, Inc.
# All Rights Reserved.
#
# Author: An-Cheng Huang, Bob Gilligan
# Date: January, 2010
# Description: Script to manage system images.  Provides the ability to
#	display status of images, select the default image to boot, and
#	to delete images.
#
# **** End License ****

use strict;
use warnings;
use Getopt::Long;
use File::Temp qw/ :mktemp /;
use File::Copy;

# 
# Constants
# 
my $UNION_BOOT = '/live/image/boot';
my $UNION_GRUB_CFG = "$UNION_BOOT/grub/grub.cfg";
my $VER_FILE = '/opt/vyatta/etc/version';
my $OLD_IMG_VER_STR = 'Old-non-image-installation';
my $OLD_GRUB_CFG = '/boot/grub/grub.cfg';
my $DISK_BOOT = '/boot';
my $XEN_DEFAULT_IMAGE = "$UNION_BOOT/%%default_image";
my $LIVE_CD = '/live/image/live';

# 
# Globals
# 
my $grub_cfg;	# Pathname of grub config file we will use.

# This function parses the grub config file and returns a hash array
# of the parsed data.  There is one element of the array for each grub
# config file entry.  Each element is a hash that contains:  The "index" of
# entry in the grub config file, the "version" string of the entry, the
# "terminal type" of the entry -- "kvm" or "serisl", and a flag indicating
# whether the entry is a "lost password reset" boot menu item.
#
sub parseGrubCfg {
    open (my $fd, '<', $grub_cfg)
	or die "Can't open grub config $grub_cfg: $!\n";

    my %ghash = ();
    my @entries = ();
    my $in_entry = 0;
    my $idx = 0;
    my $curver;
    my $running_boot_cmd=`cat /proc/cmdline`;
    if (! ($running_boot_cmd =~ s/BOOT_IMAGE=//)) {
	# Mis-formatted boot cmd.  Look harder to to find the current
	# version string.
	#
	$curver = curVer();
	if (defined($curver)) {
	    # Only one of $running_boot_cmd or $curver should be defined.
	    undef $running_boot_cmd;
	}
    }
    while (<$fd>) {
	if ($in_entry) {
	    if (/^}/) {
	        if ($in_entry == 1) {
		    # Entry did not have linux kernel line
		    my %ehash = (
			'idx' => $idx,
			'ver' => undef,
			'term' => undef,
			'reset' => undef
			);
		    push @entries, \%ehash;
	        }
	        $in_entry = 0;
	        ++$idx;
	    } elsif (/^\s+linux /) {
		my %ehash = (
		    'idx' => $idx,
		    'ver' => undef,
		    'term' => undef,
		    'reset' => undef
		    );
		# kernel line
		if (/^\s+linux \/boot\/([^\/ ]+)\/.* boot=live /) {
		    # union install
		    $ehash{'ver'} = $1;
		} else {
		    # old install
		    $ehash{'ver'} = $OLD_IMG_VER_STR;
		}
		if (/console=tty0.*console=ttyS0/) {
		    $ehash{'term'} = 'serial';
		} else {
		    $ehash{'term'} = 'kvm';
		}
		if (/standalone_root_pw_reset/) {
		    $ehash{'reset'} = 1;
		} else {
		    $ehash{'reset'} = 0;
		}
		if (defined($running_boot_cmd)) {
		    if (/$running_boot_cmd/) {
			$ehash{'running_vers'} = 1;
		    } else {
			$ehash{'running_vers'} = 0;
		    }
		} elsif (defined($curver)) {
		    my $matchstr = "/boot/$curver/vmlinuz";
		    if (/$matchstr/) {
			$ehash{'running_vers'} = 1;
		    } else {
			$ehash{'running_vers'} = 0;
		    }
		}
		push @entries, \%ehash;
		$in_entry++;
	    }
        } elsif (/^set default=(\d+)$/) {
	    $ghash{'default'} = $1;
	} elsif (/^menuentry /) {
	    $in_entry = 1;
	} 
    }
    close($fd);
    $ghash{'entries'} = \@entries;
    return \%ghash;
}

# This function deletes the entries for the specified version from the grub
# config file. returns undef if successful. Otherwise it returns an 
# error message.
#
sub deleteGrubEntries {
  my ($del_ver) = @_;

  my $rfd = undef;
  return 'Cannot delete GRUB entries' if (!open($rfd, '<', $grub_cfg));
  my ($wfd, $tfile) = mkstemp('/tmp/boot-image.XXXXXX');

  my @entry = ();
  my ($in_entry, $ver) = (0, 0);
  while (<$rfd>) {
    next if (/^$/); # ignore empty lines
    if ($in_entry) {
      if (/^}/) {
        if ($ver ne $del_ver) {
          # output entry
          print $wfd "\n";
          foreach my $l (@entry) {
            print $wfd $l;
          }
          print $wfd "}\n";
        }
        $in_entry = 0;
        $ver = 0;
        @entry = ();
      } else {
	  if (/^\s+linux/) {
	      if (/^\s+linux \/boot\/([^\/ ]+)\/.* boot=live /) {
		  # kernel line
		  $ver = $1;
	      } else {
		  $ver = $OLD_IMG_VER_STR;
	      }
	  }
	  push @entry, $_;
      }
    } elsif (/^menuentry /) {
      $in_entry = 1;
      push @entry, $_;
    } else {
      print $wfd $_;
    } 
  }
  close($wfd);
  close($rfd);

  my $p = (stat($grub_cfg))[2];
  die "Failed to modify GRUB configuration\n"
    if (!defined($p) || !chmod(($p & oct(7777)), $tfile));

  move($tfile, $grub_cfg)
    or die "Failed to delete GRUB entries\n";
}

# This function takes the default terminal type and a list of all grub
# config file entries as generated by parseGrubConfig() and returns
# the "boot list".  This list contains one entry for each image
# version.
#
sub getBootList {
  my ($dterm, $entries) = @_;
  my %vhash = ();
  my @list = ();
  foreach (@{$entries}) {
    my ($ver, $term) = ($_->{'ver'}, $_->{'term'});
    next if (!defined($ver));	# Skip non-vyatta entry
    next if ($_->{'reset'}); # skip password reset entry
    next if ($term ne $dterm); # not the default terminal
    next if (defined($vhash{$ver})); # version already in list

    $vhash{$ver} = 1;
    push @list, $_;
  }
  return \@list;
}


# Get the Vyatta version of a particular image, given its name.
#
sub image_vyatta_version {
    my ($image_name) = @_;

    my $vers;
    my $dpkg_path = "var/lib/dpkg";

    my $image_path;
    if ($image_name eq $OLD_IMG_VER_STR) {
	$image_path = "";
    } else {
	$image_path = "/live/image/boot/$image_name/live-rw";
    }
    
    $image_path .= "/var/lib/dpkg";

    if ( -e $image_path ) {
	$vers = `dpkg-query --admindir=$image_path --showformat='\${Version}' --show vyatta-version`;
	return $vers;
    } else {
	if ($image_name eq $OLD_IMG_VER_STR) {
	    return "unknown";
	}

	my @squash_files = glob("/live/image/boot/$image_name/*.squashfs");
	foreach my $squash_file (@squash_files) {
	    if (-e $squash_file) {
		system("sudo mkdir /tmp/squash_mount");
		system("sudo mount -o loop,ro -t squashfs $squash_file /tmp/squash_mount");
		$image_path = "/tmp/squash_mount/var/lib/dpkg";
		my $vers = `dpkg-query --admindir=$image_path --showformat='\${Version}' --show vyatta-version`;
		system("sudo umount /tmp/squash_mount");
		system("sudo rmdir /tmp/squash_mount");
		return $vers;
	    }
	}
	# None found
	return "unknown2"
    }
}

# Prints the boot list generated by getBootList(). If the argument
# $brief is set, display the entries for machine instead of human
# consumption:  One entry per line showing the the version string only.
#
sub displayBootList {
  my ($didx, $entries, $brief, $show_version) = @_;
  for my $i (0 .. $#{$entries}) {
    my $di = $i + 1; 
    my $ver = $ {$entries}[$i]->{'ver'};
    my $m = '';

    if (defined $show_version) {
	my $vyatta_vers = image_vyatta_version($ver);
	$m .= " [$vyatta_vers]";
    }

    if ($didx == $ {$entries}[$i]->{'idx'}) {
      $m .= ' (default boot)';
    }
    
    if ($ {$entries}[$i]->{'running_vers'} == 1) {
	$m .= ' (running image)';
    }

    if (defined($brief)) {
	print "$ver\n";
    } else {
	printf "  %2d: %s%s\n", $di, $ver, $m;
    }
  }
}

# Sets the grub config file default pointer to the boot list entry
# number passed in.
#
sub doSelect {
  my ($resp, $def_ver, $bentries, $new_ver) = @_;
  my $new_idx;
  if (defined($new_ver)) {
      for my $i (0 .. $#{$bentries}) {
	  if ($ {$bentries}[$i]->{'ver'} eq $new_ver) {
	      $new_idx = $ {$bentries}[$i]->{'idx'};
	      last;
	  }
      }
      if (!defined($new_idx)) {
	  print "Version $new_ver not found.\n";
	  exit 1;
      }
  } else {
      $new_idx = $ {$bentries}[$resp]->{'idx'};
      $new_ver = $ {$bentries}[$resp]->{'ver'};
  }
  if ($new_ver eq $def_ver) {
      print "The default boot image has not been changed.\n";
      exit 0;
  }

  system("sed -i 's/^set default=.*\$/set default=$new_idx/' $grub_cfg");
  if ($? >> 8) {
    print "Failed to set the default boot image. Exiting...\n";
    exit 1;
  }

  if (-l $XEN_DEFAULT_IMAGE) {
      my $backup_symlink = $XEN_DEFAULT_IMAGE . ".orig";
      if (!move($XEN_DEFAULT_IMAGE, $backup_symlink)) {
	  printf("Unable to back up Xen default image symlink: $XEN_DEFAULT_IMAGE\n");
	  printf("Default boot image has not been changed.\n");
	  system("logger -p local3.warning -t 'SystemImage' 'Default boot image attempt to change from $def_ver to $new_ver failed: cant back up symlink'");
	  exit 1;
      }
      if (!symlink ($new_ver, $XEN_DEFAULT_IMAGE)) {
	  move($backup_symlink, $XEN_DEFAULT_IMAGE);
	  printf("Unable to update Xen default image symlink: $XEN_DEFAULT_IMAGE.\n");
	  printf("Default boot image has not been changed.\n");
	  system("logger -p local3.warning -t 'SystemImage' 'Default boot image attempt to change from $def_ver to $new_ver failed: cant update symlink'");
	  exit 1;
      }
  }

  print <<EOF;
Default boot image has been set to "$new_ver".
You need to reboot the system to start the new default image.

EOF

  system("logger -p local3.warning -t 'SystemImage' 'Default boot image has been changed from $def_ver to $new_ver'");

  exit 0;
}

# Set the grub default pointer to the entry whose name is passed in
#
sub select_by_name {
    my ($new_def_ver, $def_term) =  @_;
    my $def_index;

    # Re-scan the the grub config file to get the current indexes
    # of each entry.
    my $gref = parseGrubCfg();

    # Find the entry that matches the new default version
    my $entries = $gref->{'entries'};
    foreach my $entry (@{$entries}) {
	# Skip non-vyatta entries
	next if (!defined($entry->{'ver'}));

	# Skip entries that are not using the same term type as before
	next if ($entry->{'term'} ne $def_term);
	# Skip the password reset entries
	next if ($entry->{'reset'});
	if ($entry->{'ver'} eq $new_def_ver) {
	    $def_index = $entry->{'idx'};
	    last;
	}
    }

    if (!defined($def_index)) {
	print "Can't find entry for $new_def_ver in grub config file.\n";
	exit 1;
    }

    # Set default pointer in grub config file to point to the new
    # default version.
    system("sed -i 's/^set default=.*\$/set default=$def_index/' $grub_cfg");
    if ($? >> 8) {
	print "Failed to set the default boot image. Exiting...\n";
	exit 1;
    }
}

# Returns the version string of the currently running system.
#
sub curVer {
    my $vers = `awk '{print \$1}' /proc/cmdline`;

    # In an image-booted system, the image name is the directory name
    # under "/boot" in the pathname of the kernel we booted.
    if ($vers =~ s/BOOT_IMAGE=\/boot\///) {
	$vers =~ s/\/?vmlinuz.*\n$//;
    } else {
	# Boot command line is not formatted as it would be for a system
	# booted via grub2 with union mounted root filesystem.  Another
	# possibility is that it the system is Xen booted via pygrub.
	# On Xen/pygrub systems, we figure out the running version by
	# looking at the bind mount of /boot.
	$vers = `mount | awk '/on \\/boot / { print \$1 }'`;
	$vers =~ s/\/live\/image\/boot\///;
	chomp($vers);
    }

    # In a non-image system, the kernel resides directly under "/boot".
    # No second-level directory means that $vers will be null.
    if ($vers eq "") {
	$vers = $OLD_IMG_VER_STR;
    }
    return $vers;
}

# Deletes all of the files belonging to the disk-based non-image
# installation.
#
sub del_non_image_files {
    my $logfile="/var/log/vyatta/disk-image-del-";
    $logfile .= `date +%F-%T`;
    system("touch $logfile");
    system("echo Deleting disk-based system files at: `date` >> $logfile");
    system("echo Run by: `whoami` >> $logfile");

    foreach my $entry (glob("/live/image/*")) {
	if ($entry eq "/live/image/boot") {
	    print "Skipping $entry.\n";
	} else {
	    print "Deleting $entry...";
	    system ("echo deleting $entry >> $logfile");
	    system ("rm -rf $entry >> $logfile 2>&1");
	    print "\n";
	}
    }
    system ("echo done at: `date` >> $logfile");
}

# Deletes all of the grub config file entries associated with that
# image and deletes the files associated with that entry.  If caller
# provides the version string of the image to be deleted ($del_ver),
# that version is targetted.  Otherwise, the caller must provide the
# index into the boot entries list ($resp) to identify the image to be
# deleted.
#
sub doDelete {
  my ($resp, $orig_def_ver, $def_ter, $bentries, $del_ver) = @_;
  if (!defined($del_ver)) {
      $del_ver = $ {$bentries}[$resp]->{'ver'};
  }
  my $boot_dir;

  my $cver = curVer();
  if (!defined($cver)) {
      print "Cannot verify current version. Exiting...\n";
      exit 1;
  }
  if ($cver eq $del_ver) {
      print "Cannot delete current running image. Reboot into a different\n";
      print "image to delete this image.  Exiting...\n";
      exit 1;
  }

  print "Are you sure you want to delete the\n\"$del_ver\" image? ";
  print '(Yes/No) [No]: ';
  $resp = <STDIN>;
  if (!defined($resp)) {
    $resp = 'no';
  }
  chomp($resp);
  $resp = lc($resp);
  if (($resp ne 'yes') && ($resp ne 'y')) {
    print "Image is NOT deleted. Exiting...\n";
    exit 1;
  }

  if (-d $UNION_BOOT) {
    $boot_dir = $UNION_BOOT;
  } elsif (-d $DISK_BOOT) {
    $boot_dir = $DISK_BOOT;
  }

  if (($del_ver ne $OLD_IMG_VER_STR) && (! -d "$boot_dir/$del_ver")) {
    print "Cannot find the target image. Exiting...\n";
    exit 1;
  }

  print "Deleting the \"$del_ver\" image...\n";
  deleteGrubEntries($del_ver);

  if ($del_ver eq $OLD_IMG_VER_STR) {
      del_non_image_files();
  } else {
    system("rm -rf '$boot_dir/$del_ver'");
    if ($? >> 8) {
      print "Error deleting the image. Exiting...\n";
      exit 1;
    }
  }

  print "Done\n";

  # Need to reset the grub default pointer becuase entry before default
  # may have been deleted, or the default entry itself may have
  # been deleted.
  if ($del_ver eq $orig_def_ver) {
      select_by_name($cver, $def_ter);
      print "The default image has been changed to the currently running image:\n";
      print "$cver\n";
  } else {
      select_by_name($orig_def_ver, $def_ter);
  }

  system("logger -p local3.warning -t 'SystemImage' 'System Image $del_ver has been deleted'");

  exit 0;
}

#
# Main section
# 

my ($show, $del, $sel, $list, $show_vers) = (undef, undef, undef, undef);

GetOptions(
  'show' => \$show,
  'delete:s' => \$del,
  'select:s' => \$sel,
  'list' => \$list,
  'show_vers' => \$show_vers,
);

if (-e $UNION_GRUB_CFG) {
    $grub_cfg = $UNION_GRUB_CFG;
} elsif (-e $OLD_GRUB_CFG) {
    $grub_cfg = $OLD_GRUB_CFG;
} elsif ((! -d $UNION_BOOT) && (-d $LIVE_CD)) {
    die "System running on Live-CD\n";
} else {
    print "Can not open Grub config file\n";
    exit 1;
}

my $gref = parseGrubCfg();

my $def_idx = $gref->{'default'};
my $entries = $gref->{'entries'};
if (!defined($def_idx) || !defined($entries)
    || !defined(${$entries}[$def_idx])) {
    die "Error parsing GRUB configuration file. Exiting...\n";
}
my $def_ver = ${$entries}[$def_idx]->{'ver'};
my $def_term = ${$entries}[$def_idx]->{'term'};

my $bentries = getBootList($def_term, $entries);
if ($#{$bentries} < 0) {
  die "No images found. Exiting...\n";
}

if (defined($list)) {
    displayBootList($def_idx, $bentries, 1);
    exit 0;
}

if (defined($sel) && ($sel ne "")) {
    # User has specified entry to select
    doSelect(0, $def_ver, $bentries, $sel);
    print "Done.\n";
    exit 0;
}

if (defined($del) && ($del ne "")) {
    # User has specified entry to delete
    doDelete(0, $def_ver, $def_term, $bentries, $del);
    print "Done.\n";
    exit 0;
}

my $msg = 'The system currently has the following image(s) installed:';
if (defined($del)) {
  # doing delete
  $msg = 'The following image(s) can be deleted:';
}
print "$msg\n\n";
displayBootList($def_idx, $bentries, undef, $show_vers);
print "\n";

exit 0 if (defined($show) || (!defined($sel) && !defined($del))); # show-only

# for doing select
my $prompt_msg = 'Select the default boot image: ';
my $error_msg = 'Invalid selection. Default is not changed.';
if (defined ($del)) {
  # doing delete
  $prompt_msg = 'Select the image to delete: ';
  $error_msg = 'Invalid selection. Nothing is deleted.';
}

print "$prompt_msg";
my $resp = <STDIN>;
if (defined($resp)) {
  chomp($resp);
  if (!($resp =~ /^\d+$/) || ($resp < 1) || ($resp > ($#{$bentries} + 1))) {
    $resp = undef;
  }
}
if (!defined($resp)) {
  die "$error_msg Exiting...\n";
}
print "\n";

$resp -= 1;

if (defined($sel)) {
  doSelect($resp, $def_ver, $bentries);
} elsif (defined($del)) {
  doDelete($resp, $def_ver, $def_term, $bentries);
} else {
  die "Unknown command.\n";
}

exit 0;

