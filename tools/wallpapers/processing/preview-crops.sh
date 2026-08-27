#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  printf 'Użycie: %s SLUG [KROK_X]\n' "$0" >&2
  exit 64
fi

slug="$1"
step="${2:-256}"
if [[ ! "$step" =~ ^[1-9][0-9]*$ ]]; then
  printf 'KROK_X musi być dodatnią liczbą całkowitą.\n' >&2
  exit 64
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
wallpaper_root="$repo_root/home/wojtek/wallpapers"
work_root="$wallpaper_root/work/import-48"
manifest="$wallpaper_root/collection.json"
master="$work_root/masters/$slug.png"
preview_root="$work_root/crop-previews/$slug/16x9"
source_root="$(jq -r '.sourceRoot // "16x9"' "$manifest")"
source_name="$(jq -r --arg slug "$slug" \
  '.wallpapers[] | select(.slug == $slug) | .source' "$manifest")"
raw="$wallpaper_root/$source_root/$source_name"

if [[ ! -s "$master" || ! -s "$raw" ]]; then
  printf 'Brak mastera albo RAW-a dla %s.\n' "$slug" >&2
  exit 1
fi

if command -v magick >/dev/null 2>&1; then
  magick_bin="$(command -v magick)"
else
  magick_candidates=(/nix/store/*-imagemagick-*/bin/magick)
  magick_bin="${magick_candidates[0]:-}"
fi
if [[ -z "$magick_bin" || ! -x "$magick_bin" ]]; then
  printf 'Nie znaleziono ImageMagick.\n' >&2
  exit 1
fi

mkdir -p "$preview_root"
"$magick_bin" "$raw" -resize '1280x720^' -gravity center -extent 1280x720 \
  "$preview_root/reference-raw.png"

for (( x=0; x<=2560; x+=step )); do
  "$magick_bin" "$master" -crop "2560x1440+$x+0" +repage \
    -resize 1280x720 "$preview_root/candidate-x${x}.png"
done
if (( 2560 % step != 0 )); then
  "$magick_bin" "$master" -crop '2560x1440+2560+0' +repage \
    -resize 1280x720 "$preview_root/candidate-x2560.png"
fi

printf 'Podglądy kadru 16:9: %s\n' "$preview_root"
