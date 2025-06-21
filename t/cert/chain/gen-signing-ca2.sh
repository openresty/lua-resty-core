#!/bin/bash

# set environment variables
SIGNING_CA1_NAME="signing-ca-1"
CERT_NAME="signing-ca-2"
DAYS_VALID=36500  # 100 years
KEY_SIZE=4096
COUNTRY="US"
STATE="California"
ORGANIZATION="OpenResty"
COMMON_NAME="Signing-CA-2"

# check the existance of the middle ca
if [ ! -f "${SIGNING_CA1_NAME}.crt" ] || [ ! -f "${SIGNING_CA1_NAME}.key" ]; then
    echo "Signing CA-1 certificate or key not found. Please generate them first."
    exit 1
fi

# generate private key
openssl genrsa -out ${CERT_NAME}.key ${KEY_SIZE}

# generate (certificate signature request) csr config file
cat > ${CERT_NAME}.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
C = ${COUNTRY}
ST = ${STATE}
O = ${ORGANIZATION}
CN = ${COMMON_NAME}

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical,CA:true
EOF

# generate certificate signature request
openssl req -new -key ${CERT_NAME}.key -out ${CERT_NAME}.csr -config ${CERT_NAME}.cnf

# sign the CA using Signing-CA-1
openssl x509 -req -in ${CERT_NAME}.csr -CA ${SIGNING_CA1_NAME}.crt -CAkey ${SIGNING_CA1_NAME}.key \
    -CAcreateserial -out ${CERT_NAME}.crt -days ${DAYS_VALID} -sha256 \
    -extfile ${CERT_NAME}.cnf -extensions v3_ca

# show certificate
openssl x509 -in ${CERT_NAME}.crt -text -noout

# rm tmp file
rm ${CERT_NAME}.cnf ${CERT_NAME}.csr

echo "Signing CA-2 certificate has been generated as ${CERT_NAME}.crt"

