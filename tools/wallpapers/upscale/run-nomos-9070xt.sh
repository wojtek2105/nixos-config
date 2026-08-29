#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
data_root="${XDG_DATA_HOME:-${HOME:?}/.local/share}"
runtime_root="${NOMOS_RUNTIME_ROOT:-$data_root/wallpaper-nomos8kdat}"
image="${NOMOS_ROCM_IMAGE:-rocm/pytorch:rocm7.2.4_ubuntu24.04_py3.12_pytorch_release_2.10.0}"
model="$runtime_root/models/4xNomos8kDAT.safetensors"
python_dir="$runtime_root/python"
mode="${1:-test}"
slug="${2:-01-frieren}"

# Keep control images apart from the later batch candidate, otherwise a
# resumable batch would legitimately skip them as existing staging results.
default_stage_name="upscaled-32x9-nomos8kdat"
if [[ "$mode" == test ]]; then
  default_stage_name="upscaled-32x9-nomos8kdat-bf16-test"
elif [[ "$mode" == file ]]; then
  default_stage_name="upscaled-32x9-nomos8kdat-bf16-file"
elif [[ "$mode" == file-fp32 ]]; then
  default_stage_name="upscaled-32x9-nomos8kdat-fp32-file"
fi
stage_name="${UPSCALE_STAGE_NAME:-$default_stage_name}"

if [[ ! "$stage_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  printf 'UPSCALE_STAGE_NAME musi być bezpieczną nazwą katalogu.\n' >&2
  exit 64
fi

export UPSCALE_STAGE_NAME="$stage_name"
case "$mode" in
  status|promote)
    exec "$repo_root/tools/wallpapers/upscale/collection.sh" "$mode"
    ;;
  test|run|batch|slugs|file|file-fp32) ;;
  *)
    printf 'Użycie: %s [test [SLUG]|file /pełna/ścieżka.png|file-fp32 /pełna/ścieżka.png|slugs SLUG...|batch 1|2|3|run|status|promote]\n' "$0" >&2
    exit 64
    ;;
