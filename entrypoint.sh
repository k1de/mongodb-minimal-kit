#!/bin/bash
# MongoDB entrypoint with optional TLS support

if [ "$TLS_ENABLED" = "true" ]; then
    if [ ! -f /certs/mongodb.pem ] || [ ! -f /certs/ca.crt ]; then
        echo "ERROR: TLS_ENABLED=true but certificates not found in /certs/"
        echo "Run: ./generate-certs.sh"
        exit 1
    fi
    exec mongod --tlsMode requireTLS \
        --tlsCertificateKeyFile /certs/mongodb.pem \
        --tlsCAFile /certs/ca.crt \
        --bind_ip_all
else
    exec mongod --bind_ip_all
fi
