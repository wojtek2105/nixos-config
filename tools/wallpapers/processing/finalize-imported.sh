#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 7 ]]; then
  printf 'Użycie: %s SLUG MASTER_5120x1440 [CROP_16_X] [CROP_21_X] [BLACK_16] [BLACK_21] [BLACK_32]\n' "$0" >&2
  exit 64
fi

slug="$1"
master_image="$2"
crop_16_x="${3:-2560}"
crop_21_x="${4:-1680}"
black_16="${5:-2.0}"
black_21="${6:-2.0}"
black_32="${7:-2.0}"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
wallpaper_root="$repo_root/home/base/wallpapers"
manifest="$wallpaper_root/collection.json"

source_root="$(jq -r '.sourceRoot // "16x9"' "$manifest")"
source_name="$(jq -r --arg slug "$slug" \
  '.wallpapers[] | select(.slug == $slug) | .source' "$manifest")"
raw_16="$wallpaper_root/$source_root/$source_name"

if [[ -n "${MAGICK_BIN:-}" ]]; then
  magick_bin="$MAGICK_BIN"
elif command -v magick >/dev/null 2>&1; then
  magick_bin="$(command -v magick)"
else
  magick_candidates=(/nix/store/*-imagemagick-*/bin/magick)
  magick_bin="${magick_candidates[0]:-}"
fi

if [[ -z "$magick_bin" || ! -x "$magick_bin" ]]; then
  printf 'Nie znaleziono ImageMagick. Ustaw MAGICK_BIN.\n' >&2
  exit 1
fi
if [[ ! -s "$master_image" ]]; then
  printf 'Brak zaakceptowanego mastera Lite: %s.\n' "$master_image" >&2
  exit 1
fi
if [[ ! -s "$raw_16" ]]; then
  printf 'Brak RAW-a referencyjnego 16:9 dla %s.\n' "$slug" >&2
  exit 1
fi

master_size="$($magick_bin identify -format '%wx%h' "$master_image")"
if [[ "$master_size" != "5120x1440" ]]; then
  printf 'Nieprawidłowy wymiar mastera: %s zamiast 5120x1440.\n' "$master_size" >&2
  exit 1
fi
if [[ ! "$crop_16_x" =~ ^[0-9]+$ ]] || (( crop_16_x > 2560 )); then
  printf 'CROP_16_X musi być liczbą od 0 do 2560.\n' >&2
  exit 64
fi
if [[ ! "$crop_21_x" =~ ^[0-9]+$ ]] || (( crop_21_x > 1680 )); then
  printf 'CROP_21_X musi być liczbą od 0 do 1680.\n' >&2
  exit 64
fi

mkdir -p \
  "$wallpaper_root/16x9" \
  "$wallpaper_root/21x9" \
  "$wallpaper_root/32x9"

# Piksele pochodzą z ostrego mastera 32:9. CROP_16_X jest dobierany przez QA
# przez wizualne porównanie z RAW-em, który pozostaje wzorcem kompozycji.
"$magick_bin" "$master_image" \
  -crop "2560x1440+${crop_16_x}+0" +repage \
  -channel RGB -level "${black_16}%,100%,1.0" +channel \
  -strip -define png:color-type=2 -define png:compression-level=9 \
  "$wallpaper_root/16x9/${slug}.png"
"$magick_bin" "$master_image" \
  -crop "3440x1440+${crop_21_x}+0" +repage \
  -channel RGB -level "${black_21}%,100%,1.0" +channel \
  -strip -define png:color-type=2 -define png:compression-level=9 \
  "$wallpaper_root/21x9/${slug}.png"
"$magick_bin" "$master_image" \
  -channel RGB -level "${black_32}%,100%,1.0" +channel \
  -strip -define png:color-type=2 -define png:compression-level=9 \
  "$wallpaper_root/32x9/${slug}.png"

printf 'Gotowe: %s (16:9 x=%s według RAW %s, 21:9 x=%s; master Lite 32:9).\n' \
  "$slug" "$crop_16_x" "${raw_16##*/}" "$crop_21_x"
