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
bin_SCRIPTS += scripts/show-dhcp-leases.pl
bin_SCRIPTS += scripts/vyatta-boot-image.pl
bin_SCRIPTS	+= scripts/rename-image.pl
bin_SCRIPTS	+= scripts/show-image-storage.pl
bin_SCRIPTS	+= scripts/tech-support-archive
bin_SCRIPTS	+= scripts/vyatta-op-cmd-wrapper

sbin_SCRIPTS     = scripts/vyatta-image-tools.pl
sbin_SCRIPTS    += scripts/vyos-openvpn-remoteconfig.pl

bin_sudo_users_SCRIPTS     = scripts/vyatta-delete-log-file.sh

all-local:
	./gen-unpriv-commands.sh

clean-local:
	$(RM) -r generated-templates

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
	cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(opdir)
	cd templates; $(cpiop) $(DESTDIR)$(opdir)
	mkdir -p $(DESTDIR)$(etc_shell_leveldir)
	cd etc/shell/level; $(cpiop) $(DESTDIR)$(etc_shell_leveldir)
