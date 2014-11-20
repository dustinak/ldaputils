#!/bin/env perl

# This script is intented to be used in debuging LDAP changes. It queries the changelog
# and will decode the changes field for easy human consumption

use Net::LDAPS;
use Getopt::Long;
use POSIX;
use Term::ReadKey;
use strict;
use warnings;

my $uid;
my $ldapserver;
my $binddn;
my $numchanges = 1000;

GetOptions(
        'uid=s'        => \$uid,
        'binddn=s'     => \$binddn,
        'changes=s'    => \$numchanges,
        'host=s'       => \$ldapserver,
        'help|?'       => sub { &usage(); },
);

# These are required parameters
if ( !defined($uid) or
     !defined($ldapserver) or
     !defined($binddn)
) {
    print "ERROR: Missing required values!\n";
    &usage;
}

my $bindpass = read_password();

# Bind to LDAP server
my $base = "dc=pdx,dc=edu";
my $ldaps = Net::LDAPS->new($ldapserver)
    or die ("ldap error! $@\n");
my $ldapsmesg = $ldaps->bind( $binddn, password => $bindpass)
    or die ("ERROR: failed to bind $@\n");

# Get the lastchangenumber
my $changenumresult = $ldaps->search ( base    => "",
                                scope   => "base",
                                filter  => "objectclass=*",
                                attrs   =>  ["lastchangenumber"]
                                );

$changenumresult->code && die ($changenumresult->error);

my $lastchangenumber= $changenumresult->entry(0)->get_value('lastchangenumber')
    or die "Unable to find 'lastchangenumber'; is this the LDAP master?\n";

my $oldchangenumber = $lastchangenumber > $numchanges
                    ? $lastchangenumber - $numchanges
                    : 0
                    ;

printf "Looking for changes between %d and %d (or so)...\n",
    $oldchangenumber,
    $lastchangenumber;

my $filter =
    "(&(changeNumber>=${oldchangenumber})(targetdn=uid=${uid},ou=people,${base}))";

# Now lets pull a list of changes
my $changesresult = $ldaps->search ( base    => "cn=changelog",
                                    scope   => "sub",
                                    filter  => $filter,
                                    attrs   =>  ["changetime","changes"]
                            );

$changesresult->code && die ($changesresult->error);

print "GOT ", $changesresult->count, " changes\n";

foreach my $change ( $changesresult->entries ) {
    print "========================================================\n";
    print "CHANGETIME:", $change->get_value('changetime'), "\n";
    print "-------------------------\n";
    print $change->get_value('changes'), "\n";
}

## Sub processes
############################################

sub usage() {
    print("Usage: $0 <options>

    --uid=<user name>                    UID to look at changes for.

    --changes=<interger>                 How many changes to look back, defaults to 1000

    --binddn=<ldap dn to bind as>        LDAP DN to bind as
                                        (ex: uid=dustin,ou=people,dc=pdx,dc=edu)

    --host=<ldap server>                 Server to look at for changelog entries

    --help                               Print usage\n\n");
    exit;
}

sub read_password {
    my $password;
    print "Enter LDAP password: ";
    ReadMode('noecho');
    chomp($password = <STDIN>);
    ReadMode(0);

    # Return after we get password
    print "\n";

    return $password;
}
