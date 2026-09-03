#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
runtime_root="${FLUX2_RUNTIME_ROOT:-${XDG_DATA_HOME:-${HOME:?}/.local/share}/wallpaper-flux2-klein}"
rocm_image="${FLUX2_ROCM_IMAGE:-rocm/pytorch:rocm7.2.4_ubuntu24.04_py3.12_pytorch_release_2.10.0}"
gpu_pci="${FLUX2_GPU_PCI:-0000:03:00.0}"
render_node="${FLUX2_RENDER_NODE:-}"
container_name="wallpaper-flux2-klein-test-${BASHPID}"
container_label="wallpaper.flux2.runner=klein-test"
mode="${1:-run}"

case "$mode" in
  run|gpu-info|status) ;;
  *)
    printf 'Użycie: %s [run|gpu-info|status] [INPUT [OUTPUT]]\n' "$0" >&2
    exit 64
    ;;
esac

input="${2:-$repo_root/home/base/wallpapers/32x9/01-frieren.png}"
output="${3:-$repo_root/home/base/wallpapers/work/import-48/flux2-klein-tests/01-frieren-klein4b.png}"
prompt_file="${FLUX2_PROMPT_FILE:-$repo_root/tools/wallpapers/flux2/prompts/preserve-anime-detail.txt}"

if [[ -z "$render_node" ]]; then
  for candidate in /sys/class/drm/renderD*/device; do
    [[ -e "$candidate" ]] || continue
    if [[ "$(realpath -- "$candidate")" == */"$gpu_pci" ]]; then
      render_node="/dev/dri/$(basename -- "${candidate%/device}")"
      break
    fi
  done
fi

if [[ "$mode" == status ]]; then
  [[ -d "$runtime_root/python/diffusers" ]] && environment_state=ready || environment_state=missing
  [[ -s "$output" ]] && output_state=ready || output_state=missing
  docker_state=stopped
  if command -v docker >/dev/null 2>&1 \
    && docker ps --filter "label=$container_label" --format '{{.Names}}' 2>/dev/null | grep -q .; then
    docker_state=running
  fi
  printf 'environment\t%s\t%s\n' "$environment_state" "$runtime_root"
  printf 'model-cache\t%s\n' "$runtime_root/hf-cache"
  printf 'gpu-pci\t%s\n' "$gpu_pci"
  printf 'render-node\t%s\n' "${render_node:-missing}"
  printf 'hsa-override\t%s\n' "${HSA_OVERRIDE_GFX_VERSION:-10.3.0}"
  printf 'container\t%s\t%s\n' "$docker_state" "$container_label"
  printf 'candidate\t%s\t%s\n' "$output_state" "$output"
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  printf 'Docker nie działa. Uruchom go ręcznie: sudo systemctl start docker\n' >&2
  exit 1
fi
if [[ -z "$render_node" || ! -c /dev/kfd || ! -d /dev/dri || ! -c "$render_node" ]]; then
  printf 'Brak urządzenia ROCm: /dev/kfd lub %s.\n' "$render_node" >&2
  printf 'Oczekiwany adres PCI dGPU: %s; nadpisz FLUX2_GPU_PCI lub FLUX2_RENDER_NODE.\n' "$gpu_pci" >&2
  exit 1
fi
render_sysfs="/sys/class/drm/$(basename -- "$render_node")/device"
if [[ ! -r "$render_sysfs/vendor" || "$(< "$render_sysfs/vendor")" != 0x1002 ]]; then
  printf 'Wybrany render node nie jest urządzeniem AMD: %s\n' "$render_node" >&2
  exit 1
fi
if [[ ! -d "$runtime_root/python/diffusers" ]]; then
  printf 'Brak środowiska FLUX. Najpierw uruchom tools/wallpapers/flux2/install.sh\n' >&2
  exit 1
fi

if [[ "$mode" == run ]]; then
  if [[ ! -s "$input" || ! -s "$prompt_file" ]]; then
    printf 'Brak wejścia (%s) albo promptu (%s).\n' "$input" "$prompt_file" >&2
    exit 1
  fi
  if [[ -e "$output" && "${FLUX2_OVERWRITE:-0}" != 1 ]]; then
    printf 'Wynik już istnieje: %s. Ustaw FLUX2_OVERWRITE=1, aby go zastąpić.\n' "$output" >&2
    exit 1
  fi
  mkdir -p "$(dirname -- "$output")"
fi

container_id=""
partial_output=""
stop_container() {
  if [[ -n "$container_id" ]]; then
    docker stop --time 10 "$container_id" >/dev/null 2>&1 || true
    container_id=""
  fi
  if [[ -n "$partial_output" ]]; then
    rm -f -- "$partial_output"
  fi
}
trap 'stop_container; exit 130' INT
trap 'stop_container; exit 143' TERM HUP
trap stop_container EXIT

