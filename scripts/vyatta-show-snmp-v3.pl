#! /usr/bin/perl

use Getopt::Long;

sub show_view() {
    print <<END;

SNMPv3 Views:

END

    foreach my $view ( listNodes("view") ) {
        print "View : $view\nOIDs :\n";
        foreach my $oid ( listNodes("view $view oid") ) {
            my $exclude = '';
            $exclude = ' exclude'
              if ( isExists("view $view oid $oid exclude") );
            my $mask = '';
            if ( isExists("view $view oid $oid mask") ) {
                my $value = returnValue("view $view oid $oid mask");
                $mask = " mask $value";
            }
            print "       .$oid$exclude$mask\n";
        }
        print "\n";
    }
}

sub show_group() {
    print <<END;

SNMPv3 Groups:

Group               View
-----               ----
END

    foreach my $group ( listNodes("group") ) {
        my $view = returnValue("group $group view");
        my $mode = returnValue("group $group mode");
        if ( length($group) >= 20 ) {
            print "$group\n                    $view($mode)\n";
        }
        else {
            $~ = "GROUP_FORMAT";
            format GROUP_FORMAT =
@<<<<<<<<<<<<<<<<<< @*(@*)
$group $view $mode
.
            write;
        }
    }
    print "\n";
}

sub show_user() {
    print <<END;

SNMPv3 Users:

User                Auth Priv Mode Group
----                ---- ---- ---- -----
END

    foreach my $user ( listNodes("user") ) {
        my $auth  = returnValue("user $user auth type");
        my $priv  = returnValue("user $user privacy type");
        my $mode  = returnValue("user $user mode");
        my $group = returnValue("user $user group");
        if ( length($user) >= 20 ) {
            print "$user\n                    $auth  $priv  $mode   $group\n";
        }
        else {
            $~ = "USER_FORMAT";
            format USER_FORMAT =
@<<<<<<<<<<<<<<<<<< @<<< @<<< @<<< @*
$user $auth $priv $mode $group
.
            write;
        }
    }
    print "\n";
}

sub show_trap() {
    print <<END;

SNMPv3 Trap-targets:

Tpap-target                   Port   Protocol Auth Priv Type   EngineID                 User
-----------                   ----   -------- ---- ---- ----   --------                 ----
END

    foreach my $trap ( listNodes("trap-target") ) {
        my $auth     = returnValue("trap-target $trap auth type");
        my $priv     = returnValue("trap-target $trap privacy type");
        my $type     = returnValue("trap-target $trap type");
        my $port     = returnValue("trap-target $trap port");
        my $user     = returnValue("trap-target $trap user");
        my $protocol = returnValue("trap-target $trap protocol");
        my $engineid = returnValue("trap-target $trap engineid");
        if ( length($trap) >= 30 ) {
            $~ = "TRAP_BIG_FORMAT";
            format TRAP_BIG_FORMAT =
^*
$trap
                              @<<<<< @<<<<<<< @<<< @<<< @<<<<< @<<<<<<<<<<<<<<<<<<<<... @*
$port $protocol $auth $priv $type $engineid $user
.
            write;
        }
        else {
            $~ = "TRAP_FORMAT";
            format TRAP_FORMAT =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<< @<<<<<<< @<<< @<<< @<<<<< @<<<<<<<<<<<<<<<<<<<<... @*
$trap $port $protocol $auth $priv $type $engineid $user
.
            write;
        }
    }
    print "\n";
}

sub show_all() {
    show_user();
    show_group();
    show_view();
    show_trap();
}

sub listNodes {
    my $path = shift;
    my @nodes =
      split( ' ', `cli-shell-api listActiveNodes service snmp v3 $path` );
    return map { substr $_, 1, -1 } @nodes;
}

sub returnValue {
    my $path  = shift;
    my $value = `cli-shell-api returnActiveValue service snmp v3 $path`;
    return $value;
}

sub isExists {
    my $path = shift;
    system("cli-shell-api existsActive service snmp v3 $path");
    return !$?;
}

my $all;
my $view;
my $group;
my $user;
my $trap;

GetOptions(
    "all!"   => \$all,
    "view!"  => \$view,
    "group!" => \$group,
    "user!"  => \$user,
    "trap!"  => \$trap,
);

show_all()   if ($all);
show_view()  if ($view);
show_group() if ($group);
show_user()  if ($user);
show_trap()  if ($trap);
