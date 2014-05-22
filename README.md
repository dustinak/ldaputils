## Repo to contain any and all LDAP utility scripts ##

* **setup_replication.pl** : This is a (fairly) basic script that sets up replication between a list of masters
                             and a defined replicant. Note that the binddn is hard codede as cn=directory manager.
                             A typical run of this command would be:
                             `./setup_replication.pl --replicaname=replicant.oit.pdx.edu --replicapword=thepassword --masterlist=m1.oit.pdx.edu,m2.oit.pdx.edu`
* **389ds_reset.pl**       : This is a very simple script that will uninstall and delete all 389DS files. It was/is good 
                             for testing the puppet modules to install/setup 389 DS.
* **bulk_ldap_query.pl**   : This is another simple script that given some attributes and search filters will query LDAP
                             and dump it's results into a csv file. The --help is fairly useful for this script.
* **initial_setup.pl**     : This script is mostly just a perl wrapper around a number of LDAP calls. The idea behind it
                             was that this would be a stop-gap until I get puppet to do all of this. 


 
