FROM phusion/baseimage:latest
MAINTAINER Daniil Mishakov <daniil987@yandex.ru>

# Suporting software versions
ARG IREDMAIL_VERSION=0.9.6

# Default values changable at startup
ARG DOMAIN=test.org
ARG HOSTNAME=mail
ARG LDAP_DOMAIN='dc=test,dc=org'
ARG TIMEZONE=Europe/Moscow
ARG SOGO_WORKERS=2
#special for 'dc'-options in ldif file
ARG DCDOMAIN=test

### Installation
# Prerequisites
ENV DEBIAN_FRONTEND noninteractive
RUN echo "APT::Install-Recommends 0;" >> /etc/apt/apt.conf.d/01-no-recommends \
    && echo "APT::Install-Suggests 0;" >> /etc/apt/apt.conf.d/01-no-recommends \
    && echo $TIMEZONE > /etc/timezone \
    && apt-get -q update \
    && apt-get upgrade -y \
    && apt-get install -y -q \
       apt-utils \
    && apt-get install -y -q \
       wget \
       bzip2 \
       iptables \
       openssl \
       mysql-server \ 
       netcat \
       pwgen \
    && echo $DOMAIN > /etc/mailname \
    && echo $HOSTNAME > /opt/hostname \
    && mv /bin/uname /bin/uname_ \
    && mv /bin/hostname /bin/hostname_
    
COPY ./uname /bin/uname
COPY ./hostname /bin/hostname

# Install of iRedMail from sources
WORKDIR /opt/iredmail

RUN wget -O - https://bitbucket.org/zhb/iredmail/downloads/iRedMail-"${IREDMAIL_VERSION}".tar.bz2 | \
    tar xvj --strip-components=1

# Generate configuration file
COPY ./config-old /opt/iredmail/config-old
COPY ./config-gen /opt/iredmail/config-gen
RUN sh ./config-gen $LDAP_DOMAIN $DOMAIN > ./config

# Initiate automatic installation process 
RUN sed s/$(hostname_)/$(cat /opt/hostname | xargs echo -n).$(cat /etc/mailname | xargs echo -n)/ /etc/hosts > /tmp/hosts_ \
    && cat /tmp/hosts_ > /etc/hosts \
    && rm /tmp/hosts_ \
    && echo $HOSTNAME > /etc/hostname \
    && sleep 5;service mysql start \
    && IREDMAIL_DEBUG='NO' \
      CHECK_NEW_IREDMAIL='NO' \
      AUTO_USE_EXISTING_CONFIG_FILE=y \
      AUTO_INSTALL_WITHOUT_CONFIRM=y \
      AUTO_CLEANUP_REMOVE_SENDMAIL=y \
      AUTO_CLEANUP_REMOVE_MOD_PYTHON=y \
      AUTO_CLEANUP_REPLACE_FIREWALL_RULES=y \
      AUTO_CLEANUP_RESTART_IPTABLES=y \
      AUTO_CLEANUP_REPLACE_MYSQL_CONFIG=y \
      AUTO_CLEANUP_RESTART_POSTFIX=n \
      bash iRedMail.sh

###Change rootpw in /etc/ldap/slapd.conf
COPY ./slapd-ch /opt/iredmail/slapd-ch
RUN sh slapd-ch

###Take password to LDAP ldif-file
COPY ./ldif-gen /opt/iredmail/ldif-gen
RUN sh ldif-gen $LDAP_DOMAIN $DOMAIN $DCDOMAIN > ./start.ldif

COPY services/slapd.sh /opt/iredmail/slapd.sh
RUN /usr/sbin/slapd -h ldap:/// -g openldap -u openldap -f /etc/ldap/slapd.conf ; \
    service --status-all && \
    PASS=$(grep 'LDAP root dn: cn=Manager,' iRedMail.tips | sed 's/^.\+ \(\w\+\)$/\1/') && \
    echo "$PASS" && \
    ldapadd -x -w $PASS -D "cn=Manager,$LDAP_DOMAIN" -f ./start.ldif

