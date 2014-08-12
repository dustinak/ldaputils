#!/bin/env perl

# This script is designed to purge delete elegible accounts from LDAP

 use Net::LDAPS;
 use Getopt::Long;
 use Term::ReadKey;
 use POSIX;
 use strict;
 use warnings;

 use Data::Dumper;

 my $ldapserver;
 my $infile;
 my $backupfile;
 my $dryrun = 0;

 GetOptions(
         'host=s'      => \$ldapserver,
         'infile=s'    => \$infile,
         'backupfile=s'=> \$backupfile,
         'dryrun'      => \$dryrun,
         'help|?'      => sub { &usage(); },
 );

 # These are required parameters
 if ( !defined($infile) or
      !defined($backupfile) or 
      !defined($ldapserver) 
    ) {
   print "ERROR: Missing required values!\n";
   &usage;
 }
 
 # Get password from the command line
 print "Enter Directory Manager password: ";
 ReadMode('noecho'); 
 chomp(my $bindpass = <STDIN>);
 ReadMode(0);

 # Return after we get password
 print "\n";

 open (INFILE, "$infile");
 my @delete_list = <INFILE>;
 close (INFILE);

 open (my $BACKFH, ">$backupfile");

 # Mostly static variables - hence why they aren't changable via command line arguments
 my $binddn = "cn=directory manager";
 my $base = "dc=pdx,dc=edu";

 my $ldaps = Net::LDAPS->new($ldapserver) or die ("ldap error! $@\n");
 my $ldapsmesg = $ldaps->bind( $binddn, password => $bindpass);

 # Get current time to compare with the value we get later
 my $currtime = strftime("%Y%m%d220000", localtime);

 foreach my $delete_uid ( @delete_list) {
   my $oktodelete = 0;

   # Strip out non-alphanumeric characters from the uid
   $delete_uid =~s/[^a-zA-Z0-9\s\p{P}]//;

   # Strip out newline
   $delete_uid =~s/\n//;

   # Check if the user's eduPersonAffiliation is correct
   my $result = $ldaps->search ( base    => "$base",
                                scope   => "sub",
                                filter  => "uid=$delete_uid",
                                attrs   =>  ["edupersonAffiliation","psuAccountExpireDate"]
                              );

   my @entries = $result->entries;

   my @eduperson = $entries[0]->get_value ('eduPersonAffiliation');
   my $psuexpiredate = $entries[0]->get_value ('psuAccountExpireDate');
   foreach my $affil ( @eduperson ) {

     # Here we're ignoring expected eduPersonAffiliation values
     if ( $affil =~/DELETED/ or 
          $affil =~/EXPIRED/ or 
          $affil =~/DISABLED/  or
          $affil =~/^STUDENT$/  or
          $affil =~/SYNC/  or
          $affil =~/TERMINATED/ ) {
       next;
     }
     else {
       $oktodelete = $oktodelete + 2;
       last;
     }
   }

   # Strip out the Z so we can interger compare
   $psuexpiredate =~s/Z//;
   if ( $psuexpiredate > $currtime ) {
     $oktodelete = $oktodelete + 4;
   }

   # Ok to delete? Do it.
   if ( $oktodelete < 1 ) {
     # First lets add the record to the backup LDIF
     my $result = $ldaps->search ( base    => "$base",
                                scope   => "sub",
                                filter  => "uid=$delete_uid",
                                attrs   =>  ""
                              );

     my @entries = $result->entries;
     if ( !$dryrun ) {
       $entries[0]->dump($BACKFH);
     }
     
     # Now delete it
     if ( !$dryrun ) {
       $ldaps->delete("uid=$delete_uid,ou=people,dc=pdx,dc=edu");
       $ldaps->delete("uid=$delete_uid,ou=group,dc=pdx,dc=edu");
       # TODO: Need to add bit to delete unix home here
     }
   }
   else {
     if ( $oktodelete eq '2' ) { print "ERROR: uid=$delete_uid has invalid eduPersonAffiliation\n"; }
     if ( $oktodelete eq '4' ) { print "ERROR: uid=$delete_uid has invalid psuAccountExpire\n"; }
     if ( $oktodelete eq '6' ) { print "ERROR: uid=$delete_uid has invalid eduPersonAffiliation and psuAccountExpire\n"; }
   }
 }

close ($BACKFH);

sub usage() {
        print("Usage: $0 <options> 

  --host=<ldap server>                 FQDN of the LDAP server we will be querying   
  
  --infile=</path/to/purge_list>       File that should contain a list of uids that are
                                       delete elegible

  --backupfile=</path/to/backupfile>   File that will contain the directory entries we 
                                       delete in LDIF format

  --dryrun                             Enables dryrun mode, in this mode the script will
                                       just look for inconsistencies, it will not dump
                                       records nor will it delete records.
  
  --help                               Print usage\n\n");
  exit;
}
