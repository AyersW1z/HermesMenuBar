#!/bin/bash
# HermesMenuBar 安装脚本

set -euo pipefail

APP_NAME="HermesMenuBar"
APP_BUNDLE="${APP_NAME}.app"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/Applications"
SOURCE_APP="${SOURCE_DIR}/build/${APP_BUNDLE}"

echo "========================================"
echo "  HermesMenuBar 安装程序"
echo "========================================"
echo ""

echo "🔨 先构建最新版本..."
"${SOURCE_DIR}/build_app.sh"

# 检查应用是否存在
if [ ! -d "${SOURCE_APP}" ]; then
    echo "❌ 错误: 找不到 ${SOURCE_APP}"
    exit 1
fi

# 创建 Applications 目录（如果不存在）
if [ ! -d "$TARGET_DIR" ]; then
    echo "📁 创建 ${TARGET_DIR} 目录..."
    mkdir -p "$TARGET_DIR"
fi

# 检查是否已存在
if [ -d "${TARGET_DIR}/${APP_BUNDLE}" ]; then
    echo "⚠️  ${APP_NAME} 已安装在 ${TARGET_DIR}"
    read -p "是否覆盖? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 安装已取消"
        exit 0
    fi
    echo "🗑️  删除旧版本..."
    rm -rf "${TARGET_DIR}/${APP_BUNDLE}"
fi

# 复制应用
echo "📦 安装 ${APP_NAME}..."
cp -R "${SOURCE_APP}" "$TARGET_DIR/"

# 设置权限
chmod +x "${TARGET_DIR}/${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo ""
echo "✅ 安装完成!"
echo ""
echo "📍 安装位置: ${TARGET_DIR}/${APP_BUNDLE}"
echo ""
echo "🚀 启动方式:"
echo "   1. 打开 Launchpad，点击 HermesMenuBar 图标"
echo "   2. 或按 Cmd+Space 打开 Spotlight，搜索 'HermesMenuBar'"
echo "   3. 或直接运行: open '${TARGET_DIR}/${APP_BUNDLE}'"
echo ""
echo "💡 提示:"
echo "   - 首次运行时，系统可能会提示'无法验证开发者'"
echo "   - 请前往 系统设置 → 隐私与安全性 → 安全性，点击'仍要打开'"
echo "   - 应用会在菜单栏显示 💬 图标"
echo ""

# 询问是否立即启动
read -p "是否立即启动 ${APP_NAME}? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
        echo "🛑 正在关闭旧版本进程..."
        pkill -x "${APP_NAME}" || true
        sleep 1
    fi
    echo "🚀 正在启动 ${APP_NAME}..."
    open -n "${TARGET_DIR}/${APP_BUNDLE}"
fi
