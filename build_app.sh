#!/bin/bash
# HermesMenuBar app bundle builder

set -euo pipefail

APP_NAME="HermesMenuBar"
APP_VERSION="1.0.0"
APP_BUNDLE_ID="com.hermes.menubar"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
PLIST_PATH="${APP_BUNDLE}/Contents/Info.plist"

echo "🔨 Building ${APP_NAME}..."
swift build --package-path "${ROOT_DIR}"

BIN_PATH="$(swift build --package-path "${ROOT_DIR}" --show-bin-path)"
EXECUTABLE_PATH="${BIN_PATH}/${APP_NAME}"

if [ ! -f "${EXECUTABLE_PATH}" ]; then
    echo "❌ Build succeeded but executable not found: ${EXECUTABLE_PATH}"
    exit 1
fi

echo "📦 Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"

cp "${EXECUTABLE_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${ROOT_DIR}/${APP_NAME}/Info.plist" "${PLIST_PATH}"

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${APP_NAME}" "${PLIST_PATH}"
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${APP_NAME}" "${PLIST_PATH}"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${APP_BUNDLE_ID}" "${PLIST_PATH}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_VERSION}" "${PLIST_PATH}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${APP_VERSION}" "${PLIST_PATH}"

echo "✅ App bundle ready: ${APP_BUNDLE}"
