#!/bin/bash
# Quick script to run tests against LocalStack with environment loaded

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load LocalStack environment variables
ENV_FILE="$PROJECT_ROOT/.env.localstack"

if [ ! -f "$ENV_FILE" ]; then
    echo "⚠️  .env.localstack not found. Creating from example..."
    cp "$PROJECT_ROOT/env.localstack.example" "$ENV_FILE"
    echo "✅ Created .env.localstack"
fi

echo "📝 Loading LocalStack environment from .env.localstack..."
# shellcheck source=/dev/null
source "$ENV_FILE"

echo "🔍 Environment configured:"
echo "  AWS_ENDPOINT_URL: $AWS_ENDPOINT_URL"
echo "  AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION"
echo "  USE_LOCALSTACK: $USE_LOCALSTACK"
echo ""

# Check if LocalStack is running
if ! curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    echo "❌ LocalStack is not running!"
    echo ""
    echo "Start it with:"
    echo "  docker compose up -d localstack"
    echo ""
    exit 1
fi

echo "✅ LocalStack is running"
echo ""

# Determine what to run
TEST_PATTERN="${1:-}"

if [ -z "$TEST_PATTERN" ]; then
    echo "🧪 Running all LocalStack integration tests..."
    cd "$PROJECT_ROOT/tests/integration"
    go test -v -timeout 15m -run ".*LocalStack"
else
    echo "🧪 Running tests matching: $TEST_PATTERN"
    cd "$PROJECT_ROOT/tests/integration"
    go test -v -timeout 15m -run "$TEST_PATTERN"
fi
