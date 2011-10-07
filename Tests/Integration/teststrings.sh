#!/bin/bash

TOPDIR=../..
RC=0

if [ ! -f teststrings ]
then
    make
fi

for stringfile in ${TOPDIR}/*/*/*.lproj/Localizable.strings
do
    ./obj/teststrings "$stringfile" > /dev/null
    code=$?
    if test $code -eq 0;
    then
        echo "$stringfile: passed";
    else
        echo "$stringfile: FAILED (code: $code)";
	RC=$(($RC+$code))
    fi
done

exit $RC
