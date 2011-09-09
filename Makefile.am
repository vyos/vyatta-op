defaultdir	 = /etc/default
default_DATA	 = etc/default/vyatta
completiondir	 = /etc/bash_completion.d
completion_DATA	 = etc/bash_completion.d/vyatta-op
opdir		 = $(datadir)/vyatta-op/templates
bin_sudo_usersdir = $(bindir)/sudo-users
etc_shell_leveldir = $(sysconfdir)/shell/level

funcdir		 = $(datadir)/vyatta-op/functions
func_DATA	 = functions/tech-support
func_DATA	+= functions/tech-support-brief

interpdir = $(datadir)/vyatta-op/functions/interpreter
interp_DATA = functions/interpreter/vyatta-op-run
interp_DATA += functions/interpreter/vyatta-unpriv
interp_DATA += functions/interpreter/vyatta-common
interp_DATA += functions/interpreter/vyatta-image-complete


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
bin_SCRIPTS	+= scripts/vyatta-show-snmp-ifmib
bin_SCRIPTS	+= scripts/rename-image.pl
bin_SCRIPTS	+= scripts/show-image-storage.pl
bin_SCRIPTS	+= scripts/vyatta-remote-copy.pl
bin_SCRIPTS	+= scripts/vyatta-show-current-user
bin_SCRIPTS	+= scripts/tech-support-archive
bin_SCRIPTS	+= scripts/vyatta-op-cmd-wrapper
bin_SCRIPTS += scripts/vyatta-ping
bin_SCRIPTS += scripts/vyatta-traceroute
bin_SCRIPTS += scripts/vyatta-monitor
bin_SCRIPTS += scripts/vyatta-monitor-cleanup
bin_SCRIPTS += scripts/vyatta-monitor-background
bin_SCRIPTS += scripts/vyatta-monitor-background-stop

sbin_SCRIPTS     = scripts/dhcpv6-client-show-leases.pl
sbin_SCRIPTS    += scripts/vyatta-image-tools.pl
sbin_SCRIPTS    += scripts/vyatta-regen-unpriv-commands.sh

bin_sudo_users_SCRIPTS      = scripts/vyatta-identify-interface.pl
bin_sudo_users_SCRIPTS     += scripts/vyatta-delete-log-file.sh
bin_sudo_users_SCRIPTS	   += scripts/vyatta-reboot.pl
bin_sudo_users_SCRIPTS     += scripts/vyatta-op-dns-forwarding.pl
bin_sudo_users_SCRIPTS     += scripts/vyatta-op-dynamic-dns.pl
bin_sudo_users_SCRIPTS     += scripts/vyatta-clear-conntrack

all-local:
	./gen-unpriv-commands.sh

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
	cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(opdir)
	cd templates; $(cpiop) $(DESTDIR)$(opdir)
	mkdir -p $(DESTDIR)$(etc_shell_leveldir)
	cd etc/shell/level; $(cpiop) $(DESTDIR)$(etc_shell_leveldir)
