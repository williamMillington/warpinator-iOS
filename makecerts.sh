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

IP_ADDRESS="192.168.2.15"

EXT_SubAltName="subjectAltName=IP:${IP_ADDRESS}"
EXT_ExKeyUsage="extendedKeyUsage=serverAuth,clientAuth"

# actual openssl location instead of LibreSSL, which does not have -addext
ssl=/usr/local/opt/openssl/bin/openssl


$ssl req -newkey rsa:2048 -nodes -keyout rootkey.key -x509 -days $DAYS_VALID -out root.crt -subj "/CN=${CN_SERVER}" -addext $EXT_SubAltName -addext $EXT_ExKeyUsage

# CA
#echo ""
#echo "Creating CA..."
#$ssl genrsa -out ca.key $SIZE
#$ssl req -new -x509 -days $DAYS_VALID -key ca.key -out ca.crt -subj "/CN=${CN_CA}"
#
## Server
#echo ""
#echo "Creating server credentials..."
#$ssl genrsa -out server.key $SIZE
#$ssl req -new -key server.key -out server.csr -subj "/CN=${CN_SERVER}" -addext $EXT_SubAltName
#$ssl x509 -req -days $DAYS_VALID -in server.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt -extensions v3_req -extfile ./ssl-extensions-x509.cnf
#
## Client
#echo ""
#echo "Creating client credentials..."
#$ssl genrsa -out client.key $SIZE
#$ssl req -new -key client.key -out client.csr -subj "/CN=${CN_CLIENT}"
#$ssl x509 -req -days $DAYS_VALID -in client.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out client.crt
#
## netty only supports PKCS8 keys. openssl is used to convert from PKCS1 to PKCS8
## http://netty.io/wiki/sslcontextbuilder-and-private-key.html
#echo ""
#echo "Converting keys to PKCS8..."
#$ssl pkcs8 -topk8 -nocrypt -in client.key -out client.pem
#$ssl pkcs8 -topk8 -nocrypt -in server.key -out server.pem
#$ssl pkcs8 -topk8 -nocrypt -in ca.key -out ca.pem
#
## Server cert with explicit EC parameters (not supported)
##$ssl ecparam -name prime256v1 -genkey -param_enc explicit -out server-explicit.key
##$ssl req -new -x509 -days $DAYS_VALID -key server-explicit.key -out server-explicit.crt -subj "/CN=${CN_SERVER}"
#
#
## Concatenate server and CA together
#echo
#echo "Concatenating CA and server certificates together..."
#cat ./server.crt ./ca.crt > serverbundle.pem
