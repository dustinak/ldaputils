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

 GetOptions(
         'uid=s'        => \$uid,
         'binddn=s'     => \$binddn,
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
 

 # Get password from the command line
 my $bindpass;
 print "Enter LDAP password: ";
 ReadMode('noecho'); 
 chomp($bindpass = <STDIN>);
 ReadMode(0);
 
 # Return after we get password
 print "\n";

 # Bind to LDAP server
 my $base = "dc=pdx,dc=edu";
 my $ldaps = Net::LDAPS->new($ldapserver) or die ("ldap error! $@\n");
 my $ldapsmesg = $ldaps->bind( $binddn, password => $bindpass);

 # Get the lastchangenumber
 my $changenumresult = $ldaps->search ( base    => "",
                                   scope   => "base",
                                   filter  => "objectclass=*",
                                   attrs   =>  ["lastchangenumber"]
                                  );

 $changenumresult->code && die ($changenumresult->error);

 my @changenumentries = $changenumresult->entries;
 my $lastchangenumber = $changenumentries[0]->get_value ('lastchangenumber');

 my $oldchangenumber;

 # We only care about the last 1000 change numbers. Might pull this out to
 # a command line parameter
 if ( $lastchangenumber < 1000 ) {
   $oldchangenumber = 0;
 }
 else {
   $oldchangenumber = $lastchangenumber - 1000;
 }
 
 # Now lets pull a list of changes
 my $changesresult = $ldaps->search ( base    => "cn=changelog",
                                      scope   => "sub",
                                      filter  => "(&(changeNumber>=$oldchangenumber)(targetdn=uid=$uid,ou=people,dc=pdx,dc=edu))",
                                      attrs   =>  ["changetime","changes"]
                                );

 $changesresult->code && die ($changesresult->error);

 my @changes = $changesresult->entries;

 my $resultcount = $changesresult->count;

 print "GOT $resultcount changes\n";

 foreach my $change ( @changes ) {
   my $changeldif = $change->get_value ('changes');
   my $changetime = $change->get_value ('changetime');

   print "========================================================\n";
   print "CHANGETIME:$changetime\n";
   print "-------------------------\n";
   print "CHANGES:$changeldif\n";

 }

 exit;

## Sub processes
############################################

sub usage() {
        print("Usage: $0 <options> 

  --uid=<user name>                    UID to look at changes for. 

  --binddn=<ldap dn to bind as>        LDAP DN to bind as
                                       (ex: uid=dustin,ou=people,dc=pdx,dc=edu)

  --host=<ldap server>                 Server to look at for changelog entries 
  
  --help                               Print usage\n\n");
  exit;
}






