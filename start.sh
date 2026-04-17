#!/bin/bash
# HermesMenuBar launcher

set -euo pipefail

echo "Launching HermesMenuBar..."

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="${ROOT_DIR}/build/HermesMenuBar.app"

"${ROOT_DIR}/build_app.sh"

if pgrep -x HermesMenuBar >/dev/null 2>&1; then
    echo "🛑 Closing any currently running HermesMenuBar process..."
    pkill -x HermesMenuBar || true
    sleep 1
fi

if [ -d "$APP_PATH" ]; then
    open -n "$APP_PATH"
    echo "HermesMenuBar has been launched."
    echo "Opened the latest build: ${APP_PATH}"
    echo "Click the 💬 menu bar icon to start chatting."
else
    echo "Error: HermesMenuBar.app was not found."
    echo "Please make sure build_app.sh completed successfully."
    exit 1
fi
