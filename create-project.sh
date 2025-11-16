#!/bin/bash
# Create isolated MongoDB project with dedicated users

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Parse arguments
PROJECT=$1
FORCE=false

if [ "$2" = "--force" ] || [ "$2" = "-f" ]; then
    FORCE=true
fi

if [ -z "$PROJECT" ]; then
    log_error "Project name is required"
    echo "Usage: ./create-project.sh PROJECT_NAME [--force]"
    echo ""
    echo "Options:"
    echo "  --force, -f    Delete existing users and recreate"
    exit 1
fi

DB="${PROJECT}_db"
READER_USER="${PROJECT}_reader"
WRITER_USER="${PROJECT}_writer"

log_info "Starting project creation for: $PROJECT"
[ "$FORCE" = true ] && log_warning "Force mode enabled - will overwrite existing users"

# Check .env file
if [ ! -f .env ]; then
    log_error ".env file not found"
    exit 1
fi

source .env

log_info "Loaded environment variables from .env"
log_info "Database name: $DB"
log_info "Reader user: $READER_USER"
log_info "Writer user: $WRITER_USER"

# Check if MongoDB is running
log_info "Checking MongoDB connection..."
if ! docker exec mongodb mongosh -u $ROOT_NAME -p $ROOT_PASSWORD --quiet --eval "db.version()" > /dev/null 2>&1; then
    log_error "Cannot connect to MongoDB. Is the container running?"
    exit 1
fi
log_success "MongoDB connection successful"

# Check if users already exist
log_info "Checking if users already exist..."

READER_EXISTS=$(docker exec -i mongodb mongosh -u $ROOT_NAME -p $ROOT_PASSWORD --quiet --eval "use('$DB'); db.getUser('$READER_USER') ? 'true' : 'false'")
WRITER_EXISTS=$(docker exec -i mongodb mongosh -u $ROOT_NAME -p $ROOT_PASSWORD --quiet --eval "use('$DB'); db.getUser('$WRITER_USER') ? 'true' : 'false'")

if [ "$READER_EXISTS" = true ] || [ "$WRITER_EXISTS" = true ]; then
    if [ "$FORCE" = true ]; then
        log_warning "Users exist, deleting them..."
        if [ "$READER_EXISTS" = true ]; then
            docker exec -i mongodb mongosh -u $ROOT_NAME -p $ROOT_PASSWORD --quiet --eval "use('$DB'); db.dropUser('$READER_USER')"
            log_success "Deleted user: $READER_USER"
        fi
        if [ "$WRITER_EXISTS" = true ]; then
            docker exec -i mongodb mongosh -u $ROOT_NAME -p $ROOT_PASSWORD --quiet --eval "use('$DB'); db.dropUser('$WRITER_USER')"
            log_success "Deleted user: $WRITER_USER"
        fi
    else
        echo ""
        log_error "Users already exist for this project!"
        [ "$READER_EXISTS" = true ] && log_error "  - User '$READER_USER' already exists in database '$DB'"
        [ "$WRITER_EXISTS" = true ] && log_error "  - User '$WRITER_USER' already exists in database '$DB'"
        echo ""
        log_warning "Available options:"
        echo ""
        echo "1. Use --force flag to recreate users:"
        echo "   ./create-project.sh $PROJECT --force"
        echo ""
        echo "2. Use a different project name:"
        echo "   ./create-project.sh ${PROJECT}_v2"
        echo ""
        echo "3. Check existing credentials:"
        echo "   cat ${PROJECT}.env"
        echo "   cat ${PROJECT}.json"
        echo ""
        echo "4. Manually delete users:"
        echo "   docker exec -i mongodb mongosh -u $ROOT_NAME -p '$ROOT_PASSWORD' <<EOF"
        echo "   use('$DB')"
        [ "$READER_EXISTS" = true ] && echo "   db.dropUser('$READER_USER')"
        [ "$WRITER_EXISTS" = true ] && echo "   db.dropUser('$WRITER_USER')"
        echo "EOF"
        echo ""
        exit 1
    fi
else
    log_success "No existing users found"
fi

# Generate passwords
log_info "Generating secure passwords..."
READER_PASS=$(openssl rand -hex 16 | md5sum | cut -d' ' -f1)
WRITER_PASS=$(openssl rand -hex 16 | md5sum | cut -d' ' -f1)
log_success "Passwords generated"

# Create database and users
log_info "Creating database and users in MongoDB..."

docker exec -i mongodb mongosh -u $ROOT_NAME -p $ROOT_PASSWORD --quiet <<EOF
use $DB
db.createUser({
  user: "$READER_USER",
  pwd: "$READER_PASS",
  roles: [{ role: "read", db: "$DB" }]
})
db.createUser({
  user: "$WRITER_USER",
  pwd: "$WRITER_PASS",
  roles: [{ role: "readWrite", db: "$DB" }]
})
exit
EOF

log_success "Database '$DB' created with users"

# Save credentials to .env
log_info "Saving credentials to ${PROJECT}.env..."
cat > ${PROJECT}.env << EOF
# MongoDB credentials for $PROJECT
# Generated: $(date)

DATABASE=$DB
READER_URI=mongodb://${READER_USER}:${READER_PASS}@localhost:${PORT:-27017}/$DB
WRITER_URI=mongodb://${WRITER_USER}:${WRITER_PASS}@localhost:${PORT:-27017}/$DB

# Individual credentials
READER_USER=$READER_USER
READER_PASSWORD=$READER_PASS
WRITER_USER=$WRITER_USER
WRITER_PASSWORD=$WRITER_PASS
EOF

log_success "Credentials saved to ${PROJECT}.env"

# Save credentials to JSON
log_info "Saving credentials to ${PROJECT}.json..."
cat > ${PROJECT}.json << EOF
{
  "database": "$DB",
  "readerUri": "mongodb://${READER_USER}:${READER_PASS}@localhost:${PORT:-27017}/$DB",
  "writerUri": "mongodb://${WRITER_USER}:${WRITER_PASS}@localhost:${PORT:-27017}/$DB"
}
EOF

log_success "Credentials saved to ${PROJECT}.json"

# Summary
echo ""
echo "════════════════════════════════════════════════════════════"
log_success "Project '$PROJECT' created successfully!"
echo "════════════════════════════════════════════════════════════"
echo ""
cat ${PROJECT}.env