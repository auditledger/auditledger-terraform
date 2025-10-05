#!/bin/bash

# Check markdown links locally
# This script runs the same link checking as the CI pipeline

set -e

echo "🔗 Checking markdown links..."
echo "================================"

# Find all markdown files except those in .git and node_modules
MARKDOWN_FILES=$(find . -name "*.md" -not -path "./.git/*" -not -path "./node_modules/*")

# Check if markdown-link-check is installed
if ! command -v markdown-link-check &> /dev/null; then
    echo "❌ markdown-link-check not found. Installing..."
    npm install -g markdown-link-check
fi

# Check if config file exists
CONFIG_FILE=".github/markdown-link-check-config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

# Run link check on all markdown files
TOTAL_ERRORS=0
for file in $MARKDOWN_FILES; do
    echo ""
    echo "=== Checking $file ==="

    # Run markdown-link-check and capture output
    OUTPUT=$(markdown-link-check "$file" -c "$CONFIG_FILE" 2>&1 || true)

    # Check if there were errors
    if echo "$OUTPUT" | grep -q "ERROR:"; then
        echo "$OUTPUT"
        # Extract error count
        ERROR_COUNT=$(echo "$OUTPUT" | grep "ERROR:" | sed 's/.*ERROR: \([0-9]*\).*/\1/')
        TOTAL_ERRORS=$((TOTAL_ERRORS + ERROR_COUNT))
    else
        echo "✅ No link errors found"
    fi
done

echo ""
echo "================================"
if [ $TOTAL_ERRORS -eq 0 ]; then
    echo "🎉 All links are valid! ($TOTAL_ERRORS errors)"
    exit 0
else
    echo "❌ Found $TOTAL_ERRORS dead link(s) total"
    exit 1
fi
