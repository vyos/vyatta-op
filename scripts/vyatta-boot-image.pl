#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my $UNION_GRUB_CFG = '/live/image/boot/grub/grub.cfg';

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
          $ehash{'ver'} = 'Old non-image installation';
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

# this function takes the default terminal type and a list of all entries
# and returns the "boot list", i.e., the list for user to select which one
# to boot.
sub getBootList {
  my ($dterm, $entries) = @_;
  my %vhash = ();
  my @list = ();
  foreach (@{$entries}) {
    my ($ver, $term) = ($_->{'ver'}, $_->{'term'});
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

my ($show, $sel) = (undef, undef);
GetOptions(
  'show' => \$show,
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
my $def_term = ${$entries}[$def_idx]->{'term'};

my $bentries = getBootList($def_term, $entries);

print "The system currently has the following images installed:\n\n";
displayBootList($def_idx, $bentries);
print "\n";

exit 0 if ($show); # show-only. done.

print 'Select the default boot image: ';
my $resp = <STDIN>;
if (!defined($resp) || !($resp =~ /^\d+$/) || ($resp < 1)
    || ($resp > ($#{$bentries} + 1))) {
  print "Invalid selection. Default is not changed. Exiting...\n";
  exit 1;
}

print "\n";
$resp -= 1;
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

