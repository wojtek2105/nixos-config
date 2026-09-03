#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 6 ]]; then
  printf 'Użycie: %s SLUG CORE_2560x1440 LITE_5120x1440 [BLACK_16] [BLACK_21] [BLACK_32]\n' "$0" >&2
  exit 64
fi

slug="$1"
core_image="$2"
lite_master="$3"
black_16="${4:-2.0}"
black_21="${5:-2.0}"
black_32="${6:-2.0}"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
wallpaper_root="$repo_root/home/base/wallpapers"

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
if [[ ! -s "$core_image" || ! -s "$lite_master" ]]; then
  printf 'Brak zaakceptowanego rdzenia Pro albo mastera Lite.\n' >&2
  exit 1
fi

core_size="$($magick_bin identify -format '%wx%h' "$core_image")"
lite_size="$($magick_bin identify -format '%wx%h' "$lite_master")"
if [[ "$core_size" != "2560x1440" || "$lite_size" != "5120x1440" ]]; then
  printf 'Nieprawidłowe wymiary: Pro=%s, Lite=%s.\n' "$core_size" "$lite_size" >&2
  exit 1
fi

mkdir -p \
  "$wallpaper_root/16x9" \
  "$wallpaper_root/21x9" \
  "$wallpaper_root/32x9"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

# Lite odpowiada wyłącznie za nową lewą przestrzeń. Oryginalny rdzeń Pro wraca
# piksel w piksel na prawą stronę; 192 px przenikania maskuje wyłącznie granicę
# outpaintingu i nie zmienia skali ani geometrii zaakceptowanego kadru.
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
  "$tmp_dir/${slug}-master.png"

# Trzy kadry są oknami na ten sam master: 16:9 to zaakceptowany Pro, 21:9
# odsłania dodatkowe 880 px po lewej, a 32:9 zachowuje pełny outpainting Lite.
# Niski black point domyka tylko najgłębsze cienie do fizycznego #000000 OLED.
"$magick_bin" "$core_image" \
  -channel RGB -level "${black_16}%,100%,1.0" +channel \
  -strip -define png:color-type=2 -define png:compression-level=9 \
  "$wallpaper_root/16x9/${slug}.png"
"$magick_bin" "$tmp_dir/${slug}-master.png" \
  -crop 3440x1440+1680+0 +repage \
  -channel RGB -level "${black_21}%,100%,1.0" +channel \
  -strip -define png:color-type=2 -define png:compression-level=9 \
  "$wallpaper_root/21x9/${slug}.png"
"$magick_bin" "$tmp_dir/${slug}-master.png" \
  -channel RGB -level "${black_32}%,100%,1.0" +channel \
  -strip -define png:color-type=2 -define png:compression-level=9 \
  "$wallpaper_root/32x9/${slug}.png"

printf 'Gotowe: %s (16:9, 21:9, 32:9).\n' "$slug"
