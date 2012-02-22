#!/usr/bin/perl
#
# Module: vyatta-op-dns-forwarding.pl
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
# Portions created by Vyatta are Copyright (C) 2008 Vyatta, Inc.
# All Rights Reserved.
#
# Author: Mohit Mehta
# Date: August 2008
# Description: Script to execute op-mode commands for DNS forwarding
#
# **** End License ****
#

use lib "/opt/vyatta/share/perl5/";
use Getopt::Long;
use Vyatta::Config;
use strict;
use warnings;

my $show_stats_output="";
my $show_nameservers_output="";
my $dnsmasq_log='/var/log/dnsmasq.log';

sub get_cache_stats {
    my ($cache_size, $queries_forwarded, $queries_answered_locally, $entries_inserted, $entries_removed);

    my $grepped_line = `grep 'cache size' $dnsmasq_log`;
    my @split_line = split(/\s+/, $grepped_line);
    my @temp_split = split(/,/, $split_line[6]);
    $cache_size = $temp_split[0];
    @temp_split = split(/\//, $split_line[7]);
    $entries_removed = $temp_split[0];
    $entries_inserted = $temp_split[1];

    $grepped_line = `grep 'queries forwarded' $dnsmasq_log`;
    @split_line = split(/\s+/, $grepped_line);
    @temp_split = split(/,/, $split_line[6]);
    $queries_forwarded = $temp_split[0];
    $queries_answered_locally = $split_line[10];

    $show_stats_output .= "----------------\n";
    $show_stats_output .= "Cache statistics\n";
    $show_stats_output .= "----------------\n";
    $show_stats_output .= "Cache size: $cache_size\n";
    $show_stats_output .= "Queries forwarded: $queries_forwarded\n";
    $show_stats_output .= "Queries answered locally: $queries_answered_locally\n";
    $show_stats_output .= "Total DNS entries inserted into cache: $entries_inserted\n";
    $show_stats_output .= "DNS entries removed from cache before expiry: $entries_removed\n";

}

sub get_nameserver_stats {

    $show_stats_output .= "\n---------------------\n";
    $show_stats_output .=   "Nameserver statistics\n";
    $show_stats_output .=   "---------------------\n";

    #To show overridden domain servers seperately, we need to compare IPs
    #configured for the domain overrides in the config with the stats.  

    my $vyatta_config = new Vyatta::Config;
    $vyatta_config->setLevel("service dns forwarding");

    my @domains = $vyatta_config->listOrigNodes("domain");   
    my @domain_servers_list;

    #build a list of servers that are overriding global nameservers
    if (@domains) {
        foreach my $domain (@domains) {
            push(@domain_servers_list, $vyatta_config->returnOrigValue("domain $domain server"));             
        }  
    }
    my $found_overrides = 0;
    my $show_stats_overrides; 
    my @grepped_lines = `grep ': server' $dnsmasq_log`;
    foreach my $lines (@grepped_lines) {
            my @each_line = split(/\s+/, $lines);
            my $nameserver_word = $each_line[5];
            my @nameserver_split = split(/#/, $nameserver_word);
            my $nameserver = $nameserver_split[0];
            my $queries_sent_word = $each_line[8];
            my @queries_sent_split = split(/,/, $queries_sent_word);
            my $queries_sent = $queries_sent_split[0];
            my $queries_retried_failed = $each_line[12];

            if (grep {$_ eq $nameserver}@domain_servers_list) {
                if (!$found_overrides) {
                    $found_overrides = 1;
                    $show_stats_overrides .= "\nDomain Override Servers\n\n";
                }
                $show_stats_overrides .= "Server: $nameserver\nQueries sent: $queries_sent\nQueries retried or failed: $queries_retried_failed\n\n";
            } else {
                $show_stats_output .= "Server: $nameserver\nQueries sent: $queries_sent\nQueries retried or failed: $queries_retried_failed\n\n";
            }
    }
    if (defined($show_stats_overrides)) {
        $show_stats_output .= $show_stats_overrides;
    }
}

sub print_stats {
    print $show_stats_output;
}

sub get_dns_nameservers {
    my $vyatta_config = new Vyatta::Config;

    $vyatta_config->setLevel("service dns forwarding");
    my $use_system_nameservers = $vyatta_config->existsOrig("system");
    my @use_dhcp_nameservers = $vyatta_config->returnOrigValues("dhcp");
    my @use_nameservers = $vyatta_config->returnOrigValues("name-server");
    my @resolv_conf_nameservers = `grep "^nameserver" /etc/resolv.conf`;
    my @dnsmasq_conf_nameservers = `grep "server=" /etc/dnsmasq.conf`;
    my @dnsmasq_running = `ps ax | grep dnsmasq | grep -v grep`;

    if (!(defined $use_system_nameservers) && (@use_dhcp_nameservers == 0) && (@use_nameservers == 0)) {

       # no specific nameservers specified under DNS forwarding, so dnsmasq is getting nameservers from /etc/resolv.conf

       if (! @resolv_conf_nameservers > 0){
           $show_nameservers_output .= "No DNS servers present to forward queries to.\n";
           if (! @dnsmasq_running > 0){
               $show_nameservers_output .= "DNS forwarding has not been configured either.\n";
           }
       } else {
            if (! @dnsmasq_running > 0){
               $show_nameservers_output .= "\n**DNS forwarding has not been configured**\n\n";
            }
            $show_nameservers_output .=    "-----------------------------------------------\n";
            if ( @dnsmasq_running > 0){
               $show_nameservers_output .= "   Nameservers configured for DNS forwarding\n";
            } else {
              $show_nameservers_output .=  " Nameservers NOT configured for DNS forwarding\n";
            }
            $show_nameservers_output .=    "-----------------------------------------------\n";
            foreach my $line (@resolv_conf_nameservers) {
               my @split_line = split(/\s+/, $line);
               my $nameserver = $split_line[1];
               my $nameserver_via = "system";
               if (@split_line > 2) {
                  my @dhclient_resolv_files = `ls /etc/resolv.conf.dhclient-new-* 2>/dev/null`;
                  foreach my $each_dhcp_resolv_conf (@dhclient_resolv_files) {
                        my @ns_dhclient_resolv=`grep "$nameserver\$" $each_dhcp_resolv_conf`;
                        if ( @ns_dhclient_resolv > 0) {
                            my @dhclient_file_array = split(/-/, $each_dhcp_resolv_conf);
                            $nameserver_via = $dhclient_file_array[2];
                            chomp $nameserver_via;
                            $nameserver_via = 'dhcp ' . $nameserver_via;
                     }
                  }
                  # check here if nameserver_via is still system, if yes then search /etc/ppp/resolv-interface.conf
                  if ($nameserver_via eq "system") {
                    my @ppp_resolv_files = `ls /etc/ppp/resolv-*conf 2>/dev/null`;
                    foreach my $each_ppp_resolv_conf (@ppp_resolv_files) {
                      my @ns_ppp_resolv=`grep "$nameserver\$" $each_ppp_resolv_conf`;
                      if ( @ns_ppp_resolv > 0) {
                        my @ppp_file_array = split(/-/, $each_ppp_resolv_conf);
                        @ppp_file_array = split(/\./, $ppp_file_array[1]);
                        $nameserver_via = $ppp_file_array[0];
                        chomp $nameserver_via;
                        $nameserver_via = 'ppp ' . $nameserver_via;
                      }
                    }
                  }
               }
               $show_nameservers_output .= "$nameserver available via '$nameserver_via'\n";
            }
      }
      $show_nameservers_output .= "\n";
    } else {

        # nameservers specified under DNS forwarding, so dnsmasq getting nameservers from /etc/dnsmasq.conf

	my @active_nameservers;
        my $active_nameserver_count = 0;
        $show_nameservers_output .= "-----------------------------------------------\n";
        $show_nameservers_output .= "   Nameservers configured for DNS forwarding\n";
        $show_nameservers_output .= "-----------------------------------------------\n";
        my $show_nameservers_output_dhcp;
        my $show_nameservers_output_domain;
        my $show_nameservers_output_nameserver;

        my $line_flag;
        ## server=/test.com/1.1.1.1 
	foreach my $line (@dnsmasq_conf_nameservers) {
	        my @split_line = split(/=/, $line);
		my @nameserver_array = split(/\s+/, $split_line[1]);
                my $nameserver = $nameserver_array[0];
                my $domain;
                my @domain_tokens; 

                if ($nameserver_array[2] eq "domain-override")
                {
                    #$nameserver has /test.com/1.1.1.1, seperate it. 
                    @domain_tokens = split(/\//, $nameserver);
                    if (!defined($line_flag)) { 
                        $line_flag = 1;
                        $show_nameservers_output_domain .= "\n";
                        $show_nameservers_output_domain .= "Domain Overrides:\n";
                        $show_nameservers_output_domain .= "\n";
                    }      
                } 
		$active_nameservers[$active_nameserver_count] = $nameserver;
		$active_nameserver_count++;
                my $nameserver_via = $nameserver_array[2];
                if (@nameserver_array > 3){
		   my $dhcp_interface = $nameserver_array[3];
	           $show_nameservers_output_dhcp .= "$nameserver available via '$nameserver_via $dhcp_interface'\n";
                 } elsif (@domain_tokens) {
                     $show_nameservers_output_domain .= "$domain_tokens[1] uses $domain_tokens[2]\n";
                   } else {
 		   $show_nameservers_output_nameserver .= "$nameserver available via '$nameserver_via'\n";
 		}
        }
        if (defined ($show_nameservers_output_nameserver)) {
          $show_nameservers_output .= $show_nameservers_output_nameserver;
        }
        if (defined ($show_nameservers_output_dhcp)) {
          $show_nameservers_output .= $show_nameservers_output_dhcp;
        }
        if (defined ($show_nameservers_output_domain)) {
          $show_nameservers_output .= $show_nameservers_output_domain ;
        }

	# then you need to get nameservers from /etc/resolv.conf that are not in dnsmasq.conf to show them as inactive

        my $active_dnsmasq_nameserver;
	my $output_inactive_nameservers = 0;
	foreach my $resolv_conf_line (@resolv_conf_nameservers) {
               my @resolv_conf_split_line = split(/\s+/, $resolv_conf_line);
               my $resolv_conf_nameserver = $resolv_conf_split_line[1];
	       $active_dnsmasq_nameserver = 0;
	       my $resolv_nameserver_via = "system";
	       foreach my $dnsmasq_nameserver (@active_nameservers) {
		       if ($dnsmasq_nameserver eq $resolv_conf_nameserver) {
			   $active_dnsmasq_nameserver = 1;
		       }
	       }
	       if ($active_dnsmasq_nameserver == 0) {
                 if ($output_inactive_nameservers == 0){
                     $output_inactive_nameservers = 1;
                     $show_nameservers_output .= "\n-----------------------------------------------\n";
                     $show_nameservers_output .=   " Nameservers NOT configured for DNS forwarding\n";
                     $show_nameservers_output .=   "-----------------------------------------------\n";
                 }
                 if (@resolv_conf_split_line > 2) {
                     my @dhclient_resolv_files = `ls /etc/resolv.conf.dhclient-new-* 2>/dev/null`;
                     foreach my $each_dhcp_resolv_conf (@dhclient_resolv_files) {
                        chomp $each_dhcp_resolv_conf;
                        my @ns_dhclient_resolv=`grep "$resolv_conf_nameserver\$" $each_dhcp_resolv_conf`;
                        if ( @ns_dhclient_resolv > 0) {
                            my @dhclient_file_array = split(/-/, $each_dhcp_resolv_conf);
			    $resolv_nameserver_via = $dhclient_file_array[2];
                            chomp $resolv_nameserver_via;
                            $resolv_nameserver_via = 'dhcp ' . $resolv_nameserver_via;
                        }
                     }
                     # check here if resolv_nameserver_via is still system, if yes then search /etc/ppp/resolv-interface.conf
                     if ($resolv_nameserver_via eq "system") {
                       my @ppp_resolv_files = `ls /etc/ppp/resolv-*conf 2>/dev/null`;
                       foreach my $each_ppp_resolv_conf (@ppp_resolv_files) {
                         my @ns_ppp_resolv=`grep "$resolv_conf_nameserver\$" $each_ppp_resolv_conf`;
                         if ( @ns_ppp_resolv > 0) {
                           my @ppp_file_array = split(/-/, $each_ppp_resolv_conf);
                           @ppp_file_array = split(/\./, $ppp_file_array[1]);
                           $resolv_nameserver_via = $ppp_file_array[0];
                           chomp $resolv_nameserver_via;
                           $resolv_nameserver_via = 'ppp ' . $resolv_nameserver_via;
                         }
                       }
                     }
                  }

		  $show_nameservers_output .= "$resolv_conf_nameserver available via '$resolv_nameserver_via'\n";
	       }
	}
    $show_nameservers_output .= "\n";
    }
}

sub print_nameservers {
    print $show_nameservers_output;
}

sub wait_for_write {

    my $last_size = (stat($dnsmasq_log))[7];
    my $cnt=0;
    while(1) {
        system("usleep 10000");         # sleep for 0.01 second
        my $curr_size = (stat($dnsmasq_log))[7];
        if( $curr_size == $last_size ) {
            # Not modified
            $cnt++;
            last if($cnt > 1);
        } else {
            # Modified\n
            $cnt=0;
        }
        $last_size = $curr_size;
    }

}

#
# main
#
my ($clear_cache, $clear_all, $show_statistics, $show_nameservers);

GetOptions("clear-cache!"               => \$clear_cache,
           "clear-all!"                 => \$clear_all,
           "show-statistics!"           => \$show_statistics,
           "show-nameservers!"          => \$show_nameservers);

if (defined $clear_cache) {
    system("kill -1 `pidof dnsmasq`");
}

if (defined $clear_all) {
     system("/etc/init.d/dnsmasq restart >&/dev/null");
}

if (defined $show_statistics) {
    system("echo > $dnsmasq_log; kill -10 `pidof dnsmasq`");
    wait_for_write;
    get_cache_stats;
    get_nameserver_stats;
    print_stats;
}

if (defined $show_nameservers) {
    get_dns_nameservers;
    print_nameservers;
}

exit 0;

# end of file
