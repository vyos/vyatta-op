#!/usr/bin/perl -w
use Getopt::Long;
use lib "/opt/vyatta/share/perl5/";

use strict;
use IO::Prompt;

my ($show, $delete, $updateone);
my @copy;
my @update;

GetOptions(
    "show=s"        => \$show,
    "delete=s"      => \$delete,
    "update=s{2}"   => \@update,
    "updateone=s"   => \$updateone,
    "copy=s{2}"     => \@copy
);

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
    update($updateone, "running");
}
if (@copy){
    copy(@copy);
}

sub conv_file {
    my $file = " ";
    my $filein = pop(@_);
    $file = $filein;
    my $topdir;
    if ($file =~ /(.+?):\/\/(.*)/){
        $topdir = $1;
        $file = $2;
    } elsif ($file =~ /^\//) {
        $topdir = "running";
    } else {
        print "File: $filein not found \n";
        exit 1;
    }
    if ($topdir eq "running") {
        $file = "/$file";
    } elsif (lc($topdir) eq 'disk-install') {
        $file = "/live/image/$file";
    } elsif (lc($topdir) eq 'tftp') {
        $file = $filein;
        $topdir = 'url';
    } elsif (lc($topdir) eq 'http') {
        $file = $filein;
        $topdir = 'url';
    } elsif (lc($topdir) eq 'ftp') {
        $file = $filein;
        $topdir = 'url';
    } elsif (lc($topdir) eq 'scp') {
        $file = $filein;
        $topdir = 'url';
    } else {
        if (!-d "/live/image/boot/$topdir/live-rw"){
            print "Image $topdir not found!\n";
            exit 1;
        }
        $file = "/live/image/boot/$topdir/live-rw/$file";
    }
    return ($topdir, $file);
}

sub conv_file_to_rel {
    my ($topdir, $filename) = @_;
    if ($topdir eq "running"){
        $filename =~ s?/?$topdir://?;
    } elsif ($topdir eq "disk-install") {
        $filename =~ s?/live/image/?$topdir://?;
    } else {
        $filename =~ s?/live/image/boot/$topdir/live-rw/?$topdir://?;
    }
    return $filename;
}

