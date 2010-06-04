defaultdir	 = /etc/default
default_DATA	 = etc/default/vyatta
completiondir	 = /etc/bash_completion.d
completion_DATA	 = etc/bash_completion.d/10vyatta-op
opdir		 = $(datadir)/vyatta-op/templates
bin_sudo_usersdir = $(bindir)/sudo-users

funcdir		 = $(datadir)/vyatta-op/functions
func_DATA	 = functions/tech-support
func_DATA	+= functions/tech-support-brief

bin_SCRIPTS	 = scripts/vyatta-show-interfaces
bin_SCRIPTS	+= scripts/vyatta-show-interfaces.pl
bin_SCRIPTS	+= scripts/vyatta-show-version
bin_SCRIPTS     += scripts/vyatta-show-dhclient.pl
bin_SCRIPTS	+= scripts/vyatta-show-dmi
bin_SCRIPTS	+= scripts/vyatta-tshark-interface-port.pl
bin_SCRIPTS	+= scripts/vyatta-show-bonding.pl
bin_SCRIPTS	+= scripts/vyatta-cpu-summary.pl
bin_SCRIPTS	+= scripts/yesno
bin_SCRIPTS     += scripts/vyatta-gettime.pl
bin_SCRIPTS     += scripts/show-users.pl
bin_SCRIPTS     += scripts/show-dhcp-leases.pl
bin_SCRIPTS     += scripts/vyatta-boot-image.pl
bin_SCRIPTS	+= scripts/vyatta-sudo
bin_SCRIPTS	+= scripts/vyatta-show-snmp.pl
bin_SCRIPTS	+= scripts/rename-image.pl
bin_SCRIPTS	+= scripts/show-image-storage.pl
bin_SCRIPTS	+= scripts/node-exists.pl
bin_SCRIPTS	+= scripts/vyatta-remote-copy.pl

sbin_SCRIPTS     = scripts/dhcpv6-client-show-leases.pl

bin_sudo_users_SCRIPTS      = scripts/vyatta-identify-interface.pl
bin_sudo_users_SCRIPTS     += scripts/vyatta-delete-log-file.sh
bin_sudo_users_SCRIPTS	   += scripts/vyatta-reboot.pl
bin_sudo_users_SCRIPTS     += scripts/vyatta-op-dns-forwarding.pl
bin_sudo_users_SCRIPTS     += scripts/vyatta-op-dynamic-dns.pl
bin_sudo_users_SCRIPTS     += scripts/vyatta-clear-conntrack

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
	cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(opdir)
	cd templates; $(cpiop) $(DESTDIR)$(opdir)
