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
 my $ldapsmesg = $ldaps->bind( $binddn, password => $bindpass) or die ("ERROR: failed to bind $@\n");

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

 print "Last change: $lastchangenumber\n";

 # Determine how far back we look in the changelog
 if ( $lastchangenumber < $numchanges ) {
   $oldchangenumber = 0;
 }
 else {
   $oldchangenumber = $lastchangenumber - $numchanges;
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
   print "$changeldif\n";

 }

 exit;

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






