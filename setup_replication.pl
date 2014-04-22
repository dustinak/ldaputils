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

 # Mostly static variables - hence why they aren't changable via command line arguments
 # You need to bind as directory manager, generally, so ya
 my $binddn = "cn=directory manager";

 GetOptions(
         'masterlist=s' => \$masterlist,
         'replicadn=s' => \$replicadn,
         'replicaname=s' => \$replicaname,
         'replicapword=s' => \$replicapword,
         'help|?' => sub { &usage(); },
 );

 if ( !defined($binddn) or 
      !defined($masterlist) or 
      !defined($replicadn) or 
      !defined($replicaname) or 
      !defined($replicapword) 
    ) {
   print "ERROR: Missing required values!\n";
   &usage;
 }
 
 my @masters = split(/,/,$masterlist);
 
 # Get password from the command line
 print "Enter Directory Manager password: ";
 ReadMode('noecho'); 
 chomp(my $bindpass = <STDIN>);
 ReadMode(0);
 
 # Do a return after accepting pword
 print "\n";

 # Setup replication dn on replica
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
 $result->code && die ("failed to add entry: $result->error\n");

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

 $result->code && die ("failed to add entry: $result->error\n");

 print " Success: Setup DN for replication on $replicaname.\n";

 $replicamesg = $replicaldaps->unbind;

 # Add replication agreement to master
 foreach my $master ( @masters ) {
   my $masterldaps = Net::LDAPS->new($master) or die ("ldap error! $@\n");
   my $mastermesg = $masterldaps->bind( $binddn, password => $bindpass);

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

   $result->code && die ("failed to add entry: $result->error\n");

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

  --help                    Print usage\n\n");
  exit;
}
