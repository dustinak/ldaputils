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
if ( ! $ldapserver or ! $binddn ) {
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

if ($uid) {
    search_uid($ldaps, $uid, $numchanges);
}
else {
    print STDERR "Missing run mode (uid, tail, etc)!\n";
    usage();
}

sub search_uid {
    my ($ldaps, $uid, $numchanges) = @_;

    my ($start_changenumber, $lastchangenumber) =
        calc_changenumber_range($ldaps, $numchanges);

    printf "Looking for changes between %d and %d (or so)...\n",
        $start_changenumber,
        $lastchangenumber;

    my $filter = "(&(changeNumber>=${start_changenumber})"
               . "(targetdn=uid=${uid},ou=people,${base}))";

    # Now lets pull a list of changes
    my $changesresult = $ldaps->search ( base    => "cn=changelog",
                                        scope   => "sub",
                                        filter  => $filter,
                                        attrs   =>  ["changetime","changes"]
                                );

    $changesresult->code && die ($changesresult->error);

    print "GOT ", $changesresult->count, " changes\n";

    foreach my $change ( $changesresult->entries ) {
        print_changelog_entry($change);
    }

}

## Sub processes
############################################

sub usage {
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

sub search_last_changenumber {
    my ($ldap) = @_;

    # Get the lastchangenumber
    my $changenumresult = $ldap->search ( base    => "",
                                    scope   => "base",
                                    filter  => "objectclass=*",
                                    attrs   =>  ["lastchangenumber"]
                                    );

    $changenumresult->code && die ($changenumresult->error);

    my $lastchangenumber= $changenumresult->entry(0)->get_value('lastchangenumber')
        or die "Unable to find 'lastchangenumber'; is this the LDAP master?\n";
}

sub calc_changenumber_range {
    my ($ldap, $requested) = @_;

    my $last = search_last_changenumber($ldap);

    my $start = $last > $requested
              ? $last - $requested
              : 0
              ;

    my @result = ($start, $last);
    return wantarray ? @result : \@result;
}

sub print_changelog_entry {
    my ($entry) = @_;

    print "========================================================\n";
    print "CHANGETIME:", $entry->get_value('changetime'), "\n";
    print "-------------------------\n";
    print $entry->get_value('changes'), "\n";
}
