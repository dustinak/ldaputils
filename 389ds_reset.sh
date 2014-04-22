#!/bin/bash

# Quick little shell script to uninstall/wipe all 389DS config

service dirsrv-admin stop
service dirsrv stop
yum -y erase 389-ds-base-libs 389-ds-console 389-console 389-adminutil 389-ds-base 389-dsgw 389-ds-console-doc 389-admin-console-doc 389-ds 389-admin 389-admin-console
rm -rf /var/log/dirsrv /var/lock/dirsrv /var/lib/dirsrv /usr/share/dirsrv /usr/lib64/dirsrv /etc/sysconfig/dirsrv-psu /etc/dirsrv

