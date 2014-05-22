#!/bin/env perl

# This is an initial setup script for 389DS servers. Eventually I plan to
# make this obsolete with a puppet module, but in the interim it will make
# my life a little easier if I just consolidate all the setup into one 
# script to rule them all.

 use Net::LDAP;
 use Getopt::Long;
 use Term::ReadKey;
 use strict;
 use warnings;

 # Parameter defaults
 my $debugmode = 0;
 my $silent = 0;

 # For init setup, we assume you want to be directory manager (if you are
 # unsure, then you probably shouldn't be running this script).
 my $binddn = "cn=directory manager";

 GetOptions(
         'debug'  => \$debugmode,
         'silent' => \$silent,
         'help|?' => sub { &usage(); },
 );

 # These are required parameters
# if ( !defined($binddn) or 
#      !defined($replicapword) 
#    ) {
#   print "ERROR: Missing required values!\n";
#   &usage;
# }

 # Get password from the command line
 print "Enter Directory Manager password: ";
 ReadMode('noecho'); 
 chomp(my $bindpass = <STDIN>);
 ReadMode(0);

 # Do a return after accepting pword
 print "\n";

 if ( $debugmode ) {
 # Debug stub
 }

 my $ldap = Net::LDAP->new("localhost") or die ("ldap error! $@\n");
 my $mesg = $ldap->bind( $binddn, password => $bindpass);


 my $result;
 # Settings in dn:cn=config
 ##########################
 $result = $ldap->modify( 'cn=config',
                      add => {
                      #  attrs => [
                          'nsslapd-schemacheck'      => 'off',
                          'nsslapd-syntaxcheck'      => 'off',
                          'nsslapd-maxdescriptors'   => '8192',
                          'nsslapd-security'         => 'on',
                       # ]
                      }
                    );
 $result->code && die ($result->error);
 print "  SUCCESS: added cn=config entries\n";

 # Settings in dn:cn=encryption,cn=config
 ##########################
 $result = $ldap->add( 'cn=encryption,cn=config',
                      attrs => [
                        'nsSSL3'      => 'on',
                      ]
                    );
 $result->code && die ("failed to add cn=encryption,cn=config entries: $result->error\n");
 print "  SUCCESS: added cn=encryption,cn=config entries\n";

 # Settings in cn=RSA,cn=encryption,cn=config
 ##########################
 $result = $ldap->add( 'cn=RSA,cn=encryption,cn=config',
                      attrs => [
                        'nsSSLToken'            => 'internal (software)',
                        'nsSSLPersonalitySSL'   => 'Server-Cert',
                        'nsSSLActivation'       => 'on',
                        'cn'                    => 'RSA',
                        'objectclass'                => ['top',
                                                         'nsEncryptionModule'],
                      ]
                    );
 $result->code && die ("failed to add cn=config entries: $result->error\n");
 print "  SUCCESS: added cn=RSA,cn=encryption,cn=config\n";

 # Import PSU Schema
 ##########################


 # Delete preinstalled indicies
 ##########################
 $result = $ldap->delete ("cn=account,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=cn,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=givenName,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=mail,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=mailAlternateAddress,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=mailHost,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=member,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=memberOf,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=ntUniqueId,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=ntUserDomainId,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=owner,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=seeAlso,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=sn,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=telephoneNumber,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=uid,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");
 $result = $ldap->delete ("cn=uniquemember,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config");

 print "  Deleted preinstalled indicies\n"; 

 # Add new indicies
 ##########################

  my %psuIndex = (
    'account'                        => ['eq','approx','sub','pres'],
    'cn'                             => ['eq','approx','sub','pres'],
    'displayname'                    => ['eq','sub','pres'],
    'edupersonorgdn'                 => ['eq','pres'],
    'edupersonorgunitdn'             => ['eq','pres'],
    'edupersonprimaryaffiliation'    => ['eq','approx','sub','pres'],
    'edupersonprimaryorgunitdn'      => ['eq','pres'],
    'gecos'                          => ['eq','sub'],
    'gidnumber'                      => ['eq','pres'],
    'givenname'                      => ['eq','approx','sub','pres'],
    'mail'                           => ['eq','sub','pres'],
    'mailAlternateAddress'           => ['eq'],
    'mailhost'                       => ['eq'],
    'maillocaladdress'               => ['eq','sub','pres'],
    'mailroutingaddress'             => ['eq','sub','pres'],
    'member'                         => ['eq'],
    'membernisnetgroup'              => ['eq','sub','pres'],
    'memberof'                       => ['eq'],
    'memberuid'                      => ['eq','sub','pres'],
    'nisnetgrouptriple'              => ['eq','sub','pres'],
    'nsroledn'                       => ['eq'],
    'ntUniqueId'                     => ['eq'],
    'ntUserDomainId'                 => ['eq'],
    'ou'                             => ['eq','approx','sub','pres'],
    'owner'                          => ['eq'],
    'psumailcode'                    => ['eq','sub','pres'],
    'psuprivate'                     => ['eq','pres'],
    'psupublish'                     => ['eq','sub','pres'],
    'roomnumber'                     => ['eq','sub','pres'],
    'seealso'                        => ['eq'],
    'sn'                             => ['eq','approx','sub','pres'],
    'telephonenumber'                => ['eq','sub','pres'],
    'uid'                            => ['eq'],
    'uidnumber'                      => ['eq','pres'],
    'uniqueidentifier'               => ['eq','pres'],
    'uniquemember'                   => ['eq'],
  );

 &indexadd(%psuIndex);

 # Submit task to re-index
 ##########################
 $result = $ldap->add( 'cn=psuindex, cn=index, cn=tasks, cn=config',
                      attrs => [
                        'nsInstance'       => 'userRoot',
                        'cn'                    => 'psu account index',
                        'objectclass'                => ['top',
                                                         'extensibleObject'],
                        'nsIndexAttribute'                    => 'account',
                        'nsIndexAttribute'                    => 'cn',
                        'nsIndexAttribute'                    => 'displayname',
                        'nsIndexAttribute'                    => 'edupersonorgdn',
                        'nsIndexAttribute'                    => 'edupersonorgunitdn',
                        'nsIndexAttribute'                    => 'edupersonprimaryaffiliation',
                        'nsIndexAttribute'                    => 'edupersonprimaryorgunitdn',
                        'nsIndexAttribute'                    => 'gecos',
                        'nsIndexAttribute'                    => 'gidnumber',
                        'nsIndexAttribute'                    => 'givenName',
                        'nsIndexAttribute'                    => 'mail',
                        'nsIndexAttribute'                    => 'mailAlternateAddress',
                        'nsIndexAttribute'                    => 'mailHost',
                        'nsIndexAttribute'                    => 'maillocaladdress',
                        'nsIndexAttribute'                    => 'mailroutingaddress',
                        'nsIndexAttribute'                    => 'member',
                        'nsIndexAttribute'                    => 'membernisnetgroup',
                        'nsIndexAttribute'                    => 'memberOf',
                        'nsIndexAttribute'                    => 'memberuid',
                        'nsIndexAttribute'                    => 'nisnetgrouptriple',
                        'nsIndexAttribute'                    => 'nsroledn',
                        'nsIndexAttribute'                    => 'ntUniqueId',
                        'nsIndexAttribute'                    => 'ntUserDomainId',
                        'nsIndexAttribute'                    => 'ou',
                        'nsIndexAttribute'                    => 'owner',
                        'nsIndexAttribute'                    => 'psumailcode',
                        'nsIndexAttribute'                    => 'psuprivate',
                        'nsIndexAttribute'                    => 'psupublish',
                        'nsIndexAttribute'                    => 'roomnumber',
                        'nsIndexAttribute'                    => 'seeAlso',
                        'nsIndexAttribute'                    => 'sn',
                        'nsIndexAttribute'                    => 'telephoneNumber',
                        'nsIndexAttribute'                    => 'uid',
                        'nsIndexAttribute'                    => 'uidnumber',
                        'nsIndexAttribute'                    => 'uniqueidentifier',
                        'nsIndexAttribute'                    => 'uniquemember',
                      ]
                    );
 $result->code && die ("failed to add index task: $result->error\n");

 print "  SUCCESS: submitted reindex task\n";

 # Unbind before we exit
 $mesg = $ldap->unbind;
 exit;



###############################
# Subprocesses
##############################

sub indexadd {
  my %ldapIndex = @_;

  print "  Adding indicies...\n";
  foreach my $key (keys %ldapIndex) {
    $result = $ldap->add( "cn=$key,cn=index,cn=userRoot,cn=ldbm database,cn=plugins,cn=config",
                      attrs => [
                        'nsSystemIndex'              => 'false',
                        'cn'                         => 'cn',
                        'nsIndexType'                => $ldapIndex{$key},
                        'objectclass'                => ['top',
                                                         'nsIndex'],
                      ]
                    );
    $result->code && die ("failed to add $key index: $result->error\n");
  }
  print "  SUCCESS: Added all indicies\n";  
}

sub usage() {
        print("Usage: $0 <options> 

  --silent                             Toggles on silent mode
 
  --debug                              Toggles on debug mode

  --help                               Print usage\n\n");
  exit;
}
