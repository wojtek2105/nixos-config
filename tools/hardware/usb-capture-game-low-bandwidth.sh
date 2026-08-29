#!/usr/bin/env bash
set -euo pipefail

# 1080p60 MJPEG: mniejsze użycie USB kosztem kompresji obrazu przez kartę.
export CAPTURE_RESOLUTION="${CAPTURE_RESOLUTION:-1920x1080}"
export CAPTURE_FPS="${CAPTURE_FPS:-60}"
export CAPTURE_PIXEL_FORMAT="${CAPTURE_PIXEL_FORMAT:-mjpeg}"
export CAPTURE_COLOR_MATRIX="${CAPTURE_COLOR_MATRIX:-bt.709}"
export CAPTURE_COLOR_LEVELS="${CAPTURE_COLOR_LEVELS:-full}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$script_dir/usb-capture-viewer.sh" "$@"
