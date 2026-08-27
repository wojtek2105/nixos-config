#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
data_root="${XDG_DATA_HOME:-${HOME:?}/.local/share}"
runtime_root="${NOMOS_RUNTIME_ROOT:-$data_root/wallpaper-nomos8kdat}"
image="${NOMOS_ROCM_IMAGE:-rocm/pytorch:rocm7.2.4_ubuntu24.04_py3.12_pytorch_release_2.10.0}"
model="$runtime_root/models/4xNomos8kDAT.safetensors"
python_dir="$runtime_root/python"
stage_name="${UPSCALE_STAGE_NAME:-upscaled-32x9-nomos8kdat}"
gpu_pci="${NOMOS_GPU_PCI:-0000:03:00.0}"
mode="${1:-test}"
slug="${2:-01-frieren}"

if [[ ! "$stage_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  printf 'UPSCALE_STAGE_NAME musi być bezpieczną nazwą katalogu.\n' >&2
  exit 64
fi

export UPSCALE_STAGE_NAME="$stage_name"
case "$mode" in
  status|promote)
    exec "$repo_root/tools/wallpapers/upscale/collection.sh" "$mode"
    ;;
  test|run|batch) ;;
  *)
    printf 'Użycie: %s [test [SLUG]|batch 1|2|3|run|status|promote]\n' "$0" >&2
    exit 64
    ;;
esac

for command in docker flock readlink stat; do
  command -v "$command" >/dev/null 2>&1 || { printf 'Brak polecenia: %s\n' "$command" >&2; exit 1; }
done
[[ -s "$model" && -d "$python_dir" ]] || {
  printf 'Brak modelu lub środowiska. Uruchom: tools/wallpapers/upscale/install-nomos8kdat-rocm.sh\n' >&2
  exit 1
}
[[ -e /dev/kfd && -d /dev/dri ]] || { printf 'Brak urządzeń ROCm /dev/kfd lub /dev/dri.\n' >&2; exit 1; }
docker info >/dev/null

work_root="$repo_root/home/wojtek/wallpapers/work/import-48"
mkdir -p "$work_root/$stage_name"
printf 'Czekam na wyłączną blokadę GPU: %s\n' "$work_root/nomos-rocm-gpu.lock"
exec 9>"$work_root/nomos-rocm-gpu.lock"
flock -w "${NOMOS_LOCK_TIMEOUT:-86400}" 9 \
  || { printf 'Nie udało się uzyskać blokady GPU.\n' >&2; exit 1; }

render_node=""
for candidate in /sys/class/drm/renderD*; do
  [[ -e "$candidate/device" ]] || continue
  candidate_pci="$(basename -- "$(readlink -f "$candidate/device")")"
  if [[ "$candidate_pci" == "$gpu_pci" ]]; then
    render_node="/dev/dri/$(basename -- "$candidate")"
    break
  fi
done
[[ -n "$render_node" && -e "$render_node" ]] || {
  printf 'Nie znaleziono render node dla RX 6800S PCI %s.\n' "$gpu_pci" >&2
  exit 1
}

container_name="wallpaper-nomos-6800s-$$"
container_id=""
stop_container() {
  if [[ -n "$container_id" ]]; then
    docker stop --time 3 "$container_id" >/dev/null 2>&1 || true
  fi
}
trap 'stop_container; exit 130' INT TERM
trap 'stop_container' EXIT

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
  -e HSA_OVERRIDE_GFX_VERSION="${HSA_OVERRIDE_GFX_VERSION:-10.3.0}"
  -e ROCR_VISIBLE_DEVICES=0
  -e HIP_VISIBLE_DEVICES=0
  -e PYTORCH_ALLOC_CONF=expandable_segments:True
  -e PYTORCH_HIP_ALLOC_CONF=expandable_segments:True
  -e NOMOS_TILE="${NOMOS_TILE:-512}"
  -e NOMOS_AUTO_TILE="${NOMOS_AUTO_TILE:-1}"
  -e NOMOS_OVERLAP="${NOMOS_OVERLAP:-32}"
  -e NOMOS_PAD_MULTIPLE="${NOMOS_PAD_MULTIPLE:-64}"
  -e NOMOS_DTYPE="${NOMOS_DTYPE:-bfloat16}"
  -e NOMOS_SOURCE_SCALE="${NOMOS_SOURCE_SCALE:-1.0}"
  -e NOMOS_BLEND="${NOMOS_BLEND:-0.65}"
  -e NOMOS_SHARPEN="${NOMOS_SHARPEN:-15}"
  -e NOMOS_OVERWRITE="${NOMOS_OVERWRITE:-0}"
)

for device in /dev/kfd "$render_node"; do
  device_group="$(stat -c '%g' "$device")"
  docker_args+=(--group-add "$device_group")
done

python_args=(
  python3 tools/wallpapers/upscale/nomos8kdat.py
  --model /runtime/models/4xNomos8kDAT.safetensors
  --manifest /repo/home/wojtek/wallpapers/collection.json
  --input-dir /repo/home/wojtek/wallpapers/32x9
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
fi

printf 'Nomos8kDAT RX 6800S: mode=%s dtype=%s source_scale=%s tile=%s overlap=%s blend=%s, GPU PCI=%s (%s)\n' \
  "$mode" "${NOMOS_DTYPE:-bfloat16}" "${NOMOS_SOURCE_SCALE:-1.0}" \
  "${NOMOS_TILE:-512}" "${NOMOS_OVERLAP:-32}" "${NOMOS_BLEND:-0.65}" \
  "$gpu_pci" "$render_node"
printf 'Staging: home/wojtek/wallpapers/work/import-48/%s\n' "$stage_name"
printf 'Ctrl+C zatrzyma kontener i proces ROCm tego przebiegu.\n'

docker "${docker_args[@]}" "$image" "${python_args[@]}" &
container_id="$container_name"
wait "$!"
container_id=""
trap - EXIT INT TERM
