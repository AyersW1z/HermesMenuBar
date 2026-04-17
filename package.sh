#!/bin/bash
# HermesMenuBar packaging script

set -e

VERSION="1.0.0"
APP_NAME="HermesMenuBar"
BUILD_DIR="build"
DIST_DIR="dist"

echo "========================================"
echo "  HermesMenuBar Packager"
echo "  Version: ${VERSION}"
echo "========================================"
echo ""

# Clean previous build output
echo "🧹 Cleaning previous build output..."
rm -rf "${BUILD_DIR}" "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

# Build the release binary
echo "🔨 Building the release version..."
swift build -c release
"$(cd "$(dirname "$0")" && pwd)/build_app.sh"

# Assemble the distributable directory
echo "📁 Creating the distribution directory..."
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
mkdir -p "${DIST_DIR}/${APP_NAME}"
cp -R "${BUILD_DIR}/${APP_NAME}.app" "${DIST_DIR}/${APP_NAME}/"
cp "README.md" "${DIST_DIR}/${APP_NAME}/"
cp "install.sh" "${DIST_DIR}/${APP_NAME}/"
cp "start.sh" "${DIST_DIR}/${APP_NAME}/"

# Create a DMG if create-dmg is installed
if command -v create-dmg &> /dev/null; then
    echo "💿 Building DMG image..."
    create-dmg \
        --volname "${APP_NAME} ${VERSION}" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --app-drop-link 450 185 \
        --icon "${APP_NAME}.app" 150 185 \
        "${DIST_DIR}/${DMG_NAME}" \
        "${DIST_DIR}/${APP_NAME}/"
    echo "✅ DMG created: ${DIST_DIR}/${DMG_NAME}"
else
    echo "⚠️  create-dmg is not installed; skipping DMG creation"
    echo "   Install it with: brew install create-dmg"
fi

# Create ZIP archive
echo "📦 Creating ZIP archive..."
cd "${DIST_DIR}"
zip -r "${APP_NAME}-${VERSION}.zip" "${APP_NAME}/"
cd ..

echo ""
echo "========================================"
echo "  ✅ Packaging complete!"
echo "========================================"
echo ""
echo "📦 Distribution files:"
echo "   - ${DIST_DIR}/${APP_NAME}-${VERSION}.zip"
if [ -f "${DIST_DIR}/${DMG_NAME}" ]; then
    echo "   - ${DIST_DIR}/${DMG_NAME}"
fi
echo ""
echo "📂 App bundle:"
echo "   - ${BUILD_DIR}/${APP_NAME}.app"
echo ""
echo "🚀 Quick test:"
echo "   open '${BUILD_DIR}/${APP_NAME}.app'"
echo ""
