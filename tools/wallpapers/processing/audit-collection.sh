#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
wallpaper_root="$repo_root/home/wojtek/wallpapers"
manifest="$wallpaper_root/collection.json"

if [[ ! -s "$manifest" ]]; then
  printf 'Brak manifestu: %s.\n' "$manifest" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  printf 'Brak jq w PATH.\n' >&2
  exit 1
fi

if ! jq -e '.wallpapers | length == 48' "$manifest" >/dev/null; then
  printf 'Manifest musi zawierać dokładnie 48 tapet.\n' >&2
  exit 1
fi
if [[ "$(jq -r '[.wallpapers[].slug] | unique | length' "$manifest")" != 48 ]]; then
  printf 'Manifest zawiera zduplikowane slugi.\n' >&2
  exit 1
fi

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

failures=0
for spec in '16x9:2560x1440' '21x9:3440x1440' '32x9:5120x1440'; do
  aspect="${spec%%:*}"
  expected="${spec#*:}"
  count=0
  while IFS= read -r slug; do
    file="$wallpaper_root/$aspect/$slug.png"
    if [[ ! -s "$file" ]]; then
      printf 'Brak %s: %s\n' "$aspect" "$slug" >&2
      failures=$((failures + 1))
      continue
    fi
    size="$($magick_bin identify -format '%wx%h' "$file")"
    if [[ "$size" != "$expected" ]]; then
      printf 'Zły wymiar %s/%s: %s zamiast %s\n' "$aspect" "$slug" "$size" "$expected" >&2
      failures=$((failures + 1))
    fi
    count=$((count + 1))
  done < <(jq -r '.wallpapers[].slug' "$manifest")
  printf '%s: %d/48 plików, wymiar %s\n' "$aspect" "$count" "$expected"
done

if (( failures > 0 )); then
  printf 'Audyt nieudany: %d problemów.\n' "$failures" >&2
  exit 1
fi
printf 'Audyt kolekcji zakończony pomyślnie.\n'
