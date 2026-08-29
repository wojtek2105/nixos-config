#!/usr/bin/env bash
set -euo pipefail

# High-quality preset for a standalone AMD Radeon RX 9070 XT (16 GiB) on
# NixOS. AnimeSharp is a full 23-block ESRGAN model and is substantially larger
# than the tiny RealESRGAN anime 6B fallback used on the laptop.
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
data_root="${XDG_DATA_HOME:-${HOME:?}/.local/share}"
animesharp_models="${ANIMESHARP_MODELS:-$data_root/animesharp-ncnn/models}"

export REALESRGAN_BIN="${REALESRGAN_BIN:-$data_root/realesrgan-ncnn-vulkan/realesrgan-ncnn-vulkan}"
export REALESRGAN_MODELS="${REALESRGAN_MODELS:-$animesharp_models}"
export REALESRGAN_MODEL="${REALESRGAN_MODEL:-4x-AnimeSharp-fp16}"
export REALESRGAN_SCALE="${REALESRGAN_SCALE:-4}"
# 384 is a safe starting point for 16 GiB. 512 can be tried after one clean
# run; lower it again if the Vulkan driver reports an out-of-memory/reset.
export REALESRGAN_TILE="${REALESRGAN_TILE:-384}"
# A machine with only the 9070 XT normally exposes it as Vulkan device 0.
# Override this when another GPU is present: REALESRGAN_GPU_ID=1.
export REALESRGAN_GPU_ID="${REALESRGAN_GPU_ID:-0}"
export UPSCALE_SHARDS="${UPSCALE_SHARDS:-4}"
export UPSCALE_STAGE_NAME="${UPSCALE_STAGE_NAME:-upscaled-32x9-animesharp}"

if [[ ! -s "$REALESRGAN_MODELS/$REALESRGAN_MODEL.param" \
  || ! -s "$REALESRGAN_MODELS/$REALESRGAN_MODEL.bin" ]]; then
  printf 'Brak modelu %s w %s.\n' "$REALESRGAN_MODEL" "$REALESRGAN_MODELS" >&2
  printf 'Najpierw uruchom: tools/wallpapers/upscale/install-animesharp-ncnn.sh\n' >&2
  exit 1
fi

printf 'Profil RX 9070 XT: model=%s, skala=%s, tile=%s, GPU=%s, workerów=%s\n' \
  "$REALESRGAN_MODEL" "$REALESRGAN_SCALE" "$REALESRGAN_TILE" \
  "$REALESRGAN_GPU_ID" "$UPSCALE_SHARDS"
printf 'Uwaga: workery są podzielone na shardy, ale blokada GPU wykonuje inferencję po jednym na karcie.\n'
printf 'Wyniki trafiają do stagingu; ten przebieg nie nadpisuje aktywnych tapet.\n'

mode="${1:-run}"
case "$mode" in
  run)
    exec "$repo_root/tools/wallpapers/upscale/run-night.sh"
    ;;
  slugs)
    if [[ $# -lt 2 ]]; then
      printf 'Tryb slugs wymaga co najmniej jednego sluga z collection.json.\n' >&2
      exit 64
    fi
    shift
    for selected_slug in "$@"; do
      if [[ ! "$selected_slug" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        printf 'Nieprawidłowy slug: %s\n' "$selected_slug" >&2
        exit 64
      fi
    done
    # One GPU worker is deliberate: parallel shards would only queue on the
    # global GPU lock and would make the selected-output logs harder to review.
    export UPSCALE_SLUGS="$*"
    export UPSCALE_SHARDS=1
    exec "$repo_root/tools/wallpapers/upscale/run-night.sh"
    ;;
  status|promote)
    exec "$repo_root/tools/wallpapers/upscale/collection.sh" "$mode"
    ;;
  *)
    printf 'Użycie: %s [run|slugs SLUG...|status|promote]\n' "$0" >&2
    exit 64
    ;;
esac
