cp test.crt test_passphrase.crt
openssl rsa -in test.key -out test_passphrase.key -aes256 -passout pass:123456
