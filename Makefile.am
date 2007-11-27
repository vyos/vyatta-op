defaultdir	 = /etc/default
default_DATA	 = etc/default/vyatta
completiondir	 = /etc/bash_completion.d
completion_DATA	 = etc/bash_completion.d/10vyatta-op
opdir		 = $(datadir)/vyatta-op/templates

funcdir		 = $(datadir)/vyatta-op/functions
func_DATA = functions/tech-support

bin_SCRIPTS	 = scripts/vyatta-show-interfaces
bin_SCRIPTS	+= scripts/vyatta-show-version

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
	cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(opdir)
	cd templates; $(cpiop) $(DESTDIR)$(opdir)