esac
if [[ "$mode" == slugs && $# -lt 2 ]]; then
  printf 'Tryb slugs wymaga co najmniej jednego sluga z collection.json.\n' >&2
  exit 64
fi
for command in docker flock readlink stat sha256sum; do
  command -v "$command" >/dev/null 2>&1 \
    || { printf 'Brak polecenia: %s\n' "$command" >&2; exit 1; }
done
[[ -s "$model" && -d "$python_dir" ]] || {
  printf 'Brak modelu lub środowiska. Uruchom: tools/wallpapers/upscale/install-nomos8kdat-rocm.sh\n' >&2
  exit 1
}
[[ -e /dev/kfd && -d /dev/dri ]] \
  || { printf 'Brak urządzeń ROCm /dev/kfd lub /dev/dri.\n' >&2; exit 1; }
docker info >/dev/null

if [[ "$mode" == file || "$mode" == file-fp32 ]]; then
  if [[ $# -ne 2 || "$slug" != /* || ! -f "$slug" ]]; then
    printf 'Tryb %s wymaga istniejącej pełnej ścieżki do jednego obrazu.\n' "$mode" >&2
    exit 64
  fi
  input_path="$(readlink -f -- "$slug")"
  input_dir="$(dirname -- "$input_path")"
  input_name="$(basename -- "$input_path")"
  input_hash="$(sha256sum -- "$input_path")"
  input_hash="${input_hash%% *}"
  output_stem="${input_name%.*}"
  output_stem="${output_stem//[^a-zA-Z0-9._-]/_}"
  output_name="${output_stem}-${input_hash:0:12}.png"
fi

# Prefer the AMD DRM device with the largest dedicated VRAM allocation. This
# distinguishes the 16 GiB RX 9070 XT from a small integrated Radeon without
# hard-coding PCI topology from one desktop build.
gpu_pci="${NOMOS_GPU_PCI:-}"
best_vram=0
if [[ -z "$gpu_pci" ]]; then
  for card in /sys/class/drm/card[0-9]*; do
    [[ -r "$card/device/vendor" && -r "$card/device/mem_info_vram_total" ]] || continue
    [[ "$(<"$card/device/vendor")" == 0x1002 ]] || continue
    vram="$(<"$card/device/mem_info_vram_total")"
    if (( vram > best_vram )); then
      best_vram="$vram"
      gpu_pci="$(basename -- "$(readlink -f "$card/device")")"
    fi
  done
fi
[[ -n "$gpu_pci" ]] || { printf 'Nie znaleziono karty AMD DRM z raportem VRAM.\n' >&2; exit 1; }

render_node=""
for candidate in /sys/class/drm/renderD*; do
  [[ -e "$candidate/device" ]] || continue
  if [[ "$(basename -- "$(readlink -f "$candidate/device")")" == "$gpu_pci" ]]; then
    render_node="/dev/dri/$(basename -- "$candidate")"
    break
  fi
done
[[ -n "$render_node" && -e "$render_node" ]] || {
  printf 'Nie znaleziono render node dla RX 9070 XT PCI %s.\n' "$gpu_pci" >&2
  exit 1
}

work_root="$repo_root/home/wojtek/wallpapers/work/import-48"
mkdir -p "$work_root/$stage_name"
printf 'Czekam na wyłączną blokadę GPU: %s\n' "$work_root/nomos-rocm-gpu.lock"
exec 9>"$work_root/nomos-rocm-gpu.lock"
flock -w "${NOMOS_LOCK_TIMEOUT:-86400}" 9 \
  || { printf 'Nie udało się uzyskać blokady GPU.\n' >&2; exit 1; }

container_name="wallpaper-nomos-9070xt-$$"
container_id=""
stop_container() {
  if [[ -n "$container_id" ]]; then
    docker stop --time 3 "$container_id" >/dev/null 2>&1 || true
  fi
}
trap 'stop_container; exit 130' INT TERM
trap 'stop_container' EXIT

# FP32 needs roughly 11 GiB for Nomos weights alone and leaves insufficient
# working memory on a 16 GiB card.  BF16 is the stable quality default here;
# request FP32 explicitly only on a GPU with substantially more free VRAM.
default_dtype="bfloat16"
default_tile="512"
default_min_free_vram_gib="0"
if [[ "$mode" == file-fp32 ]]; then
  default_dtype="float32"
  default_tile="256"
  # FP32 weights need ~11.4 GiB before activations; do not start a run that
  # cannot fit once the user has closed desktop or game processes on the GPU.
  default_min_free_vram_gib="14.0"
fi
gpu_ordinal="${NOMOS_GPU_ORDINAL:-0}"
docker_args=(
  run --rm
  --name "$container_name"
  --device /dev/kfd
  --device /dev/dri
  --ipc host
  --security-opt seccomp=unconfined
  -v "$repo_root:/repo"
  -v "$runtime_root:/runtime"
  -w /repo
  -e PYTHONPATH=/runtime/python
  -e ROCR_VISIBLE_DEVICES="$gpu_ordinal"
  -e HIP_VISIBLE_DEVICES=0
  -e PYTORCH_ALLOC_CONF=expandable_segments:True
  -e PYTORCH_HIP_ALLOC_CONF=expandable_segments:True
  # 832 can demand more than 8 GiB for a single 4x DAT activation, leaving no
  # headroom beside model weights on a 16 GiB card.  512 is the stable quality
  # default; override only after a clean control run.
  -e NOMOS_TILE="${NOMOS_TILE:-$default_tile}"
  -e NOMOS_AUTO_TILE="${NOMOS_AUTO_TILE:-1}"
  -e NOMOS_WARMUP="${NOMOS_WARMUP:-1}"
  -e NOMOS_OVERLAP="${NOMOS_OVERLAP:-32}"
  -e NOMOS_PAD_MULTIPLE="${NOMOS_PAD_MULTIPLE:-64}"
  -e NOMOS_DTYPE="${NOMOS_DTYPE:-$default_dtype}"
  -e NOMOS_MIN_VRAM_GIB="${NOMOS_MIN_VRAM_GIB:-12.0}"
  -e NOMOS_MIN_FREE_VRAM_GIB="${NOMOS_MIN_FREE_VRAM_GIB:-$default_min_free_vram_gib}"
  -e NOMOS_SOURCE_SCALE="${NOMOS_SOURCE_SCALE:-1.0}"
  -e NOMOS_BLEND="${NOMOS_BLEND:-0.65}"
  -e NOMOS_SHARPEN="${NOMOS_SHARPEN:-15}"
  -e NOMOS_OVERWRITE="${NOMOS_OVERWRITE:-0}"
)
if [[ "$mode" == file || "$mode" == file-fp32 ]]; then
  # The source mount is read-only; arbitrary user files can never be replaced.
  docker_args+=(-v "$input_dir:/input:ro")
fi

if [[ -n "${HSA_OVERRIDE_GFX_VERSION:-}" ]]; then
  docker_args+=(-e HSA_OVERRIDE_GFX_VERSION="$HSA_OVERRIDE_GFX_VERSION")
fi
for device in /dev/kfd "$render_node"; do
  device_group="$(stat -c '%g' "$device")"
  docker_args+=(--group-add "$device_group")
done

python_args=(
  python3 tools/wallpapers/upscale/nomos8kdat.py
  --model /runtime/models/4xNomos8kDAT.safetensors
  --manifest /repo/home/wojtek/wallpapers/collection.json
  --input-dir /repo/home/wojtek/wallpapers/work/import-48/masters
  --output-dir "/repo/home/wojtek/wallpapers/work/import-48/$stage_name"
)
if [[ "$mode" == test ]]; then
  python_args+=(--slug "$slug")
elif [[ "$mode" == batch ]]; then
  if [[ ! "$slug" =~ ^[123]$ ]]; then
    printf 'Batch musi mieć numer 1, 2 albo 3.\n' >&2
    exit 64
  fi
  python_args+=(--batch-index "$((slug - 1))" --batch-count 3)
elif [[ "$mode" == slugs ]]; then
  shift
  for selected_slug in "$@"; do
    python_args+=(--slug "$selected_slug")
  done
elif [[ "$mode" == file || "$mode" == file-fp32 ]]; then
  mkdir -p "$work_root/$stage_name/external"
  output_path="$work_root/$stage_name/external/$output_name"
  python_args+=(
    --input-file "/input/$input_name"
    --output-file "/repo/home/wojtek/wallpapers/work/import-48/$stage_name/external/$output_name"
    --target-width "${NOMOS_FILE_TARGET_WIDTH:-2560}"
    --target-height "${NOMOS_FILE_TARGET_HEIGHT:-1440}"
  )
fi

printf 'Nomos8kDAT RX 9070 XT: mode=%s dtype=%s source_scale=%s tile=%s overlap=%s blend=%s\n' \
  "$mode" "${NOMOS_DTYPE:-$default_dtype}" "${NOMOS_SOURCE_SCALE:-1.0}" \
  "${NOMOS_TILE:-$default_tile}" "${NOMOS_OVERLAP:-32}" "${NOMOS_BLEND:-0.65}"
printf 'GPU PCI=%s render=%s ROCm ordinal=%s; bez HSA override.\n' \
  "$gpu_pci" "$render_node" "$gpu_ordinal"
printf 'Staging: home/wojtek/wallpapers/work/import-48/%s\n' "$stage_name"
if [[ "$mode" == file || "$mode" == file-fp32 ]]; then
  printf 'Wejście tylko do odczytu: %s\nWynik: %s\n' "$input_path" "$output_path"
fi
printf 'Ctrl+C zatrzyma kontener i proces ROCm tego przebiegu.\n'

docker "${docker_args[@]}" "$image" "${python_args[@]}" &
container_id="$container_name"
wait "$!"
container_id=""
trap - EXIT INT TERM
