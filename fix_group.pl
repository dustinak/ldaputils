#!/bin/env perl

# Yet another auxillary LDAP script. This is to fix an issue where by
# the gidNumber on the group DN is not linked up with the gidNumber in
# a user's DN from ou=people

# This script is kindda a mess since I copied another and tweaked it. In
# theory this won't be needed for long.. maybe?

 use Net::LDAPS;
 use Getopt::Long;
 use POSIX;
 use Term::ReadKey;
 use strict;
 use warnings;

 my $uid;
 my $dryrun = 0;
 my $ldapserver = 'ldapmaster.oit.pdx.edu';

 GetOptions(
         'uid=s'       => \$uid,
         'dryrun'      => \$dryrun,
         'help|?'      => sub { &usage(); },
 );
 
# These are required parameters
 if ( !defined($uid) ) {
   print "ERROR: Missing required values!\n";
   &usage;
 }
 
 # Mostly static variables - hence why they aren't changable via command line arguments
 my $ldaps = Net::LDAPS->new($ldapserver) or die ("ldap error! $@\n");
 my $bindpass;

 # Anon bind
 my $ldapsmesg = $ldaps->bind;

 # Get password from the command line
 if ( ! $dryrun ) {
   print "Enter Directory Manager password: ";
   ReadMode('noecho'); 
   chomp($bindpass = <STDIN>);
   ReadMode(0);
 }
 else {
   print "DRY RUN MODE ENABLED - No changes will be made\n";
 }
 
 # Return after we get password
 print "\n";

 # Mostly static variables - hence why they aren't changable via command line arguments

 chomp ($uid);

 # Get the GID from user's DN
 my $uidresult = $ldaps->search ( base    => "ou=people,dc=pdx,dc=edu",
                                   scope   => "sub",
                                   filter  => "uid=$uid",
                                   attrs   =>  ["gidnumber"]
                                  );

 $uidresult->code && die ($uidresult->error);

 my @uidentries = $uidresult->entries;
 my $user_gidnumber = $uidentries[0]->get_value ('gidnumber');
 
 # Get the GID from the group DN
 my $groupresult = $ldaps->search ( base    => "ou=Group,dc=pdx,dc=edu",
                                     scope   => "sub",
                                     filter  => "cn=$uid",
                                     attrs   =>  ["gidnumber"]
                                   );

 $groupresult->code && die ($groupresult->error);

 my @groupentries = $groupresult->entries;
 my $group_gidnumber = $groupentries[0]->get_value ('gidnumber');

 if ( $user_gidnumber ne $group_gidnumber ) {
   print "GROUP ID MISMATCH! User:$user_gidnumber Group:$group_gidnumber\n";
   my $gidcheck = $ldaps->search ( base    => "ou=Group,dc=pdx,dc=edu",
                                     scope   => "sub",
                                     filter  => "gidnumber=$user_gidnumber",
                                     attrs   =>  ["gidnumber"]
                                   );

   if ( $gidcheck->count eq '0' ) {
   
     print "  Correct GID ($user_gidnumber) is not taken.\n";
     print "  Changing GID on cn=$uid,ou=group,dc=pdx,dc=edu from $group_gidnumber to $user_gidnumber\n";
     if ( ! $dryrun ) {
       # All the LDAPy bits for binding as dirmanager
       my $binddn = "cn=directory manager";
       my $base = "dc=pdx,dc=edu";

       my $ldapswrite = Net::LDAPS->new($ldapserver) or die ("ldap error! $@\n");
       my $ldapswritemesg = $ldapswrite->bind( $binddn, password => $bindpass);

       my $result = $ldapswrite->modify( "cn=$uid,ou=group,dc=pdx,dc=edu",
                      replace => {
                          'gidnumber'      => "$user_gidnumber",
                      }
                    );
       $result->code && die ($result->error);
     }
   }
   else {
     print " ERROR: Correct GID ($user_gidnumber) IS taken! Manual fix needed\n";
   }

 }
 else {
   print "No group ID mismatch found\n";
 }
 # We're done here, nothing to see, move along
 exit;

## Sub processes
############################################

sub usage() {
        print("Usage: $0 <options> 

  --uid=<user name>                    UID to fix/check. 

  --dryrun                             Enables dryrun mode, in this mode the script will
                                       just look for inconsistencies, it will not dump
                                       records nor will it delete records.
  
  --help                               Print usage\n\n");
  exit;
}






