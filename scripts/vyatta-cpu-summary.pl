#! /usr/bin/perl
# implement "show cpu-info"

open my $cpuinfo, '<', '/proc/cpuinfo'
  or die "Can't open /proc/cpuinfo : $!";

my %models;
my %packages;
my %cores;

my %map = (
    'model name'  => \%models,
    'physical id' => \%packages,
    'core id'     => \%cores
);

my $cpu = 0;
while (<$cpuinfo>) {
    chomp;
    my ( $tag, $val ) = split /:/;
    if ( !$tag ) {
        ++$cpu;
        next;
    }

    $tag =~ s/\s+$//;
    $val =~ s/^\s+//;

    my $ref = $map{$tag};
    $ref->{$val} = $cpu  if ($ref);
}
close $cpuinfo;

print "CPU       ", join( "       \n", keys %models ), "\n";
print "Packages  ", scalar keys %packages, "\n";
print "Cores     ", scalar keys %cores,    "\n";
print "Threads   ", $cpu, "\n";
