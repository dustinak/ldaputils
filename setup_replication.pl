#!/bin/env perl

# The point of this script is to make it simple to add a new replica to our LDAP system.

# TODO: If replicapword is not supplied, generate a random one

 use Net::LDAPS;
 use Getopt::Long;
 use Term::ReadKey;
 use strict;
 use warnings;

 my $replicapword;
 my $replicadn = 'cn=replication manager,cn=config';
 my $replicaname;
 my $masterlist;
 my $debugmode = 0;
 my $noinit = 0;

 # Mostly static variables - hence why they aren't changable via command line arguments
 # You need to bind as directory manager, generally, so ya
 my $binddn = "cn=directory manager";

 GetOptions(
         'masterlist=s' => \$masterlist,
         'replicadn=s' => \$replicadn,
         'replicaname=s' => \$replicaname,
         'replicapword=s' => \$replicapword,
         'debug' => \$debugmode,
         'noinit' => \$noinit,
         'help|?' => sub { &usage(); },
 );

 # These are required parameters
 if ( !defined($binddn) or 
      !defined($masterlist) or 
      !defined($replicadn) or 
      !defined($replicaname) or 
      !defined($replicapword) 
    ) {
   print "ERROR: Missing required values!\n";
   &usage;
 }

 #TODO: Sanitize and validate inputs
 
 my @masters = split(/,/,$masterlist);
 
 # Get password from the command line
 print "Enter Directory Manager password: ";
 ReadMode('noecho'); 
 chomp(my $bindpass = <STDIN>);
 ReadMode(0);

 if ( $debugmode ) {
   print "DEBUG: Master list: $masterlist\n";
   print "DEBUG: Replica    : $replicaname\n";
   print "DEBUG: Replicadn  : $replicadn\n";
 }

 # Do a return after accepting pword
 print "\n";

 # Setup replication dn on replica
 # If we're running --noinit, then we can assume the following 2 records are 
 # already in place
 if ( !$noinit ) {
   my $replicaldaps = Net::LDAPS->new($replicaname) or die ("ldap error! $@\n");
   my $replicamesg = $replicaldaps->bind( $binddn, password => $bindpass);

   my $result = $replicaldaps->add( $replicadn,
                      attrs => [
                        'cn'                     => 'replication manager',
                        'sn'                     => 'RM',
                        'userpassword'           => $replicapword,
                        'passwordExpirationTime' => '20380119031407Z',
                        'nsIdleTimeout'          => '0', 
                        'objectclass'            => ['top', 'person',
                                                    'organizationalPerson'],
                      ]
                    );
   $result->code && die ("failed to add replication manager dn: $result->error\n");

   $result = $replicaldaps->add( 'cn=replica,cn="dc=pdx,dc=edu",cn=mapping tree,cn=config',
                      attrs => [
                        'cn'                     => 'replica',
                        'nsds5replicaroot'       => 'dc=pdx,dc=edu',
                        'nsds5replicatype'       => '2',
                        'nsds5ReplicaBindDN'     => $replicadn,
                        'nsDS5ReplicaId'         => '65535',
                        'nsds5flags'             => '0',
                        'objectclass'            => ['top', 'nsds5replica',
                                                    'extensibleObject'],
                      ]
                    );

   $result->code && die ("failed to add cn=replica: $result->error\n");

   print " Success: Setup DN for replication on $replicaname.\n";

   $replicamesg = $replicaldaps->unbind;
 }
 else {
   print " Assuming cn=replica and cn=replication manager have already been setup.\n";
 }

 my $firstmaster = 1;

 # Add replication agreement to master
 foreach my $master ( @masters ) {

   if ( $debugmode ) {
     print "DEBUG: Setting up replication agreement for $master\n";
   }

   my $masterldaps = Net::LDAPS->new($master) or die ("ldap error! $@\n");
   my $mastermesg = $masterldaps->bind( $binddn, password => $bindpass);

   # Setup a first master toggle so that the replica is initialized *only* from the first master
   # on the list. This is done with the nsds5BeginReplicaRefresh attribute. It doesn't matter which
   # master does the init, just that one of them does it. Makes sense to me to have the first one
   # do it. Also, only do this if we have NOT set noinit.
   if ( $firstmaster and !$noinit ) {
     my $result = $masterldaps->add( "cn=$replicaname,cn=replica,cn=\"dc=pdx,dc=edu\",cn=mapping tree,cn=config",
                      attrs => [
                        'cn'                         => $replicaname,
                        'nsds5replicahost'           => $replicaname,
                        'nsds5replicaport'           => '636',
                        'nsds5ReplicaBindDN'         => $replicadn,
                        'nsds5replicabindmethod'     => 'SIMPLE',
                        'nsds5replicatransportinfo'  => 'SSL',
                        'nsds5replicaroot'           => 'dc=pdx,dc=edu',
                        'nsds5replicacredentials'    => $replicapword,
                        'nsds5BeginReplicaRefresh'   => 'start',
                        'objectclass'                => ['top',
                                                         'nsds5replicationagreement'],
                      ]
                    );
     $firstmaster--;
     $result->code && die ("failed to add replication agreement: $result->error\n");

     print " Success: Setup replication agreement between $master and $replicaname.\n";
   }
   else {
     my $result = $masterldaps->add( "cn=$replicaname,cn=replica,cn=\"dc=pdx,dc=edu\",cn=mapping tree,cn=config",
                      attrs => [
                        'cn'                         => $replicaname,
                        'nsds5replicahost'           => $replicaname,
                        'nsds5replicaport'           => '636',
                        'nsds5ReplicaBindDN'         => $replicadn,
                        'nsds5replicabindmethod'     => 'SIMPLE',
                        'nsds5replicatransportinfo'  => 'SSL',
                        'nsds5replicaroot'           => 'dc=pdx,dc=edu',
                        'nsds5replicacredentials'    => $replicapword,
                        'objectclass'                => ['top',
                                                         'nsds5replicationagreement'],
                      ]
                    );
     $result->code && die ("failed to add replication agreement: $result->error\n");

     print " Success: Setup replication agreement between $master and $replicaname.\n";
   }

   $result->code && die ("failed to add replication agreement: $result->error\n");

   print " Success: Setup replication agreement between $master and $replicaname.\n";

   $mastermesg = $masterldaps->unbind;
 }
 exit;

sub usage() {
        print("Usage: setup_replication.pl <options> 

  --masterlist=<master1,master2..>     Comma seperated list of LDAP masters    

  --binddn=<binddn>                    DN to bind to the LDAP server

  --replicaname=<FQDN>                 FQDN of the new replica server
  --replicapword=<password>            Password for the replication manager account

  --noinit                             Do not initialize the replica.

  --debug                              Toggles on debug mode

  --help                               Print usage

  Example: ./setup_replication.pl --replicaname=<replica fqdn> --replicapword=<password> 
                      --masterlist=<master1, master2, ... masterN>\n\n");
  exit;
}
