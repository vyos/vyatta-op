#!/usr/bin/perl
#
# Copyright (C) 2017 VyOS maintainers and contributors
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 or later as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use lib "/opt/vyatta/share/perl5/";
use Vyatta::Config;

use warnings;
use strict;

sub auth_warning
{
    print("NOTE: authentication options are deliberately left out,\n");
    print("since we cannot know file paths on a remote system\n\n");
}

my $config = new Vyatta::Config;

if(!$config->inSession()) {
    print("This command can only be used from configuration mode!");
    exit(1);
}

my $intf = $ARGV[0];
if(!defined($intf))
{
    print("OpenVPN interface is not specified!\n");
    exit(1);
}

my $remote = $ARGV[1];
if(!defined($remote))
{
    print("Remote side platform is not specified!\n");
    exit(1);
}

if(!$config->exists("interfaces openvpn $intf"))
{
    print("OpenVPN interface $intf does not exist!\n");
    exit(1);
}

$config->setLevel("interfaces openvpn $intf");

my $mode = $config->returnValue('mode');

my $localhost = $config->returnValue("local-host");
my $localport = $config->returnValue("local-port");
my $remotehost = $config->returnValue("remote-host");
my $remoteaddr = $config->returnValue("remote-address");
my $remoteport = $config->returnValue("remote-port");
my $cipher = $config->returnValue("encryption");
my $hash = $config->returnValue("hash");
my $protocol = $config->returnValue("protocol");
my $persist = $config->exists("persistent-tunnel");
my $tlsrole = $config->returnValue("tls role");
my $devtype = $config->returnValue("device-type");
my @options = $config->returnValues("openvpn-option");

# local-addr is a tag node...
# Let's limit it to only the first address for now,
# since remote-address is limited to only one address anyway!
my @localaddrs = $config->listNodes('local-address');
my $localaddr = undef;
if(@localaddrs) {
    $localaddr = $localaddrs[0];
}

if($mode eq 'client')
{
    print("It is impossible to produce a complete server config from a client config!\n");
    exit(1);
}
elsif($mode eq 'site-to-site')
{
    if($remote eq 'vyos')
    {
        auth_warning;

        print("edit interfaces openvpn $intf\n");
        print("set mode site-to-site\n");
        print("set device-type $devtype\n") if defined($devtype);
        print("set remote-host $localhost\n") if defined($localhost);
        print("set remote-address $localaddr\n") if defined($localaddr);
        print("set remote-port $localport\n") if defined($localport);
        print("set local-host $remotehost\n") if defined($remotehost);
        print("set local-address $remoteaddr\n") if defined($remoteaddr);
        print("set local-port $remoteport\n") if defined($remoteport);
        print("set protocol $protocol\n") if defined($protocol);
        print("set encryption $cipher\n") if defined($cipher);
        print("set hash $hash\n") if defined($hash);

        for my $o (@options) { print("set openvpn-option \"$o\"\n"); }

        print "tls role passive\n" if (defined($tlsrole) && ($tlsrole eq 'active'));
        print "tls role active\n" if (defined($tlsrole) && ($tlsrole eq 'passive'));
        print("top\n");
    }
}
elsif($mode eq 'server')
{
    if($remote eq 'vyos')
    {
        auth_warning;

        print("edit interfaces openvpn $intf\n");
        print("set mode client");
        print("set device-type $devtype\n") if defined($devtype);
        print("set remote-host $localhost\n") if defined($localhost);
        print("set remote-port $localport\n") if defined($localport);
        print("set protocol $protocol\n") if defined($protocol);
        print("top\n");
    }
}
