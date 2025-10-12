#!/bin/bash
# Setup script for local testing with LocalStack

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Setting up local testing environment (LocalStack) for AuditLedger Terraform..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Please install Docker Desktop.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker installed${NC}"

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose not found. Please install Docker Compose.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker Compose installed${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform not found. Please install Terraform.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Terraform installed ($(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4))${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${YELLOW}⚠️  AWS CLI not found. Installing is recommended for testing.${NC}"
else
    echo -e "${GREEN}✅ AWS CLI installed${NC}"
fi

echo ""

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p "$PROJECT_ROOT/.localstack"
echo -e "${GREEN}✅ Directories created${NC}"

# Start services
echo ""
echo "🐳 Starting LocalStack..."
cd "$PROJECT_ROOT"

if docker compose version &> /dev/null; then
    docker compose up -d
else
    docker-compose up -d
fi

echo ""
echo "⏳ Waiting for services to be healthy..."
sleep 5

# Check LocalStack
echo "Checking LocalStack..."
for i in {1..30}; do
    if curl -s http://localhost:4566/_localstack/health | grep -q '"s3": "available"'; then
        echo -e "${GREEN}✅ LocalStack is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ LocalStack failed to start${NC}"
        exit 1
    fi
    sleep 2
done

echo ""
echo -e "${GREEN}🎉 LocalStack is ready!${NC}"
echo ""

# Create .env file if it doesn't exist
if [ ! -f "$PROJECT_ROOT/.env.localstack" ]; then
    echo "📝 Creating .env.localstack from example..."
    cp "$PROJECT_ROOT/env.localstack.example" "$PROJECT_ROOT/.env.localstack"
    echo -e "${GREEN}✅ Created .env.localstack${NC}"
fi

echo ""
echo "📝 Next steps:"
echo ""
echo "1. Load LocalStack environment:"
echo "   source .env.localstack"
echo ""
echo "2. Or use the test script:"
echo "   ./scripts/test-localstack.sh"
echo ""
echo "3. Or manually run tests:"
echo "   cd tests/integration"
echo "   USE_LOCALSTACK=true AWS_ENDPOINT_URL=http://localhost:4566 go test -v"
echo ""
echo "4. Stop services when done:"
echo "   docker compose down"
echo ""
echo "📚 For more info, see: tests/README.md"
