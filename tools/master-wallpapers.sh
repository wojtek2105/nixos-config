#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
wallpaper_root="$repo_root/home/wojtek/wallpapers"
source_root="$wallpaper_root/sources"
from_scene="${1:-01}"
to_scene="${2:-22}"
target_black="${OLED_BLACK_TARGET:-35}"
# Consolidate shadows that are already dark, but never crush a bright or
# incomplete source merely to manufacture the requested OLED percentage.
max_black_point="${OLED_MAX_BLACK_POINT:-10}"

if [[ -n "${MAGICK_BIN:-}" ]]; then
  magick_bin="$MAGICK_BIN"
elif command -v magick >/dev/null 2>&1; then
  magick_bin="$(command -v magick)"
else
  magick_candidates=(/nix/store/*-imagemagick-*/bin/magick)
  magick_bin="${magick_candidates[0]:-}"
fi

if [[ -z "$magick_bin" || ! -x "$magick_bin" ]]; then
  printf 'Nie znaleziono ImageMagick. Ustaw MAGICK_BIN albo dodaj pakiet do środowiska.\n' >&2
  exit 1
fi

mkdir -p "$wallpaper_root/32x9" "$wallpaper_root/21x9" "$wallpaper_root/16x9"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

metrics="$wallpaper_root/METRICS.tsv"
printf 'scene\tblack_point\texact_black_pct\tnear_black_pct\tmean_luma_pct\tstatus\n' > "$metrics"

black_fraction() {
  local image="$1"
  local threshold="$2"
  "$magick_bin" "$image" -alpha off -channel RGB -separate \
    -evaluate-sequence max -threshold "${threshold}%" -negate \
    -format '%[fx:mean*100]' info:
}

shopt -s nullglob
sources=("$source_root"/[0-9][0-9]-*-source.jpg)
if (( ${#sources[@]} == 0 )); then
  printf 'Brak źródeł do masteringu w %s.\n' "$source_root" >&2
  exit 1
fi

for source in "${sources[@]}"; do
  source_file="$(basename -- "$source")"
  scene_id="${source_file%%-*}"
  (( 10#$scene_id < 10#$from_scene || 10#$scene_id > 10#$to_scene )) && continue
  slug="${source_file%-source.jpg}"

  raw="$tmp_dir/${slug}-raw.png"
  mastered="$wallpaper_root/32x9/${slug}.png"

  printf '[%s] kadruję i masteruję %s...\n' "$scene_id" "$slug"
  "$magick_bin" "$source" -auto-orient -filter Lanczos \
    -resize 'x1440' -gravity east -crop '5120x1440+0+0' +repage \
    -colorspace sRGB -modulate 94,104,100 "$raw"

  low=0
  high="$max_black_point"
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
    mid="$(awk -v low="$low" -v high="$high" 'BEGIN { printf "%.5f", (low + high) / 2 }')"
    fraction="$(black_fraction "$raw" "$mid")"
    if awk -v fraction="$fraction" -v target="$target_black" 'BEGIN { exit !(fraction < target) }'; then
      low="$mid"
    else
      high="$mid"
    fi
  done
  black_point="$high"

  "$magick_bin" "$raw" -channel RGB -level "${black_point}%,94%,1.0" +channel \
    -strip -define png:color-type=2 -define png:compression-level=9 "$mastered"

  "$magick_bin" "$mastered" -gravity east -crop '3440x1440+0+0' +repage \
    -strip -define png:color-type=2 -define png:compression-level=9 \
    "$wallpaper_root/21x9/${slug}.png"
  "$magick_bin" "$mastered" -gravity east -crop '2560x1440+0+0' +repage \
    -strip -define png:color-type=2 -define png:compression-level=9 \
    "$wallpaper_root/16x9/${slug}.png"

  exact_black="$(black_fraction "$mastered" 0)"
  near_black="$(black_fraction "$mastered" 3.13725)"
  mean_luma="$($magick_bin "$mastered" -colorspace gray -format '%[fx:mean*100]' info:)"
  if awk -v black="$exact_black" -v target="$target_black" \
      -v luma="$mean_luma" 'BEGIN { exit !(black >= target && black <= 50 && luma <= 18) }'; then
    status="OK"
  else
    status="REVIEW_SOURCE"
  fi
  printf '%s\t%s\t%.2f\t%.2f\t%.2f\t%s\n' \
    "$scene_id" "$black_point" "$exact_black" "$near_black" "$mean_luma" "$status" \
    >> "$metrics"
done

printf 'Mastering zakończony. Metryki: %s\n' "$metrics"
