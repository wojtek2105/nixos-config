#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
wallpaper_root="$repo_root/home/wojtek/wallpapers"
candidate_root="$wallpaper_root/candidates"
lite_master="${1:-$candidate_root/seedream5-lite/14-blood-certificate-domain-master-v1.png}"
# Accepted Pro v3 already contains AI-authored diegetic ACME, Traefik/443 and
# the larger Pochita. Do not route scene 14 through the retired local overlay.
core_image="${2:-$candidate_root/seedream5-pro/14-vrising-certificate-ai-labels-acme-v3.png}"
slug="14-blood-certificate-domain"

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
if [[ ! -s "$lite_master" || ! -s "$core_image" ]]; then
  printf 'Brak zaakceptowanego mastera Lite albo rdzenia Pro.\n' >&2
  exit 1
fi

lite_size="$($magick_bin identify -format '%wx%h' "$lite_master")"
core_size="$($magick_bin identify -format '%wx%h' "$core_image")"
if [[ "$lite_size" != "5120x1440" || "$core_size" != "2560x1440" ]]; then
  printf 'Nieprawidłowe wymiary: Lite=%s, Pro=%s.\n' "$lite_size" "$core_size" >&2
  exit 1
fi

mkdir -p \
  "$wallpaper_root/sources" \
  "$wallpaper_root/32x9" \
  "$wallpaper_root/21x9" \
  "$wallpaper_root/16x9"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

# Lite dobrze dopowiedział lewą połowę, ale przemalował część rdzenia. Pro wraca
# więc na prawą stronę. Wąskie 192 px przenikania znajduje się w najciemniejszej
# architekturze; nie rozmywa postaci, mechanizmu, tekstu ani heraldyki.
"$magick_bin" -size 192x1440 xc:black \
  -sparse-color barycentric '0,0 black 191,0 white' \
  "$tmp_dir/feather.png"
"$magick_bin" "$tmp_dir/feather.png" -size 2368x1440 xc:white +append \
  "$tmp_dir/core-mask.png"
"$magick_bin" "$core_image" "$tmp_dir/core-mask.png" \
  -alpha off -compose CopyOpacity -composite "$tmp_dir/core-feathered.png"
"$magick_bin" "$lite_master" "$tmp_dir/core-feathered.png" \
  -geometry +2560+0 -compose over -composite \
  -strip -define png:color-type=2 -define png:compression-level=9 \
  "$wallpaper_root/sources/${slug}-source.png"

# Każdy kadr zawiera inną proporcję ciemnej nawy, dlatego dostaje minimalny,
# osobny black point. Progi 2.0–3.75% dotyczą wyłącznie tonów 5–10/255 i dają
# co najmniej 35% prawdziwego #000000 bez gaszenia czerwieni, złota i postaci.
"$magick_bin" "$wallpaper_root/sources/${slug}-source.png" \
  -channel RGB -level '2%,100%,1.0' +channel \
  -strip -define png:color-type=2 -define png:compression-level=9 \
  "$wallpaper_root/32x9/${slug}.png"
"$magick_bin" "$wallpaper_root/sources/${slug}-source.png" \
  -crop 3440x1440+1680+0 +repage \
  -channel RGB -level '3.75%,100%,1.0' +channel \
  -strip -define png:color-type=2 -define png:compression-level=9 \
  "$wallpaper_root/21x9/${slug}.png"
"$magick_bin" "$core_image" \
  -channel RGB -level '3.25%,100%,1.0' +channel \
  -strip -define png:color-type=2 -define png:compression-level=9 \
  "$wallpaper_root/16x9/${slug}.png"

printf 'Gotowe warianty sceny 14:\n'
printf '  32:9  %s\n' "$wallpaper_root/32x9/${slug}.png"
printf '  21:9  %s\n' "$wallpaper_root/21x9/${slug}.png"
printf '  16:9  %s\n' "$wallpaper_root/16x9/${slug}.png"
