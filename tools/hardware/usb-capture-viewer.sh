#!/usr/bin/env bash
set -euo pipefail

if ! command -v mpv >/dev/null 2>&1; then
  printf 'Brak mpv w PATH. Jest deklarowany w home/wojtek/desktop.nix.\n' >&2
  exit 1
fi

requested_device="${1:-${CAPTURE_DEVICE:-}}"
resolution="${CAPTURE_RESOLUTION:-1920x1080}"
fps="${CAPTURE_FPS:-60}"
audio_mode="${CAPTURE_AUDIO:-auto}"
audio_device="${CAPTURE_AUDIO_DEVICE:-}"
audio_delay="${CAPTURE_AUDIO_DELAY:-0}"
fallback_pixel_format="${CAPTURE_PIXEL_FORMAT:-mjpeg}"
# Raw YUY2 capture frames have no reliable color metadata. This card delivers
# 1080p60 as PC/full range; mpv otherwise assumes limited range and crushes
# shadows. Use CAPTURE_COLOR_LEVELS=limited only if a different source looks
# washed out. Valid values: auto, limited, full.
color_levels="${CAPTURE_COLOR_LEVELS:-full}"
color_matrix="${CAPTURE_COLOR_MATRIX:-bt.709}"
# Optional crop applied after colour interpretation, e.g. 1728:1080 for a
# centred 16:10 view from 1080p. It preserves geometry; do not use an aspect
# override here because that would stretch circles and UI.
capture_crop="${CAPTURE_CROP:-}"

case "$color_levels" in
  auto|limited|full) ;;
  *)
    printf 'Nieprawidłowy CAPTURE_COLOR_LEVELS=%s (dozwolone: auto, limited, full).\n' "$color_levels" >&2
    exit 1
    ;;
esac

if [[ -n "$capture_crop" && ! "$capture_crop" =~ ^[0-9]+:[0-9]+(:[0-9]+(:[0-9]+)?)?$ ]]; then
  printf 'Nieprawidłowy CAPTURE_CROP=%s (format: szerokość:wysokość[:x:y]).\n' \
    "$capture_crop" >&2
  exit 1
fi

video_filter="format:colormatrix=$color_matrix:colorlevels=$color_levels"
[[ -n "$capture_crop" ]] && video_filter+=",crop=$capture_crop"

is_capture_device() {
  local device="$1"
  if command -v v4l2-ctl >/dev/null 2>&1; then
    v4l2-ctl --device "$device" --all 2>/dev/null \
      | grep -qE 'Video Capture|Video Capture Multiplanar'
  else
    [[ -c "$device" ]]
  fi
}

if [[ -n "$requested_device" ]]; then
  [[ -c "$requested_device" ]] || {
    printf 'Urządzenie nie istnieje albo nie jest urządzeniem znakowym: %s\n' "$requested_device" >&2
    exit 1
  }
  device="$requested_device"
else
  device=""
  best_score=-1
  for sys_device in /sys/class/video4linux/video*; do
    [[ -e "$sys_device" ]] || continue
    candidate="/dev/$(basename -- "$sys_device")"
    is_capture_device "$candidate" || continue

    name="$(<"$sys_device/name")"
    lower_name="${name,,}"
    score=0
    [[ "$(readlink -f "$sys_device/device")" == *'/usb'* ]] && score=$((score + 20))
    [[ "$lower_name" =~ (capture|hdmi|grabber|uvc) ]] && score=$((score + 100))
    # A built-in webcam is also USB/UVC, so penalize it strongly enough that a
    # generically named external capture card (for example "USB3 Video") wins.
    [[ "$lower_name" =~ (integrated|webcam|camera) ]] && score=$((score - 200))
    if (( score > best_score )); then
      best_score="$score"
      device="$candidate"
    fi
  done
fi

if [[ -z "$device" ]]; then
  printf 'Nie znaleziono wejścia wideo. Podłącz rejestrator i sprawdź: ls /dev/video*\n' >&2
  printf 'Możesz wymusić urządzenie: CAPTURE_DEVICE=/dev/video2 %s\n' "$0" >&2
  exit 1
fi

pixel_format=""
video_input_args=()
if command -v v4l2-ctl >/dev/null 2>&1; then
  formats="$(v4l2-ctl --device "$device" --list-formats-ext 2>/dev/null || true)"
  requested_pixel_format="${CAPTURE_PIXEL_FORMAT:-}"
  case "${requested_pixel_format,,}" in
    "") ;;
    mjpeg|mjpg) pixel_format="MJPG" ;;
    nv12) pixel_format="NV12" ;;
    yuyv|yuy2|yuyv422) pixel_format="YUYV" ;;
    *)
      printf 'Nieprawidłowy CAPTURE_PIXEL_FORMAT=%s (dozwolone: mjpeg, nv12, yuyv422).\n' \
        "$requested_pixel_format" >&2
      exit 1
      ;;
  esac

  if [[ -n "$pixel_format" ]] && ! grep -q "'$pixel_format'" <<< "$formats"; then
    printf 'Karta %s nie obsługuje formatu %s w V4L2.\n' "$device" "$pixel_format" >&2
    exit 1
  elif [[ -z "$pixel_format" ]] && grep -q "'MJPG'" <<< "$formats"; then
    pixel_format="MJPG"
  elif [[ -z "$pixel_format" ]] && grep -q "'NV12'" <<< "$formats"; then
    pixel_format="NV12"
  elif [[ -z "$pixel_format" ]] && grep -q "'YUYV'" <<< "$formats"; then
    pixel_format="YUYV"
  fi

  if [[ "$resolution" =~ ^([0-9]+)x([0-9]+)$ ]]; then
    format_request="width=${BASH_REMATCH[1]},height=${BASH_REMATCH[2]}"
    [[ -n "$pixel_format" ]] && format_request+=",pixelformat=$pixel_format"
    v4l2-ctl --device "$device" --set-fmt-video="$format_request" >/dev/null 2>&1 \
      || printf 'Uwaga: urządzenie odrzuciło żądany format %s. Używam bieżącego.\n' "$resolution" >&2
    v4l2-ctl --device "$device" --set-parm="$fps" >/dev/null 2>&1 \
      || printf 'Uwaga: urządzenie odrzuciło %s Hz. Używam bieżącego FPS.\n' "$fps" >&2

    printf 'Tryb wynegocjowany przez urządzenie:\n'
    v4l2-ctl --device "$device" --get-fmt-video 2>/dev/null || true
    v4l2-ctl --device "$device" --get-parm 2>/dev/null || true
  fi
else
  # Direct execution may happen before the Home Manager wrapper (which adds
  # v4l2-ctl) is activated. Request the mode through FFmpeg in that case.
  video_input_args=(
    --demuxer-lavf-format=video4linux2
    --demuxer-lavf-o="video_size=$resolution,input_format=$fallback_pixel_format,framerate=$fps"
  )
  printf 'Brak v4l2-ctl: wymuszam przez MPV format %s, %s @ %s FPS.\n' \
    "$fallback_pixel_format" "$resolution" "$fps"
fi

usb_root_for() {
  local current
  current="$(readlink -f "$1")"
  while [[ "$current" != / ]]; do
    if [[ -r "$current/idVendor" && -r "$current/idProduct" ]]; then
      printf '%s\n' "$current"
      return 0
    fi
    current="$(dirname -- "$current")"
  done
  return 1
}

audio_args=(--audio=no)
if [[ ! "$audio_mode" =~ ^(0|no|false|off)$ ]]; then
  if [[ -z "$audio_device" ]]; then
    video_usb_root="$(usb_root_for "/sys/class/video4linux/$(basename -- "$device")/device" || true)"
    if [[ -n "$video_usb_root" ]]; then
      for sound_card in /sys/class/sound/card[0-9]*; do
        [[ -e "$sound_card/device" ]] || continue
        card_name="$(basename -- "$sound_card")"
        card_index="${card_name#card}"
        [[ -d "/proc/asound/$card_name/pcm0c" ]] || continue
        sound_usb_root="$(usb_root_for "$sound_card/device" || true)"
        if [[ "$sound_usb_root" == "$video_usb_root" ]]; then
          audio_device="hw:$card_index,0"
          break
        fi
      done
    fi
  fi

  if [[ -n "$audio_device" ]]; then
    audio_args=(
      --audio-file="av://alsa:$audio_device"
      --audio-file-auto=no
      --audio-delay="$audio_delay"
    )
  elif [[ "$audio_mode" != auto ]]; then
    printf 'Nie znaleziono wejścia audio tej samej karty USB.\n' >&2
    exit 1
  fi
fi

device_name_file="/sys/class/video4linux/$(basename -- "$device")/name"
if [[ -r "$device_name_file" ]]; then
  device_name="$(<"$device_name_file")"
else
  device_name="USB capture"
fi
printf 'Otwieram %s (%s), %s @ %s Hz.\n' "$device_name" "$device" "$resolution" "$fps"
if [[ -n "$audio_device" && ! "$audio_mode" =~ ^(0|no|false|off)$ ]]; then
  printf 'Dźwięk: %s (automatycznie powiązany z tym samym urządzeniem USB).\n' "$audio_device"
else
  printf 'Dźwięk: wyłączony.\n'
fi
printf 'Zmiana parametrów: CAPTURE_RESOLUTION=3840x2160 CAPTURE_FPS=30 %s\n' "$0"
printf 'Kolor: %s, %s. Dla wypranego obrazu użyj CAPTURE_COLOR_LEVELS=limited.\n' \
  "$color_matrix" "$color_levels"
[[ -n "$capture_crop" ]] && printf 'Kadrowanie: %s (bez rozciągania).\n' "$capture_crop"
printf 'Terminal pokazuje podczas pracy: wejściowy / dekodowany / ekranowy FPS.\n'

exec mpv \
  --title="USB Capture — $device_name" \
  --profile=low-latency \
  --untimed \
  --cache=no \
  --osd-level=1 \
  --osd-align-x=right \
  --osd-align-y=top \
  --osd-margin-x=20 \
  --osd-margin-y=20 \
  --osd-font-size=22 \
  --osd-msg1='IN ${container-fps} FPS | DECODE ${estimated-vf-fps} FPS | DISPLAY ${display-fps} Hz | DROP ${decoder-frame-drop-count}/${frame-drop-count}' \
  --term-status-msg='capture input=${container-fps} | decoded=${estimated-vf-fps} | display=${display-fps}' \
  --vf="$video_filter" \
  "${video_input_args[@]}" \
  "${audio_args[@]}" \
  "av://v4l2:$device"
