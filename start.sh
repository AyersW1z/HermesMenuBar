#!/bin/bash
# HermesMenuBar 启动脚本

set -euo pipefail

echo "正在启动 HermesMenuBar..."

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="${ROOT_DIR}/build/HermesMenuBar.app"

"${ROOT_DIR}/build_app.sh"

if pgrep -x HermesMenuBar >/dev/null 2>&1; then
    echo "🛑 正在关闭旧的 HermesMenuBar 进程..."
    pkill -x HermesMenuBar || true
    sleep 1
fi

if [ -d "$APP_PATH" ]; then
    open -n "$APP_PATH"
    echo "HermesMenuBar 已启动！"
    echo "已打开最新构建版本: ${APP_PATH}"
    echo "点击菜单栏的 💬 图标开始聊天。"
else
    echo "错误: 找不到 HermesMenuBar.app"
    echo "请先检查 build_app.sh 是否成功执行"
    exit 1
fi
