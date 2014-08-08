#!/bin/env perl

# This is a short and sweet script written to move people's unix homes into the death_row area
# if they do not have entries in LDAP.

 use Net::LDAPS;
 use Getopt::Long;
 use POSIX;
 use File::Copy;
 use strict;
 use warnings;

 my $diskpath;
 my $dryrun = 0;
 my $ldapserver;

 GetOptions(
         'diskpath=s'  => \$diskpath,
         'host=s'      => \$ldapserver,
         'dryrun'      => \$dryrun,
         'help|?'      => sub { &usage(); },
 );
 
# These are required parameters
 if ( !defined($diskpath) or 
      !defined($ldapserver) 
    ) {
   print "ERROR: Missing required values!\n";
   &usage;
 }
 
 # Mostly static variables - hence why they aren't changable via command line arguments
 my $deathrow = "death_row";
 my $base = "ou=people,dc=pdx,dc=edu";

 my $ldaps = Net::LDAPS->new($ldapserver) or die ("ldap error! $@\n");

 # Anon bind
 my $ldapsmesg = $ldaps->bind;

 # Make sure we have the directories we think we have
 if ( ! -d "$diskpath/$deathrow" ) {
   print "ERROR: death_row directory not found!\n";
   exit;
 }

 if ( ! -d "$diskpath/u" ) {
   print "ERROR: user home top level directory not found!\n";
   exit;
 }

  opendir my($dh), "$diskpath/u/" or die "Couldn't open dir '$diskpath/u/': $!";
  my @dir_list = readdir $dh;
  closedir $dh;

  foreach my $dir ( @dir_list ) {
   # Ignore . and .. in the directory listing
   if ( $dir =~/\./ ) { next; } 
   if ( $dir =~/\.\./ ) { next; } 

   my $result = $ldaps->search ( base    => "$base",
                                scope   => "sub",
                                filter  => "uid=$dir",
                                attrs   =>  ["uid"]
                              );

   # Not sure I like this, but in theory if that returns no entires, we're
   # good to delete
   if ( $result->count eq '0' ) {
     if ( ! $dryrun ) {
       print "  Moving $diskpath/u/$dir to $diskpath/$deathrow/$dir.\n";
       move("$diskpath/u/$dir","$diskpath/$deathrow/$dir") or die "ERROR: $!\n";
     }
     else {
       print "  DRYRUN: Moving $diskpath/u/$dir to $diskpath/$deathrow/$dir.\n";
     }
   }

 }

 # We're done here, nothing to see, move along
 exit;

## Sub processes
############################################

sub usage() {
        print("Usage: $0 <options> 

  --host=<ldap server>                 FQDN of the LDAP server we will be querying   
  
  --diskpath=</path/to/disk>           Top level to look in for homes, this is where
                                       we expect to see the u and death_row directories

  --dryrun                             Enables dryrun mode, in this mode the script will
                                       just look for inconsistencies, it will not dump
                                       records nor will it delete records.
  
  --help                               Print usage\n\n");
  exit;
}






