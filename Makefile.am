defaultdir	 = /etc/default
default_DATA	 = etc/default/vyatta
completiondir	 = /etc/bash_completion.d
completion_DATA	 = etc/bash_completion.d/vyatta-op
opdir		 = $(datadir)/vyatta-op/templates

bin_SCRIPTS	 = scripts/show_interfaces
bin_SCRIPTS	+= scripts/show_interfaces_ethernet
bin_SCRIPTS	+= scripts/show_interfaces_loopback
bin_SCRIPTS	+= scripts/show_interfaces_statistics
bin_SCRIPTS	+= scripts/show_interfaces_summary
bin_SCRIPTS	+= scripts/show_interfaces_system
bin_SCRIPTS	+= scripts/show_interfaces_tunnel
bin_SCRIPTS	+= scripts/show_version

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
	cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(opdir)
	cd templates; $(cpiop) $(DESTDIR)$(opdir)
