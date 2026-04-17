#!/bin/bash
# HermesMenuBar 打包脚本

set -e

VERSION="1.0.0"
APP_NAME="HermesMenuBar"
BUILD_DIR="build"
DIST_DIR="dist"

echo "========================================"
echo "  HermesMenuBar 打包程序"
echo "  版本: ${VERSION}"
echo "========================================"
echo ""

# 清理旧构建
echo "🧹 清理旧构建..."
rm -rf "${BUILD_DIR}" "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

# 构建 Release 版本
echo "🔨 构建 Release 版本..."
swift build -c release
"$(cd "$(dirname "$0")" && pwd)/build_app.sh"

# 创建分发包
echo "📁 创建分发包..."
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
mkdir -p "${DIST_DIR}/${APP_NAME}"
cp -R "${BUILD_DIR}/${APP_NAME}.app" "${DIST_DIR}/${APP_NAME}/"
cp "README.md" "${DIST_DIR}/${APP_NAME}/"
cp "install.sh" "${DIST_DIR}/${APP_NAME}/"
cp "start.sh" "${DIST_DIR}/${APP_NAME}/"

# 创建 DMG (如果安装了 create-dmg)
if command -v create-dmg &> /dev/null; then
    echo "💿 创建 DMG 镜像..."
    create-dmg \
        --volname "${APP_NAME} ${VERSION}" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --app-drop-link 450 185 \
        --icon "${APP_NAME}.app" 150 185 \
        "${DIST_DIR}/${DMG_NAME}" \
        "${DIST_DIR}/${APP_NAME}/"
    echo "✅ DMG 创建完成: ${DIST_DIR}/${DMG_NAME}"
else
    echo "⚠️  未安装 create-dmg，跳过 DMG 创建"
    echo "   可以使用: brew install create-dmg"
fi

# 创建 ZIP
echo "📦 创建 ZIP 压缩包..."
cd "${DIST_DIR}"
zip -r "${APP_NAME}-${VERSION}.zip" "${APP_NAME}/"
cd ..

echo ""
echo "========================================"
echo "  ✅ 打包完成!"
echo "========================================"
echo ""
echo "📦 分发文件:"
echo "   - ${DIST_DIR}/${APP_NAME}-${VERSION}.zip"
if [ -f "${DIST_DIR}/${DMG_NAME}" ]; then
    echo "   - ${DIST_DIR}/${DMG_NAME}"
fi
echo ""
echo "📂 应用位置:"
echo "   - ${BUILD_DIR}/${APP_NAME}.app"
echo ""
echo "🚀 快速测试:"
echo "   open '${BUILD_DIR}/${APP_NAME}.app'"
echo ""
