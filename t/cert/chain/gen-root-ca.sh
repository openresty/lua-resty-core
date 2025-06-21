#!/bin/bash

CERT_NAME="root-ca"
DAYS_VALID=36500
KEY_SIZE=4096
COUNTRY="US"
STATE="California"
LOCALITY="San Francisco"
ORGANIZATION="OpenResty"
COMMON_NAME="Root CA"

openssl genrsa -out ${CERT_NAME}.key ${KEY_SIZE}

cat > ${CERT_NAME}.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = ${COUNTRY}
ST = ${STATE}
L = ${LOCALITY}
O = ${ORGANIZATION}
CN = ${COMMON_NAME}

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical,CA:true
EOF

openssl req -x509 -new -nodes -key ${CERT_NAME}.key -sha256 -days ${DAYS_VALID} \
    -out ${CERT_NAME}.crt -config ${CERT_NAME}.cnf

openssl x509 -in ${CERT_NAME}.crt -text -noout

rm ${CERT_NAME}.cnf

echo "Root CA certificate has been generated as ${CERT_NAME}.pem"

