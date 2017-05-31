#!/bin/sh

#This script make archive of future volumes

#make catalog for archive files
mkdir /opt/arch

#archive /var/vmail
tar -cjpf /opt/arch/vmail.tar.gz /var/vmail/*

#archive /etc/ssl
tar -cjpf /opt/arch/ssl.tar.gz /etc/ssl/*

#archive /etc/nginx
tar -cjpf /opt/arch/nginx.tar.gz /etc/nginx/*

#ldap
tar -cjpf /opt/arch/ldap.tar.gz /etc/ldap/*

#ldap DB
tar -cjpf /opt/arch/ldapdb.tar.gz /var/lib/ldap/*

#postfix
tar -cjpf /opt/arch/postfix.tar.gz /etc/postfix/*

#dovecot
tar -cjpf /opt/arch/dovecot.tar.gz /etc/dovecot/*

#spamassassin
tar -cjpf /opt/arch/spamassassin.tar.gz /etc/spamassassin/*

#sogo
tar -cjpf /opt/arch/sogo.tar.gz /etc/sogo/*

#awstats
tar -cjpf /opt/arch/awstats.tar.gz /etc/awstats/*

#iredapd
tar -cjpf /opt/arch/iredapd.tar.gz /opt/iredapd/*

#rouncube
tar -cjpf /opt/arch/roundcube.tar.gz /opt/www/roundcubemail-1.2.4/*

#amavis
tar -cjpf /opt/arch/amavis.tar.gz /etc/amavis/*

#fail2ban DB
tar -cjpf /opt/arch/fail2bandb.tar.gz /var/lib/fail2ban/*

#clamav DB
tar -cjpf /opt/arch/clamavdb.tar.gz /var/lib/clamav/*

#dkim
tar -cjpf /opt/arch/dkim.tar.gz /var/lib/dkim/*

#logs
tar -cjpf /opt/arch/logs.tar.gz /var/log/*
