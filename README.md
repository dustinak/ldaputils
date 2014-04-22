## Repo to contain any and all LDAP utility scripts ##

* **setup_replication.pl** : This is a (fairly) basic script that sets up replication between a list of masters
                             and a defined replicant. Note that the binddn is hard codede as cn=directory manager.
                             A typical run of this command would be:
                             `./setup_replication.pl --replicaname=replicant.oit.pdx.edu --replicapword=thepassword --masterlist=m1.oit.pdx.edu,m2.oit.pdx.edu`
