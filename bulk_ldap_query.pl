#!/bin/env perl

# This script is very simple, it binds to an LDAP server as directory manager and performs a massive query. 
# I wanted to set this up in a script in case we ever have a similar need from someone else. This script will
# output a csv file with the query results. 

 use Net::LDAPS;
 use Getopt::Long;
 use Term::ReadKey;
 use strict;
 use warnings;

 use Data::Dumper;

 my $attrs;
 my $ldapserver;
 my $outfile = "./ldapoutput.csv";
 my $searchfilter = "eduPersonAffiliation=*EMPLOYEE*";


 GetOptions(
         'attrs=s' => \$attrs,
         'host=s' => \$ldapserver,
         'searchfilter=s' => \$searchfilter,
         'outfile=s' => \$outfile,
         'help|?' => sub { &usage(); },
 );

 # These are required parameters
 if ( !defined($attrs) or 
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

 open (OUTFILE, ">$outfile");

 # Return after we get password
 print "\n";

 # Array-ify the $attrs
 my $attrs_array;
 @ { $attrs_array } = sort split(/,/,$attrs);    

 # Mostly static variables - hence why they aren't changable via command line arguments
 my $binddn = "cn=directory manager";
 my $base = "dc=pdx,dc=edu";

 my $ldaps = Net::LDAPS->new($ldapserver) or die ("ldap error! $@\n");
 my $ldapsmesg = $ldaps->bind( $binddn, password => $bindpass);

 my $result = $ldaps->search ( base    => "$base",
                                scope   => "sub",
                                filter  => "$searchfilter",
                                attrs   =>  $attrs_array
                              );


 foreach my $header ( @{ $attrs_array } ) {
   print OUTFILE "$header,";
 }
 print OUTFILE "\n";

### Yoinked code from http://search.cpan.org/~gbarr/perl-ldap/lib/Net/LDAP/Examples.pod
 my @entries = $result->entries;

 my $entr;
 foreach $entr ( @entries ) {
   my $attr;

   # Looks a lil wierd, we're looping over the requested attributes
   # array here. We do this in case some of the attributes we've
   # requested are empty.
   foreach $attr ( @{ $attrs_array } ) {
     # skip binary we can't handle
     next if ( $attr =~ /;binary$/ );
     print OUTFILE $entr->get_value ( $attr ) ,",";
   }
   print OUTFILE "\n";
 }
### End yoinked code
 
 close (OUTFILE);

sub usage() {
        print("Usage: $0 <options> 

  --attrs=<cn,uid..>                   Comma seperated list of LDAP attributes to return 

  --host=<ldap server>                 FQDN of the LDAP server we will be querying   
  
  --outfile=</path/to/output>          File to write out output to
                                       (default: ./ldapoutput.csv)

  --searchfilter=<LDAP search filter>  LDAP search filter for this query
                                       (default: eduPersonAffiliation=*EMPLOYEE*)
  
  --help                               Print usage\n\n");
  exit;
}

