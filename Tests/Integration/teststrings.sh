#!/bin/sh

TOPDIR=../..

if [ ! -f teststrings ]
then
    make teststrings
fi

for stringfile in ${TOPDIR}/*/*/*.lproj/Localizable.strings
do
    ./teststrings "$stringfile" > /dev/null
    code=$?
    if test $code -eq 0;
    then
        echo "$stringfile: passed";
    else
        echo "$stringfile: failed (code: $code)";
    fi
done
