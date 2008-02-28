defaultdir	 = /etc/default
default_DATA	 = etc/default/vyatta
completiondir	 = /etc/bash_completion.d
completion_DATA	 = etc/bash_completion.d/10vyatta-op
opdir		 = $(datadir)/vyatta-op/templates

funcdir		 = $(datadir)/vyatta-op/functions
func_DATA	 = functions/tech-support

alloweddir	 = $(datadir)/vyatta-op/functions/allowed
allowed_DATA	 = functions/allowed/hosts

bin_SCRIPTS	 = scripts/vyatta-show-interfaces
bin_SCRIPTS	+= scripts/vyatta-show-interfaces.pl
bin_SCRIPTS	+= scripts/vyatta-show-version
bin_SCRIPTS     += scripts/vyatta-show-dhclient.pl
bin_SCRIPTS	+= scripts/vyatta-show-log
bin_SCRIPTS	+= scripts/vyatta-show-log-all
bin_SCRIPTS	+= scripts/vyatta-show-log-file
bin_SCRIPTS	+= scripts/vyatta-show-dmesg
bin_SCRIPTS	+= scripts/vyatta-show-dmesg-all
bin_SCRIPTS	+= scripts/vyatta-show-dmi
bin_SCRIPTS	+= scripts/vyatta-identify-interface.pl

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
	cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(opdir)
	cd templates; $(cpiop) $(DESTDIR)$(opdir)
