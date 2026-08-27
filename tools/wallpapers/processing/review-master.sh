#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 4 || ! "$1" =~ ^(accept|reject)$ ]]; then
  printf 'Użycie: %s accept SLUG [CROP_16_X CROP_21_X] | reject SLUG [POWÓD]\n' "$0" >&2
  exit 64
fi

action="$1"
slug="$2"
reason="${3:-manual-review}"
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
work_root="$repo_root/home/wojtek/wallpapers/work/import-48"
master_file="$work_root/masters/$slug.png"

if [[ ! -s "$master_file" ]]; then
  printf 'Brak mastera: %s.\n' "$master_file" >&2
  exit 1
fi

magick_candidates=(/nix/store/*-imagemagick-*/bin/magick)
magick_bin="${MAGICK_BIN:-${magick_candidates[0]:-}}"
size="$($magick_bin identify -format '%wx%h' "$master_file")"
if [[ "$size" != 5120x1440 ]]; then
  printf 'Nieprawidłowy wymiar %s: %s.\n' "$slug" "$size" >&2
  exit 1
fi

if [[ "$action" == accept ]]; then
  crop_16_x="${3:-2560}"
  crop_21_x="${4:-1680}"
  if [[ ! "$crop_16_x" =~ ^[0-9]+$ ]] || (( crop_16_x > 2560 )); then
    printf 'CROP_16_X musi być liczbą od 0 do 2560.\n' >&2
    exit 64
  fi
  if [[ ! "$crop_21_x" =~ ^[0-9]+$ ]] || (( crop_21_x > 1680 )); then
    printf 'CROP_21_X musi być liczbą od 0 do 1680.\n' >&2
    exit 64
  fi
  jq -n \
    --arg slug "$slug" \
    --argjson crop16 "$crop_16_x" \
    --argjson crop21 "$crop_21_x" \
    '{slug: $slug, crop16X: $crop16, crop21X: $crop21}' \
    > "$work_root/accepted/$slug.json"
  touch "$work_root/accepted/$slug.ready"
  rm -f -- "$work_root/rejected/$slug.reason"
  printf 'Zaakceptowano master: %s.\n' "$slug"
else
  printf '%s\n' "$reason" > "$work_root/rejected/$slug.reason"
  rm -f -- "$work_root/accepted/$slug.ready"
  rm -f -- "$work_root/accepted/$slug.json"
  printf 'Odrzucono master %s: %s.\n' "$slug" "$reason"
fi
