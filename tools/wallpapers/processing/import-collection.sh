#!/usr/bin/env bash
set -uo pipefail

if [[ $# -lt 1 || $# -gt 3 || ! "$1" =~ ^(generate|finalize|status)$ ]]; then
  printf 'Użycie: %s generate|finalize|status [SHARD_INDEX SHARD_COUNT]\n' "$0" >&2
  exit 64
fi

mode="$1"
shard_index="${2:-0}"
shard_count="${3:-1}"
if [[ ! "$shard_index" =~ ^[0-9]+$ || ! "$shard_count" =~ ^[1-9][0-9]*$ ]] \
  || (( shard_index >= shard_count )); then
  printf 'Shard wymaga 0 <= SHARD_INDEX < SHARD_COUNT.\n' >&2
  exit 64
fi
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
wallpaper_root="$repo_root/home/base/wallpapers"
manifest="$wallpaper_root/collection.json"
source_root="$(jq -r '.sourceRoot // "16x9"' "$manifest")"
work_root="$wallpaper_root/work/import-48"
master_root="$work_root/masters"
source_backup_root="$work_root/sources"
generated_root="$work_root/generated"
accepted_root="$work_root/accepted"
rejected_root="$work_root/rejected"
finalized_root="$work_root/finalized"
mkdir -p \
  "$master_root" \
  "$source_backup_root" \
  "$generated_root" \
  "$accepted_root" \
  "$rejected_root" \
  "$finalized_root"

if ! jq -e '.wallpapers | length == 48' "$manifest" >/dev/null; then
  printf 'Manifest musi zawierać dokładnie 48 tapet.\n' >&2
  exit 1
fi

failures=0
item_index=-1
while IFS= read -r item; do
  item_index=$((item_index + 1))
  if (( item_index % shard_count != shard_index )); then
    continue
  fi
  slug="$(jq -r '.slug' <<< "$item")"
  source_name="$(jq -r '.source' <<< "$item")"
  prompt_name="$(jq -r '.prompt // empty' <<< "$item")"
  ready="$(jq -r '.ready // false' <<< "$item")"
  source_file="$wallpaper_root/$source_root/$source_name"
  master_file="$master_root/$slug.png"

  if [[ "$mode" == status ]]; then
    complete=true
    for aspect in 16x9 21x9 32x9; do
      [[ -s "$wallpaper_root/$aspect/$slug.png" ]] || complete=false
    done
    if [[ "$complete" == true ]]; then
      printf 'ready\t%s\n' "$slug"
    elif [[ -s "$master_file" ]]; then
      printf 'master\t%s\n' "$slug"
    else
      printf 'missing\t%s\n' "$slug"
    fi
    continue
  fi

  if [[ "$ready" == true ]]; then
    printf 'Pomijam gotowy komplet: %s\n' "$slug"
    continue
  fi

  if [[ "$mode" == generate ]]; then
    if [[ -s "$master_file" ]]; then
      touch "$generated_root/$slug.ready"
      printf 'Pomijam istniejący master: %s\n' "$slug"
      continue
    fi
    prompt_file="$wallpaper_root/prompts/$prompt_name"
    if [[ ! -s "$source_file" || ! -s "$prompt_file" ]]; then
      printf 'Brak źródła lub promptu dla %s.\n' "$slug" >&2
      failures=$((failures + 1))
      continue
    fi
    cp -n -- "$source_file" "$source_backup_root/$source_name"
    error_code_file="$work_root/$slug.error-code"
    rm -f -- "$error_code_file"
    if env \
      SEEDREAM_MODEL=seedream-5-0-lite-260128 \
      SEEDREAM_WALLPAPER_SIZE=5120x1440 \
      SEEDREAM_ERROR_CODE_FILE="$error_code_file" \
      "$repo_root/tools/wallpapers/generation/seedream-edit.sh" \
      "$source_file" "$prompt_file" "$master_file"; then
      touch "$generated_root/$slug.ready"
    elif [[ -r "$error_code_file" ]] \
      && [[ "$(< "$error_code_file")" == OutputImageSensitiveContentDetected* ]]; then
      printf 'Seedream 5.0 odrzucił %s; próbuję fallback 4.5.\n' "$slug"
      rm -f -- "$error_code_file"
      if env \
        SEEDREAM_MODEL=seedream-4-5-251128 \
        SEEDREAM_WALLPAPER_SIZE=5120x1440 \
        SEEDREAM_ERROR_CODE_FILE="$error_code_file" \
        "$repo_root/tools/wallpapers/generation/seedream-edit.sh" \
        "$source_file" "$prompt_file" "$master_file"; then
        touch "$generated_root/$slug.ready"
      else
        failures=$((failures + 1))
      fi
    else
      failures=$((failures + 1))
    fi
    continue
  fi

  if [[ ! -s "$master_file" ]]; then
    printf 'Brak zaakceptowanego mastera dla %s.\n' "$slug" >&2
    failures=$((failures + 1))
    continue
  fi
  crop_file="$accepted_root/$slug.json"
  if [[ ! -s "$crop_file" ]]; then
    printf 'Brak planu kadru QA dla %s.\n' "$slug" >&2
    failures=$((failures + 1))
    continue
  fi
  crop_16_x="$(jq -r '.crop16X // empty' "$crop_file")"
  crop_21_x="$(jq -r '.crop21X // empty' "$crop_file")"
  if [[ ! "$crop_16_x" =~ ^[0-9]+$ || ! "$crop_21_x" =~ ^[0-9]+$ ]]; then
    printf 'Niepełny plan kadru QA dla %s.\n' "$slug" >&2
    failures=$((failures + 1))
    continue
  fi
  if ! "$repo_root/tools/wallpapers/processing/finalize-imported.sh" \
    "$slug" "$master_file" "$crop_16_x" "$crop_21_x"; then
    failures=$((failures + 1))
  fi
done < <(jq -c '.wallpapers[]' "$manifest")

if (( failures > 0 )); then
  printf 'Nieukończone pozycje: %d.\n' "$failures" >&2
  exit 1
fi

if [[ "$mode" == generate && "$shard_count" == 1 ]]; then
  touch "$work_root/generation-complete"
fi
