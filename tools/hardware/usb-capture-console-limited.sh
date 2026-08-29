#!/usr/bin/env bash
set -euo pipefail

# 1080p60 YUY2 dla konsoli ustawionej na HDMI Limited (16–235).
export CAPTURE_RESOLUTION="${CAPTURE_RESOLUTION:-1920x1080}"
export CAPTURE_FPS="${CAPTURE_FPS:-60}"
export CAPTURE_PIXEL_FORMAT="${CAPTURE_PIXEL_FORMAT:-yuyv422}"
export CAPTURE_COLOR_MATRIX="${CAPTURE_COLOR_MATRIX:-bt.709}"
export CAPTURE_COLOR_LEVELS="${CAPTURE_COLOR_LEVELS:-limited}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$script_dir/usb-capture-viewer.sh" "$@"