### Final configuration
RUN . ./config \
    && sed -i 's/PREFORK=.*$'/PREFORK=$SOGO_WORKERS/ /etc/default/sogo \
    && sed -i 's/WOWorkersCount.*$'/WOWorkersCount=$SOGO_WORKERS\;/ /etc/sogo/sogo.conf \
    && sed -i 's/SOGoTimeZone = .*$/SOGoTimeZone = \"Europe\/Moscow\"\;/' /etc/sogo/sogo.conf \
    && sed -i '/^Foreground /c Foreground true' /etc/clamav/clamd.conf \
    && sed -i '/init.d/c pkill -sighup clamd' /etc/logrotate.d/clamav-daemon \
    && sed -i '/^Foreground /c Foreground true' /etc/clamav/freshclam.conf \
    && sed -i 's/^bind-address/#bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf \
    && sed -i 's/sogo-ealarms-notify.*$/sogo-ealarms-notify \&>\/dev\/null /' /var/spool/cron/crontabs/sogo

# Prepare for the first run
RUN tar jcf /root/mysql.tar.bz2 /var/lib/mysql && rm -rf /var/lib/mysql \
    && tar jcf /root/vmail.tar.bz2 /var/vmail && rm -rf /var/vmail \
    && tar jcf /root/clamav.tar.bz2 /var/lib/clamav && rm -rf /var/lib/clamav

#Copy iRedMail.tips for future uses
RUN mkdir /var/vmail
RUN cp /opt/iredmail/iRedMail.tips /var/vmail/iRedMail.tips
RUN cp /opt/iredmail/config /var/vmail/config-old

#Prepare for the empty config - first run
COPY ./archive.sh /opt/iredmail
RUN  ./archive.sh

### Startup services
# Core Services
ADD rc.local /etc/rc.local
ADD services/slapd.sh /etc/service/slapd/run
ADD services/mysql.sh /etc/service/mysql/run
ADD services/postfix.sh /etc/service/postfix/run
ADD services/amavis.sh /etc/service/amavis/run
ADD services/iredapd.sh /etc/service/iredapd/run
ADD services/dovecot.sh /etc/service/dovecot/run

# Frontend
ADD services/sogo.sh /etc/service/sogo/run
ADD services/iredadmin.sh /etc/service/iredadmin/run
ADD services/php7-fpm.sh /etc/service/php7-fpm/run
ADD services/nginx.sh /etc/service/httpd/run

# Enhancement
ADD services/fail2ban.sh /etc/service/fail2ban/run
ADD services/clamav-daemon.sh /etc/service/clamav-daemon/run
ADD services/clamav-freshclam.sh /etc/service/clamav-freshclam/run


### Purge some packets and save disk space
RUN apt-get purge -y -q dialog apt-utils augeas-tools \
    && apt-get autoremove -y -q \
    && apt-get clean -y -q \
    && rm -rf /var/lib/apt/lists/*

# Open Ports:
# Nginx: 80/tcp, 443/tcp Postfix: 25/tcp, 587/tcp
# Dovecot: 110/tcp, 143/tcp, 993/tcp, 995/tcp
# LDAP: 389/tcp - for test purpose or replicate LDAP

EXPOSE 80 443 25 587 110 143 389 993 995

#VOLUMES
VOLUME /var/vmail                      #backup & mailboxes
VOLUME /etc/ssl                        #ssl sert & key
VOLUME /etc/nginx                      #nginx configuration
VOLUME /etc/ldap                       #ldap configuration
VOLUME /var/lib/ldap/                  #ldap DB
VOLUME /etc/postfix                    #postfix configuration
VOLUME /etc/dovecot                    #dovecot configuration
VOLUME /etc/spamassassin               #spamassassin configuration
VOLUME /etc/sogo                       #sogo configuration
VOLUME /etc/awstats/                   #awstats
VOLUME /opt/iredapd/                   #iredapd configuration
VOLUME /opt/www/roundcubemail-1.2.4/   #roundcube configuration
VOLUME /etc/amavis/                    #amavis configuration
VOLUME /var/lib/fail2ban               #fail2ban database
VOLUME /var/lib/clamav                 #clamav database
VOLUME /var/lib/dkim                   #DKIM keys
VOLUME /var/log                        #different logs

RUN echo '***************************************************' ; \
    echo "postmaster@$DOMAIN password" ; \
    echo $(grep -A 1 '   \* Login account:' iRedMail.tips | grep 'Username'  | sed 's/^.\+ \(\w\+\)$/\1/') ; \
    echo '***************************************************' 

