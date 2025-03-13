#!/bin/bash

cp /etc/postfix/main.cf /etc/postfix/main.cf.bak
chown root:root /etc/postfix/virtual
chown root:root /etc/postfix/virtual.db
postmap /etc/postfix/virtual

/opt/install.sh
# /opt/install.sh make changes /etc/postfix/main.cf, so restore bak file
rm -f /etc/postfix/main.cf
cp /etc/postfix/main.cf.bak /etc/postfix/main.cf
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf