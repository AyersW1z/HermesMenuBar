#!/bin/bash
# HermesMenuBar installer

set -euo pipefail

APP_NAME="HermesMenuBar"
APP_BUNDLE="${APP_NAME}.app"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/Applications"
SOURCE_APP="${SOURCE_DIR}/build/${APP_BUNDLE}"

echo "========================================"
echo "  HermesMenuBar Installer"
echo "========================================"
echo ""

echo "🔨 Building the latest version first..."
"${SOURCE_DIR}/build_app.sh"

# Verify that the app bundle exists
if [ ! -d "${SOURCE_APP}" ]; then
    echo "❌ Error: ${SOURCE_APP} was not found"
    exit 1
fi

# Create the Applications directory if needed
if [ ! -d "$TARGET_DIR" ]; then
    echo "📁 Creating ${TARGET_DIR}..."
    mkdir -p "$TARGET_DIR"
fi

# Check whether the app is already installed
if [ -d "${TARGET_DIR}/${APP_BUNDLE}" ]; then
    echo "⚠️  ${APP_NAME} is already installed in ${TARGET_DIR}"
    read -p "Overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled"
        exit 0
    fi
    echo "🗑️  Removing the previous version..."
    rm -rf "${TARGET_DIR}/${APP_BUNDLE}"
fi

# Copy the app bundle
echo "📦 Installing ${APP_NAME}..."
cp -R "${SOURCE_APP}" "$TARGET_DIR/"

# Ensure the executable bit is set
chmod +x "${TARGET_DIR}/${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo ""
echo "✅ Installation complete!"
echo ""
echo "📍 Installed to: ${TARGET_DIR}/${APP_BUNDLE}"
echo ""
echo "🚀 Launch options:"
echo "   1. Open Launchpad and click HermesMenuBar"
echo "   2. Press Cmd+Space and search for HermesMenuBar"
echo "   3. Run: open '${TARGET_DIR}/${APP_BUNDLE}'"
echo ""
echo "💡 Notes:"
echo "   - On first launch, macOS may warn that the developer cannot be verified"
echo "   - Go to System Settings → Privacy & Security and choose Open Anyway if needed"
echo "   - The app shows a 💬 icon in the menu bar"
echo ""

# Ask whether to launch immediately
read -p "Launch ${APP_NAME} now? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
        echo "🛑 Closing the currently running instance..."
        pkill -x "${APP_NAME}" || true
        sleep 1
    fi
    echo "🚀 Launching ${APP_NAME}..."
    open -n "${TARGET_DIR}/${APP_BUNDLE}"
fi
