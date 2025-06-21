#!/bin/bash

# set environment
ROOT_CA_NAME="root-ca"
CERT_NAME="signing-ca-1"
DAYS_VALID=36500  # 100 years
KEY_SIZE=4096
COUNTRY="US"
STATE="California"
ORGANIZATION="OpenResty"
COMMON_NAME="Signing-CA-1"

# check root ca exists
if [ ! -f "${ROOT_CA_NAME}.crt" ] || [ ! -f "${ROOT_CA_NAME}.key" ]; then
    echo "Root CA certificate or key not found. Please generate them first."
    exit 1
fi

# generate private key
openssl genrsa -out ${CERT_NAME}.key ${KEY_SIZE}

# create certificate request config file (csr)
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

# generate certificate request file
openssl req -new -key ${CERT_NAME}.key -out ${CERT_NAME}.csr -config ${CERT_NAME}.cnf

# sign the csr using the root ca
openssl x509 -req -in ${CERT_NAME}.csr -CA ${ROOT_CA_NAME}.crt -CAkey ${ROOT_CA_NAME}.key \
    -CAcreateserial -out ${CERT_NAME}.crt -days ${DAYS_VALID} -sha256 \
    -extfile ${CERT_NAME}.cnf -extensions v3_ca

# show cert
openssl x509 -in ${CERT_NAME}.crt -text -noout

# remove tmp files
rm ${CERT_NAME}.cnf ${CERT_NAME}.csr

echo "Signing CA certificate has been generated as ${CERT_NAME}.crt"

