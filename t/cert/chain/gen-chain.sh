openssl x509 -in test.com.crt  -text -noout > chain.pem
cat test.com.crt >> chain.pem
openssl x509 -in signing-ca-1.crt -text -noout >> chain.pem
cat signing-ca-1.crt >> chain.pem
openssl x509 -in signing-ca-2.crt -text -noout >> chain.pem
cat signing-ca-2.crt >> chain.pem

