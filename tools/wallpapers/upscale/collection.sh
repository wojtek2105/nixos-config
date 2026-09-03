#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 || ! "$1" =~ ^(run|promote|status)$ ]]; then
  printf 'Użycie: %s run|promote|status [SHARD_INDEX SHARD_COUNT]\n' "$0" >&2
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
work_root="$wallpaper_root/work/import-48"
stage_name="${UPSCALE_STAGE_NAME:-upscaled-32x9}"
if [[ ! "$stage_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  printf 'UPSCALE_STAGE_NAME musi być bezpieczną nazwą katalogu.\n' >&2
  exit 64
fi
stage_root="$work_root/$stage_name"
backup_root="$work_root/pre-upscale-32x9"
mkdir -p "$stage_root" "$backup_root"

if [[ "$mode" != status ]]; then
  # Four workers may be started as shards, but only one may use the single GPU
  # at a time. Other shards wait here instead of competing for VRAM.
  printf 'LOCK waiting: %s (timeout=%ss)\n' \
    "$work_root/upscale-gpu.lock" "${REALESRGAN_LOCK_TIMEOUT:-86400}"
  exec 9>"$work_root/upscale-gpu.lock"
  flock -w "${REALESRGAN_LOCK_TIMEOUT:-86400}" 9 \
    || { printf 'Nie udało się uzyskać blokady GPU.\n' >&2; exit 1; }
  printf 'LOCK acquired.\n'
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'Brak jq w PATH.\n' >&2
  exit 1
fi
if ! jq -e '.wallpapers | length == 48' "$manifest" >/dev/null; then
  printf 'Manifest musi zawierać dokładnie 48 tapet.\n' >&2
  exit 1
fi

# A whitespace-separated allow-list makes a short quality comparison possible
# without ever touching unrelated staged or active wallpapers.  Slugs in this
# collection are shell-safe identifiers; reject anything else before it reaches
# a path or a child process.
declare -A requested_slugs=()
if [[ -n "${UPSCALE_SLUGS:-}" ]]; then
  read -r -a selected_slug_list <<< "$UPSCALE_SLUGS"
  for selected_slug in "${selected_slug_list[@]}"; do
    if [[ ! "$selected_slug" =~ ^[a-zA-Z0-9._-]+$ ]]; then
      printf 'UPSCALE_SLUGS zawiera nieprawidłowy slug: %s\n' "$selected_slug" >&2
      exit 64
    fi
    if ! jq -e --arg slug "$selected_slug" \
      '.wallpapers[] | select(.slug == $slug)' "$manifest" >/dev/null; then
      printf 'Brak sluga w collection.json: %s\n' "$selected_slug" >&2
      exit 64
    fi
    requested_slugs["$selected_slug"]=1
  done
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

if [[ "$mode" != status ]]; then
  realesrgan_bin="${REALESRGAN_BIN:-}"
  models_root="${REALESRGAN_MODELS:-}"
  if [[ -z "$realesrgan_bin" || ! -x "$realesrgan_bin" ]]; then
    printf 'Ustaw REALESRGAN_BIN na binarkę realesrgan-ncnn-vulkan.\n' >&2
    exit 1
  fi
  if [[ ! -d "$models_root" ]]; then
    printf 'Ustaw REALESRGAN_MODELS na katalog models z pakietu Real-ESRGAN.\n' >&2
    exit 1
  fi

  # Portable Linux binary is dynamically linked against generic glibc. On
  # NixOS, use the native loader explicitly and pin the AMD Vulkan ICD.
  loader="${REALESRGAN_LOADER:-}"
  if [[ -z "$loader" ]]; then
    loader_candidates=(/nix/store/*-glibc-*/lib64/ld-linux-x86-64.so.2)
    loader="${loader_candidates[0]:-}"
  fi
  library_path="${REALESRGAN_LIBRARY_PATH:-}"
  if [[ -z "$library_path" ]]; then
    glibc_lib="${loader%/lib64/ld-linux-x86-64.so.2}/lib"
    # Some inaccessible or stale Nix store entries make `find` return 1 even
    # after it has found a valid library. With `set -e -o pipefail` that used
    # to abort the worker silently before Vulkan was started.
    find_library_dir() {
      local pattern="$1"
      local library
      library="$(find /nix/store -maxdepth 3 -type f -name "$pattern" \
        -print -quit 2>/dev/null || true)"
      if [[ -n "$library" ]]; then
        dirname -- "$library"
      fi
    }
    gcc_lib="$(find_library_dir 'libgomp.so.1.0.0')"
    gcc_libgcc="$(find_library_dir 'libgcc_s.so.1')"
    vulkan_lib="$(find_library_dir 'libvulkan.so.1.4.*')"
    library_path="/run/opengl-driver/lib:${vulkan_lib}:${gcc_lib}:${gcc_libgcc}:${glibc_lib}"
  fi
  icd="${VK_ICD_FILENAMES:-/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json}"

  run_esrgan() {
    if [[ -x "$loader" ]]; then
      VK_ICD_FILENAMES="$icd" LD_LIBRARY_PATH="$library_path" \
        "$loader" --library-path "$library_path" "$realesrgan_bin" "$@"
    else
      "$realesrgan_bin" "$@"
    fi
  }

  model="${REALESRGAN_MODEL:-realesrgan-x4plus-anime}"
  # realesrgan-x4plus is a 4x model; using -s 2 with it produces corrupted
  # tiled output on the portable NCNN build. Downsampling to 1440p happens
  # after the valid 4x result is written.
  scale="${REALESRGAN_SCALE:-4}"
  tile="${REALESRGAN_TILE:-128}"
  gpu_id="${REALESRGAN_GPU_ID:-1}"
  threads="${REALESRGAN_THREADS:-1:1:1}"
  printf 'BACKEND bin=%s models=%s model=%s scale=%s tile=%s gpu=%s threads=%s\n' \
    "$realesrgan_bin" "$models_root" "$model" "$scale" "$tile" "$gpu_id" "$threads"
fi

failures=0
index=-1
while IFS= read -r item; do
  index=$((index + 1))
  if (( index % shard_count != shard_index )); then
    continue
  fi
  slug="$(jq -r '.slug' <<< "$item")"
  if (( ${#requested_slugs[@]} > 0 )) && [[ -z "${requested_slugs[$slug]:-}" ]]; then
    continue
  fi
  input="$wallpaper_root/32x9/$slug.png"
  staged="$stage_root/$slug.png"

  if [[ "$mode" == status ]]; then
    if [[ -s "$staged" ]]; then
      size="$($magick_bin identify -format '%wx%h' "$staged")"
      printf 'staged\t%s\t%s\n' "$slug" "$size"
    else
      printf 'missing\t%s\n' "$slug"
    fi
    continue
  fi

  if [[ "$mode" == run ]]; then
    if [[ -s "$staged" ]]; then
      printf 'Pomijam istniejący upscale: %s\n' "$slug"
      continue
    fi
    if [[ ! -s "$input" ]]; then
      printf 'Brak wejścia 32:9 dla %s.\n' "$slug" >&2
      failures=$((failures + 1))
      continue
    fi
    # NCNN expects the output path not to exist yet. Creating an empty
    # placeholder with mktemp can make some portable builds emit tiled data.
    tmp_dir="$(mktemp -d "$stage_root/.${slug}.XXXXXX")"
    tmp_output="$tmp_dir/upscaled.png"
    trap 'rm -rf -- "$tmp_dir"' EXIT
    printf 'INFERENCE slug=%s input=%s temp=%s\n' "$slug" "$input" "$tmp_output"
    if run_esrgan \
      -i "$input" \
      -o "$tmp_output" \
      -m "$models_root" \
      -n "$model" \
      -s "$scale" \
      -t "$tile" \
      -g "$gpu_id" \
      -j "$threads" \
      -f png; then
      "$magick_bin" "$tmp_output" \
        -resize '5120x1440!' \
        -strip -define png:color-type=2 -define png:compression-level=9 \
        "$staged"
      rm -rf -- "$tmp_dir"
      trap - EXIT
      printf 'Upscale gotowy: %s (%s, skala %s, tile %s, wątki %s).\n' "$slug" "$model" "$scale" "$tile" "$threads"
    else
      rm -rf -- "$tmp_dir"
      trap - EXIT
      printf 'Upscale nieudany: %s.\n' "$slug" >&2
      failures=$((failures + 1))
    fi
    continue
  fi

  if [[ ! -s "$staged" ]]; then
    printf 'Brak staged upscale dla %s.\n' "$slug" >&2
    failures=$((failures + 1))
    continue
  fi
  if [[ ! -s "$backup_root/$slug.png" ]]; then
    cp -- "$input" "$backup_root/$slug.png"
  fi
  cp -- "$staged" "$input"

  # For generated scenes, rebuild both crops from the improved 32:9 master
  # using the existing RAW-derived QA offsets. Existing ready scenes keep
  # their accepted 16:9/21:9 crops while their 32:9 master is improved.
  plan="$work_root/accepted/$slug.json"
  master="$work_root/masters/$slug.png"
  if [[ -s "$plan" && -s "$master" ]]; then
    cp -- "$staged" "$master"
    crop_16_x="$(jq -r '.crop16X // empty' "$plan")"
    crop_21_x="$(jq -r '.crop21X // empty' "$plan")"
    if [[ "$crop_16_x" =~ ^[0-9]+$ && "$crop_21_x" =~ ^[0-9]+$ ]]; then
      "$repo_root/tools/wallpapers/processing/finalize-imported.sh" \
        "$slug" "$master" "$crop_16_x" "$crop_21_x"
    else
      printf 'Niepełny plan QA dla %s; pozostawiam stare cropy.\n' "$slug" >&2
    fi
  fi
  printf 'Wypromowano: %s\n' "$slug"
done < <(jq -c '.wallpapers[]' "$manifest")

if (( failures > 0 )); then
  printf 'Nieukończone pozycje: %d.\n' "$failures" >&2
  exit 1
fi
