#!/usr/bin/env bash
set -euo pipefail

# High-quality AnimeSharp preset for the laptop RX 6800S (8 GiB) on NixOS.
# The model is identical to the 9070 XT profile; the smaller tile reduces peak
# VRAM use and trades throughput for stability.
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
data_root="${XDG_DATA_HOME:-${HOME:?}/.local/share}"
animesharp_models="${ANIMESHARP_MODELS:-$data_root/animesharp-ncnn/models}"

export REALESRGAN_BIN="${REALESRGAN_BIN:-$data_root/realesrgan-ncnn-vulkan/realesrgan-ncnn-vulkan}"
export REALESRGAN_MODELS="${REALESRGAN_MODELS:-$animesharp_models}"
export REALESRGAN_MODEL="${REALESRGAN_MODEL:-4x-AnimeSharp-fp16}"
export REALESRGAN_SCALE="${REALESRGAN_SCALE:-4}"
# 128 is the stable starting point for the full 23-block model on 8 GiB after
# tile 192 caused a Vulkan failure. Smaller tiles reduce peak VRAM use without
# changing target resolution or model quality, at the cost of throughput.
export REALESRGAN_TILE="${REALESRGAN_TILE:-128}"
# On rog-polamaniec Vulkan device 1 is the discrete RX 6800S; device 0 is 680M.
export REALESRGAN_GPU_ID="${REALESRGAN_GPU_ID:-1}"
# One worker is easier to recover after a driver reset. More shards would still
# wait on the single-GPU lock and would not increase inference throughput.
export UPSCALE_SHARDS="${UPSCALE_SHARDS:-1}"
export UPSCALE_STAGE_NAME="${UPSCALE_STAGE_NAME:-upscaled-32x9-animesharp}"

if [[ ! -s "$REALESRGAN_MODELS/$REALESRGAN_MODEL.param" \
  || ! -s "$REALESRGAN_MODELS/$REALESRGAN_MODEL.bin" ]]; then
  printf 'Brak modelu %s w %s.\n' "$REALESRGAN_MODEL" "$REALESRGAN_MODELS" >&2
  printf 'Najpierw uruchom: tools/wallpapers/upscale/install-animesharp-ncnn.sh\n' >&2
  exit 1
fi

printf 'Profil RX 6800S: model=%s, skala=%s, tile=%s, GPU=%s, workerów=%s\n' \
  "$REALESRGAN_MODEL" "$REALESRGAN_SCALE" "$REALESRGAN_TILE" \
  "$REALESRGAN_GPU_ID" "$UPSCALE_SHARDS"
printf 'Staging: work/import-48/%s; aktywne tapety pozostają bez zmian do promote.\n' \
  "$UPSCALE_STAGE_NAME"

mode="${1:-run}"
case "$mode" in
  run)
    exec "$repo_root/tools/wallpapers/upscale/run-night.sh"
    ;;
  status|promote)
    exec "$repo_root/tools/wallpapers/upscale/collection.sh" "$mode"
    ;;
  *)
    printf 'Użycie: %s [run|status|promote]\n' "$0" >&2
    exit 64
    ;;
esac
