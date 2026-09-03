#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
work_root="$repo_root/home/base/wallpapers/work/import-48"
mkdir -p "$work_root/finalized"

shopt -s nullglob
for marker in "$work_root"/accepted/*.ready; do
  slug="${marker##*/}"
  slug="${slug%.ready}"
  finalized_marker="$work_root/finalized/$slug.ready"
  if [[ -e "$finalized_marker" ]]; then
    continue
  fi
  crop_file="$work_root/accepted/$slug.json"
  if [[ ! -s "$crop_file" ]]; then
    printf 'Brak planu kadru dla %s; pomijam promocję.\n' "$slug" >&2
    continue
  fi
  crop_16_x="$(jq -r '.crop16X' "$crop_file")"
  crop_21_x="$(jq -r '.crop21X' "$crop_file")"
  if [[ "$crop_16_x" == null || "$crop_21_x" == null ]]; then
    printf 'Niepełny plan kadru dla %s; pomijam promocję.\n' "$slug" >&2
    continue
  fi
  bash "$repo_root/tools/wallpapers/processing/finalize-imported.sh" \
    "$slug" "$work_root/masters/$slug.png" "$crop_16_x" "$crop_21_x"
  touch "$finalized_marker"
done