docker_args=(
  run --rm
  --name "$container_name"
  --label "$container_label"
  --user "$(id -u):$(id -g)"
  --device /dev/kfd
  # ROCr enumerates topology through the complete DRM directory. Restricting
  # the container to one render node can make KFD visible while HIP still sees
  # no usable agent, so expose DRM and select the dGPU through ROCr/HIP below.
  --device /dev/dri
  --group-add "$(stat -c %g /dev/kfd)"
  --group-add "$(stat -c %g "$render_node")"
  --ipc host
  --security-opt seccomp=unconfined
  --env HOME=/runtime/home
  --env HF_HOME=/runtime/hf-cache
  --env HSA_OVERRIDE_GFX_VERSION="${HSA_OVERRIDE_GFX_VERSION:-10.3.0}"
  --env HIP_VISIBLE_DEVICES="${HIP_VISIBLE_DEVICES:-0}"
  --env ROCR_VISIBLE_DEVICES="${ROCR_VISIBLE_DEVICES:-0}"
  --env PYTHONPATH=/runtime/python
  --env PYTORCH_HIP_ALLOC_CONF="${PYTORCH_HIP_ALLOC_CONF:-expandable_segments:True}"
  --volume "$runtime_root:/runtime"
  --volume "$repo_root:/repo"
  --workdir /repo
)

if [[ "$mode" == gpu-info ]]; then
  docker "${docker_args[@]}" "$rocm_image" \
    bash -lc '
      set -euo pipefail
      printf "devices: "; ls -l /dev/kfd /dev/dri/renderD* || true
      printf "visibility: ROCR=%s HIP=%s HSA_OVERRIDE=%s\n" \
        "${ROCR_VISIBLE_DEVICES:-unset}" \
        "${HIP_VISIBLE_DEVICES:-unset}" \
        "${HSA_OVERRIDE_GFX_VERSION:-unset}"
      if command -v rocminfo >/dev/null 2>&1; then
        rocminfo 2>&1 | grep -E "^  Name:|^  Marketing Name:|^  Vendor Name:|gfx[0-9]+" | head -n 80 || true
      fi
      python3 -c '\''import torch; print("torch", torch.__version__); print("HIP", torch.version.hip); available = torch.cuda.is_available(); print("available", available); print("GPU_count", torch.cuda.device_count()); assert available, "ROCm GPU unavailable after KFD/DRM preflight"; p = torch.cuda.get_device_properties(0); print("GPU", p.name); print("arch", getattr(p, "gcnArchName", "unknown")); print("VRAM_GiB", round(p.total_memory / 2**30, 2))'\''
    '
  trap - INT TERM HUP EXIT
  exit 0
fi

input="$(realpath -- "$input")"
output="$(realpath -m -- "$output")"
prompt_file="$(realpath -- "$prompt_file")"
for path in "$input" "$output" "$prompt_file"; do
  if [[ "$path" != "$repo_root"/* ]]; then
    printf 'FLUX przyjmuje pliki wyłącznie z repozytorium: %s\n' "$path" >&2
    exit 1
  fi
done
partial_output="$(dirname -- "$output")/.$(basename -- "$output").part"
container_input="/repo/${input#"$repo_root"/}"
container_output="/repo/${output#"$repo_root"/}"
container_prompt="/repo/${prompt_file#"$repo_root"/}"

printf 'FLUX.2 Klein test: %s -> %s\n' "$input" "$output"
printf 'GPU PCI=%s, render=%s, HSA override=%s\n' \
  "$gpu_pci" "$render_node" "${HSA_OVERRIDE_GFX_VERSION:-10.3.0}"
printf 'Ctrl+C zatrzyma także kontener i proces ROCm.\n'
container_id="$container_name"
token_args=()
if [[ -n "${HF_TOKEN:-}" ]]; then
  token_args+=(--env HF_TOKEN)
fi
docker "${docker_args[@]}" \
  "${token_args[@]}" \
  --env FLUX2_WIDTH="${FLUX2_WIDTH:-1024}" \
  --env FLUX2_HEIGHT="${FLUX2_HEIGHT:-288}" \
  --env FLUX2_DTYPE="${FLUX2_DTYPE:-float16}" \
  --env FLUX2_STEPS="${FLUX2_STEPS:-4}" \
  --env FLUX2_SEED="${FLUX2_SEED:-24012026}" \
  --env FLUX2_OFFLOAD="${FLUX2_OFFLOAD:-sequential}" \
  --env FLUX2_MODEL="${FLUX2_MODEL:-black-forest-labs/FLUX.2-klein-4B}" \
  "$rocm_image" \
  python3 tools/wallpapers/flux2/enhance.py \
    "$container_input" "$container_output" "$container_prompt" &

status=0
wait "$!" || status="$?"
container_id=""
rm -f -- "$partial_output"
trap - INT TERM HUP EXIT
exit "$status"
