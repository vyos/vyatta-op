#!/usr/bin/perl -w
use Getopt::Long;
use lib "/opt/vyatta/share/perl5/";

use strict;

my ($show, $delete, $updateone);
my @copy;
my @update;

GetOptions("show=s"        => \$show,
           "delete=s"      => \$delete,
           "update=s{2}"   => \@update,
           "updateone=s"   => \$updateone,
           "copy=s{2}"     => \@copy);

if (defined $show){
  show($show);
}
if (defined $delete){
  delete_file($delete);
}
if (@update){
  update(@update);
}
if (defined($updateone)){
  update($updateone, "running://");
}
if (@copy){
  copy(@copy);
}

sub conv_file {
  my $file = " ";
  $file = pop(@_);
  $file =~ s/://;
  $file =~ /(.+?)\/\/(.*)/;
  my $topdir = $1;
  $file = $2;
  if ( $topdir eq "running" ) {
    $file = "/$file";
  } else {
    $file = "/live/image/boot/$topdir/live-rw/$file";
  }
  return ($topdir, $file);
}

sub conv_file_to_rel {
  my ($topdir, $filename) = @_;
  if ($topdir eq "running"){
    $filename =~ s?/?$topdir://?;
  } else {
    $filename =~ s?/live/image/boot/$topdir/live-rw/?$topdir://?;
  }
  return $filename;
}

sub delete_file {
  my ($file) = @_;
  (my $topdir, $file) = conv_file($file);
  if (-d $file){
    my $print_dir = conv_file_to_rel($topdir,$file);
    if (y_or_n("Do you want to erase the entire $print_dir directory?")){
      system("rm -rf $file");
      print("Directory erased\n");
    }
  } elsif (-f $file) {
    my $print_file = conv_file_to_rel($topdir,$file);
    if (y_or_n("Do you want to erase the $print_file file?")){
      system("rm -rf $file");
      print("File erased\n");
    }
  }
}

sub copy {
  my ($from, $to) = @_;
  my ($f_topdir, $t_topdir);
  ($f_topdir, $from) = conv_file($from);
  ($t_topdir, $to) = conv_file($to);
  $from =~ /.*\/(.*)/;
  my $from_file = $1;
  if ( -d $from && -e $to && !( -d $to ) ){
    print "Cannot copy a directory to a file.\n";
    return 1;
  } elsif ( -f $to  || (-d $to && -f "$to/$from_file") ) {
    if (y_or_n("This file exists; overwrite if needed?")){
      rsync($from, $to);
    }
  } elsif ( -d $to && -d $from ){
    my $print_from = conv_file_to_rel($f_topdir, $from);
    my $print_to = conv_file_to_rel($t_topdir, $to);
    if (y_or_n("Merge directory $print_from with $print_to?")){
      rsync($from, $to);
    }
  } else {
    rsync($from, $to);
  }
}

sub update {
  my ($to, $from) = @_;
  my ($t_topdir, $f_topdir);
  ($f_topdir, $from) = conv_file($from);
  ($t_topdir, $to) = conv_file($to);
  my $print_from = conv_file_to_rel($f_topdir, $from);
  my $print_to = conv_file_to_rel($t_topdir, $to);
  my $msg = "WARNING: This is a destructive copy of the /config directories\n"
          . "This will erase all data in the ".$print_to."config directory\n"
          . "This data will be replaced with the data from $print_from\n"
          . "Do you wish to continue?";
  if (y_or_n("$msg")){
    system("rm -rf $to/config");
    rsync("$from/config", $to);
  }
}

sub rsync {
  my ($from,$to) = @_;
  system("rsync -av --progress $from $to");
}

sub y_or_n {
  my ($msg) = @_;
  print "$msg (Y/N): ";
  my $input = <>;
  return 1 if ($input =~ /Y|y/);
  return 0;
}

sub show {
  my ($topdir, $file) = conv_file(pop(@_));
  my $output = "";
  if ( -d $file ) {
    print "########### DIRECTORY LISTING ###########\n";
    system("ls -lGph  --group-directories-first $file");
  } elsif ( -T $file ) {
    print "########### FILE INFO ###########\n";
    my $filename = conv_file_to_rel($topdir, $file);
    print "File Name: $filename\n";
    print "Text File: \n";
    my $lsstr = `ls -lGh $file`;
    parsels($lsstr);
    print "  Description:\t";
    system("file -sb $file");
    print "\n########### FILE DATA ###########\n";
    system("cat $file");
  } elsif ( -B $file ) {
    print "########### FILE INFO ###########\n";
    my $filename = conv_file_to_rel($topdir, $file);
    print "File Name: $filename\n";
    print "Binary File: \n";
    my $lsstr = `ls -lGh $file`;
    parsels($lsstr);
    print "  Description:\t";
    system("file -sb $file");
    print "\n########### FILE DATA ###########\n";
    system("hexdump -C $file| less");
  } else {
    print "File Not Found\n";
  }
}

sub parsels {
  my $lsout = pop(@_);
  my @ls = split(' ', $lsout);
  print "  Permissions: $ls[0]\n";
  print "  Owner:\t$ls[2]\n";
  print "  Size:\t\t$ls[3]\n";
  print "  Modified:\t$ls[4] $ls[5] $ls[6]\n";
}
