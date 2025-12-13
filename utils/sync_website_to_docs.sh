#!/bin/bash
# Sync website files to docs folder for GitHub Pages
# This ensures docs/ always has the latest website content

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBSITE_DIR="$BASE_DIR/website"
DOCS_DIR="$BASE_DIR/docs"

echo "🔄 Syncing website files to docs/ for GitHub Pages..."
echo ""

# Copy website files (excluding app-store-materials and temp files)
# Note: CNAME file is preserved in docs/ and not overwritten
rsync -av --delete \
    --exclude='app-store-materials' \
    --exclude='temp-screenshots' \
    --exclude='.DS_Store' \
    --exclude='CNAME' \
    "$WEBSITE_DIR/" "$DOCS_DIR/"

echo ""
echo "✅ Website files synced to docs/"
echo "   📁 Ready for GitHub Pages deployment"

