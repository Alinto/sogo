#!/bin/bash

rm -f apache-selfsigned.key apache-selfsigned.csr apache-selfsigned.crt
openssl genpkey -algorithm RSA -out apache-selfsigned.key 
openssl req -new -key apache-selfsigned.key -out apache-selfsigned.csr
openssl x509 -req -days 3650 -in apache-selfsigned.csr -signkey apache-selfsigned.key -out apache-selfsigned.crt

