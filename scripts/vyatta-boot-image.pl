#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use File::Temp qw/ :mktemp /;

my $UNION_BOOT = '/live/image/boot';
my $UNION_GRUB_CFG = "$UNION_BOOT/grub/grub.cfg";
my $VER_FILE = '/opt/vyatta/etc/version';
my $OLD_IMG_VER_STR = 'Old non-image installation';

# this function parses the grub config file and returns a hash reference
# of the parsed data.
sub parseGrubCfg {
  my $fd = undef;
  return undef if (!open($fd, '<', $UNION_GRUB_CFG));

  my %ghash = ();
  my @entries = ();
  my $in_entry = 0;
  my $idx = 0;
  while (<$fd>) {
    if ($in_entry) {
      if (/^}/) {
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
        push @entries, \%ehash;
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

# this function deletes the entries for the specified version from the grub
# config file. returns undef if successful. otherwise returns error message.
sub deleteGrubEntries {
  my ($del_ver) = @_;

  my $rfd = undef;
  return 'Cannot delete GRUB entries' if (!open($rfd, '<', $UNION_GRUB_CFG));
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
        if (/^\s+linux \/boot\/([^\/ ]+)\/.* boot=live /) {
          # kernel line
          $ver = $1;
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

  my $p = (stat($UNION_GRUB_CFG))[2];
  return 'Failed to modify GRUB configuration'
    if (!defined($p) || !chmod(($p & 07777), $tfile));
  system("mv $tfile $UNION_GRUB_CFG");
  return 'Failed to delete GRUB entries' if ($? >> 8);
  return undef;
}

# this function takes the default terminal type and a list of all entries
# and returns the "boot list", i.e., the list for user to select which one
# to boot.
sub getBootList {
  my ($dver, $dterm, $entries, $delete) = @_;
  my %vhash = ();
  my @list = ();
  foreach (@{$entries}) {
    my ($ver, $term) = ($_->{'ver'}, $_->{'term'});
    # don't list non-image entry if deleting
    next if (defined($delete) && $ver eq $OLD_IMG_VER_STR);
    # don't list default entry if deleting
    next if (defined($delete) && $ver eq $dver);

    next if ($_->{'reset'}); # skip password reset entry
    next if ($term ne $dterm); # not the default terminal
    next if (defined($vhash{$ver})); # version already in list

    $vhash{$ver} = 1;
    push @list, $_;
  }
  return \@list;
}

sub displayBootList {
  my ($didx, $entries) = @_;
  for my $i (0 .. $#{$entries}) {
    my $di = $i + 1; 
    my $ver = ${$entries}[$i]->{'ver'};
    my $m = '';
    if ($didx == ${$entries}[$i]->{'idx'}) {
      $m = ' (default boot)';
    }
    printf "  %2d: %s%s\n", $di, $ver, $m;
  }
}

my ($show, $del, $sel) = (undef, undef, undef);
GetOptions(
  'show' => \$show,
  'delete' => \$del,
  'select' => \$sel
);

my $gref = parseGrubCfg();
if (!defined($gref)) {
  print "Cannot find GRUB configuration file. Exiting...\n";
  exit 1;
}
my $def_idx = $gref->{'default'};
my $entries = $gref->{'entries'};
if (!defined($def_idx) || !defined($entries)
    || !defined(${$entries}[$def_idx])) {
  print "Error parsing GRUB configuration file. Exiting...\n";
  exit 1;
}
my $def_ver = ${$entries}[$def_idx]->{'ver'};
my $def_term = ${$entries}[$def_idx]->{'term'};

my $bentries = getBootList($def_ver, $def_term, $entries, $del);
if ($#{$bentries} < 0) {
  print "No images found. Exiting...\n";
  exit 1;
}

my $msg = 'The system currently has the following image(s) installed:';
if (defined($del)) {
  # doing delete
  $msg = 'The following image(s) can be deleted:';
}
print "$msg\n\n";
displayBootList($def_idx, $bentries);
print "\n";

exit 0 if (defined($show) || (!defined($sel) && !defined($del))); # show-only

# for doing select
my $prompt_msg = 'Select the default boot image: ';
my $error_msg = 'Invalid selection. Default is not changed.';
if ($del) {
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
  print "$error_msg Exiting...\n";
  exit 1;
}
print "\n";

$resp -= 1;

if ($sel) {
  doSelect($resp);
} elsif ($del) {
  doDelete($resp);
}
exit 0;

sub doSelect {
  my ($bdx) = @_;
  my $new_idx = ${$bentries}[$resp]->{'idx'};
  my $new_ver = ${$bentries}[$resp]->{'ver'};
  system("sed -i 's/^set default=.*\$/set default=$new_idx/' $UNION_GRUB_CFG");
  if ($? >> 8) {
    print "Failed to set the default boot image. Exiting...\n";
    exit 1;
  }
  print <<EOF;
Default boot image has been set to "$new_ver".
You need to reboot the system to start the new default image.

EOF
  exit 0;
}

sub curVer {
  my ($fd, $ver) = (undef, undef);
  open($fd, '<', $VER_FILE) or return undef;
  while (<$fd>) {
    next if (!(/^Version\s+:\s+(\S+)$/));
    $ver = $1;
    last;
  }
  close($fd);
  return $ver;
}

sub doDelete {
  my ($bdx) = @_;
  my $del_ver = ${$bentries}[$resp]->{'ver'};
  print "Are you sure you want to delete the\n\"$del_ver\" image? ";
  print '(Yes/No) [No]: ';
  my $resp = <STDIN>;
  if (!defined($resp)) {
    $resp = 'no';
  }
  chomp($resp);
  $resp = lc($resp);
  if ($resp ne 'yes') {
    print "Image is NOT deleted. Exiting...\n";
    exit 1;
  }

  my $cver = curVer();
  if (!defined($cver)) {
    print "Cannot verify current version. Exiting...\n";
    exit 1;
  }
  if ($cver eq $del_ver) {
    print <<EOF;
Cannot delete current running image. Reboot into a different version
before deleting. Exiting...
EOF
    exit 1;
  }
  if (! -d "$UNION_BOOT/$del_ver") {
    print "Cannot find the target image. Exiting...\n";
    exit 1;
  }

  print "Deleting the \"$del_ver\" image...";
  my $err = deleteGrubEntries($del_ver);
  if (defined($err)) {
    print "$err. Exiting...\n";
    exit 1;
  }
  system("rm -rf '$UNION_BOOT/$del_ver'");
  if ($? >> 8) {
    print "Error deleting the image. Exiting...\n";
    exit 1;
  }

  print "Done\n";
  exit 0;
}

