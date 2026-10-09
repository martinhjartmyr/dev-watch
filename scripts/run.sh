#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Build if needed
if [[ ! -d "${PROJECT_DIR}/build/DevWatch.app" ]]; then
    "${SCRIPT_DIR}/build.sh"
fi

# Kill any existing instance
pkill -x DevWatch 2>/dev/null || true

echo "🚀 Launching DevWatch..."
open "${PROJECT_DIR}/build/DevWatch.app"
echo "✨ DevWatch is now running in your Mac menu bar!"
