#!/bin/bash
#
# Creates a trust collection certificate (ca.crt)
# and self-signed server certificate (server.crt) and private key (server.pem)
# and client certificate (client.crt) and key file (client.pem) for mutual TLS.
# Replace "example.com" with the host name you'd like for your certificate.
#
# https://github.com/grpc/grpc-java/tree/master/examples
#
SIZE=2048

CN_CA=WarpinatorCA
CN_SERVER=WarpinatorIOS
CN_CLIENT=localhost

DAYS_VALID=30

# CA
openssl genrsa -out ca.key $SIZE
openssl req -new -x509 -days $DAYS_VALID -key ca.key -out ca.crt -subj "/CN=${CN_CA}"

# Server
openssl genrsa -out server.key $SIZE
openssl req -new -key server.key -out server.csr -subj "/CN=${CN_SERVER}"
openssl x509 -req -days $DAYS_VALID -in server.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt

# Client
openssl genrsa -out client.key $SIZE
openssl req -new -key client.key -out client.csr -subj "/CN=${CN_CLIENT}"
openssl x509 -req -days $DAYS_VALID -in client.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out client.crt

# netty only supports PKCS8 keys. openssl is used to convert from PKCS1 to PKCS8
# http://netty.io/wiki/sslcontextbuilder-and-private-key.html
openssl pkcs8 -topk8 -nocrypt -in client.key -out client.pem
openssl pkcs8 -topk8 -nocrypt -in server.key -out server.pem

# Server cert with explicit EC parameters (not supported)
openssl ecparam -name prime256v1 -genkey -param_enc explicit -out server-explicit.key
openssl req -new -x509 -days $DAYS_VALID -key server-explicit.key -out server-explicit.crt -subj "/CN=${CN_SERVER}"
