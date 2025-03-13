#!/bin/bash
cd ${WORKSPACE}  \
./configure --enable-debug --disable-strip --enable-mfa \
make  \
make install \
echo "register sogo library" \
echo "/usr/local/lib/sogo" > /etc/ld.so.conf.d/sogo.conf  \
ldconfig \
echo "create directories and enforce permissions" \
install -o sogo -g sogo -m 755 -d /var/run/sogo  \
install -o sogo -g sogo -m 750 -d /var/spool/sogo  \
install -o sogo -g sogo -m 750 -d /var/log/sogo 

su -s /bin/bash - sogo -c "echo \"set debuginfod enabled off\" >> ~/.gdbinit"