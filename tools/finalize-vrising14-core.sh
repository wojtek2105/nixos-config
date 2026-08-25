#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
wallpaper_root="$repo_root/home/wojtek/wallpapers"
candidate_root="$wallpaper_root/candidates/seedream5-pro"
base_image="${1:-$candidate_root/14-vrising-certificate-mechanism-v1.png}"
crossover_image="${2:-$candidate_root/14-vrising-certificate-crossover-v1.png}"
output_image="${3:-$candidate_root/14-blood-certificate-domain-core.png}"

if [[ -n "${MAGICK_BIN:-}" ]]; then
  magick_bin="$MAGICK_BIN"
elif command -v magick >/dev/null 2>&1; then
  magick_bin="$(command -v magick)"
else
  magick_candidates=(/nix/store/*-imagemagick-*/bin/magick)
  magick_bin="${magick_candidates[0]:-}"
fi

font_candidates=(
  /nix/store/*-dejavu-fonts-*/share/fonts/truetype/DejaVuSerifCondensed-Bold.ttf
)
font_file="${WALLPAPER_LABEL_FONT:-${font_candidates[0]:-}}"
traefik_icon="$wallpaper_root/assets/traefik-labs-icon.svg"

if [[ -z "$magick_bin" || ! -x "$magick_bin" ]]; then
  printf 'Nie znaleziono ImageMagick. Ustaw MAGICK_BIN.\n' >&2
  exit 1
fi
if [[ -z "$font_file" || ! -s "$font_file" ]]; then
  printf 'Nie znaleziono DejaVu Serif Condensed Bold. Ustaw WALLPAPER_LABEL_FONT.\n' >&2
  exit 1
fi
if [[ ! -s "$base_image" || ! -s "$crossover_image" || ! -s "$traefik_icon" ]]; then
  printf 'Brak wejściowego rdzenia albo wariantu z crossoverem.\n' >&2
  exit 1
fi

mkdir -p "$(dirname -- "$output_image")"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

# Pro narysował dobrą Pochitę zbyt dużą. Ten kontrolowany crop i maska zachowują
# jej oryginalne piksele, ale redukują ją do easter egga o wysokości 58 px.
"$magick_bin" "$crossover_image" -crop 360x300+1200+780 +repage \
  "$tmp_dir/pochita-region.png"
"$magick_bin" -size 360x300 xc:black \
  -fill white -stroke none \
  -draw 'path "M 100,165 C 105,125 135,110 175,112 C 220,112 257,133 269,173 C 279,211 258,249 219,260 C 178,271 130,255 108,226 C 92,206 89,182 100,165 Z" polygon 77,127 105,105 155,123 160,165 108,178 82,161 ellipse 143,252 18,13 0,360 ellipse 211,258 17,12 0,360' \
  -fill none -stroke white -strokewidth 17 \
  -draw 'path "M 184,122 L 187,91 Q 210,72 233,93 L 235,130"' \
  -blur 0x1 "$tmp_dir/pochita-mask.png"
"$magick_bin" "$tmp_dir/pochita-region.png" "$tmp_dir/pochita-mask.png" \
  -alpha off -compose CopyOpacity -composite -trim +repage -resize x58 \
  "$tmp_dir/pochita-small.png"

# Oficjalny znak Traefik Labs staje się heraldycznym haftem: bez napisu,
# prostokątnego tła i produktowej plakietki. Ciemny obrys udaje zagłębienie
# nici w materiale, a półprzezroczyste złoto przepuszcza światło i fałdy flagi.
"$magick_bin" -background none -density 384 "$traefik_icon" \
  -trim +repage -resize 54x62! -alpha extract "$tmp_dir/traefik-mask.png"
"$magick_bin" "$tmp_dir/traefik-mask.png" -morphology Dilate Diamond:1 \
  "$tmp_dir/traefik-shadow-mask.png"
"$magick_bin" -size 54x62 xc:'#211717' "$tmp_dir/traefik-shadow-mask.png" \
  -alpha off -compose CopyOpacity -composite -channel A -evaluate multiply 0.82 +channel \
  "$tmp_dir/traefik-thread-shadow.png"
"$magick_bin" -size 54x62 xc:'#E39C45' "$tmp_dir/traefik-mask.png" \
  -alpha off -compose CopyOpacity -composite -channel A -evaluate multiply 0.72 +channel \
  "$tmp_dir/traefik-gold-thread.png"

"$magick_bin" -size 74x30 xc:none -font "$font_file" -gravity center \
  -fill '#211717D9' -stroke none -pointsize 17 -annotate +1+1 '443' \
  -fill '#E39C45B8' -pointsize 17 -annotate +0+0 '443' \
  "$tmp_dir/port-thread.png"

# Krótkie napisy są tłoczeniami na istniejących rekwizytach. Warstwa ciemna
# tworzy wklęsły ślad, a przesunięty o jeden piksel Biscuit gold łapie światło.
"$magick_bin" -size 2560x1440 xc:none -font "$font_file" -gravity northwest \
  -fill '#120D0DEB' -stroke none -pointsize 15 -annotate +1374+866 'ACME' \
  -fill '#E39C458F' -pointsize 15 -annotate +1373+865 'ACME' \
  "$tmp_dir/diegetic-engravings.png"

"$magick_bin" "$base_image" "$tmp_dir/pochita-small.png" \
  -geometry +1305+895 -compose over -composite \
  "$tmp_dir/traefik-thread-shadow.png" -geometry +1889+565 -compose over -composite \
  "$tmp_dir/traefik-gold-thread.png" -geometry +1888+564 -compose over -composite \
  "$tmp_dir/port-thread.png" -geometry +1878+634 -compose over -composite \
  "$tmp_dir/diegetic-engravings.png" -compose over -composite \
  -strip -define png:color-type=2 -define png:compression-level=9 \
  "$output_image"

printf 'Gotowy finalny rdzeń sceny 14: %s\n' "$output_image"
