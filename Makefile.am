defaultdir	 = /etc/default
default_DATA	 = etc/default/vyatta
completiondir	 = /etc/bash_completion.d
completion_DATA	 = etc/bash_completion.d/10vyatta-op
opdir		 = $(datadir)/vyatta-op/templates
bin_sudo_usersdir = $(bindir)/sudo-users

funcdir		 = $(datadir)/vyatta-op/functions
func_DATA	 = functions/tech-support

alloweddir	 = $(datadir)/vyatta-op/functions/allowed
allowed_DATA	 = functions/allowed/hosts

bin_SCRIPTS	 = scripts/vyatta-show-interfaces
bin_SCRIPTS	+= scripts/vyatta-show-interfaces.pl
bin_SCRIPTS	+= scripts/vyatta-show-version
bin_SCRIPTS     += scripts/vyatta-show-dhclient.pl
bin_SCRIPTS	+= scripts/vyatta-show-dmi
bin_SCRIPTS	+= scripts/vyatta-tshark-interface-port.pl

bin_sudo_users_SCRIPTS      = scripts/vyatta-identify-interface.pl
bin_sudo_users_SCRIPTS     += scripts/vyatta-delete-log-file.sh

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
	cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(opdir)
	cd templates; $(cpiop) $(DESTDIR)$(opdir)