sub delete_file {
    my ($file) = @_;
    (my $topdir, $file) = conv_file($file);
    if ($topdir eq 'url'){
        print "Cannot delete files from a url\n";
        exit 1;
    }
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

sub url_copy {
    my ($from, $to) = @_;
    my ($f_topdir, $t_topdir);
    ($f_topdir, $from) = conv_file($from);
    ($t_topdir, $to) = conv_file($to);
    if ($t_topdir eq 'url' && $f_topdir eq 'url'){
        print "Cannot copy a url to a url\n";
        exit 1;
    } elsif($t_topdir eq 'url') {
        if (-d $from){
            print "Cannot upload an entire directory to url\n";
            exit 1;
        } elsif ($to =~ /http/){
            print "Cannot upload to http url\n";
            exit 1;
        }
        curl_to($from, $to);
    } elsif ($f_topdir eq 'url') {
        if (-d $to){
            $from =~ /.*\/(.*)/;
            my $from_file = $1;
            $to = "$to/$from_file";
            if (-f "$to") {
                if (!y_or_n("This file exists; overwrite if needed?")){
                    exit 0;
                }
            }
        }
        curl_from($from, $to);
    }
    exit 0;
}

sub copy {
    my ($from, $to) = @_;
    my ($f_topdir, $t_topdir);
    ($f_topdir, $from) = conv_file($from);
    if ($f_topdir eq 'url'){
        url_copy($from, $to);
    }
    ($t_topdir, $to) = conv_file($to);
    if ($t_topdir eq 'url'){
        url_copy($from, $to);
    }
    $from =~ /.*\/(.*)/;
    my $from_file = $1;
    if (-d $from && -e $to && !(-d $to)){
        print "Cannot copy a directory to a file.\n";
        return 1;
    } elsif (-f $to  || (-d $to && -f "$to/$from_file")) {
        if (y_or_n("This file exists; overwrite if needed?")){
            rsync($from, $to);
        }
    } elsif (-d $to && -d $from){
        if (y_or_n("This directory exists; would you like to merge?")){
            rsync($from, $to);
        }
    } else {
        rsync($from, $to);
    }
}

sub update {
    my ($to, $from) = @_;
    my ($t_topdir, $f_topdir);
    ($f_topdir, $from) = conv_file("$from://");
    if ($f_topdir eq 'url'){
        print "Cannot clone from a url\n";
        exit 1;
    }
    ($t_topdir, $to) = conv_file("$to://");
    if ($t_topdir eq 'running'){
        print "Cannot clone to running\n";
        exit 1;
    }
    if ($t_topdir eq 'disk-install'){
        print "Cannot clone to disk-install\n";
        exit 1;
    }
    if ($t_topdir eq 'url'){
        print "Cannot clone to a url\n";
        exit 1;
    }
    my $print_from = conv_file_to_rel($f_topdir, $from);
    my $print_to = conv_file_to_rel($t_topdir, $to);
    my $msg = "WARNING: This is a destructive copy of the /config directories\n".
              "This will erase all data in the ".$print_to."config directory\n".
              "This data will be replaced with the data from ".$print_from."config\n".
              "The current config data will be backed up in ".$print_to."config.preclone\n".
              "Do you wish to continue?";
    if (y_or_n("$msg")){
        system("rm -rf $to/config.preclone");
        system("mv $to/config $to/config.preclone") if (-d "$to/config");
        my $confdir="config";
        $confdir="opt/vyatta/etc/config" if ($f_topdir eq "disk-install");
        if (rsync("$from/$confdir", $to) > 0){
            print "Clone Failed!\nRestoring old config\n";
            system("mv $to/config.preclone $to/config");
        }
    }
}

sub rsync {
    my ($from,$to) = @_;
    system("rsync -a --progress --exclude '.wh.*' $from $to");
    return $?;
}

sub curl_to {
    my ($from, $to) = @_;
    my $rc = system("curl -# -T $from $to");
    if ($to =~  /scp/ && ($rc >> 8) == 51){
        $to =~ m/scp:\/\/(.*?)\//;
        my $host = $1;
        if ($host =~ m/.*@(.*)/) {
            $host = $1;
        }
        my $rsa_key = `ssh-keyscan -t rsa $host 2>/dev/null`;
        print "The authenticity of host '$host' can't be established.\n";
        my $fingerprint = `ssh-keygen -lf /dev/stdin <<< \"$rsa_key\" | awk {' print \$2 '}`;
        chomp $fingerprint;
        print "RSA key fingerprint is $fingerprint.\n";
        if (prompt("Are you sure you want to continue connecting (yes/no) [Yes]? ", -tynd=>"y")) {
            if (! -d "$ENV{HOME}/.ssh/") {
                mkdir "$ENV{HOME}/.ssh/";
            }
            open(my $known_hosts, ">>", "$ENV{HOME}/.ssh/known_hosts")
                or die "Cannot open known_hosts: $!";
            print $known_hosts "$rsa_key\n";
            close($known_hosts);
            $rc = system("curl -# -T $from $to");
            print "\n";
        }
    }
    print "\n";
}

sub curl_from {
    my ($from, $to) = @_;
    my $rc = system("curl -# $from > $to");
    if ($from =~ /scp/ && ($rc >> 8) == 51){
        $from =~ m/scp:\/\/(.*?)\//;
        my $host = $1;
        if ($host =~ m/.*@(.*)/) {
            $host = $1;
        }
        my $rsa_key = `ssh-keyscan -t rsa $host 2>/dev/null`;
        print "The authenticity of host '$host' can't be established.\n";
        my $fingerprint = `ssh-keygen -lf /dev/stdin <<< \"$rsa_key\" | awk {' print \$2 '}`;
        chomp $fingerprint;
        print "RSA key fingerprint is $fingerprint.\n";
        if (prompt("Are you sure you want to continue connecting (yes/no) [Yes]? ", -tynd=>"y")) {
            if (! -d "$ENV{HOME}/.ssh/") {
                mkdir "$ENV{HOME}/.ssh/";
            }
            open(my $known_hosts, ">>", "$ENV{HOME}/.ssh/known_hosts")
                or die "Cannot open known_hosts: $!";
            print $known_hosts "$rsa_key\n";
            close($known_hosts);
            $rc = system("curl -# $from > $to");
            print "\n";
        }
    }
    print "\n";
}

sub y_or_n {
    my ($msg) = @_;
    my $process_client = $ENV{'VYATTA_PROCESS_CLIENT'};
    if (defined $process_client){
        return 1 if ($process_client =~ /gui2_rest/);
    }
    print "$msg (Y/N): ";
    my $input = <>;
    return 1 if ($input =~ /Y|y/);
    return 0;
}

sub show {
    my ($topdir, $file) = conv_file(pop(@_));
    my $output = "";
    if ($topdir eq 'url'){
        print "Cannot show files from a url\n";
        exit 1;
    }
    if (-d $file) {
        print "########### DIRECTORY LISTING ###########\n";
        system("ls -lGph  --group-directories-first $file");
    } elsif (-T $file) {
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
    } elsif ($file =~ /.*\.pcap/){
        print "########### FILE INFO ###########\n";
        my $filename = conv_file_to_rel($topdir, $file);
        print "File Name: $filename\n";
        print "Binary File: \n";
        my $lsstr = `ls -lGh $file`;
        parsels($lsstr);
        print "  Description:\t";
        system("file -sb $file");
        print "\n########### FILE DATA ###########\n";
        system("sudo tshark -r $file | less");
    } elsif (-B $file) {
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
        my $filename = conv_file_to_rel($topdir, $file);
        print "File: $filename not found\n";
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
