#!/bin/bash
# Generate self-signed TLS certificates for MongoDB

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

CERTS_DIR="./certs"
DAYS_VALID=365
HOSTNAME=${1:-localhost}

if [ -d "$CERTS_DIR" ] && [ -f "$CERTS_DIR/mongodb.pem" ]; then
    log_error "Certificates already exist in $CERTS_DIR"
    echo ""
    echo "To regenerate, run:"
    echo "  rm -rf $CERTS_DIR && ./generate-certs.sh"
    exit 1
fi

log_info "Creating certificates directory..."
mkdir -p "$CERTS_DIR"

log_info "Generating CA certificate..."
openssl genrsa -out "$CERTS_DIR/ca.key" 4096 2>/dev/null
openssl req -new -x509 -days $DAYS_VALID -key "$CERTS_DIR/ca.key" \
    -out "$CERTS_DIR/ca.crt" \
    -subj "/CN=MongoDB-CA/O=MongoDB-Minimal-Kit" 2>/dev/null

log_info "Generating server certificate for hostname: $HOSTNAME"
openssl genrsa -out "$CERTS_DIR/server.key" 4096 2>/dev/null

cat > "$CERTS_DIR/server.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $HOSTNAME

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $HOSTNAME
DNS.2 = localhost
DNS.3 = mongodb
IP.1 = 127.0.0.1
EOF

openssl req -new -key "$CERTS_DIR/server.key" \
    -out "$CERTS_DIR/server.csr" \
    -config "$CERTS_DIR/server.cnf" 2>/dev/null

openssl x509 -req -days $DAYS_VALID \
    -in "$CERTS_DIR/server.csr" \
    -CA "$CERTS_DIR/ca.crt" \
    -CAkey "$CERTS_DIR/ca.key" \
    -CAcreateserial \
    -out "$CERTS_DIR/server.crt" \
    -extensions v3_req \
    -extfile "$CERTS_DIR/server.cnf" 2>/dev/null

log_info "Creating MongoDB PEM file..."
cat "$CERTS_DIR/server.key" "$CERTS_DIR/server.crt" > "$CERTS_DIR/mongodb.pem"
chmod 600 "$CERTS_DIR/mongodb.pem"

# Cleanup intermediate files
rm -f "$CERTS_DIR/server.csr" "$CERTS_DIR/server.cnf" "$CERTS_DIR/ca.srl"

echo ""
echo "════════════════════════════════════════════════════════════"
log_success "Certificates generated!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Files created in $CERTS_DIR/:"
echo "  ca.crt       - CA certificate (share with clients)"
echo "  mongodb.pem  - Server certificate + key"
echo ""
echo "Next steps:"
echo "  1. Set TLS_ENABLED=true in .env"
echo "  2. Start MongoDB: docker-compose up -d"
echo "  3. Create project: ./create-project.sh myproject"
