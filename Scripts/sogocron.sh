#!/bin/sh

export PATH=/usr/local/sbin:$PATH

cd /root/SOGo
# echo "Pulling monotone repository"

oldversion=$(mtn status)
mtn pull >& /dev/null
mtn update >& /dev/null
newversion=$(mtn status)

if [ "$oldversion" == "$newversion" ]
then
  exit 0
fi

echo "SOGo mainsite updated at $(date)..."

. /root/GNUstep/Library/Makefiles/GNUstep.sh >& /dev/null
make distclean > /dev/null
./configure --disable-strip --without-gnustep >& /dev/null
make -s > /dev/null
rm -rf /usr/local/lib/sogod-0.9
make -s install > /dev/null
# echo "Copying templates to /usr/local/share/sogo-0.9/templates"
# rm -rf /usr/local/share/sogo-0.9/templates
# cp -a UI/Templates /usr/local/share/sogo-0.9/templates
# echo "Copying web resources to /usr/local/share/sogo-0.9/www"
# cp -a UI/WebServerResources /usr/local/share/sogo-0.9/www
# echo "Killing server"
pkill sogod-0.9 >& /dev/null
# echo "Starting sogod-0.9 (log in /var/log/sogod)"
echo "Launching on $(date)" > /var/log/sogod
sogod-0.9 >> /var/log/sogod 2>&1 &

