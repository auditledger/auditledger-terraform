#!/bin/bash
# Teardown script for local testing environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🛑 Stopping local testing environment..."

cd "$PROJECT_ROOT"

# Stop containers
if docker compose version &> /dev/null; then
    docker compose down
else
    docker-compose down
fi

echo "✅ Services stopped"

# Optional: Clean up data
read -p "Do you want to delete test data (.localstack, .azurite)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$PROJECT_ROOT/.localstack"
    rm -rf "$PROJECT_ROOT/.azurite"
    rm -rf "$PROJECT_ROOT/.azurite-logs"
    echo "✅ Test data deleted"
else
    echo "ℹ️  Test data preserved for next run"
fi

echo ""
echo "✅ Teardown complete!"
