#!/bin/bash
openssl x509 -in signing-ca-2.crt -outform der -out signing-ca-2.der
openssl x509 -in signing-ca-1.crt -outform der -out signing-ca-1.der
cat test.com.der signing-ca-2.der signing-ca-1.der > chain.der

