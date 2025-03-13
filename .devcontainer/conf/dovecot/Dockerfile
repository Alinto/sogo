# From https://github.com/dovecot/docker/blob/main/2.3.21.1/
FROM debian:11-slim

LABEL org.opencontainers.image.authors="dovecot@dovecot.org"

ENV container=docker \
    LC_ALL=C
ARG DEBIAN_FRONTEND=noninteractive

ADD dovecot.gpg /etc/apt/keyrings/dovecot.gpg
ADD dovecot.list /etc/apt/sources.list.d

RUN apt-get -y update && apt-get -y install \
    tini \
    dovecot-core \
    dovecot-gssapi \
    dovecot-imapd \
    dovecot-ldap \
    dovecot-lmtpd \
    dovecot-managesieved \
    dovecot-mysql \
    dovecot-pgsql \
    dovecot-pop3d \
    dovecot-sieve \
    dovecot-solr \
    dovecot-sqlite \
    dovecot-submissiond \
    ca-certificates \
    ssl-cert && \
    rm -rf /var/lib/apt/lists && \
    groupadd -g 1000 vmail && \
    useradd -u 1000 -g 1000 vmail -d /srv/vmail && \
    passwd -l vmail && \
    rm -rf /etc/dovecot && \
    mkdir /srv/mail && \
    chown vmail:vmail /srv/mail && \
    make-ssl-cert generate-default-snakeoil && \
    mkdir /etc/dovecot && \
    ln -s /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/dovecot/cert.pem && \
    ln -s /etc/ssl/private/ssl-cert-snakeoil.key /etc/dovecot/key.pem

#ADD dovecot.conf /etc/dovecot/dovecot.conf

# Add for SOGo env
RUN apt-get update  --allow-insecure-repositories && \
    apt-get install --allow-unauthenticated -y dovecot-ldap dovecot-sieve dovecot-managesieved dovecot-lmtpd

RUN chown -R dovecot:dovecot /var/mail
RUN mkdir /var/sieve && \
    chmod -R 755 /var/sieve && \
    chown -R vmail:vmail /var/sieve

ADD dovecot.conf /etc/dovecot/dovecot.conf
ADD conf.d /etc/dovecot/conf.d
ADD dovecot-ldap.conf.ext /etc/dovecot/dovecot-ldap.conf.ext
# Clean
RUN apt-get clean && rm -rf /var/lib/apt/lists/* 
# End add for SOGo env

ADD wait-for-it.sh /wait-for-it.sh

EXPOSE 24
EXPOSE 110
EXPOSE 143
EXPOSE 587
EXPOSE 990
EXPOSE 993
EXPOSE 4190

VOLUME ["/etc/dovecot", "/srv/mail"]
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["./wait-for-it.sh", "openldap:389", "--", "/usr/sbin/dovecot", "-F"]
