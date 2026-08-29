#!/usr/bin/env bash
set -euo pipefail

# 4K30 SDR MJPEG: kompatybilny tryb jakościowy dla kart USB 3.x.
export CAPTURE_RESOLUTION="${CAPTURE_RESOLUTION:-3840x2160}"
export CAPTURE_FPS="${CAPTURE_FPS:-30}"
export CAPTURE_PIXEL_FORMAT="${CAPTURE_PIXEL_FORMAT:-mjpeg}"
export CAPTURE_COLOR_MATRIX="${CAPTURE_COLOR_MATRIX:-bt.709}"
export CAPTURE_COLOR_LEVELS="${CAPTURE_COLOR_LEVELS:-full}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$script_dir/usb-capture-viewer.sh" "$@"
