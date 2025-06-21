#!/bin/bash

SIGNING_CA2_NAME="signing-ca-2"
CERT_NAME="test.com"
DAYS_VALID=36500  # 100 years
KEY_SIZE=4096
COUNTRY="US"
STATE="California"
ORGANIZATION="OpenResty"
COMMON_NAME="test.com"

if [ ! -f "${SIGNING_CA2_NAME}.crt" ] || [ ! -f "${SIGNING_CA2_NAME}.key" ]; then
    echo "Signing CA-2 certificate or key not found. Please generate them first."
    exit 1
fi

openssl genrsa -out ${CERT_NAME}.key ${KEY_SIZE}

cat > ${CERT_NAME}.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
C = ${COUNTRY}
ST = ${STATE}
O = ${ORGANIZATION}
CN = ${COMMON_NAME}

[v3_req]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

openssl req -new -key ${CERT_NAME}.key -out ${CERT_NAME}.csr -config ${CERT_NAME}.cnf

openssl x509 -req -in ${CERT_NAME}.csr -CA ${SIGNING_CA2_NAME}.crt -CAkey ${SIGNING_CA2_NAME}.key \
    -CAcreateserial -out ${CERT_NAME}.crt -days ${DAYS_VALID} -sha256 \
    -extfile ${CERT_NAME}.cnf -extensions v3_req

openssl x509 -in ${CERT_NAME}.crt -text -noout

rm ${CERT_NAME}.cnf ${CERT_NAME}.csr

echo "Server certificate for ${CERT_NAME} has been generated as ${CERT_NAME}.crt"

mv ${CERT_NAME}.key ${CERT_NAME}.key.pem
cp ${CERT_NAME}.key.pem test-com.key.pem

openssl x509 -in test.com.crt -outform der -out test.com.der
openssl pkey -in test.com.key.pem -outform DER -out test.com.key.der

cp test.com.der test-com.der
cp test.com.key.der test-com.key.der
